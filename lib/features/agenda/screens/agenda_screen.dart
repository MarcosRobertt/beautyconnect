import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

import '../../../core/constants/app_constants.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../controllers/cliente_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart'; 

final _todosAgendamentosHistoricoProvider = FutureProvider.autoDispose<List<Agendamento>>((ref) async {
  ref.watch(agendamentoControllerProvider); 
  return await ref.read(agendamentoControllerProvider.notifier).todos();
});

class HistoricoClienteScreen extends ConsumerWidget {
  const HistoricoClienteScreen({super.key, required this.clienteId});

  final String clienteId;

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

  void _confirmarExclusao(BuildContext context, WidgetRef ref, Agendamento agendamento) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('Excluir Comanda?', style: TextStyle(color: Colors.red.shade900, fontSize: 18))),
          ],
        ),
        content: const Text(
          'Tem certeza que deseja apagar este agendamento do histórico?\n\n'
          'Ao fazer isso, o status mudará para Cancelado e qualquer valor atrelado a ele será removido do seu faturamento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Voltar', style: TextStyle(color: Colors.grey))
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              Navigator.pop(ctx); 
              
              final novaObs = agendamento.observacao.isEmpty 
                  ? '[Excluído pelo Histórico]' 
                  : '${agendamento.observacao} | [Excluído pelo Histórico]';
              
              final atualizado = agendamento.copyWith(
                status: AgendamentoStatus.cancelado,
                observacao: novaObs,
              );

              await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
              
              try {
                await FirebaseFirestore.instance.collection('agendamentos').doc(agendamento.id).update({'observacao': novaObs});
              } catch (_) {}

              ref.invalidate(_todosAgendamentosHistoricoProvider); 
              ref.invalidate(todosAgendamentosProvider);           
              ref.invalidate(dashboardMetricsProvider);            

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Comanda removida do histórico!'), backgroundColor: Colors.green)
                );
              }
            },
            child: const Text('Sim, Excluir'),
          ),
        ],
      ),
    );
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

              final ultimoAgendamento = historicoCliente.isNotEmpty ? historicoCliente.first : null;

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

                                return StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance.collection('agendamentos').doc(ag.id).snapshots(),
                                  builder: (context, snapshot) {
                                    
                                    String obsExibicao = ag.observacao;
                                    String dataDaBaixaFormatada = '';
                                    
                                    if (snapshot.hasData && snapshot.data!.exists) {
                                      final mapDados = snapshot.data!.data() as Map<String, dynamic>;
                                      
                                      if (mapDados.containsKey('observacao') && mapDados['observacao'] != null) {
                                        obsExibicao = mapDados['observacao'].toString();
                                      }
                                      
                                      if (mapDados.containsKey('dataPagamento') && mapDados['dataPagamento'] != null) {
                                        try {
                                          final dtPagamento = DateTime.parse(mapDados['dataPagamento'].toString());
                                          dataDaBaixaFormatada = 'Pago em: ${DateFormat('dd/MM/yyyy').format(dtPagamento)}';
                                        } catch (_) {}
                                      }
                                    }

                                    final matchReagendado = regExpReagendado.firstMatch(obsExibicao);
                                    final qtdReagendado = matchReagendado?.group(1);

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      clipBehavior: Clip.antiAlias,
                                      color: isCancelado ? Colors.grey.shade50 : Colors.white,
                                      child: InkWell(
                                        onTap: () {
                                          ref.read(agendamentoControllerProvider.notifier).mudarData(ag.data);
                                          ref.read(agendamentoControllerProvider.notifier).mudarVisao(VisaoAgenda.dia);
                                          context.go(AppRoutes.agenda);
                                        },
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isCancelado ? Colors.red.shade100 : const Color(0xFFE6EBE4), 
                                            child: Icon(
                                              isCancelado ? Icons.cancel : Icons.calendar_today,
                                              color: isCancelado ? Colors.red : const Color(0xFF627970), 
                                              size: 20,
                                            ),
                                          ),
                                          title: Text(
                                            ag.servico, 
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              decoration: isCancelado ? TextDecoration.lineThrough : null,
                                              color: isCancelado ? Colors.grey : Colors.black87,
                                            )
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${DateFormat('dd/MM/yyyy').format(ag.data)} às ${ag.horaInicio}',
                                                style: TextStyle(
                                                  decoration: isCancelado ? TextDecoration.lineThrough : null,
                                                  color: isCancelado ? Colors.grey : Colors.black54,
                                                ),
                                              ),
                                              
                                              if (dataDaBaixaFormatada.isNotEmpty && !isCancelado)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Text(
                                                    dataDaBaixaFormatada,
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                                  ),
                                                ),
                                              
                                              if (obsExibicao.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: isCancelado ? Colors.grey.shade200 : const Color(0xFFE6EBE4), 
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: isCancelado ? Colors.grey.shade300 : const Color(0xFF627970).withOpacity(0.3)),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(
                                                          Icons.receipt_long, 
                                                          size: 14, 
                                                          color: isCancelado ? Colors.grey : const Color(0xFF627970)
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            obsExibicao,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: isCancelado ? Colors.grey : const Color(0xFF2C3532), 
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min, 
                                            children: [
                                              if (!isCancelado) 
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                  tooltip: 'Excluir / Cancelar Comanda',
                                                  onPressed: () => _confirmarExclusao(context, ref, ag),
                                                ),
                                              
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    moeda.format(ag.valor), 
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      decoration: isCancelado ? TextDecoration.lineThrough : null,
                                                      color: isCancelado ? Colors.grey : Colors.black87,
                                                    )
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 4,
                                                    children: [
                                                      if (qtdReagendado != null)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                                          child: Text('🔄 $qtdReagendado x', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                                        ),
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
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
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
