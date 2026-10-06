import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/insumo.dart';

final estoqueControllerProvider = StateNotifierProvider<EstoqueController, AsyncValue<List<Insumo>>>((ref) {
  return EstoqueController();
});

class EstoqueController extends StateNotifier<AsyncValue<List<Insumo>>> {
  EstoqueController() : super(const AsyncValue.loading()) {
    carregarInsumos();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void carregarInsumos() {
    try {
      _db.collection('estoque').snapshots().listen((snapshot) {
        final lista = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Insumo.fromMap(data);
        }).toList();

        lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        state = AsyncValue.data(lista);
      }, onError: (e, stack) {
        state = AsyncValue.error(e, stack);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> salvar(Insumo insumo) async {
    final mapData = insumo.toMap();

    if (insumo.id.isEmpty) {
      final docRef = await _db.collection('estoque').add(mapData);
      await docRef.update({'id': docRef.id});
    } else {
      await _db.collection('estoque').doc(insumo.id).set(
        mapData,
        SetOptions(merge: true),
      );
    }
  }

  Future<void> deletar(String id) async {
    if (id.isNotEmpty) {
      await _db.collection('estoque').doc(id).delete();
    }
  }

  // 🟢 NOVO: A profissional abriu um pote novo
  Future<void> iniciarPote(Insumo insumo) async {
    final novoCiclo = CicloDeUso(
      id: const Uuid().v4(),
      dataAbertura: DateTime.now(),
    );
    
    final listaAtualizada = List<CicloDeUso>.from(insumo.ciclosDeUso)..add(novoCiclo);
    
    // Desconta 1 unidade do armário (porque foi pro balcão)
    final novoEstoque = insumo.quantidade > 0 ? insumo.quantidade - 1 : 0;
    
    await _db.collection('estoque').doc(insumo.id).update({
      'quantidade': novoEstoque,
      'ciclosDeUso': listaAtualizada.map((c) => c.toMap()).toList(),
    });
  }

  // 🔴 NOVO: O pote acabou (Fecha o ciclo para a IA calcular depois)
  Future<void> finalizarPoteAberto(Insumo insumo) async {
    final indexAberto = insumo.ciclosDeUso.indexWhere((c) => c.dataFim == null);
    if (indexAberto == -1) return; // Não tem pote aberto

    final listaAtualizada = List<CicloDeUso>.from(insumo.ciclosDeUso);
    final cicloAntigo = listaAtualizada[indexAberto];
    
    listaAtualizada[indexAberto] = CicloDeUso(
      id: cicloAntigo.id,
      dataAbertura: cicloAntigo.dataAbertura,
      dataFim: DateTime.now(), // 🔴 Grava a data que acabou
    );

    await _db.collection('estoque').doc(insumo.id).update({
      'ciclosDeUso': listaAtualizada.map((c) => c.toMap()).toList(),
    });
  }
}
