import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../agenda/controllers/agendamento_controller.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../services/analise_ia_service.dart';

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
                    // CABEÇALHO DO RELATÓRIO
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

                    // INDICADORES DE DESEMPENHO (METRICAS)
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

                    // METAS SUGERIDAS PARA ESTA SEMANA
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

                    // PLANO DE AÇÃO E SUGESTÕES DA IA
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
