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
              // 1. DADOS DE HOJE
              final agendamentosHoje = todos
                  .where((a) => a.data.year == hoje.year && a.data.month == hoje.month && a.data.day == hoje.day)
                  .toList();
              final livres = InteligenciaService.horariosLivresNoDia(agendamentosHoje);

              // 2. FILTRAGEM DE PERÍODOS
              final inicioMes = _mesSelecionado;
              final fimMes = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0, 23, 59, 59);
              
              final inicioMesAnterior = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1, 1);
              final fimMesAnterior = DateTime(_mesSelecionado.year, _mesSelecionado.month, 0, 23, 59, 59);

              double receitaMes = 0;
              int procedimentosMes = 0;
              int minutosMes = 0;
              final servicosMes = <String, double>{};
              final faturamentoPorDia = <int, double>{}; // Para o Calendário Mensal

              double receitaMesAnterior = 0;
              int procedimentosMesAnterior = 0;
              int minutosMesAnterior = 0;
              final servicosMesAnterior = <String, double>{};

              final ocupacaoPorDiaSemana = {2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

              // 3. VARREDURA DE DADOS (Cálculo de Eficiência)
              for (final a in todos) {
                if (a.clienteId == 'BLOQUEIO' || a.status == AgendamentoStatus.cancelado) continue;

                if (a.data.isAfter(inicioMes.subtract(const Duration(seconds: 1))) && 
                    a.data.isBefore(fimMes.add(const Duration(seconds: 1)))) {
                  receitaMes += a.valor;
                  procedimentosMes++;
                  minutosMes += a.duracaoMinutos;
                  servicosMes[a.servico] = (servicosMes[a.servico] ?? 0) + a.valor;
                  
                  // Para o calendário de calor
                  faturamentoPorDia[a.data.day] = (faturamentoPorDia[a.data.day] ?? 0) + a.valor;

                  if (ocupacaoPorDiaSemana.containsKey(a.data.weekday)) {
                    ocupacaoPorDiaSemana[a.data.weekday] = ocupacaoPorDiaSemana[a.data.weekday]! + 1;
                  }
                } else if (a.data.isAfter(inicioMesAnterior.subtract(const Duration(seconds: 1))) && 
                           a.data.isBefore(fimMesAnterior.add(const Duration(seconds: 1)))) {
                  receitaMesAnterior += a.valor;
                  procedimentosMesAnterior++;
                  minutosMesAnterior += a.duracaoMinutos;
                  servicosMesAnterior[a.servico] = (servicosMesAnterior[a.servico] ?? 0) + a.valor;
                }
              }

              // 4. MÁQUINAS DE CÁLCULO DA IA
              final tmMes = procedimentosMes > 0 ? receitaMes / procedimentosMes : 0.0;
              final tmMesAnterior = procedimentosMesAnterior > 0 ? receitaMesAnterior / procedimentosMesAnterior : 0.0;

              final horasMes = minutosMes / 60.0;
              final horasMesAnterior = minutosMesAnterior / 60.0;
              final rentabilidadeHora = horasMes > 0 ? receitaMes / horasMes : 0.0;
              final rentabilidadeHoraAnterior = horasMesAnterior > 0 ? receitaMesAnterior / horasMesAnterior : 0.0;

              // Identificar o serviço destaque (maior crescimento absoluto)
              String servicoDestaque = '';
              double valorCrescimentoServico = 0;
              servicosMes.forEach((nome, valorAtual) {
                final valorAnt = servicosMesAnterior[nome] ?? 0.0;
                final diff = valorAtual - valorAnt;
                if (diff > valorCrescimentoServico) {
                  valorCrescimentoServico = diff;
                  servicoDestaque = nome;
                }
              });

              // Identificar Dia Mais Fraco
              int diaMaisFraco = 2; 
              int minOcupacao = 9999;
              ocupacaoPorDiaSemana.forEach((dia, qtd) {
                if (qtd < minOcupacao) {
                  minOcupacao = qtd;
                  diaMaisFraco = dia;
                }
              });
              final nomesDias = {2: 'Terça', 3: 'Quarta', 4: 'Quinta', 5: 'Sexta', 6: 'Sábado'};
              final nomeDiaFraco = nomesDias[diaMaisFraco] ?? 'Terça';

              // 5. CLIENTES PARA REATIVAÇÃO ESTRATÉGICA
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
                      Text('Análise do Mês', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        _CardMetricaIA(titulo: 'Rentabilidade/Hora', valorAtual: rentabilidadeHora, valorAnterior: rentabilidadeHoraAnterior, ehMoeda: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- CALENDÁRIO MENSAL (MAPA DE CALOR) ---
                  _CalendarioMensalCalor(
                    mesReferencia: _mesSelecionado,
                    faturamentoPorDia: faturamentoPorDia,
                  ),
                  const SizedBox(height: 24),

                  // --- INTELIGÊNCIA DE NEGÓCIOS (TEXTO ESTRATÉGICO) ---
                  Text('Diagnóstico de Negócios (IA)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                            const Text('Sócio Estratégico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Bloco 1: Eficiência de Tempo
                        _BlocoTextoIA(
                          titulo: 'Eficiência de Tempo:',
                          texto: 'Você trabalhou ${horasMes.toStringAsFixed(1)} horas até agora neste mês. '
                                 'Sua hora na cadeira está rendendo ${formatarMoedaIA(rentabilidadeHora)} '
                                 '(${rentabilidadeHora > rentabilidadeHoraAnterior ? 'crescimento' : 'queda'} em relação ao mês passado).',
                        ),
                        const SizedBox(height: 12),
                        
                        // Bloco 2: Mix de Serviços
                        if (servicoDestaque.isNotEmpty && valorCrescimentoServico > 0)
                          _BlocoTextoIA(
                            titulo: 'Mix de Serviços:',
                            texto: 'O serviço de "$servicoDestaque" impulsionou seu caixa trazendo ${formatarMoedaIA(valorCrescimentoServico)} a mais que no mês passado. '
                                   'Sinal de que suas clientes estão buscando mais este procedimento. Ofereça-o ativamente no checklist pré-atendimento!',
                          ),
                        const SizedBox(height: 12),

                        // Bloco 3: Plano de Ação de Marketing
                        _BlocoTextoIA(
                          titulo: 'Plano de Ação (Marketing):',
                          texto: 'Sua $nomeDiaFraco-feira é o dia mais ocioso. '
                                 'Regra de Mercado: Nunca dê desconto no valor principal. Crie o "Combo $nomeDiaFraco VIP": '
                                 'Ao agendar uma manutenção/procedimento principal, a cliente ganha um Spa de Hidratação (custo baixo para você, alto valor percebido para ela).',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- ALVOS PARA REATIVAÇÃO ---
                  Text('Alvos Estratégicos (Reativação)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('Aplique a técnica de Ancoragem de Valor para recuperar estas clientes:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  
                  if (atrasados.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Sua taxa de retenção está perfeita!')))
                  else
                    ...atrasados.map((c) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: Icon(Icons.auto_graph, color: Colors.orange.shade800, size: 20),
                            ),
                            title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Ciclo de retorno atrasado desde ${fmtData.format(c.sugerida)}'),
                            trailing: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade700,
                                side: BorderSide(color: Colors.green.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              icon: const Icon(Icons.chat, size: 16),
                              label: const Text('Abordar', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                // ENVIO ESTRATÉGICO BASEADO EM VALOR
                                final agendamentoOferta = Agendamento(
                                  id: 'oferta_ia',
                                  clienteId: c.id,
                                  data: DateTime.now(),
                                  horaInicio: '✨',
                                  horaFim: '🎁',
                                  duracaoMinutos: 0,
                                  servico: 'Condição VIP ($nomeDiaFraco)',
                                  valor: 0.0,
                                  status: AgendamentoStatus.agendado,
                                  observacao: 'Oferta Estratégica: Agregando valor sem desconto direto.',
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
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// COMPONENTE: Calendário Mensal (Mapa de Calor)
class _CalendarioMensalCalor extends StatelessWidget {
  const _CalendarioMensalCalor({required this.mesReferencia, required this.faturamentoPorDia});
  final DateTime mesReferencia;
  final Map<int, double> faturamentoPorDia;

  @override
  Widget build(BuildContext context) {
    final diasNoMes = DateTime(mesReferencia.year, mesReferencia.month + 1, 0).day;
    final primeiroDiaDaSemana = DateTime(mesReferencia.year, mesReferencia.month, 1).weekday; 
    
    // Calcula média para o mapa de calor
    double totalMes = 0;
    int diasTrabalhados = 0;
    faturamentoPorDia.forEach((_, valor) {
      if (valor > 0) {
        totalMes += valor;
        diasTrabalhados++;
      }
    });
    final mediaDiaria = diasTrabalhados > 0 ? totalMes / diasTrabalhados : 0.0;

    final diasGrid = <Widget>[];
    final cabecalhos = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    
    for (var d in cabecalhos) {
      diasGrid.add(Center(child: Text(d, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))));
    }

    final ajusteSemana = primeiroDiaDaSemana == 7 ? 0 : primeiroDiaDaSemana; // Domingo no Dart é 7, queremos que seja 0 no array
    
    for (int i = 0; i < ajusteSemana; i++) {
      diasGrid.add(const SizedBox()); // Espaços vazios antes do dia 1
    }

    for (int dia = 1; dia <= diasNoMes; dia++) {
      final faturamento = faturamentoPorDia[dia] ?? 0.0;
      
      Color corFundo = Colors.grey.shade100;
      Color corTexto = Colors.grey.shade700;

      if (faturamento > 0) {
        if (faturamento > mediaDiaria * 1.2) {
          corFundo = Colors.green.shade400; // Dia Forte
          corTexto = Colors.white;
        } else if (faturamento < mediaDiaria * 0.7) {
          corFundo = Colors.orange.shade300; // Dia Fraco
          corTexto = Colors.white;
        } else {
          corFundo = Colors.green.shade200; // Dia na Média
          corTexto = Colors.white;
        }
      }

      diasGrid.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: corFundo, borderRadius: BorderRadius.circular(4)),
          child: Center(
            child: Text('$dia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: corTexto)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mapa de Calor Mensal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Text('Dias verdes representam picos de receita acima da sua média.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: diasGrid,
        ),
      ],
    );
  }
}

class _BlocoTextoIA extends StatelessWidget {
  const _BlocoTextoIA({required this.titulo, required this.texto});
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(color: Colors.purple.shade900, fontSize: 13, height: 1.4),
        children: [
          TextSpan(text: '$titulo ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: texto),
        ],
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

    if (valorAnterior > 0) {
      final variacao = ((valorAtual - valorAnterior) / valorAnterior) * 100;
      txtEvolucao = '${variacao > 0 ? '+' : ''}${variacao.toStringAsFixed(1)}%';
      
      if (variacao >= 10) {
        corBadge = Colors.green;
        iconeSeta = Icons.trending_up;
      } else if (variacao <= -5) {
        corBadge = Colors.red;
        iconeSeta = Icons.trending_down;
      } else {
        corBadge = Colors.amber.shade700;
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
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
            decoration: BoxDecoration(color: corBadge.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
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
