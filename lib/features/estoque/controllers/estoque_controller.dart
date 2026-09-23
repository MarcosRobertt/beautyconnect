
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/insumo.dart';

final estoqueControllerProvider = StateNotifierProvider<EstoqueController, AsyncValue<List<Insumo>>>((ref) {
  return EstoqueController();
});

class EstoqueController extends StateNotifier<AsyncValue<List<Insumo>>> {
  EstoqueController() : super(const AsyncValue.loading()) {
    carregarInsumos();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ouve as atualizações do estoque em tempo real
  void carregarInsumos() {
    try {
      _db.collection('estoque').snapshots().listen((snapshot) {
        final lista = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Insumo.fromMap(data);
        }).toList();

        // Ordena por nome
        lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

        state = AsyncValue.data(lista);
      }, onError: (e, stack) {
        state = AsyncValue.error(e, stack);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Salva um novo insumo ou atualiza um existente
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

  /// Remove um insumo do banco
  Future<void> deletar(String id) async {
    if (id.isNotEmpty) {
      await _db.collection('estoque').doc(id).delete();
    }
  }
}
