import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../clientes/controllers/cliente_controller.dart'; 
import '../controllers/produto_controller.dart';
import '../controllers/venda_controller.dart';
import '../models/produto.dart';
import '../models/venda_produto.dart';

class ProdutosScreen extends ConsumerStatefulWidget {
  const ProdutosScreen({super.key});

  @override
  ConsumerState<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends ConsumerState<ProdutosScreen> {
  final _moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');
  DateTime _mesFiltro = DateTime.now(); 
  
  // 🔍 NOVOS: Controles de Filtro da Vitrine
  String _searchQuery = '';
  String _categoriaSelecionada = 'Todas';
  final List<String> _categorias = ['Todas', 'Joias', 'Produtos de Beleza', 'Outros'];

  void _abrirFormulario({Produto? produto}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _FormularioProduto(produtoEdit: produto),
    );
  }

  void _abrirModalVenda(Produto p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _ModalVendaProduto(produto: p),
    );
  }

  void _confirmarExclusao(Produto p) async {
    final snapshot = await FirebaseFirestore.instance.collection('loja_vendas').where('produtoId', isEqualTo: p.id).limit(1).get();
    final temVendas = snapshot.docs.isNotEmpty;
    if (!mounted) return;

    if (temVendas) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('Produto com histórico', style: TextStyle(fontSize: 16)))]),
          content: Text('O produto "${p.nome}" já possui vendas.\n\nSe excluí-lo:\n1. O DRE antigo não será alterado.\n2. Você não poderá devolver itens ao estoque em estornos futuros.\n\nDeseja apagar mesmo assim?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(produtoControllerProvider.notifier).excluirProduto(p.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto excluído.'), backgroundColor: Colors.red));
              },
              child: const Text('Sim, Excluir'),
            ),
          ],
        ),
      );
    } else {
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
  }

  void _confirmarExclusaoVenda(VendaProduto v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Estornar Venda')]),
        content: Text('Deseja estornar a venda de ${v.quantidade}x ${v.produtoNome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vendaControllerProvider.notifier).cancelarVenda(v);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venda estornada com sucesso! 🔄'), backgroundColor: Colors.blue));
            },
            child: const Text('Estornar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF8A2463);
    final produtosAsync = ref.watch(produtoControllerProvider);
    final vendasAsync = ref.watch(vendaControllerProvider);

    final controleMes = Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: primaryColor), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month - 1)); ref.read(vendaControllerProvider.notifier).carregarVendasMes(_mesFiltro); }),
          Text(DateFormat('MMMM yyyy', 'pt_BR').format(_mesFiltro).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
          IconButton(icon: const Icon(Icons.chevron_right, color: primaryColor), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + 1)); ref.read(vendaControllerProvider.notifier).carregarVendasMes(_mesFiltro); }),
        ],
      ),
    );

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
            IconButton(icon: const Icon(Icons.add_circle, color: primaryColor, size: 28), onPressed: () => _abrirFormulario())
          ],
        ),
        body: TabBarView(
          children: [
            // ==========================================
            // ABA 1: VITRINE COM FILTROS E TOTAIS
            // ==========================================
            produtosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (produtos) {
                // 1. Filtragem ultra-rápida na memória
                final produtosFiltrados = produtos.where((p) {
                  final matchNome = p.nome.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchCategoria = _categoriaSelecionada == 'Todas' || p.categoria == _categoriaSelecionada;
                  return matchNome && matchCategoria;
                }).toList();

                // 2. Cálculo do Total do Estoque Filtrado
                double capitalInvestido = 0;
                double potencialVenda = 0;
                for (var p in produtosFiltrados) {
                  capitalInvestido += (p.custo * p.estoque);
                  potencialVenda += (p.precoVenda * p.estoque);
                }

                return Column(
                  children: [
                    // BARRA DE PESQUISA
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Pesquisar produto...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),

                    // PÍLULAS DE CATEGORIA
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categorias.length,
                        itemBuilder: (context, index) {
                          final cat = _categorias[index];
                          final isSelected = _categoriaSelecionada == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              selectedColor: primaryColor,
                              backgroundColor: Colors.white,
                              onSelected: (selected) { if(selected) setState(() => _categoriaSelecionada = cat); },
                            ),
                          );
                        },
                      ),
                    ),

                    // CARD DE VALOR TOTAL DO ESTOQUE
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.shade100)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Capital Investido (Custo)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_moeda.format(capitalInvestido), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Potencial de Venda', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_moeda.format(potencialVenda), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // LISTA DE PRODUTOS
                    Expanded(
                      child: produtosFiltrados.isEmpty
                        ? const Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: produtosFiltrados.length,
                            itemBuilder: (context, index) {
                              final p = produtosFiltrados[index];
                              final semEstoque = p.estoque <= 0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: semEstoque ? Colors.red.shade200 : Colors.grey.shade200)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 55, height: 55,
                                        decoration: BoxDecoration(color: semEstoque ? Colors.red.shade50 : Colors.pink.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 28))),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Container(
                                              margin: const EdgeInsets.only(top: 2, bottom: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(4)),
                                              child: Text(p.categoria, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade700)),
                                            ),
                                            Text(semEstoque ? '⚠️ SEM ESTOQUE' : '📦 Estoque: ${p.estoque} un', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: semEstoque ? Colors.red : Colors.blueGrey)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(_moeda.format(p.precoVenda), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              InkWell(onTap: () => _abrirFormulario(produto: p), child: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey)),
                                              const SizedBox(width: 12),
                                              InkWell(onTap: () => _confirmarExclusao(p), child: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(backgroundColor: semEstoque ? Colors.grey.shade400 : Colors.green.shade600, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(0, 32)),
                                            onPressed: semEstoque ? null : () => _abrirModalVenda(p),
                                            icon: const Icon(Icons.point_of_sale, size: 16),
                                            label: const Text('VENDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                );
              },
            ),
            
            // ==========================================
            // ABA 2: HISTÓRICO DE VENDAS
            // ==========================================
            vendasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (vendas) {
                if (vendas.isEmpty) { return Column(children: [controleMes, const Expanded(child: Center(child: Text('Nenhuma venda registrada neste mês.', style: TextStyle(color: Colors.grey))))]); }
                final totalVendido = vendas.fold(0.0, (sum, v) => sum + v.valorTotal);
                final totalLucro = vendas.fold(0.0, (sum, v) => sum + v.lucroTotal);

                return Column(
                  children: [
                    controleMes,
                    Container(
                      padding: const EdgeInsets.all(16), color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Column(children: [const Text('Total Vendido', style: TextStyle(fontSize: 12, color: Colors.green)), Text(_moeda.format(totalVendido), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800))]))),
                          const SizedBox(width: 12),
                          Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Column(children: [const Text('Lucro Líquido', style: TextStyle(fontSize: 12, color: Colors.blue)), Text(_moeda.format(totalLucro), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800))]))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: vendas.length,
                        itemBuilder: (context, index) {
                          final v = vendas[index];
                          return Card(
                            elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                            child: ListTile(
                              leading: Text(v.emoji, style: const TextStyle(fontSize: 24)),
                              title: Text('${v.quantidade}x ${v.produtoNome}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('👤 ${v.clienteNome}', style: const TextStyle(fontSize: 12)), Text('📅 ${DateFormat('dd/MM/yyyy HH:mm').format(v.dataVenda)}', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_moeda.format(v.valorTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  Text('Lucro: ${_moeda.format(v.lucroTotal)}', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  InkWell(onTap: () => _confirmarExclusaoVenda(v), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.undo, size: 10, color: Colors.red.shade700), const SizedBox(width: 4), Text('ESTORNAR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade700))]))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MODAL DE VENDA EXPRESSA 
