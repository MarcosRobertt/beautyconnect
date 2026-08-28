import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../controllers/servico_controller.dart';
import '../models/servico.dart';

class ServicosScreen extends ConsumerWidget {
  const ServicosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(servicoControllerProvider);
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviços'),
        actions: [
          // BOTÃO COMPACTO: Apresenta apenas o ícone com dica visual
          estado.maybeWhen(
            data: (lista) => IconButton(
              icon: const Icon(Icons.price_change),
              tooltip: 'Reajuste em lote',
              onPressed: () => _mostrarReajusteLote(context, ref, lista),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
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

  void _mostrarReajusteLote(BuildContext context, WidgetRef ref, List<Servico> servicos) {
    if (servicos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum serviço para reajustar.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _ModalReajusteLote(servicos: servicos, ref: ref),
    );
  }
}

class _ModalReajusteLote extends StatefulWidget {
  const _ModalReajusteLote({required this.servicos, required this.ref});
  final List<Servico> servicos;
  final WidgetRef ref;

  @override
  State<_ModalReajusteLote> createState() => _ModalReajusteLoteState();
}

class _ModalReajusteLoteState extends State<_ModalReajusteLote> {
  late Set<String> _selecionados;
  final _porcentagemController = TextEditingController();
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _selecionados = widget.servicos.map((s) => s.id).toSet();
  }

  @override
  void dispose() {
    _porcentagemController.dispose();
    super.dispose();
  }

  Future<void> _aplicarReajuste() async {
    final texto = _porcentagemController.text.replaceAll(',', '.');
    final porcentagem = double.tryParse(texto);
    
    if (porcentagem == null || porcentagem == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um valor válido de porcentagem (ex: 10 ou -5).')),
      );
      return;
    }

    if (_selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um serviço para reajustar.')),
      );
      return;
    }

    setState(() => _processando = true);

    try {
      final notifier = widget.ref.read(servicoControllerProvider.notifier);
      
      for (final servico in widget.servicos) {
        if (_selecionados.contains(servico.id)) {
          final novoValor = servico.valor * (1 + (porcentagem / 100));
          final valorArredondado = double.parse(novoValor.toStringAsFixed(2));
          final atualizado = servico.copyWith(valor: valorArredondado);
          await notifier.salvar(atualizado);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reajuste de $porcentagem% aplicado a ${_selecionados.length} serviço(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aplicar reajuste: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reajuste em Lote'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _porcentagemController,
              decoration: const InputDecoration(
                labelText: 'Porcentagem (%)',
                hintText: 'Ex: 10 (Aumento) ou -5 (Desconto)',
                prefixIcon: Icon(Icons.percent),
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Serviços afetados:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selecionados.length == widget.servicos.length) {
                        _selecionados.clear();
                      } else {
                        _selecionados = widget.servicos.map((s) => s.id).toSet();
                      }
                    });
                  },
                  child: Text(_selecionados.length == widget.servicos.length ? 'Desmarcar todos' : 'Marcar todos'),
                ),
              ],
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.servicos.length,
                itemBuilder: (context, index) {
                  final s = widget.servicos[index];
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.nome),
                    subtitle: Text('Valor atual: R\$ ${s.valor.toStringAsFixed(2).replaceAll('.', ',')}'),
                    value: _selecionados.contains(s.id),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selecionados.add(s.id);
                        } else {
                          _selecionados.remove(s.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _processando ? null : _aplicarReajuste,
          child: _processando 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Aplicar Reajuste'),
        ),
      ],
    );
  }
}
