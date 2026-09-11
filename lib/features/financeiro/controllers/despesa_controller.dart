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

  Future<void> carregarDespesasMes(DateTime mesReferencia, {bool forcarServidor = false}) async {
    try {
      state = const AsyncValue.loading();
      final inicioMes = DateTime(mesReferencia.year, mesReferencia.month, 1);
      final fimMes = DateTime(mesReferencia.year, mesReferencia.month + 1, 0, 23, 59, 59);

      final options = forcarServidor 
          ? const GetOptions(source: Source.server) 
          : const GetOptions(source: Source.serverAndCache);

      final snapshot = await _db.collection('despesas')
          .where('dataVencimento', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('dataVencimento', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(options);

      final despesas = snapshot.docs.map((doc) => Despesa.fromMap(doc.data(), doc.id)).toList();
      despesas.sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));
      state = AsyncValue.data(despesas);
    } catch (e) {
      if (forcarServidor) {
        carregarDespesasMes(mesReferencia, forcarServidor: false);
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<void> salvarDespesa(Despesa despesa) async {
    try {
      final batch = _db.batch();
      final colecao = _db.collection('despesas');

      // Só gera várias parcelas se for uma NOVA despesa (id vazio)
      if (despesa.id.isEmpty && despesa.tipo == 'PARCELADA' && despesa.totalParcelas != null && despesa.totalParcelas! > 1) {
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
        // Atualiza despesa existente OU cria uma nova normal
        final docRef = colecao.doc(despesa.id.isEmpty ? _uuid.v4() : despesa.id);
        batch.set(docRef, {
          ...despesa.toMap(),
          'id': docRef.id,
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Erro ao salvar despesa: $e');
    }
  }

  Future<void> alternarStatusDespesa(Despesa despesa, DateTime mesReferencia) async {
    try {
      final novoStatus = despesa.status == 'PAGO' ? 'PENDENTE' : 'PAGO';
      final novaDataPagamento = novoStatus == 'PAGO' ? DateTime.now() : null;

      await _db.collection('despesas').doc(despesa.id).update({
        'status': novoStatus,
        'dataPagamento': novaDataPagamento?.toIso8601String(),
      });

      await carregarDespesasMes(mesReferencia, forcarServidor: true);
    } catch (e) {
      throw Exception('Erro ao alterar status: $e');
    }
  }

  Future<void> excluirDespesa(String id, DateTime mesReferencia) async {
    try {
      await _db.collection('despesas').doc(id).delete();
      await carregarDespesasMes(mesReferencia, forcarServidor: true);
    } catch (e) {
      throw Exception('Erro ao excluir despesa: $e');
    }
  }

  Future<void> duplicarDespesaProximoMes(Despesa despesa, DateTime mesReferencia) async {
    try {
      final proximaData = DateTime(
        despesa.dataVencimento.year,
        despesa.dataVencimento.month + 1,
        despesa.dataVencimento.day,
      );

      final novaDespesa = Despesa(
        id: '',
        descricao: despesa.descricao,
        valor: despesa.valor,
        categoria: despesa.categoria,
        tipo: despesa.tipo == 'PARCELADA' ? 'REGULAR' : despesa.tipo,
        dataVencimento: proximaData,
        status: 'PENDENTE',
      );

      await salvarDespesa(novaDespesa);
      await carregarDespesasMes(mesReferencia, forcarServidor: true);
    } catch (e) {
      throw Exception('Erro ao duplicar despesa: $e');
    }
  }
}
