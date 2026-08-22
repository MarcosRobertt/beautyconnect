import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/storage/storage_service.dart';
import '../models/servico.dart';

class ServicoRepository {
  ServicoRepository(this._storage);

  final StorageService<Servico> _storage;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Servico>> listar() async {
    final snapshot = await _firestore.collection('servicos').get();
    final lista = snapshot.docs.map((doc) => Servico.fromJson(doc.data())).toList();
    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return lista;
  }

  Future<Servico?> buscar(String id) async {
    final doc = await _firestore.collection('servicos').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Servico.fromJson(doc.data()!);
  }

  Future<void> salvar(Servico servico) async {
    await _firestore.collection('servicos').doc(servico.id).set(servico.toJson());
  }

  Future<void> editar(Servico servico) async {
    await _firestore.collection('servicos').doc(servico.id).update(servico.toJson());
  }

  Future<void> excluir(String id) async {
    await _firestore.collection('servicos').doc(id).delete();
  }

  /// Substitui todo o catálogo (usado ao restaurar um backup.json).
  Future<void> substituirTudo(List<Servico> novos) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore.collection('servicos').get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    for (final s in novos) {
      final docRef = _firestore.collection('servicos').doc(s.id);
      batch.set(docRef, s.toJson());
    }

    await batch.commit();
  }
}
