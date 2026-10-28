import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/storage/whatsapp_service.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../../clientes/models/cliente.dart';
import '../../agenda/services/inteligencia_service.dart';

String formatarMoedaIA(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

class AnaliseIaScreen extends ConsumerStatefulWidget {
  const AnaliseIaScreen({super.key});

  @override
  ConsumerState<AnaliseIaScreen> createState() => _AnaliseIaScreenState();
}

class _AnaliseIaScreenState extends ConsumerState<AnaliseIaScreen> {
  DateTime _mesSelecionado = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final NumberFormat _fmtMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // 🎨 NOVA IDENTIDADE VISUAL (VERDE SÁLVIA)
  final Color _primaryColor = const Color(0xFF3A4E40); // Verde Escuro Principal
  final Color _lightAccent = const Color(0xFFE8EFEA);  // Verde Claro (Fundos)
  final Color _borderAccent = const Color(0xFFB5C4B9); // Verde Intermédio (Bordas)

  // ============================================================================
  // 🧠 O CÉREBRO DA IA: ALGORITMO PREDITIVO DE FATURAMENTO
  // ============================================================================
  Map<String, dynamic> _processarInteligenciaArtificial(List<Agendamento> todosAgendamentos, DateTime mesAlvo) {
    final hoje = DateTime.now();
    final ehMesAtual = mesAlvo.year == hoje.year && mesAlvo.month == hoje.month;
    final diasNoMes = DateUtils.getDaysInMonth(mesAlvo.year, mesAlvo.month);
    
    // Se for mês passado, o dia atual é o último do mês (não há dias restantes)
    final int diaAtual = ehMesAtual ? hoje.day : diasNoMes;
    final int diasRestantes = ehMesAtual ? (diasNoMes - diaAtual) : 0;

    double realizado = 0.0;
    double agendadoFuturo = 0.0;

    for (final a in todosAgendamentos) {
      if (a.status == AgendamentoStatus.cancelado || a.clienteId == 'BLOQUEIO') continue;
      if (a.data.year != mesAlvo.year || a.data.month != mesAlvo.month) continue;

      if (!ehMesAtual) {
        // Se é mês passado, TUDO é realizado
        realizado += a.valor;
      } else {
        // Se é o mês atual, divide entre passado e futuro
        if (a.data.isBefore(DateTime(hoje.year, hoje.month, hoje.day)) || 
           (a.data.day == hoje.day && a.status == AgendamentoStatus.concluido)) {
          realizado += a.valor;
        } else {
          agendadoFuturo += a.valor;
        }
      }
    }

    final baseGarantida = realizado + agendadoFuturo;

    // Se o mês já fechou, não tem previsão
    if (!ehMesAtual || diasRestantes <= 0) {
      return {
        'realizado': realizado,
        'agendadoFuturo': 0.0,
        'previsaoIA': realizado,
        'tendencia': 'Mês Fechado Consolidado',
      };
    }

    // Análise de Ritmo e Previsão
    final mediaDiariaRealizada = realizado / (diaAtual == 1 && realizado == 0 ? 1 : diaAtual);
    final projecaoMatematica = realizado + (mediaDiariaRealizada * diasRestantes);

    double previsaoIA = 0.0;
    String tendencia = '';

    if (projecaoMatematica > baseGarantida) {
      previsaoIA = (projecaoMatematica * 0.6) + (baseGarantida * 0.4);
      tendencia = 'Alta (Forte captação de clientes de última hora)';
    } else {
      previsaoIA = baseGarantida;
      tendencia = 'Consolidada (Agenda futura superando o ritmo atual)';
    }

    return {
      'realizado': realizado,
      'agendadoFuturo': agendadoFuturo,
      'previsaoIA': previsaoIA,
      'tendencia': tendencia,
    };
  }

  void _abrirModalTreinarIA(BuildContext context, WidgetRef ref, Cliente cliente) {
    final profController = TextEditingController(text: cliente.profissao ?? '');
    final obsTexto = (cliente.observacoes.isNotEmpty) ? cliente.observacoes : '';
    final obsController = TextEditingController(text: obsTexto);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: _primaryColor),
                  const SizedBox(width: 8),
                  Text('Treinar IA - ${cliente.nome}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Adicione informações para a IA gerar dicas de vendas no próximo atendimento.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: profController,
                decoration: const InputDecoration(
                  labelText: 'Qual a profissão dela?',
                  hintText: 'Ex: Enfermeira, Advogada, Estudante',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observações Estratégicas',
                  hintText: 'Ex: Vai viajar mês que vem, prefere unha curta, etc.',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () {
                  final atualizado = cliente.copyWith(
                    profissao: profController.text.trim(),
                    observacoes: obsController.text.trim(),
                  );
                  ref.read(clienteControllerProvider.notifier).salvar(atualizado);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('IA alimentada com sucesso!'), backgroundColor: _primaryColor),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Salvar e Treinar IA'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _gerarDicaEstrategica(double realizado, double agendado, double previsao, int diaAtual) {
    if (diaAtual < 10 && agendado < realizado) {
      return 'Dica IA: Início de mês! Sua base garantida futura está baixa. Acione clientes inativas para lotar as próximas semanas.';
    } else if (diaAtual >= 20 && agendado > (realizado * 0.5)) {
      return 'Dica IA: Fim de mês espetacular! Sua agenda futura está muito forte. Foco em não atrasar horários e tentar fazer upsell na cadeira (oferecer Spa de Mãos).';
    } else {
      return 'Dica IA: O ritmo financeiro do salão está estável. A IA está considerando seu histórico de agendamentos de última hora para gerar essa previsão. Continue divulgando espaços vagos no Instagram!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    final fmtData = DateFormat('dd/MM/yyyy');
    final hoje = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        title: const Text('Relatório Gerencial (IA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _lightAccent.withOpacity(0.5),
      ),
      body: clientesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: _primaryColor)),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (clientes) {
          return todosAgendamentosAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: _primaryColor)),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (todos) {
              final inicioMes = _mesSelecionado;
              final fimMes = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0, 23, 59, 59);
              final inicioMesAnterior = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1, 1);
              final fimMesAnterior = DateTime(_mesSelecionado.year, _mesSelecionado.month, 0, 23, 59, 59);

              final ehMesAtual = _mesSelecionado.year == hoje.year && _mesSelecionado.month == hoje.month;

              // Processamento da IA Preditiva
              final dadosIA = _processarInteligenciaArtificial(todos, _mesSelecionado);
              final double previsaoRealizada = dadosIA['realizado'];
              final double previsaoAgendado = dadosIA['agendadoFuturo'];
              final double previsaoFinal = dadosIA['previsaoIA'];
              final String tendenciaStr = dadosIA['tendencia'];

              double receitaMes = 0, receitaMesAnterior = 0;
              int procedimentosMes = 0, procedimentosMesAnterior = 0;
              int minutosMes = 0, minutosMesAnterior = 0;
              
              final servicosMes = <String, double>{};
              final servicosMesAnterior = <String, double>{};
              final faturamentoPorDia = <int, double>{}; 
              final faturamentoPorDiaAnterior = <int, double>{}; 
              final ocupacaoPorDiaSemana = {2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

              final Set<String> clientesAtendidosMes = {};
              final Set<String> clientesAtendidosMesAnterior = {};
              final Map<String, DateTime> primeiraVisitaCliente = {};

              // 🚀 LÓGICA DE MESES: Descobrir o mês mais antigo para popular o Dropdown
              DateTime dataMaisAntiga = DateTime(hoje.year, 1, 1); // Fallback: Início do ano atual
              for (final a in todos) {
                if (a.clienteId == 'BLOQUEIO' || a.status == AgendamentoStatus.cancelado) continue;
                if (a.data.isBefore(dataMaisAntiga)) {
                  dataMaisAntiga = DateTime(a.data.year, a.data.month, 1);
                }
                if (!primeiraVisitaCliente.containsKey(a.clienteId) || a.data.isBefore(primeiraVisitaCliente[a.clienteId]!)) {
                  primeiraVisitaCliente[a.clienteId] = a.data;
                }
              }

              for (final a in todos) {
                if (a.clienteId == 'BLOQUEIO' || a.status == AgendamentoStatus.cancelado) continue;

                if (a.data.isAfter(inicioMes.subtract(const Duration(seconds: 1))) && a.data.isBefore(fimMes.add(const Duration(seconds: 1)))) {
                  receitaMes += a.valor;
                  procedimentosMes++;
                  minutosMes += a.duracaoMinutos;
                  servicosMes[a.servico] = (servicosMes[a.servico] ?? 0) + a.valor;
                  faturamentoPorDia[a.data.day] = (faturamentoPorDia[a.data.day] ?? 0) + a.valor;
                  clientesAtendidosMes.add(a.clienteId);

                  if (ocupacaoPorDiaSemana.containsKey(a.data.weekday)) ocupacaoPorDiaSemana[a.data.weekday] = ocupacaoPorDiaSemana[a.data.weekday]! + 1;
                } 
                else if (a.data.isAfter(inicioMesAnterior.subtract(const Duration(seconds: 1))) && a.data.isBefore(fimMesAnterior.add(const Duration(seconds: 1)))) {
                  receitaMesAnterior += a.valor;
                  procedimentosMesAnterior++;
                  minutosMesAnterior += a.duracaoMinutos;
                  servicosMesAnterior[a.servico] = (servicosMesAnterior[a.servico] ?? 0) + a.valor;
                  faturamentoPorDiaAnterior[a.data.day] = (faturamentoPorDiaAnterior[a.data.day] ?? 0) + a.valor;
                  clientesAtendidosMesAnterior.add(a.clienteId);
                }
              }

              int clientesNovasMes = 0;
              for (String cid in clientesAtendidosMes) {
                final pv = primeiraVisitaCliente[cid];
                if (pv != null && pv.isAfter(inicioMes.subtract(const Duration(seconds: 1))) && pv.isBefore(fimMes.add(const Duration(seconds: 1)))) {
                  clientesNovasMes++;
                }
              }

              int clientesNovasMesAnterior = 0;
              for (String cid in clientesAtendidosMesAnterior) {
                final pv = primeiraVisitaCliente[cid];
                if (pv != null && pv.isAfter(inicioMesAnterior.subtract(const Duration(seconds: 1))) && pv.isBefore(fimMesAnterior.add(const Duration(seconds: 1)))) {
                  clientesNovasMesAnterior++;
                }
              }

              final diasTrabalhadosMes = faturamentoPorDia.keys.length;
              final diasTrabalhadosMesAnterior = faturamentoPorDiaAnterior.keys.length;

              final tmMes = procedimentosMes > 0 ? receitaMes / procedimentosMes : 0.0;
              final tmMesAnterior = procedimentosMesAnterior > 0 ? receitaMesAnterior / procedimentosMesAnterior : 0.0;
              final horasMes = minutosMes / 60.0;
              final horasMesAnterior = minutosMesAnterior / 60.0;
              final rentabilidadeHora = horasMes > 0 ? receitaMes / horasMes : 0.0;
              final rentabilidadeHoraAnterior = horasMesAnterior > 0 ? receitaMesAnterior / horasMesAnterior : 0.0;

              String servicoDestaque = '';
              double valorCrescimentoServico = 0;
              servicosMes.forEach((nome, valorAtual) {
                final diff = valorAtual - (servicosMesAnterior[nome] ?? 0.0);
                if (diff > valorCrescimentoServico) {
                  valorCrescimentoServico = diff;
                  servicoDestaque = nome;
                }
              });

              int diaMaisFraco = 2, minOcupacao = 9999;
              ocupacaoPorDiaSemana.forEach((dia, qtd) {
                if (qtd < minOcupacao) { minOcupacao = qtd; diaMaisFraco = dia; }
              });
              final nomeDiaFraco = {2: 'Terça', 3: 'Quarta', 4: 'Quinta', 5: 'Sexta', 6: 'Sábado'}[diaMaisFraco] ?? 'Terça';

              final atrasados = <({String id, String nome, String telefone, DateTime sugerida})>[];
              for (final c in clientes) {
                final doCliente = todos.where((a) => a.clienteId == c.id).toList();
                final info = InteligenciaService.calcularParaCliente(doCliente);
                if (info.atrasado && info.proximaDataSugerida != null) {
                  atrasados.add((id: c.id, nome: c.nome, telefone: c.telefone, sugerida: info.proximaDataSugerida!));
                }
              }
              atrasados.sort((a, b) => a.sugerida.compareTo(b.sugerida));

              final clientesParaTreinar = clientes.where((c) {
                final semProfissao = c.profissao == null || c.profissao!.trim().isEmpty;
                final semObs = c.observacoes.trim().isEmpty;
                return semProfissao || semObs;
              }).take(5).toList(); 

              // 🚀 GERADOR DINÂMICO DE MESES (DO MÊS MAIS ANTIGO ATÉ O MÊS ATUAL/DEZEMBRO)
              List<DateTime> listaCompletaMeses = [];
              DateTime mesCursor = DateTime(hoje.year, hoje.month, 1);
              
              // Garante que mostramos pelo menos até o fim do ano atual
              if (mesCursor.month < 12) {
                 mesCursor = DateTime(hoje.year, 12, 1);
              }

              while (mesCursor.isAfter(dataMaisAntiga.subtract(const Duration(days: 1)))) {
                listaCompletaMeses.add(mesCursor);
                mesCursor = DateTime(mesCursor.year, mesCursor.month - 1, 1);
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Análise do Mês', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          DropdownButton<DateTime>(
                            value: _mesSelecionado,
                            underline: const SizedBox(),
                            icon: Icon(Icons.calendar_month, size: 18, color: _primaryColor),
                            items: listaCompletaMeses.map((data) {
                              final label = DateFormat('MMMM yyyy', 'pt_BR').format(data);
                              return DropdownMenuItem(value: data, child: Text(label[0].toUpperCase() + label.substring(1), style: const TextStyle(fontSize: 14)));
                            }).toList(),
                            onChanged: (v) { if (v != null) setState(() => _mesSelecionado = v); },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // =========================================================
                  // PAINEL DE INTELIGÊNCIA ARTIFICIAL (SE FOR MÊS ATUAL)
                  // =========================================================
                  if (ehMesAtual) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: _borderAccent, width: 2),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: _primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Text('PREVISÃO DE FECHAMENTO (IA)', style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _fmtMoeda.format(previsaoFinal),
                              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: _primaryColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tendência detectada: $tendenciaStr',
                              style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _lightAccent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderAccent)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Já Realizado', style: TextStyle(fontSize: 11, color: _primaryColor, fontWeight: FontWeight.bold)),
                                Text(_fmtMoeda.format(previsaoRealizada), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blueGrey.shade200)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Futuro Garantido', style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                Text(_fmtMoeda.format(previsaoAgendado), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.amber.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.amber.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _gerarDicaEstrategica(previsaoRealizada, previsaoAgendado, previsaoFinal, hoje.day),
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 12, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 48),
                  ],
                  // =========================================================

                  // CARDS FINANCEIROS PADRÕES
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CardMetricaIA(titulo: 'Faturamento Realizado', valorAtual: receitaMes, valorAnterior: receitaMesAnterior, ehMoeda: true),
                        const SizedBox(width: 12),
                        _CardMetricaIA(titulo: 'Ticket Médio', valorAtual: tmMes, valorAnterior: tmMesAnterior, ehMoeda: true),
                        const SizedBox(width: 12),
                        _CardMetricaIA(titulo: 'Rentabilidade/Hora', valorAtual: rentabilidadeHora, valorAnterior: rentabilidadeHoraAnterior, ehMoeda: true),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text('Produtividade & Engajamento', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CardMetricaIA(titulo: 'Atendimentos', valorAtual: procedimentosMes.toDouble(), valorAnterior: procedimentosMesAnterior.toDouble(), ehMoeda: false),
                        const SizedBox(width: 12),
                        _CardMetricaIA(titulo: 'Clientes Atendidas', valorAtual: clientesAtendidosMes.length.toDouble(), valorAnterior: clientesAtendidosMesAnterior.length.toDouble(), ehMoeda: false),
                        const SizedBox(width: 12),
                        _CardMetricaIA(titulo: 'Clientes Novas ✨', valorAtual: clientesNovasMes.toDouble(), valorAnterior: clientesNovasMesAnterior.toDouble(), ehMoeda: false),
                        const SizedBox(width: 12),
                        _CardMetricaIA(titulo: 'Horas Trabalhadas', valorAtual: horasMes, valorAnterior: horasMesAnterior, ehMoeda: false, isDecimal: true),
                        const SizedBox(width: 12),
                        _CardMetricaIA(titulo: 'Dias Trabalhados', valorAtual: diasTrabalhadosMes.toDouble(), valorAnterior: diasTrabalhadosMesAnterior.toDouble(), ehMoeda: false),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  _CalendarioMensalCalor(mesReferencia: _mesSelecionado, faturamentoPorDia: faturamentoPorDia),
                  const SizedBox(height: 24),
                  
                  Text('Diagnóstico de Negócios (IA)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderAccent)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, color: _primaryColor, size: 28),
                            const SizedBox(width: 8),
                            Text('Sócio Estratégico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _BlocoTextoIA(
                          titulo: 'Eficiência de Tempo:',
                          texto: 'Você trabalhou ${horasMes.toStringAsFixed(1)} horas neste mês em $diasTrabalhadosMes dias. '
                                 'Sua hora na cadeira rendeu ${formatarMoedaIA(rentabilidadeHora)} '
                                 '(${rentabilidadeHora > rentabilidadeHoraAnterior ? 'crescimento' : 'queda'} vs mês passado).',
                        ),
                        const SizedBox(height: 12),
                        if (servicoDestaque.isNotEmpty && valorCrescimentoServico > 0)
                          _BlocoTextoIA(
                            titulo: 'Mix de Serviços:',
                            texto: 'O serviço "$servicoDestaque" impulsionou seu caixa trazendo ${formatarMoedaIA(valorCrescimentoServico)} a mais que no mês passado. '
                                   'Ofereça-o ativamente no checklist pré-atendimento!',
                          ),
                        const SizedBox(height: 12),
                        _BlocoTextoIA(
                          titulo: 'Plano de Ação (Marketing):',
                          texto: 'Sua $nomeDiaFraco-feira é o dia mais ocioso. '
                                 'Regra de Mercado: Nunca dê desconto no valor principal. Crie o "Combo $nomeDiaFraco VIP": '
                                 'Ao agendar a manutenção, a cliente ganha um Spa de Hidratação.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (clientesParaTreinar.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.model_training, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('Treine sua IA', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Text('Complete os dados abaixo para a IA gerar dicas de vendas automáticas.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ...clientesParaTreinar.map((c) => Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: _borderAccent)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Falta: Profissão ou Observações', style: TextStyle(fontSize: 11, color: Colors.orange)),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: _primaryColor, side: BorderSide(color: _primaryColor)),
                          onPressed: () => _abrirModalTreinarIA(context, ref, c),
                          child: const Text('Preencher', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  Text('Alvos Estratégicos (Reativação)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('Aplique a técnica de Ancoragem de Valor para recuperar estas clientes:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (atrasados.isEmpty)
                    Card(elevation: 0, shape: RoundedRectangleBorder(side: BorderSide(color: _borderAccent), borderRadius: BorderRadius.circular(8)), child: const Padding(padding: EdgeInsets.all(16), child: Text('Sua taxa de retenção está perfeita!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))))
                  else
                    ...atrasados.map((c) => Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.orange.shade200), borderRadius: BorderRadius.circular(8)),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.auto_graph, color: Colors.orange.shade800, size: 20)),
                            title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Ciclo atrasado desde ${fmtData.format(c.sugerida)}', style: const TextStyle(fontSize: 11)),
                            trailing: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: _primaryColor, side: BorderSide(color: _primaryColor), padding: const EdgeInsets.symmetric(horizontal: 12)),
                              icon: const Icon(Icons.chat, size: 16),
                              label: const Text('Abordar', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                final agendamentoOferta = Agendamento(
                                  id: 'oferta_ia', clienteId: c.id, data: DateTime.now(),
                                  horaInicio: '✨', horaFim: '🎁', duracaoMinutos: 0,
                                  servico: 'Condição VIP ($nomeDiaFraco)', valor: 0.0,
                                  status: AgendamentoStatus.agendado,
                                  observacao: 'Oferta Estratégica.',
                                  createdAt: DateTime.now(), updatedAt: DateTime.now(),
                                );
                                WhatsAppService.enviarConfirmacao(telefone: c.telefone, nomeCliente: c.nome, agendamento: agendamentoOferta);
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

class _CalendarioMensalCalor extends StatelessWidget {
  const _CalendarioMensalCalor({required this.mesReferencia, required this.faturamentoPorDia});
  final DateTime mesReferencia;
  final Map<int, double> faturamentoPorDia;

  @override
  Widget build(BuildContext context) {
    final diasNoMes = DateTime(mesReferencia.year, mesReferencia.month + 1, 0).day;
    final primeiroDiaDaSemana = DateTime(mesReferencia.year, mesReferencia.month, 1).weekday; 
    
    double totalMes = 0; int diasTrabalhados = 0;
    faturamentoPorDia.forEach((_, valor) {
      if (valor > 0) { totalMes += valor; diasTrabalhados++; }
    });
    final mediaDiaria = diasTrabalhados > 0 ? totalMes / diasTrabalhados : 0.0;
    final diasGrid = <Widget>[];
    for (var d in ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']) {
      diasGrid.add(Center(child: Text(d, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))));
    }

    final ajusteSemana = primeiroDiaDaSemana == 7 ? 0 : primeiroDiaDaSemana; 
    for (int i = 0; i < ajusteSemana; i++) diasGrid.add(const SizedBox()); 

    for (int dia = 1; dia <= diasNoMes; dia++) {
      final faturamento = faturamentoPorDia[dia] ?? 0.0;
      Color corFundo = Colors.white;
      Color corTexto = Colors.grey.shade700;

      if (faturamento > 0) {
        if (faturamento > mediaDiaria * 1.2) { corFundo = const Color(0xFF3A4E40); corTexto = Colors.white; } // Verde Sálvia Forte
        else if (faturamento < mediaDiaria * 0.7) { corFundo = Colors.orange.shade300; corTexto = Colors.white; }
        else { corFundo = const Color(0xFFB5C4B9); corTexto = Colors.white; } // Verde Sálvia Claro
      }
      diasGrid.add(Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: corFundo, borderRadius: BorderRadius.circular(4), border: faturamento == 0 ? Border.all(color: Colors.grey.shade200) : null), child: Center(child: Text('$dia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: corTexto)))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mapa de Calor Mensal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Text('Dias escuros representam picos de receita acima da média.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: diasGrid),
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
    return RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4), children: [TextSpan(text: '$titulo ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: texto)]));
  }
}

class _CardMetricaIA extends StatelessWidget {
  const _CardMetricaIA({
    required this.titulo,
    required this.valorAtual,
    required this.valorAnterior,
    required this.ehMoeda,
    this.isDecimal = false,
  });

  final String titulo;
  final double valorAtual, valorAnterior;
  final bool ehMoeda;
  final bool isDecimal;

  @override
  Widget build(BuildContext context) {
    Color corBadge = Colors.grey;
    IconData iconeSeta = Icons.remove;
    String txtEvolucao = 'Sem base';

    if (valorAnterior > 0) {
      final variacao = ((valorAtual - valorAnterior) / valorAnterior) * 100;
      txtEvolucao = '${variacao > 0 ? '+' : ''}${variacao.toStringAsFixed(1)}%';
      if (variacao >= 10) { corBadge = Colors.green; iconeSeta = Icons.trending_up; }
      else if (variacao <= -5) { corBadge = Colors.red; iconeSeta = Icons.trending_down; }
      else { corBadge = Colors.amber.shade700; iconeSeta = Icons.trending_flat; }
    } else if (valorAtual > 0) { corBadge = Colors.green; iconeSeta = Icons.trending_up; txtEvolucao = 'Novo!'; }

    final String exibicaoValor = ehMoeda 
        ? formatarMoedaIA(valorAtual) 
        : (isDecimal ? valorAtual.toStringAsFixed(1) : valorAtual.toInt().toString());

    return Container(
      width: 140, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB5C4B9))), // Border Sálvia
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600), maxLines: 1),
          const SizedBox(height: 4),
          Text(exibicaoValor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: corBadge.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(iconeSeta, size: 12, color: corBadge), const SizedBox(width: 2), Text(txtEvolucao, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: corBadge))])),
        ],
      ),
    );
  }
}
