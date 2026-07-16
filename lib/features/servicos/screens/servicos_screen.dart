import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../controllers/servico_controller.dart';

class ServicosScreen extends ConsumerWidget {
  const ServicosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(servicoControllerProvider);
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(title: const Text('Serviços')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.servicoNovo),
        icon: const Icon(Icons.add),
        label: const Text('Novo Serviço'),
      ),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar serviços: $e')),
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(child: Text('Nenhum serviço cadastrado ainda.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = lista[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Color(s.corValor), radius: 12),
                  title: Text(s.nome),
                  subtitle: Text('${s.duracaoMin} min · ${moeda.format(s.valor)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => context.push('${AppRoutes.servicoEditar}/${s.id}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmarExclusao(context, ref, s.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, WidgetRef ref, String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir serviço'),
        content: const Text(
          'Tem certeza? Agendamentos que já usaram este serviço não são afetados '
          '(o nome e valor ficam gravados no histórico), mas ele deixará de aparecer '
          'para novos agendamentos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar == true) {
      await ref.read(servicoControllerProvider.notifier).excluir(id);
    }
  }
}
