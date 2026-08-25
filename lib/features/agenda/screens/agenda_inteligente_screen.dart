import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/storage/whatsapp_service.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/agendamento_controller.dart';
import '../models/agendamento.dart';
import '../services/inteligencia_service.dart';

String formatarMoedaIA(double valor) {
  return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
}

class AgendaInteligenteScreen extends ConsumerStatefulWidget {
  const AgendaInteligenteScreen({super.key});

  @override
  ConsumerState<AgendaInteligenteScreen> createState() => _AgendaInteligenteScreenState();
}

class _AgendaInteligenteScreenState extends ConsumerState<AgendaInteligenteScreen> {
  DateTime _mesSelecionado = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    final fmtData = DateFormat('dd/MM/yyyy');
    final hoje = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conselheiro IA', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      ),
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar clientes: $e')),
        data: (clientes) {
          return todosAgendamentosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro ao carregar agendamentos: $e')),
            data: (todos) {
              // 1. DADOS ORIGINAIS MANTIDOS
              final agendamentosHoje = todos
                  .where((a) => a.data.year == hoje.year && a.data.month == hoje.month && a.data.day == hoje.day)
                  .toList();
              final livres = InteligenciaService.horariosLivresNoDia(agendamentosHoje);

              // 2. FILTRAGEM DO MÊS SELECIONADO E MÊS ANTERIOR
              final inicioMes = _mesSelecionado;
              final fimMes = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0, 23, 59, 59);
              
              final inicioMesAnterior = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1, 1);
              final fimMesAnterior = DateTime(_mesSelecionado.year, _mesSelecionado.month, 0, 23, 59, 59);

              double receitaMes = 0;
              int procedimentosMes = 0;
              double receitaMesAnterior = 0;
              int procedimentosMesAnterior = 0;

