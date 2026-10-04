import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/venda_produto.dart';
import '../models/produto.dart';
import 'produto_controller.dart'; // Para avisar a vitrine que o estoque baixou

final vendaControllerProvider = StateNotifierProvider<VendaController, AsyncValue<List<VendaProduto>>>((ref) {
  return VendaController(ref);
});

class VendaController extends StateNotifier<AsyncValue<List<VendaProduto>>> {
  final Ref ref;
  VendaController(this.ref) : super(const AsyncValue.loading()) {
    carregarVendasMes(DateTime.now());
  }

  final _db = FirebaseFirestore.instance;

  // 🚀 OTIMIZAÇÃO: Busca apenas as vendas do mês atual para não gastar Firebase à toa
  Future<void> carregarVendasMes(DateTime mes) async {
    try {
      state = const AsyncValue.loading();
      final inicioMes = DateTime(mes.year, mes.month, 1);
      final fimMes = DateTime(mes.year, mes.month + 1, 0, 23, 59, 59);

      final snap = await _db.collection('loja_vendas')
          .where('dataVenda', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('dataVenda', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(const GetOptions(source: Source.serverAndCache));
      
      final vendas = snap.docs.map((doc) => VendaProduto.fromMap(doc.data(), doc.id)).toList();
      vendas.sort((a, b) => b.dataVenda.compareTo(a.dataVenda)); // Mais recentes no topo

      state = AsyncValue.data(vendas);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // 🛡️ MÁGICA DUPLA: Registra o recibo da venda E dá baixa no estoque na mesma tacada
  Future<void> registrarVendaAvulsa(Produto produto, int quantidadeSelecionada, String nomeCliente) async {
    final novaVenda = VendaProduto(
      id: '',
      produtoId: produto.id,
      produtoNome: produto.nome,
      emoji: produto.emoji,
      custoHistorico: produto.custo,     // "Foto" do custo hoje
      precoVendido: produto.precoVenda,  // "Foto" da venda hoje
      quantidade: quantidadeSelecionada,
      clienteNome: nomeCliente.isEmpty ? 'Avulso (Balcão)' : nomeCliente,
      dataVenda: DateTime.now(),
    );

    final batch = _db.batch();

    // 1. Cria o recibo da venda
    final docVenda = _db.collection('loja_vendas').doc();
    batch.set(docVenda, novaVenda.toMap());

    // 2. Deduz o estoque do produto (Mão invisível do sistema)
    final docProduto = _db.collection('loja_produtos').doc(produto.id);
    final novoEstoque = produto.estoque - quantidadeSelecionada;
    batch.update(docProduto, {'estoque': novoEstoque < 0 ? 0 : novoEstoque});

    // Envia tudo pro Firebase de uma vez só (Economiza requisições)
    await batch.commit();

    // Atualiza a tela de vendas e a tela de vitrine
    await carregarVendasMes(DateTime.now());
    ref.read(produtoControllerProvider.notifier).carregarProdutos();
  }
}
