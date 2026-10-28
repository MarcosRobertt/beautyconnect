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
  
  // 🎨 IDENTIDADE VISUAL (VERDE SÁLVIA)
  final Color _primaryColor = const Color(0xFF3A4E40); 
  final Color _lightAccent = const Color(0xFFE8EFEA);  
  final Color _borderAccent = const Color(0xFFB5C4B9); 

  // Filtros da Vitrine
  String _searchQuery = '';
  String _categoriaSelecionadaVitrine = 'Todas';
  
  // Filtros do Histórico de Vendas
  DateTime? _diaFiltroVendas;
  String _categoriaSelecionadaVendas = 'Todas';

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
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('Produto com histórico', style: TextStyle(fontSize: 16)))]),
        content: Text('O produto "${p.nome}" já possui vendas.\n\nSe excluí-lo:\n1. O DRE antigo não será alterado.\n2. Você não poderá devolver itens ao estoque em estornos futuros.\n\nDeseja apagar mesmo assim?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () { Navigator.pop(ctx); ref.read(produtoControllerProvider.notifier).excluirProduto(p.id); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto excluído.'), backgroundColor: Colors.red)); }, child: const Text('Sim, Excluir')),
        ],
      ));
    } else {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Excluir Produto'), content: Text('Tem certeza que deseja apagar "${p.nome}" da loja?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(ctx); ref.read(produtoControllerProvider.notifier).excluirProduto(p.id); }, child: const Text('Excluir')),
        ],
      ));
    }
  }

  void _confirmarExclusaoVenda(VendaProduto v) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Estornar Venda')]),
      content: Text('Deseja estornar a venda de ${v.quantidade}x ${v.produtoNome}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar', style: TextStyle(color: Colors.grey))),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () { Navigator.pop(ctx); ref.read(vendaControllerProvider.notifier).cancelarVenda(v); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venda estornada com sucesso! 🔄'), backgroundColor: Colors.blue)); }, child: const Text('Estornar')),
      ],
    ));
  }

  Widget _buildValidadeBadge(Produto p) {
    if (!p.temValidade || p.dataValidade == null) return const SizedBox.shrink();
    
    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final venc = DateTime(p.dataValidade!.year, p.dataValidade!.month, p.dataValidade!.day);
    final diasRestantes = venc.difference(hoje).inDays;

    if (diasRestantes < 0) {
      return Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)), child: Text('❌ VENCIDO (${diasRestantes.abs()} dias)', style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontWeight: FontWeight.bold)));
    } else if (diasRestantes <= 30) {
      return Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)), child: Text('⚠️ Vence em $diasRestantes dias', style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.bold)));
    }
    return Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _lightAccent, borderRadius: BorderRadius.circular(4), border: Border.all(color: _borderAccent)), child: Text('✅ Validade: ${DateFormat('dd/MM/yy').format(p.dataValidade!)}', style: TextStyle(fontSize: 10, color: _primaryColor)));
  }

  @override
  Widget build(BuildContext context) {
    final produtosAsync = ref.watch(produtoControllerProvider);
    final vendasAsync = ref.watch(vendaControllerProvider);

    final controleMes = Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: Icon(Icons.chevron_left, color: _primaryColor), onPressed: () { setState(() { _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month - 1); _diaFiltroVendas = null; }); ref.read(vendaControllerProvider.notifier).carregarVendasMes(_mesFiltro); }),
          Text(DateFormat('MMMM yyyy', 'pt_BR').format(_mesFiltro).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryColor)),
          IconButton(icon: Icon(Icons.chevron_right, color: _primaryColor), onPressed: () { setState(() { _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + 1); _diaFiltroVendas = null; }); ref.read(vendaControllerProvider.notifier).carregarVendasMes(_mesFiltro); }),
        ],
      ),
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAF9),
        appBar: AppBar(
          title: const Text('Loja & Revenda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: _lightAccent.withOpacity(0.5),
          bottom: TabBar(labelColor: _primaryColor, indicatorColor: _primaryColor, tabs: const [Tab(icon: Icon(Icons.storefront), text: 'Vitrine (Estoque)'), Tab(icon: Icon(Icons.receipt_long), text: 'Histórico')]),
          actions: [IconButton(icon: Icon(Icons.add_circle, color: _primaryColor, size: 28), onPressed: () => _abrirFormulario())],
        ),
        body: TabBarView(
          children: [
            // ==========================================
            // ABA 1: VITRINE
            // ==========================================
            produtosAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: _primaryColor)), error: (e, _) => Center(child: Text('Erro: $e')),
              data: (produtos) {
                final produtosFiltrados = produtos.where((p) {
                  final matchNome = p.nome.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchCategoria = _categoriaSelecionadaVitrine == 'Todas' || p.categoria == _categoriaSelecionadaVitrine;
                  return matchNome && matchCategoria;
                }).toList();

                double capitalInvestido = 0; double potencialVenda = 0;
                for (var p in produtosFiltrados) { capitalInvestido += (p.custo * p.estoque); potencialVenda += (p.precoVenda * p.estoque); }

                return Column(
                  children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: TextField(onChanged: (val) => setState(() => _searchQuery = val), decoration: InputDecoration(hintText: 'Pesquisar produto...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderAccent)), contentPadding: const EdgeInsets.symmetric(vertical: 0)))),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _categorias.length,
                        itemBuilder: (context, index) {
                          final cat = _categorias[index]; final isSelected = _categoriaSelecionadaVitrine == cat;
                          return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), selected: isSelected, selectedColor: _primaryColor, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: _borderAccent)), onSelected: (selected) { if(selected) setState(() => _categoriaSelecionadaVitrine = cat); }));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderAccent)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Capital Investido', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(_moeda.format(capitalInvestido), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange))]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Potencial de Venda', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(_moeda.format(potencialVenda), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryColor))]),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: produtosFiltrados.isEmpty ? const Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.grey))) : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: produtosFiltrados.length,
                        itemBuilder: (context, index) {
                          final p = produtosFiltrados[index]; final semEstoque = p.estoque <= 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: semEstoque ? Colors.red.shade200 : _borderAccent)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(width: 55, height: 55, decoration: BoxDecoration(color: semEstoque ? Colors.red.shade50 : _lightAccent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 28)))),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Container(margin: const EdgeInsets.only(top: 2, bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(4)), child: Text(p.categoria, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade700))),
                                        Text(semEstoque ? '⚠️ SEM ESTOQUE' : '📦 Estoque: ${p.estoque} un', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: semEstoque ? Colors.red : Colors.blueGrey)),
                                        _buildValidadeBadge(p), 
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_moeda.format(p.precoVenda), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryColor)),
                                      const SizedBox(height: 8),
                                      Row(children: [InkWell(onTap: () => _abrirFormulario(produto: p), child: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey)), const SizedBox(width: 12), InkWell(onTap: () => _confirmarExclusao(p), child: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300))]),
                                      const SizedBox(height: 8),
                                      FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: semEstoque ? Colors.grey.shade400 : _primaryColor, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(0, 32)), onPressed: semEstoque ? null : () => _abrirModalVenda(p), icon: const Icon(Icons.point_of_sale, size: 16), label: const Text('VENDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
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
            // ABA 2: HISTÓRICO (Com Filtros e Status)
            // ==========================================
            vendasAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: _primaryColor)), error: (e, _) => Center(child: Text('Erro: $e')),
              data: (vendas) {
                // Ponte para buscar a categoria do produto 
                final listaProdutos = produtosAsync.value ?? [];
                String categoriaDaVenda(VendaProduto v) {
                  try {
                    return listaProdutos.firstWhere((p) => p.nome == v.produtoNome).categoria;
                  } catch (_) {
                    return 'Outros';
                  }
                }

                // Coleta categorias
                final categoriasVendidas = {'Todas'};
                for (var v in vendas) { 
                  categoriasVendidas.add(categoriaDaVenda(v)); 
                }
                final listCatVendas = categoriasVendidas.toList()..sort();
                if (!listCatVendas.contains(_categoriaSelecionadaVendas)) _categoriaSelecionadaVendas = 'Todas';

                // Aplicação dos Filtros
                final vendasFiltradas = vendas.where((v) {
                  bool matchData = true;
                  if (_diaFiltroVendas != null) {
                    matchData = v.dataVenda.year == _diaFiltroVendas!.year && v.dataVenda.month == _diaFiltroVendas!.month && v.dataVenda.day == _diaFiltroVendas!.day;
                  }
                  bool matchCat = _categoriaSelecionadaVendas == 'Todas' || categoriaDaVenda(v) == _categoriaSelecionadaVendas;
                  return matchData && matchCat;
                }).toList();

                final totalVendido = vendasFiltradas.fold(0.0, (sum, v) => sum + v.valorTotal);
                final totalLucro = vendasFiltradas.fold(0.0, (sum, v) => sum + v.lucroTotal);

                return Column(
                  children: [
                    controleMes,
                    
                    // 🔘 BARRA DE FILTROS DO HISTÓRICO
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                            child: Text('Filtros:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 16),
                              InkWell(
                                onTap: () async {
                                  final hoje = DateTime.now();
                                  final dataInicial = _mesFiltro.year == hoje.year && _mesFiltro.month == hoje.month ? hoje : DateTime(_mesFiltro.year, _mesFiltro.month, 1);
                                  
                                  final picked = await showDatePicker(
                                    context: context, 
                                    initialDate: _diaFiltroVendas ?? dataInicial, 
                                    firstDate: DateTime(_mesFiltro.year, _mesFiltro.month, 1), 
                                    lastDate: DateTime(_mesFiltro.year, _mesFiltro.month + 1, 0),
                                    builder: (context, child) { return Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)), child: child!); }
                                  );
                                  if (picked != null) {
                                    setState(() => _diaFiltroVendas = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _diaFiltroVendas != null ? _primaryColor : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _diaFiltroVendas != null ? _primaryColor : _borderAccent)
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: _diaFiltroVendas != null ? Colors.white : Colors.black87),
                                      const SizedBox(width: 6),
                                      Text(_diaFiltroVendas != null ? DateFormat('dd/MM').format(_diaFiltroVendas!) : 'Dia', style: TextStyle(color: _diaFiltroVendas != null ? Colors.white : Colors.black87, fontWeight: _diaFiltroVendas != null ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                                      if (_diaFiltroVendas != null) ...[
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => setState(() => _diaFiltroVendas = null),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(height: 24, width: 1, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 32,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal, itemCount: listCatVendas.length,
                                    itemBuilder: (context, index) {
                                      final cat = listCatVendas[index]; final isSelected = _categoriaSelecionadaVendas == cat;
                                      return Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 11)), selected: isSelected, selectedColor: _primaryColor, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: _borderAccent)), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), onSelected: (selected) { if(selected) setState(() => _categoriaSelecionadaVendas = cat); }));
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16), color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _lightAccent, borderRadius: BorderRadius.circular(8)), child: Column(children: [const Text('Total Vendido', style: TextStyle(fontSize: 12, color: Colors.blueGrey)), Text(_moeda.format(totalVendido), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor))]))),
                          const SizedBox(width: 12),
                          Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Column(children: [const Text('Lucro Líquido', style: TextStyle(fontSize: 12, color: Colors.blue)), Text(_moeda.format(totalLucro), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800))]))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: vendasFiltradas.isEmpty 
                      ? const Center(child: Text('Nenhuma venda registrada para este filtro.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                        padding: const EdgeInsets.all(16), itemCount: vendasFiltradas.length,
                        itemBuilder: (context, index) {
                          final v = vendasFiltradas[index];
                          
                          bool estaAtrasado = false;
                          if (!v.isPago && v.dataPagamentoEsperada != null) {
                            final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                            final prev = DateTime(v.dataPagamentoEsperada!.year, v.dataPagamentoEsperada!.month, v.dataPagamentoEsperada!.day);
                            estaAtrasado = prev.isBefore(hoje);
                          }

                          return Card(
                            elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: !v.isPago ? Colors.orange.shade300 : _borderAccent)),
                            child: ListTile(
                              leading: Text(v.emoji, style: const TextStyle(fontSize: 24)),
                              title: Text('${v.quantidade}x ${v.produtoNome}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, 
                                children: [
                                  Text('👤 ${v.clienteNome}', style: const TextStyle(fontSize: 12)), 
                                  Text('📅 ${DateFormat('dd/MM/yyyy HH:mm').format(v.dataVenda)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  if (!v.isPago)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: estaAtrasado ? Colors.red.shade100 : Colors.orange.shade100, borderRadius: BorderRadius.circular(4)), 
                                      child: Text(estaAtrasado ? '⚠️ ATRASADO' : '⏳ Receber: ${DateFormat('dd/MM/yy').format(v.dataPagamentoEsperada!)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: estaAtrasado ? Colors.red.shade900 : Colors.orange.shade900))
                                    )
                                ]
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_moeda.format(v.valorTotal), style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)),
                                  Text(v.formaPagamento, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!v.isPago)
                                        InkWell(onTap: () { ref.read(vendaControllerProvider.notifier).confirmarPagamento(v); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Pagamento confirmado! ✅'), backgroundColor: _primaryColor)); }, child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _lightAccent, borderRadius: BorderRadius.circular(4)), child: Row(children: [Icon(Icons.check, size: 10, color: _primaryColor), const SizedBox(width: 4), Text('DAR BAIXA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _primaryColor))]))),
                                      InkWell(onTap: () => _confirmarExclusaoVenda(v), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)), child: Row(children: [Icon(Icons.undo, size: 10, color: Colors.red.shade700), const SizedBox(width: 4), Text('ESTORNAR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade700))]))),
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
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MODAL DE VENDA EXPRESSA COM PAGAMENTO
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
  DateTime _dataSelecionada = DateTime.now();
  
  String _formaPagamento = 'Dinheiro';
  bool _estaPago = true;
  DateTime _dataPagamentoEsperada = DateTime.now().add(const Duration(days: 7)); 

  bool _salvando = false;
  final Color _primaryColor = const Color(0xFF3A4E40);

  void _confirmarVenda() async {
    setState(() => _salvando = true);
    
    await ref.read(vendaControllerProvider.notifier).registrarVendaAvulsa(
      widget.produto, _quantidade, _nomeClienteDigitado.trim(), _dataSelecionada,
      _formaPagamento, _estaPago, _estaPago ? null : _dataPagamentoEsperada
    );

    if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Venda de ${widget.produto.nome} registrada!'), backgroundColor: _primaryColor)); }
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
          Row(children: [Text(p.emoji, style: const TextStyle(fontSize: 32)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Registrar Venda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)), Text(p.nome, style: const TextStyle(fontSize: 14, color: Colors.grey))]))]),
          const Divider(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantidade:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Row(children: [IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: _quantidade > 1 ? () => setState(() => _quantidade--) : null), Text('$_quantidade', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: Icon(Icons.add_circle_outline, color: _primaryColor), onPressed: _quantidade < p.estoque ? () => setState(() => _quantidade++) : null)])
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

          // 📅 NOVO CAMPO: DATA DA VENDA E FORMA DE PAGAMENTO NA MESMA LINHA
          Row(
            children: [
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, 
                      initialDate: _dataSelecionada, 
                      firstDate: DateTime(2020), 
                      lastDate: DateTime.now(), 
                      builder: (context, child) { return Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)), child: child!); }
                    );
                    if (picked != null) {
                      final agora = DateTime.now();
                      setState(() => _dataSelecionada = DateTime(picked.year, picked.month, picked.day, agora.hour, agora.minute));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Data da Venda', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15)),
                    child: Text(DateFormat('dd/MM/yy').format(_dataSelecionada)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _formaPagamento,
                  decoration: const InputDecoration(labelText: 'Recebimento', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15)),
                  items: ['Dinheiro', 'Pix', 'Cartão de Crédito', 'Cartão de Débito', 'Fiado / A Prazo'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _formaPagamento = val!;
                      if (_formaPagamento == 'Fiado / A Prazo') _estaPago = false;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 💰 CONTROLE DE PAGAMENTO
          Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('O pagamento já foi recebido?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  value: _estaPago, activeColor: _primaryColor,
                  onChanged: (val) => setState(() => _estaPago = val),
                ),
                if (!_estaPago) ...[
                  const Divider(),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _dataPagamentoEsperada, firstDate: DateTime.now(), lastDate: DateTime(2035), builder: (context, child) { return Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)), child: child!); });
                      if (picked != null) setState(() => _dataPagamentoEsperada = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(children: [Icon(Icons.calendar_today, color: Colors.orange.shade700, size: 20), const SizedBox(width: 12), Text('Data prevista para o acerto:\n${DateFormat('dd/MM/yyyy').format(_dataPagamentoEsperada)}', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold))]),
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE8EFEA), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total da Venda:', style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)), Text(NumberFormat.simpleCurrency(locale: 'pt_BR').format(total), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryColor))]),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
              const SizedBox(width: 12),
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _primaryColor), onPressed: _salvando ? null : _confirmarVenda, icon: _salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check), label: Text(_salvando ? 'PROCESSANDO...' : 'CONFIRMAR VENDA')),
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
  String _categoriaSelecionada = 'Joias'; 
  DateTime _dataCompra = DateTime.now(); 
  
  bool _temValidade = false;
  DateTime _dataValidade = DateTime.now().add(const Duration(days: 365));

  bool _salvando = false;
  final Color _primaryColor = const Color(0xFF3A4E40);

  final List<String> _opcoesEmojis = ['🛍️', '💅', '🧴', '💄', '💍', '💎', '🎀', '✨', '🎁', '🧼'];
  final List<String> _categoriasForm = ['Joias', 'Produtos de Beleza', 'Outros'];

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
      _temValidade = p.temValidade;
      if (p.dataValidade != null) _dataValidade = p.dataValidade!;
      
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
      categoria: _categoriaSelecionada, 
      dataCompra: _dataCompra,  
      temValidade: _temValidade,
      dataValidade: _temValidade ? _dataValidade : null,
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
          Text(widget.produtoEdit != null ? '✏ Editar Produto' : '🛍 Novo Produto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Container(width: 70, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _emojiSelecionado, isExpanded: true, items: _opcoesEmojis.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 22)))).toList(), onChanged: (val) => setState(() => _emojiSelecionado = val!)))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words)),
            ],
          ),
          const SizedBox(height: 16),

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
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _dataCompra, firstDate: DateTime(2020), lastDate: DateTime.now(), builder: (context, child) { return Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)), child: child!); });
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
          const SizedBox(height: 16),

          // 📅 CONTROLE DE VALIDADE
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Produto tem validade?', style: TextStyle(fontSize: 14)),
                  value: _temValidade, activeColor: _primaryColor,
                  onChanged: (val) => setState(() => _temValidade = val),
                ),
                if (_temValidade) ...[
                  const Divider(),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _dataValidade, firstDate: DateTime.now(), lastDate: DateTime(2035), builder: (context, child) { return Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)), child: child!); });
                      if (picked != null) setState(() => _dataValidade = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(children: [const Icon(Icons.date_range, color: Colors.blueGrey), const SizedBox(width: 12), Text('Data de Vencimento:\n${DateFormat('dd/MM/yyyy').format(_dataValidade)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
              const SizedBox(width: 12),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: _primaryColor), onPressed: _salvando ? null : _salvar, child: _salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.produtoEdit != null ? 'ATUALIZAR' : 'CADASTRAR')),
            ],
          ),
        ],
      ),
    );
  }
}