// ==========================================
class _ModalVendaProduto extends ConsumerStatefulWidget {
  final Produto produto;
  const _ModalVendaProduto({required this.produto});
  @override
  ConsumerState<_ModalVendaProduto> createState() => _ModalVendaProdutoState();
}

class _ModalVendaProdutoState extends ConsumerState<_ModalVendaProduto> {
  String _nomeClienteDigitado = '';
  int _quantidade = 1;
  DateTime _dataSelecionada = DateTime.now(); // 📅 NOVO
  bool _salvando = false;

  void _confirmarVenda() async {
    setState(() => _salvando = true);
    await ref.read(vendaControllerProvider.notifier).registrarVendaAvulsa(widget.produto, _quantidade, _nomeClienteDigitado.trim(), _dataSelecionada);
    if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Venda de ${widget.produto.nome} registrada!'), backgroundColor: Colors.green)); }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    final total = p.precoVenda * _quantidade;
    final clientesAsync = ref.watch(clienteControllerProvider);
    final nomesClientes = clientesAsync.maybeWhen(data: (clientes) => clientes.map((c) => c.nome).toList(), orElse: () => <String>[]);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Text(p.emoji, style: const TextStyle(fontSize: 32)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Registrar Venda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)), Text(p.nome, style: const TextStyle(fontSize: 14, color: Colors.grey))]))]),
          const Divider(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantidade:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Row(children: [IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: _quantidade > 1 ? () => setState(() => _quantidade--) : null), Text('$_quantidade', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: _quantidade < p.estoque ? () => setState(() => _quantidade++) : null)])
            ],
          ),
          const SizedBox(height: 16),
          
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              _nomeClienteDigitado = textEditingValue.text; 
              if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
              return nomesClientes.where((nome) => nome.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) => _nomeClienteDigitado = selection,
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextField(controller: controller, focusNode: focusNode, onChanged: (val) => _nomeClienteDigitado = val, decoration: const InputDecoration(labelText: 'Nome da Cliente', hintText: 'Busca automática...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_search_outlined)), textCapitalization: TextCapitalization.words);
            },
          ),
          const SizedBox(height: 16),

          // 📅 NOVO: Seletor de Data da Venda
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _dataSelecionada, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (picked != null) setState(() => _dataSelecionada = DateTime(picked.year, picked.month, picked.day, DateTime.now().hour, DateTime.now().minute));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [const Icon(Icons.calendar_today, color: Colors.grey), const SizedBox(width: 12), Text('Data da Venda: ${DateFormat('dd/MM/yyyy').format(_dataSelecionada)}', style: const TextStyle(fontSize: 16))]),
            ),
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total a Receber:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), Text(NumberFormat.simpleCurrency(locale: 'pt_BR').format(total), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade800))]),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
              const SizedBox(width: 12),
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600), onPressed: _salvando ? null : _confirmarVenda, icon: _salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check), label: Text(_salvando ? 'PROCESSANDO...' : 'CONFIRMAR VENDA')),
            ],
          ),
        ],
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
  String _categoriaSelecionada = 'Joias'; // 🏷️ NOVO
  DateTime _dataCompra = DateTime.now(); // 📅 NOVO
  bool _salvando = false;

  final List<String> _opcoesEmojis = ['🛍️', '💅', '🧴', '💄', '💍', '💎', '🎀', '✨', '🎁', '🧼'];
  final List<String> _categoriasForm = ['Joias', 'Produtos de Beleza', 'Outros']; // 🏷️ NOVO

  @override
  void initState() {
    super.initState();
    if (widget.produtoEdit != null) {
      final p = widget.produtoEdit!;
      _nomeController.text = p.nome;
      _custoController.text = p.custo.toStringAsFixed(2).replaceAll('.', ',');
      _vendaController.text = p.precoVenda.toStringAsFixed(2).replaceAll('.', ',');
      _estoqueController.text = p.estoque.toString();
      _categoriaSelecionada = _categoriasForm.contains(p.categoria) ? p.categoria : 'Outros';
      _dataCompra = p.dataCompra;
      
      if (_opcoesEmojis.contains(p.emoji)) { _emojiSelecionado = p.emoji; } else { _opcoesEmojis.add(p.emoji); _emojiSelecionado = p.emoji; }
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
      categoria: _categoriaSelecionada, // 🏷️ NOVO
      dataCompra: _dataCompra, // 📅 NOVO
    );

    await ref.read(produtoControllerProvider.notifier).salvarProduto(produto);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.produtoEdit != null ? '✏️ Editar Produto' : '🛍️ Novo Produto', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8A2463))),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Container(width: 70, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _emojiSelecionado, isExpanded: true, items: _opcoesEmojis.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 22)))).toList(), onChanged: (val) => setState(() => _emojiSelecionado = val!)))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words)),
            ],
          ),
          const SizedBox(height: 16),

          // 🏷️ NOVO: Seletor de Categoria
          DropdownButtonFormField<String>(
            value: _categoriaSelecionada,
            decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
            items: _categoriasForm.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _categoriaSelecionada = val!),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: TextField(controller: _custoController, decoration: const InputDecoration(labelText: 'Custo (Pago)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _vendaController, decoration: const InputDecoration(labelText: 'Preço Venda', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: TextField(controller: _estoqueController, decoration: const InputDecoration(labelText: 'Estoque Atual', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              // 📅 NOVO: Seletor de Data de Compra
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _dataCompra, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (picked != null) setState(() => _dataCompra = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                    child: Text('Comprado em:\n${DateFormat('dd/MM/yy').format(_dataCompra)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
              const SizedBox(width: 12),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8A2463)), onPressed: _salvando ? null : _salvar, child: _salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.produtoEdit != null ? 'ATUALIZAR' : 'CADASTRAR')),
            ],
          ),
        ],
      ),
    );
  }
}
