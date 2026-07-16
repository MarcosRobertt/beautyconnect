import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/services/inteligencia_service.dart';
import '../controllers/cliente_controller.dart';
import '../widgets/cliente_card.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _buscaController = TextEditingController();

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.clienteNovo),
        icon: const Icon(Icons.add),
        label: const Text('Novo Cliente'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _buscaController,
              decoration: const InputDecoration(
                hintText: 'Pesquisar cliente por nome ou WhatsApp...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (texto) => ref.read(clienteControllerProvider.notifier).pesquisar(texto),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: estado.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro ao carregar clientes: $e')),
                data: (lista) {
                  if (lista.isEmpty) {
                    return const Center(child: Text('Nenhum cliente encontrado.'));
                  }
                  final todosAgendamentos = todosAgendamentosAsync.value ?? [];
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 210,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: lista.length,
                    itemBuilder: (context, i) {
                      final cliente = lista[i];
                      final agendamentosDoCliente = todosAgendamentos.where((a) => a.clienteId == cliente.id).toList();
                      return ClienteCard(
                        cliente: cliente,
                        inteligencia: InteligenciaService.calcularParaCliente(agendamentosDoCliente),
                        onEditar: () => context.push('${AppRoutes.clienteEditar}/${cliente.id}'),
                        onExcluir: () => _confirmarExclusao(context, ref, cliente.id),
                        onHistorico: () => context.push('${AppRoutes.clienteHistorico}/${cliente.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, WidgetRef ref, String id) async {
    // CORREÇÃO (Sprint 1): antes, era possível excluir um cliente mesmo com
    // agendamentos vinculados, que passavam a aparecer como "Cliente
    // removido" na Agenda. Agora a exclusão é bloqueada nesse caso.
    final todosAgendamentos = await ref.read(agendamentoControllerProvider.notifier).todos();
    final possuiAgendamentos = todosAgendamentos.any((a) => a.clienteId == id);

    if (possuiAgendamentos) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Não é possível excluir'),
          content: const Text(
            'Este cliente possui agendamentos (passados ou futuros) vinculados. '
            'Cancele ou reatribua esses agendamentos antes de excluir o cliente.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cliente'),
        content: const Text('Tem certeza que deseja excluir este cliente? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar == true) {
      await ref.read(clienteControllerProvider.notifier).excluir(id);
    }
  }
}
