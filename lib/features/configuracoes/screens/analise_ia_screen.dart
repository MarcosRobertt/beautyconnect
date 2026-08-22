import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../../clientes/models/cliente.dart';

// =========================================================================
// MODELO E MOTOR DE INTELIGÊNCIA ARTIFICIAL
// =========================================================================
class RelatorioSemanalIA {
  RelatorioSemanalIA({
    required this.dataInicioSemana,
    required this.dataFimSemana,
    required this.faturamentoSemana,
    required this.qtdAtendimentos,
    required this.ticketMedio,
    required this.taxaOcupacaoEstimada,
    required this.potencialPerdidoCancelamentos,
    required this.metaDiariaAtendimentos,
    required this.metaDiariaReceita,
    required this.sugestoesAcao,
  });

  final DateTime dataInicioSemana;
  final DateTime dataFimSemana;
  final double faturamentoSemana;
  final int qtdAtendimentos;
  final double ticketMedio;
  final double taxaOcupacaoEstimada;
  final double potencialPerdidoCancelamentos;
  final int metaDiariaAtendimentos;
  final double metaDiariaReceita;
  final List<String> sugestoesAcao;
}

class AnaliseIAService {
  static RelatorioSemanalIA gerarRelatorioSemanaAnterior({
    required List<Agendamento> todosAgendamentos,
    required List<Cliente> todosClientes,
  }) {
    final hoje = DateTime.now();
    
    // Segunda a Domingo da semana passada
    final diaSemanaAtual = hoje.weekday;
    final domingoSemanaPassada = hoje.subtract(Duration(days: diaSemanaAtual));
    final segundaSemanaPassada = domingoSemanaPassada.subtract(const Duration(days: 6));

    final inicioSemana = DateTime(segundaSemanaPassada.year, segundaSemanaPassada.month, segundaSemanaPassada.day, 0, 0, 0);
    final fimSemana = DateTime(domingoSemanaPassada.year, domingoSemanaPassada.month, domingoSemanaPassada.day, 23, 59, 59);

    final agendamentosSemana = todosAgendamentos.where((a) =>
      a.clienteId != 'BLOQUEIO' &&
      a.data.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) &&
      a.data.isBefore(fimSemana.add(const Duration(seconds: 1)))
    ).toList();

    final concluidos = agendamentosSemana.where((a) => 
        a.status == AgendamentoStatus.concluido || a.status == AgendamentoStatus.confirmado).toList();
        
    final cancelados = agendamentosSemana.where((a) => 
        a.status == AgendamentoStatus.cancelado).toList();

    double faturamentoTotal = concluidos.fold(0.0, (sum, a) => sum + a.valor);
    int totalAtendimentos = concluidos.length;
    double ticketMedio = totalAtendimentos > 0 ? faturamentoTotal / totalAtendimentos : 0.0;
    double potencialPerdido = cancelados.fold(0.0, (sum, a) => sum + a.valor);

    // Estimativa de ocupação (Base 40h/semana)
    double horasTrabalhadas = (totalAtendimentos * 75) / 60;
    double taxaOcupacao = (horasTrabalhadas / 40.0) * 100;
    if (taxaOcupacao > 100.0) taxaOcupacao = 100.0;

    int metaDiariaAtendimentos = (totalAtendimentos > 0) ? ((totalAtendimentos / 5) * 1.1).ceil() : 4;
    double metaDiariaReceita = (faturamentoTotal > 0) ? ((faturamentoTotal / 5) * 1.1) : 250.0;

    final sugestoes = <String>[];

    if (ticketMedio > 0 && ticketMedio < 70) {
      sugestoes.add('💡 **Aumente seu Ticket Médio:** Seu ticket médio foi de ${NumberFormat.simpleCurrency(locale: "pt_BR").format(ticketMedio)}. Ofereça serviços adicionais como Spa dos Pés ou Esmaltação em Gel.');
    } else {
      sugestoes.add('🌟 **Excelente Ticket Médio:** Mantenha a oferta de adicionais para sustentar sua média em ${NumberFormat.simpleCurrency(locale: "pt_BR").format(ticketMedio)}.');
    }

    if (potencialPerdido > 0) {
      sugestoes.add('⚠️ **Atenção aos Cancelamentos:** Na semana passada você teve ${cancelados.length} cancelamento(s), com perda de ${NumberFormat.simpleCurrency(locale: "pt_BR").format(potencialPerdido)}. Reforce a confirmação na véspera.');
    }

