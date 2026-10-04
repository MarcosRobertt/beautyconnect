import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../controllers/produto_controller.dart';
import '../models/produto.dart';

class ProdutosScreen extends ConsumerStatefulWidget {
  const ProdutosScreen({super.key});

  @override
  ConsumerState<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends ConsumerState<ProdutosScreen> {
  final _moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

  void _abrirFormulario({Produto? produto}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _FormularioProduto(produtoEdit: produto),
    );
  }

  void _confirmarExclusao(Produto p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: Text('Tem certeza que deseja apagar "${p.nome}" da loja?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(produtoControllerProvider.notifier).excluirProduto(p.id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF8A2463);
    final produtosAsync = ref.watch(produtoControllerProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF0F4),
        appBar: AppBar(
          title: const Text('Loja & Revenda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          bottom: const TabBar(
            labelColor: primaryColor,
            indicatorColor: primaryColor,
            tabs: [
              Tab(icon: Icon(Icons.storefront), text: 'Vitrine (Estoque)'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Histórico de Vendas'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: primaryColor, size: 28),
              tooltip: 'Cadastrar Novo Produto',
              onPressed: () => _abrirFormulario(),
            )
          ],
        ),
        body: TabBarView(
          children: [
            // ==========================================
            // ABA 1: VITRINE (ESTOQUE)
            // ==========================================
            produtosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (produtos) {
                if (produtos.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sua vitrine está vazia.\nClique no + para cadastrar o primeiro produto.', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Colors.grey)
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: produtos.length,
                  itemBuilder: (context, index) {
                    final p = produtos[index];
                    final semEstoque = p.estoque <= 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), 
                        side: BorderSide(color: semEstoque ? Colors.red.shade200 : Colors.grey.shade200)
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: semEstoque ? Colors.red.shade50 : Colors.pink.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(p.emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              semEstoque ? '⚠️ SEM ESTOQUE' : '📦 Estoque: ${p.estoque} un', 
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: semEstoque ? Colors.red : Colors.blueGrey)
                            ),
                            Text('Custo: ${_moeda.format(p.custo)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_moeda.format(p.precoVenda), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _abrirFormulario(produto: p),
                                  child: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => _confirmarExclusao(p),
                                  child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            
            // ==========================================
            // ABA 2: HISTÓRICO DE VENDAS (Etapa 2)
            // ==========================================
            const Center(
              child: Text(
                'Nenhuma venda registrada ainda.\n(O motor de vendas será ativado na próxima etapa!)', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Colors.grey)
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// FORMULÁRIO DE CADASTRO/EDIÇÃO DE PRODUTO
// ==========================================
class _FormularioProduto extends ConsumerStatefulWidget {
  final Produto? produtoEdit;
  const _FormularioProduto({this.produtoEdit});

  @override
  ConsumerState<_FormularioProduto> createState() => _FormularioProdutoState();
}

class _FormularioProdutoState extends ConsumerState<_FormularioProduto> {
  final _nomeController = TextEditingController();
  final _custoController = TextEditingController();
  final _vendaController = TextEditingController();
  final _estoqueController = TextEditingController(text: '1');
  
  String _emojiSelecionado = '🛍️';
  bool _salvando = false;

  final List<String> _opcoesEmojis = [
    '🛍️', '💅', '🧴', '💄', '💍', '💎', '🎀', '✨', '🎁', '🧼'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.produtoEdit != null) {
      final p = widget.produtoEdit!;
      _nomeController.text = p.nome;
      _custoController.text = p.custo.toStringAsFixed(2).replaceAll('.', ',');
      _vendaController.text = p.precoVenda.toStringAsFixed(2).replaceAll('.', ',');
      _estoqueController.text = p.estoque.toString();
      
      if (_opcoesEmojis.contains(p.emoji)) {
        _emojiSelecionado = p.emoji;
      } else {
        _opcoesEmojis.add(p.emoji);
        _emojiSelecionado = p.emoji;
      }
    }
  }

  void _salvar() async {
    if (_nomeController.text.isEmpty || _vendaController.text.isEmpty) return;

    setState(() => _salvando = true);

    final custoParse = double.tryParse(_custoController.text.replaceAll(',', '.')) ?? 0.0;
    final vendaParse = double.tryParse(_vendaController.text.replaceAll(',', '.')) ?? 0.0;
    final estoqueParse = int.tryParse(_estoqueController.text) ?? 0;

    final produto = Produto(
      id: widget.produtoEdit?.id ?? '',
      nome: _nomeController.text.trim(),
      emoji: _emojiSelecionado,
      custo: custoParse,
      precoVenda: vendaParse,
      estoque: estoqueParse,
    );

    await ref.read(produtoControllerProvider.notifier).salvarProduto(produto);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.produtoEdit != null ? '✏️ Editar Produto' : '🛍️ Novo Produto', 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8A2463))
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // Seletor de Emoji Enxuto
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _emojiSelecionado,
                    isExpanded: true,
                    items: _opcoesEmojis.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 22)))).toList(),
                    onChanged: (val) => setState(() => _emojiSelecionado = val!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome do Produto (Ex: Óleo Hidratante)', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custoController,
                  decoration: const InputDecoration(labelText: 'Custo (R\$ pago)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _vendaController,
                  decoration: const InputDecoration(labelText: 'Preço Venda (R\$)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _estoqueController,
            decoration: const InputDecoration(labelText: 'Quantidade em Estoque', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8A2463)),
                onPressed: _salvando ? null : _salvar,
                child: _salvando 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Text(widget.produtoEdit != null ? 'ATUALIZAR' : 'CADASTRAR'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
