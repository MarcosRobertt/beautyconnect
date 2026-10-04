import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/produto.dart';

final produtoControllerProvider = StateNotifierProvider<ProdutoController, AsyncValue<List<Produto>>>((ref) {
  return ProdutoController();
});

class ProdutoController extends StateNotifier<AsyncValue<List<Produto>>> {
  ProdutoController() : super(const AsyncValue.loading()) {
    carregarProdutos();
  }

  final _db = FirebaseFirestore.instance.collection('loja_produtos');

  Future<void> carregarProdutos() async {
    try {
      state = const AsyncValue.loading();
      // 🚀 Busca rápida, ordenada por nome
      final snap = await _db.orderBy('nome').get(const GetOptions(source: Source.serverAndCache));
      
      final produtos = snap.docs.map((doc) => Produto.fromMap(doc.data(), doc.id)).toList();
      state = AsyncValue.data(produtos);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> salvarProduto(Produto p) async {
    if (p.id.isEmpty) {
      await _db.add(p.toMap()); // Novo produto
    } else {
      await _db.doc(p.id).update(p.toMap()); // Editando existente
    }
    await carregarProdutos(); // Atualiza a tela automaticamente
  }

  Future<void> excluirProduto(String id) async {
    await _db.doc(id).delete();
    await carregarProdutos();
  }
}
