import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/venda_produto.dart';
import '../models/produto.dart';
import 'produto_controller.dart';

final vendaControllerProvider = StateNotifierProvider<VendaController, AsyncValue<List<VendaProduto>>>((ref) {
  return VendaController(ref);
});

class VendaController extends StateNotifier<AsyncValue<List<VendaProduto>>> {
  final Ref ref;
  DateTime _mesAtual = DateTime.now(); // 🧠 Lembra qual mês o usuário está visualizando!

  VendaController(this.ref) : super(const AsyncValue.loading()) {
    carregarVendasMes(DateTime.now());
  }

  final _db = FirebaseFirestore.instance;

  Future<void> carregarVendasMes(DateTime mes) async {
    try {
      _mesAtual = mes; // Guarda a referência
      state = const AsyncValue.loading();
      final inicioMes = DateTime(mes.year, mes.month, 1);
      final fimMes = DateTime(mes.year, mes.month + 1, 0, 23, 59, 59);

      final snap = await _db.collection('loja_vendas')
          .where('dataVenda', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('dataVenda', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(const GetOptions(source: Source.serverAndCache));
      
      final vendas = snap.docs.map((doc) => VendaProduto.fromMap(doc.data(), doc.id)).toList();
      vendas.sort((a, b) => b.dataVenda.compareTo(a.dataVenda)); 

      state = AsyncValue.data(vendas);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> registrarVendaAvulsa(Produto produto, int quantidadeSelecionada, String nomeCliente) async {
    final novaVenda = VendaProduto(
      id: '',
      produtoId: produto.id,
      produtoNome: produto.nome,
      emoji: produto.emoji,
      custoHistorico: produto.custo,     
      precoVendido: produto.precoVenda,  
      quantidade: quantidadeSelecionada,
      clienteNome: nomeCliente.isEmpty ? 'Avulso (Balcão)' : nomeCliente,
      dataVenda: DateTime.now(),
    );

    final batch = _db.batch();

    final docVenda = _db.collection('loja_vendas').doc();
    batch.set(docVenda, novaVenda.toMap());

    final docProduto = _db.collection('loja_produtos').doc(produto.id);
    final novoEstoque = produto.estoque - quantidadeSelecionada;
    batch.update(docProduto, {'estoque': novoEstoque < 0 ? 0 : novoEstoque});

    await batch.commit();

    await carregarVendasMes(_mesAtual); // Atualiza e mantém no mês que estava
    ref.read(produtoControllerProvider.notifier).carregarProdutos();
  }

  Future<void> cancelarVenda(VendaProduto venda) async {
    final batch = _db.batch();

    final docVenda = _db.collection('loja_vendas').doc(venda.id);
    batch.delete(docVenda);

    final docProduto = _db.collection('loja_produtos').doc(venda.produtoId);
    batch.update(docProduto, {'estoque': FieldValue.increment(venda.quantidade)});

    await batch.commit();

    await carregarVendasMes(_mesAtual); // Atualiza e mantém no mês que estava
    ref.read(produtoControllerProvider.notifier).carregarProdutos();
  }
}