              // 3. ANÁLISE DE OCIOSIDADE (Terça = 2 a Sábado = 6)
              final ocupacaoPorDia = {2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

              for (final a in todos) {
                if (a.clienteId == 'BLOQUEIO' || a.status == AgendamentoStatus.cancelado) continue;

                if (a.data.isAfter(inicioMes.subtract(const Duration(seconds: 1))) && 
                    a.data.isBefore(fimMes.add(const Duration(seconds: 1)))) {
                  receitaMes += a.valor;
                  procedimentosMes++;
                  
                  if (ocupacaoPorDia.containsKey(a.data.weekday)) {
                    ocupacaoPorDia[a.data.weekday] = ocupacaoPorDia[a.data.weekday]! + 1;
                  }
                } else if (a.data.isAfter(inicioMesAnterior.subtract(const Duration(seconds: 1))) && 
                           a.data.isBefore(fimMesAnterior.add(const Duration(seconds: 1)))) {
                  receitaMesAnterior += a.valor;
                  procedimentosMesAnterior++;
                }
              }

              final tmMes = procedimentosMes > 0 ? receitaMes / procedimentosMes : 0.0;
              final tmMesAnterior = procedimentosMesAnterior > 0 ? receitaMesAnterior / procedimentosMesAnterior : 0.0;

              // DESCOBRIR O DIA MAIS FRACO
              int diaMaisFraco = 2; // Inicia na Terça
              int minOcupacao = 9999;
              ocupacaoPorDia.forEach((dia, qtd) {
                if (qtd < minOcupacao) {
                  minOcupacao = qtd;
                  diaMaisFraco = dia;
                }
              });
              final nomesDias = {2: 'Terça', 3: 'Quarta', 4: 'Quinta', 5: 'Sexta', 6: 'Sábado'};
              final nomeDiaFraco = nomesDias[diaMaisFraco] ?? 'Terça';

              // 4. CLIENTES PARA REATIVAÇÃO (Lógica original aprimorada com IA)
              final atrasados = <({String id, String nome, String telefone, DateTime sugerida})>[];
              for (final c in clientes) {
                final doCliente = todos.where((a) => a.clienteId == c.id).toList();
                final info = InteligenciaService.calcularParaCliente(doCliente);
                if (info.atrasado && info.proximaDataSugerida != null) {
                  atrasados.add((id: c.id, nome: c.nome, telefone: c.telefone, sugerida: info.proximaDataSugerida!));
                }
              }
              atrasados.sort((a, b) => a.sugerida.compareTo(b.sugerida));

              // SELETOR DE MESES
              List<DateTime> ultimosMeses = List.generate(6, (index) {
                return DateTime(hoje.year, hoje.month - index, 1);
              });

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- CABEÇALHO COM HISTÓRICO ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Desempenho Mensal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      DropdownButton<DateTime>(
                        value: _mesSelecionado,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.calendar_month, size: 18),
                        items: ultimosMeses.map((data) {
                          final label = DateFormat('MMMM yyyy', 'pt_BR').format(data);
                          return DropdownMenuItem(
                            value: data,
                            child: Text(label[0].toUpperCase() + label.substring(1), style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _mesSelecionado = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- CARDS DE MÉTRICAS COMPARATIVAS ---
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CardMetricaIA(titulo: 'Faturamento', valorAtual: receitaMes, valorAnterior: receitaMesAnterior, ehMoeda: true),
                        const SizedBox(width: 12),
                        _CardMetricaIA(titulo: 'Ticket Médio', valorAtual: tmMes, valorAnterior: tmMesAnterior, ehMoeda: true),
                        const SizedBox(width: 12),
                        _CardMetricaIA(titulo: 'Procedimentos', valorAtual: procedimentosMes.toDouble(), valorAnterior: procedimentosMesAnterior.toDouble(), ehMoeda: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- RAIO-X DE OCIOSIDADE (ESTRATÉGIA IA) ---
                  Text('Estratégia de Crescimento', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology, color: Colors.purple, size: 28),
                            const SizedBox(width: 8),
                            const Text('Análise da Inteligência', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.purple.shade900, fontSize: 14, height: 1.4),
                            children: [
                              const TextSpan(text: 'Analisando os horários deste mês (ignorando domingos e segundas), notei que a sua '),
                              TextSpan(text: '$nomeDiaFraco-feira', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' é o dia com a menor taxa de ocupação da agenda.\n\n'),
                              const TextSpan(text: '💡 Ação Recomendada: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: 'Crie um combo ou ofereça 10% de desconto exclusivo para reativar clientes sumidas utilizando os horários livres de $nomeDiaFraco.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- ALVOS PARA REATIVAÇÃO ---
                  Text('Alvos para Reativação', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('Clientes inativas prontas para receber sua oferta:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  
                  if (atrasados.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Todas as clientes estão com o retorno em dia!')))
                  else
                    ...atrasados.map((c) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                            ),
                            title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Retorno sugerido: ${fmtData.format(c.sugerida)}'),
                            trailing: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade700,
                                side: BorderSide(color: Colors.green.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              icon: const Icon(Icons.chat, size: 16), // Corrigido para Icons.chat
                              label: const Text('Convidar', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                // CORREÇÃO: Utiliza o envio de confirmação com um agendamento fictício de oferta, igual ao Dashboard!
                                final agendamentoOferta = Agendamento(
                                  id: 'oferta_ia',
                                  clienteId: c.id,
                                  data: DateTime.now(),
                                  horaInicio: '🎁',
                                  horaFim: '✨',
                                  duracaoMinutos: 0,
                                  servico: 'Condição Especial ($nomeDiaFraco)',
                                  valor: 0.0,
                                  status: AgendamentoStatus.agendado,
                                  observacao: 'Sentimos sua falta! Volte a se cuidar conosco.',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );
                                
                                WhatsAppService.enviarConfirmacao(
                                  telefone: c.telefone,
                                  nomeCliente: c.nome,
                                  agendamento: agendamentoOferta,
                                );
                              },
                            ),
                          ),
                        )),
                  const SizedBox(height: 24),

                  // --- HORÁRIOS LIVRES HOJE (MANTIDO DO ORIGINAL) ---
                  Text('Horários livres hoje', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (livres.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Nenhum horário livre hoje.')))
                  else
                    ...livres.map((f) => Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.schedule, color: Colors.grey),
                            title: Text('${f.inicio} – ${f.fim}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ),
                        )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CardMetricaIA extends StatelessWidget {
  const _CardMetricaIA({
    required this.titulo,
    required this.valorAtual,
    required this.valorAnterior,
    required this.ehMoeda,
  });

  final String titulo;
  final double valorAtual;
  final double valorAnterior;
  final bool ehMoeda;

  @override
  Widget build(BuildContext context) {
    Color corBadge = Colors.grey;
    IconData iconeSeta = Icons.remove;
    String txtEvolucao = 'Sem base';

    // Regras de negócio da Inteligência
    if (valorAnterior > 0) {
      final variacao = ((valorAtual - valorAnterior) / valorAnterior) * 100;
      txtEvolucao = '${variacao > 0 ? '+' : ''}${variacao.toStringAsFixed(1)}%';
      
      if (variacao >= 10) {
        corBadge = Colors.green; // Excelente
        iconeSeta = Icons.trending_up;
      } else if (variacao <= -5) {
        corBadge = Colors.red; // Atenção
        iconeSeta = Icons.trending_down;
      } else {
        corBadge = Colors.amber.shade700; // Estável
        iconeSeta = Icons.trending_flat;
      }
    } else if (valorAtual > 0) {
      corBadge = Colors.green;
      iconeSeta = Icons.trending_up;
      txtEvolucao = 'Novo!';
    }

    final exibicaoValor = ehMoeda ? formatarMoedaIA(valorAtual) : valorAtual.toInt().toString();

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600), maxLines: 1),
          const SizedBox(height: 4),
          Text(exibicaoValor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: corBadge.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconeSeta, size: 12, color: corBadge),
                const SizedBox(width: 2),
                Text(txtEvolucao, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: corBadge)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
