
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/despesa.dart';

final despesaControllerProvider = StateNotifierProvider<DespesaController, AsyncValue<List<Despesa>>>((ref) {
  return DespesaController();
});

class DespesaController extends StateNotifier<AsyncValue<List<Despesa>>> {
  DespesaController() : super(const AsyncValue.loading());
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<void> carregarDespesasMes(DateTime mesReferencia) async {
    try {
      state = const AsyncValue.loading();
      final inicioMes = DateTime(mesReferencia.year, mesReferencia.month, 1);
      final fimMes = DateTime(mesReferencia.year, mesReferencia.month + 1, 0, 23, 59, 59);

      final snapshot = await _db.collection('despesas')
          .where('dataVencimento', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('dataVencimento', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get();

      final despesas = snapshot.docs.map((doc) => Despesa.fromMap(doc.data(), doc.id)).toList();
      despesas.sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));
      state = AsyncValue.data(despesas);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> salvarDespesa(Despesa despesa) async {
    try {
      final batch = _db.batch();
      final colecao = _db.collection('despesas');

      if (despesa.tipo == 'PARCELADA' && despesa.totalParcelas != null && despesa.totalParcelas! > 1) {
        final valorParcela = despesa.valor / despesa.totalParcelas!;
        final idAgrupador = _uuid.v4();

        for (int i = 0; i < despesa.totalParcelas!; i++) {
          final novaData = DateTime(despesa.dataVencimento.year, despesa.dataVencimento.month + i, despesa.dataVencimento.day);
          final novoId = _uuid.v4();
          
          final docRef = colecao.doc(novoId);
          batch.set(docRef, {
            ...despesa.toMap(),
            'id': novoId,
            'valor': valorParcela,
            'dataVencimento': novaData.toIso8601String(),
            'parcelaAtual': i + 1,
            'idAgrupador': idAgrupador,
          });
        }
      } else {
        final docRef = colecao.doc(despesa.id.isEmpty ? _uuid.v4() : despesa.id);
        batch.set(docRef, {
          ...despesa.toMap(),
          'id': docRef.id,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Erro ao salvar despesa: $e');
    }
  }
}
