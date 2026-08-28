import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../controllers/cliente_controller.dart';

// Provedor que busca TODO o histórico do banco de dados sempre que houver alteração
final _todosAgendamentosHistoricoProvider = FutureProvider.autoDispose<List<Agendamento>>((ref) async {
  ref.watch(agendamentoControllerProvider); 
  return await ref.read(agendamentoControllerProvider.notifier).todos();
});

class HistoricoClienteScreen extends ConsumerWidget {
  const HistoricoClienteScreen({super.key, required this.clienteId});

  final String clienteId;

  // --- Helpers para a Etiqueta Dinâmica de Status ---
  String _obterTextoStatus(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado: return 'Agendado';
      case AgendamentoStatus.confirmado: return 'Confirmado';
      case AgendamentoStatus.concluido: return 'Concluído';
      case AgendamentoStatus.cancelado: return 'Cancelado';
    }
  }

  Color _obterCorFundoStatus(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado: return Colors.blue.shade50;
      case AgendamentoStatus.confirmado: return Colors.teal.shade50;
      case AgendamentoStatus.concluido: return Colors.green.shade50;
      case AgendamentoStatus.cancelado: return Colors.red.shade50;
    }
  }

  Color _obterCorTextoStatus(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado: return Colors.blue.shade700;
      case AgendamentoStatus.confirmado: return Colors.teal.shade800;
      case AgendamentoStatus.concluido: return Colors.green.shade800;
      case AgendamentoStatus.cancelado: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clienteAsync = ref.watch(clienteControllerProvider);
    final agendamentosAsync = ref.watch(_todosAgendamentosHistoricoProvider);
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico da Cliente')),
      body: clienteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (clientes) {
          final cliente = clientes.firstWhere((c) => c.id == clienteId);

          return agendamentosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro ao carregar histórico: $e')),
            data: (todosAgendamentos) {
              final historicoCliente = todosAgendamentos
                  .where((a) => a.clienteId == clienteId)
                  .toList()
                ..sort((a, b) => b.data.compareTo(a.data));

              // Identifica o último agendamento da cliente (o mais recente da lista ordenada)
              final ultimoAgendamento = historicoCliente.isNotEmpty ? historicoCliente.first : null;

              // CÁLCULO DAS MÉTRICAS TOTAIS
              int totalCancelamentos = 0;
              int totalReagendamentos = 0;
              final regExpReagendado = RegExp(r'\[Reagendado:\s*(\d+)x\]');

              for (final ag in historicoCliente) {
                if (ag.status == AgendamentoStatus.cancelado) {
                  totalCancelamentos++;
                }
                final matchReagendado = regExpReagendado.firstMatch(ag.observacao);
                if (matchReagendado != null) {
                  totalReagendamentos += int.parse(matchReagendado.group(1)!);
                }
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // QUADRANTE SUPERIOR REFINADO (Nome, Última Data, Procedimento + Métricas)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cliente.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            
                            if (ultimoAgendamento != null) ...[
                              const SizedBox(height: 8),
                              Text('Último agendamento: ${DateFormat('dd/MM/yyyy').format(ultimoAgendamento.data)}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                              Text('Procedimento: ${ultimoAgendamento.servico}', style: const TextStyle(color: Colors.grey)),
                            ] else ...[
                              const SizedBox(height: 8),
                              const Text('Nenhum procedimento registrado.', style: TextStyle(color: Colors.grey)),
                            ],
                            
                            const Divider(height: 24),
                            
                            // PAINEL DE TOTALIZADORES
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: Column(
                                      children: [
                                        Text(totalCancelamentos.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                                        const Text('Cancelamentos', style: TextStyle(fontSize: 11, color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: Column(
                                      children: [
                                        Text(totalReagendamentos.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                        Text('Reagendamentos', style: TextStyle(fontSize: 11, color: Colors.amber.shade900)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Linha do Tempo de Agendamentos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const Text('Toque em um agendamento para abrir a agenda neste dia.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 8),

                    Expanded(
                      child: historicoCliente.isEmpty
                          ? const Center(child: Text('Nenhum agendamento registrado para esta cliente.'))
                          : ListView.builder(
                              itemCount: historicoCliente.length,
                              itemBuilder: (context, index) {
                                final ag = historicoCliente[index];
                                final isCancelado = ag.status == AgendamentoStatus.cancelado;

                                final matchReagendado = regExpReagendado.firstMatch(ag.observacao);
                                final qtdReagendado = matchReagendado?.group(1);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () {
                                      ref.read(agendamentoControllerProvider.notifier).mudarData(ag.data);
                                      ref.read(agendamentoControllerProvider.notifier).mudarVisao(VisaoAgenda.dia);
                                      context.go(AppRoutes.agenda);
                                    },
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isCancelado ? Colors.red.shade100 : Colors.purple.shade50,
                                        child: Icon(
                                          isCancelado ? Icons.cancel : Icons.calendar_today,
                                          color: isCancelado ? Colors.red : Colors.purple,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(ag.servico, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${DateFormat('dd/MM/yyyy').format(ag.data)} às ${ag.horaInicio}'),
                                          if (ag.observacao.isNotEmpty)
                                            Text('Obs: ${ag.observacao}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(moeda.format(ag.valor), style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4,
                                            children: [
                                              // ETIQUETA DE REAGENDAMENTO
                                              if (qtdReagendado != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: Text('🔄 $qtdReagendado x', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                                ),
                                              // ETIQUETA DINÂMICA DE STATUS
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _obterCorFundoStatus(ag.status), 
                                                  borderRadius: BorderRadius.circular(4)
                                                ),
                                                child: Text(
                                                  _obterTextoStatus(ag.status), 
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _obterCorTextoStatus(ag.status))
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
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
