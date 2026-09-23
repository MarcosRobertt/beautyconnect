import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../controllers/estoque_controller.dart';
import '../models/insumo.dart';

class EstoqueScreen extends ConsumerStatefulWidget {
  const EstoqueScreen({super.key});

  @override
  ConsumerState<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends ConsumerState<EstoqueScreen> {
  String _filtroBusca = '';

  void _abrirModalInsumo(BuildContext context, [Insumo? insumoExistente]) {
    final nomeController = TextEditingController(text: insumoExistente?.nome ?? '');
    final categoriaController = TextEditingController(text: insumoExistente?.categoria ?? 'Géis e Acrílicos');
    final quantidadeController = TextEditingController(text: insumoExistente?.quantidade.toString() ?? '1');
    final estoqueMinimoController = TextEditingController(text: insumoExistente?.estoqueMinimo.toString() ?? '1');
    final precoController = TextEditingController(text: insumoExistente?.precoPago.toStringAsFixed(2) ?? '0.00');
    DateTime dataCompra = insumoExistente?.dataCompra ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      insumoExistente == null ? 'Novo Insumo / Produto' : 'Editar Insumo',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ['Géis e Acrílicos', 'Preparadores', 'Esmaltes', 'Descartáveis', 'Ferramentas', 'Outros'].contains(categoriaController.text)
                          ? categoriaController.text
                          : 'Géis e Acrílicos',
                      decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                      items: ['Géis e Acrílicos', 'Preparadores', 'Esmaltes', 'Descartáveis', 'Ferramentas', 'Outros']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => categoriaController.text = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantidadeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qtd. Atual', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: estoqueMinimoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qtd. Mínima', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precoController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Preço Pago (R\$)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dataCompra,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() => dataCompra = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Data Compra', border: OutlineInputBorder()),
                              child: Text(DateFormat('dd/MM/yyyy').format(dataCompra), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(insumoExistente == null ? 'Cadastrar Produto' : 'Salvar Alterações'),
                      onPressed: () {
                        if (nomeController.text.trim().isEmpty) return;

                        final novoInsumo = Insumo(
                          id: insumoExistente?.id ?? '',
                          nome: nomeController.text.trim(),
                          categoria: categoriaController.text,
                          quantidade: int.tryParse(quantidadeController.text) ?? 1,
                          estoqueMinimo: int.tryParse(estoqueMinimoController.text) ?? 1,
                          precoPago: double.tryParse(precoController.text.replaceAll(',', '.')) ?? 0.0,
                          dataCompra: dataCompra,
                        );

                        ref.read(estoqueControllerProvider.notifier).salvar(novoInsumo);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final estoqueAsync = ref.watch(estoqueControllerProvider);
    final fmtMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fmtData = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque de Insumos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirModalInsumo(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo Insumo'),
      ),
      body: estoqueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar estoque: $e')),
        data: (insumos) {
          final hoje = DateTime.now();
          final inicioMes = DateTime(hoje.year, hoje.month, 1);

          double gastoMes = 0;
          int itensEmAlerta = 0;

          for (final i in insumos) {
            if (i.emAlerta) itensEmAlerta++;
            if (i.dataCompra.isAfter(inicioMes.subtract(const Duration(seconds: 1)))) {
              gastoMes += i.precoPago * i.quantidade;
            }
          }

          final insumosFiltrados = insumos.where((i) {
            return i.nome.toLowerCase().contains(_filtroBusca.toLowerCase()) ||
                i.categoria.toLowerCase().contains(_filtroBusca.toLowerCase());
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 0,
                            color: Colors.deepOrange.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Gasto no Mês', style: TextStyle(fontSize: 11, color: Colors.deepOrange.shade900, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(fmtMoeda.format(gastoMes), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade900)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            color: itensEmAlerta > 0 ? Colors.red.shade50 : Colors.green.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Alertas de Reposição', style: TextStyle(fontSize: 11, color: itensEmAlerta > 0 ? Colors.red.shade900 : Colors.green.shade900, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('$itensEmAlerta produto(s)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: itensEmAlerta > 0 ? Colors.red.shade900 : Colors.green.shade900)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar insumo por nome ou categoria...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (v) => setState(() => _filtroBusca = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: insumosFiltrados.isEmpty
                    ? const Center(child: Text('Nenhum insumo encontrado.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: insumosFiltrados.length,
                        itemBuilder: (context, index) {
                          final item = insumosFiltrados[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: item.emAlerta ? Colors.red.shade100 : Colors.blue.shade100,
                                child: Icon(
                                  item.emAlerta ? Icons.warning_amber : Icons.inventory_2,
                                  color: item.emAlerta ? Colors.red.shade800 : Colors.blue.shade800,
                                  size: 20,
                                ),
                              ),
                              title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${item.categoria} • Compra: ${fmtData.format(item.dataCompra)}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center, // <--- ERRO CORRIGIDO AQUI
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Qtd: ${item.quantidade}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: item.emAlerta ? Colors.red : Colors.black87)),
                                  Text('Mín: ${item.estoqueMinimo}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              onTap: () => _abrirModalInsumo(context, item),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
