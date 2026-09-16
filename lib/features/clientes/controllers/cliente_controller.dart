import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cliente.dart';

final clienteControllerProvider = StateNotifierProvider<ClienteController, AsyncValue<List<Cliente>>>((ref) {
  return ClienteController();
});

// CORREÇÃO: Agora o provedor expõe a classe correta com os métodos para o Dashboard
final clienteRepositoryProvider = Provider<ClienteController>((ref) {
  return ref.watch(clienteControllerProvider.notifier);
});

class ClienteController extends StateNotifier<AsyncValue<List<Cliente>>> {
  ClienteController() : super(const AsyncValue.loading()) {
    carregarClientes();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> carregarClientes() async {
    try {
      _db.collection('clientes').snapshots().listen((snapshot) {
        final lista = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Cliente.fromMap(data);
        }).toList();
        
        state = AsyncValue.data(lista);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // CORREÇÃO: Método listar para manter a compatibilidade com o DashboardController
  Future<List<Cliente>> listar() async {
    return state.value ?? [];
  }

  Future<Cliente?> buscar(String id) async {
    final clientesAtuais = state.value ?? [];
    try {
      return clientesAtuais.firstWhere((c) => c.id == id);
    } catch (_) {
      final doc = await _db.collection('clientes').doc(id).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return Cliente.fromMap(data);
      }
    }
    return null;
  }

  Future<void> salvar(Cliente cliente) async {
    final clientesAtuais = state.value ?? [];
    final telLimpoNovo = cliente.telefone.replaceAll(RegExp(r'\D'), '');

    if (telLimpoNovo.isNotEmpty) {
      final jaExisteOutro = clientesAtuais.any((c) {
        final telLimpoExistente = c.telefone.replaceAll(RegExp(r'\D'), '');
        final ehMesmoTelefone = telLimpoExistente == telLimpoNovo;
        final ehOutroCliente = c.id != cliente.id;

        return ehMesmoTelefone && ehOutroCliente;
      });

      if (jaExisteOutro) {
        throw Exception('Este número de telefone já está cadastrado para outro cliente.');
      }
    }

    final mapData = cliente.toMap();

    if (cliente.id.isEmpty) {
      final docRef = await _db.collection('clientes').add(mapData);
      await docRef.update({'id': docRef.id});
    } else {
      await _db.collection('clientes').doc(cliente.id).set(
        mapData,
        SetOptions(merge: true),
      );
    }
  }

  Future<void> editar(Cliente cliente) async {
    await salvar(cliente);
  }

  Future<void> deletar(String id) async {
    if (id.isNotEmpty) {
      await _db.collection('clientes').doc(id).delete();
    }
  }

  Future<void> excluir(String id) async {
    await deletar(id);
  }

  List<Cliente> verificarNomesSemelhantes(String nome, {String? idAtual}) {
    if (nome.trim().length < 3) return [];
    final clientesAtuais = state.value ?? [];
    final nomeLower = nome.toLowerCase().trim();

    return clientesAtuais.where((c) {
      final ehOutro = c.id != idAtual;
      final contemNome = c.nome.toLowerCase().contains(nomeLower);
      return ehOutro && contemNome;
    }).toList();
  }
}
