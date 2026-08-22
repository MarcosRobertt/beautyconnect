import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/storage/storage_service.dart';
import '../models/cliente.dart';

/// Repository de Cliente. Nenhuma tela ou controller deve chamar o banco
/// diretamente — tudo passa por aqui, que agora usa o Firestore (Nuvem).
class ClienteRepository {
  // Mantemos o construtor original para não quebrar a sua injeção de dependências (Providers)
  ClienteRepository(this._storage);

  final StorageService<Cliente> _storage;
  
  // Nova conexão com a nuvem
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Cliente>> listar() async {
    final snapshot = await _firestore.collection('clientes').get();
    
    // Converte os dados da nuvem para o seu modelo Cliente
    final lista = snapshot.docs.map((doc) {
      // ⚠️ ATENÇÃO: Se o seu modelo usar fromMap em vez de fromJson, altere a linha abaixo!
      return Cliente.fromJson(doc.data());
    }).toList();

    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return lista;
  }

  Future<Cliente?> buscar(String id) async {
    final doc = await _firestore.collection('clientes').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    
    return Cliente.fromJson(doc.data()!);
  }

  Future<void> salvar(Cliente cliente) async {
    // Usa toJson() para converter o Cliente para o banco. Se o seu modelo usar toMap(), altere aqui.
    await _firestore.collection('clientes').doc(cliente.id).set(cliente.toJson());
  }

  Future<void> editar(Cliente cliente) async {
    await _firestore.collection('clientes').doc(cliente.id).update(cliente.toJson());
  }

  Future<void> excluir(String id) async {
    await _firestore.collection('clientes').doc(id).delete();
  }

  Future<List<Cliente>> pesquisar(String texto) async {
    final lista = await listar();
    final termo = texto.trim().toLowerCase();
    if (termo.isEmpty) return lista;
    
    return lista.where((c) => 
      c.nome.toLowerCase().contains(termo) || 
      c.telefone.contains(termo)
    ).toList();
  }

  /// Substitui toda a base de clientes (usado ao restaurar um backup.json).
  Future<void> substituirTudo(List<Cliente> novos) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore.collection('clientes').get();

    // Limpa a nuvem atual
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    // Adiciona os dados do backup na nuvem
    for (final c in novos) {
      final docRef = _firestore.collection('clientes').doc(c.id);
      batch.set(docRef, c.toJson());
    }

    await batch.commit();
  }
}
