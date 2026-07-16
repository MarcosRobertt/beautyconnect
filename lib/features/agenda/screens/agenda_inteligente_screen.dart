import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/agendamento_controller.dart';
import '../services/inteligencia_service.dart';

/// Tela de Agenda Inteligente: clientes atrasados para retornar e horários
/// livres de hoje entre atendimentos. Cálculos puros via InteligenciaService,
/// a partir dos dados já existentes (não introduz nenhuma persistência nova).
class AgendaInteligenteScreen extends ConsumerWidget {
  const AgendaInteligenteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    final fmtData = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda Inteligente')),
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar clientes: $e')),
        data: (clientes) {
          return todosAgendamentosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro ao carregar agendamentos: $e')),
            data: (todos) {
              final hoje = DateTime.now();
              final agendamentosHoje = todos
                  .where((a) => a.data.year == hoje.year && a.data.month == hoje.month && a.data.day == hoje.day)
                  .toList();
              final livres = InteligenciaService.horariosLivresNoDia(agendamentosHoje);

              final atrasados = <({String nome, DateTime sugerida})>[];
              for (final c in clientes) {
                final doCliente = todos.where((a) => a.clienteId == c.id).toList();
                final info = InteligenciaService.calcularParaCliente(doCliente);
                if (info.atrasado && info.proximaDataSugerida != null) {
                  atrasados.add((nome: c.nome, sugerida: info.proximaDataSugerida!));
                }
              }
              atrasados.sort((a, b) => a.sugerida.compareTo(b.sugerida));

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Clientes atrasados para retornar', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (atrasados.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('Nenhum cliente atrasado no momento.'),
                      ),
                    )
                  else
                    ...atrasados.map((c) => Card(
                          child: ListTile(
                            leading: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                            title: Text(c.nome),
                            subtitle: Text('Retorno sugerido: ${fmtData.format(c.sugerida)}'),
                          ),
                        )),
                  const SizedBox(height: 20),
                  Text('Horários livres hoje', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (livres.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('Nenhum horário livre hoje (agenda cheia ou expediente encerrado).'),
                      ),
                    )
                  else
                    ...livres.map((f) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.schedule),
                            title: Text('${f.inicio} – ${f.fim}'),
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
