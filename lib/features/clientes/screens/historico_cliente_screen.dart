import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/status_chip.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../agenda/services/inteligencia_service.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';

/// Tela de Histórico do Cliente: todos os atendimentos, quantidade de
/// visitas, valor total gasto e serviços realizados.
class HistoricoClienteScreen extends ConsumerWidget {
  const HistoricoClienteScreen({super.key, required this.clienteId});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clienteAsync = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final fmtData = DateFormat('dd/MM/yyyy');

    Cliente? cliente;
    for (final c in clienteAsync.value ?? <Cliente>[]) {
      if (c.id == clienteId) {
        cliente = c;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(cliente != null ? 'Histórico — ${cliente.nome}' : 'Histórico do Cliente')),
      body: todosAgendamentosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar histórico: $e')),
        data: (todos) {
          final doCliente = todos.where((a) => a.clienteId == clienteId).toList()
            ..sort((a, b) => b.data.compareTo(a.data));

          final concluidos = doCliente.where((a) => a.status == AgendamentoStatus.concluido).toList();
          final valorTotal = concluidos.fold<double>(0, (s, a) => s + a.valor);
          final inteligencia = InteligenciaService.calcularParaCliente(doCliente);

          // Serviços realizados, agrupados por nome com contagem.
          final servicosContagem = <String, int>{};
          for (final a in concluidos) {
            servicosContagem[a.servico] = (servicosContagem[a.servico] ?? 0) + 1;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _EstatCard(titulo: 'Visitas concluídas', valor: '${concluidos.length}')),
                  const SizedBox(width: 12),
                  Expanded(child: _EstatCard(titulo: 'Total gasto', valor: moeda.format(valorTotal))),
                ],
              ),
              const SizedBox(height: 12),
              if (inteligencia.proximaDataSugerida != null)
                Card(
                  color: inteligencia.atrasado
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      inteligencia.atrasado
                          ? 'Cliente atrasado para retornar — sugerido para ${fmtData.format(inteligencia.proximaDataSugerida!)}.'
                          : 'Próximo retorno sugerido: ${fmtData.format(inteligencia.proximaDataSugerida!)} '
                              '(frequência média de ${inteligencia.frequenciaMediaDias} dias).',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (servicosContagem.isNotEmpty) ...[
                Text('Serviços realizados', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: servicosContagem.entries
                      .map((e) => Chip(label: Text('${e.key} (${e.value}x)')))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              Text('Todos os atendimentos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (doCliente.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Nenhum atendimento registrado ainda.')),
                )
              else
                ...doCliente.map((a) => Card(
                      child: ListTile(
                        title: Text('${fmtData.format(a.data)} às ${a.horaInicio} — ${a.servico}'),
                        subtitle: Text(moeda.format(a.valor)),
                        trailing: StatusChip(status: a.status),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _EstatCard extends StatelessWidget {
  const _EstatCard({required this.titulo, required this.valor});
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(valor, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