    if (taxaOcupacao < 60.0) {
      sugestoes.add('📅 **Preencha Horários Mortos:** Sua ocupação foi de ${taxaOcupacao.toStringAsFixed(0)}%. Crie promoções especiais para terças e quartas-feiras de manhã.');
    } else {
      sugestoes.add('🔥 **Agenda Aquecida:** Sua taxa de ocupação foi de ${taxaOcupacao.toStringAsFixed(0)}%. Otimize seus intervalos entre clientes.');
    }

    final clientesInativas = todosClientes.where((c) {
      final agDoCliente = todosAgendamentos.where((a) => a.clienteId == c.id && a.status == AgendamentoStatus.concluido).toList();
      if (agDoCliente.isEmpty) return false;
      agDoCliente.sort((a, b) => b.data.compareTo(a.data));
      final dias = hoje.difference(agDoCliente.first.data).inDays;
      return dias >= 20 && dias <= 35;
    }).length;

    if (clientesInativas > 0) {
      sugestoes.add('📲 **Oportunidade no CRM:** Você tem $clientesInativas cliente(s) na aba Recorrência (sem vir há +20 dias). Mande mensagem para agendar retorno.');
    }

    return RelatorioSemanalIA(
      dataInicioSemana: inicioSemana,
      dataFimSemana: fimSemana,
      faturamentoSemana: faturamentoTotal,
      qtdAtendimentos: totalAtendimentos,
      ticketMedio: ticketMedio,
      taxaOcupacaoEstimada: taxaOcupacao,
      potencialPerdidoCancelamentos: potencialPerdido,
      metaDiariaAtendimentos: metaDiariaAtendimentos,
      metaDiariaReceita: metaDiariaReceita,
      sugestoesAcao: sugestoes,
    );
  }
}

// =========================================================================
// TELA PRINCIPAL DE ANÁLISE DA IA
// =========================================================================
class AnaliseIAScreen extends ConsumerWidget {
  const AnaliseIAScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    final clientesAsync = ref.watch(clienteControllerProvider);
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text('Inteligência & Metas'),
          ],
        ),
      ),
      body: todosAgendamentosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao analisar dados: $e')),
        data: (agendamentos) {
          return clientesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro ao carregar clientes: $e')),
            data: (clientes) {
              final relatorio = AnaliseIAService.gerarRelatorioSemanaAnterior(
                todosAgendamentos: agendamentos,
                todosClientes: clientes,
              );

              final fmtData = DateFormat('dd/MM');
              final periodoStr = '${fmtData.format(relatorio.dataInicioSemana)} a ${fmtData.format(relatorio.dataFimSemana)}';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade700, Colors.purple.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Fechamento da Semana Anterior', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                                child: Text(periodoStr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(moeda.format(relatorio.faturamentoSemana), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          Text('${relatorio.qtdAtendimentos} atendimentos realizados', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Raio-X Operacional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _CardIAIndica(
                          titulo: 'Ticket Médio',
                          valor: moeda.format(relatorio.ticketMedio),
                          sub: 'por cliente',
                          icone: Icons.payments_outlined,
                          cor: Colors.blue,
                        ),
                        const SizedBox(width: 10),
                        _CardIAIndica(
                          titulo: 'Ocupação',
                          valor: '${relatorio.taxaOcupacaoEstimada.toStringAsFixed(0)}%',
                          sub: 'da capacidade',
                          icone: Icons.pie_chart_outline,
                          cor: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.flag, color: Colors.amber, size: 20),
                              SizedBox(width: 8),
                              Text('Metas Sugeridas para esta Semana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Meta Diária Atendimentos', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text('${relatorio.metaDiariaAtendimentos} / dia', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              Container(width: 1, height: 30, color: Colors.amber.shade200),
                              Column(
                                children: [
                                  const Text('Meta Diária Receita', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text('${moeda.format(relatorio.metaDiariaReceita)} / dia', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Sugestões da IA para Alavancar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),

                    ...relatorio.sugestoesAcao.map((sugestao) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          sugestao.replaceAll('**', ''), 
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CardIAIndica extends StatelessWidget {
  const _CardIAIndica({
    required this.titulo,
    required this.valor,
    required this.sub,
    required this.icone,
    required this.cor,
  });

  final String titulo;
  final String valor;
  final String sub;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor, size: 20),
            const SizedBox(height: 8),
            Text(titulo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
