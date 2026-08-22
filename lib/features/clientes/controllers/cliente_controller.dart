import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cliente.dart';
import '../repositories/cliente_repository.dart';

// Repositório do Firestore desacoplado do Hive
final clienteRepositoryProvider = Provider<ClienteRepository>((ref) {
  return ClienteRepository(null as dynamic);
});

/// Estado exposto para as telas: lista de clientes + termo de pesquisa atual.
final clienteControllerProvider =
    StateNotifierProvider<ClienteController, AsyncValue<List<Cliente>>>((ref) {
  return ClienteController(ref.watch(clienteRepositoryProvider));
});

/// Total real de clientes cadastrados, lendo diretamente do Firestore.
final totalClientesProvider = FutureProvider<int>((ref) async {
  ref.watch(clienteControllerProvider);
  final repository = ref.watch(clienteRepositoryProvider);
  final todos = await repository.listar();
  return todos.length;
});

class ClienteController extends StateNotifier<AsyncValue<List<Cliente>>> {
  ClienteController(this._repository) : super(const AsyncValue.loading()) {
    carregar();
  }

  final ClienteRepository _repository;

  Future<void> carregar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.listar());
  }

  Future<void> pesquisar(String texto) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.pesquisar(texto));
  }

  Future<void> salvar(Cliente cliente) async {
    await _repository.salvar(cliente);
    await carregar();
  }

  Future<void> editar(Cliente cliente) async {
    await _repository.editar(cliente);
    await carregar();
  }

  Future<void> excluir(String id) async {
    await _repository.excluir(id);
    await carregar();
  }

  Future<Cliente?> buscar(String id) => _repository.buscar(id);

  /// Usado pela tela de Configurações após restaurar um backup.
  Future<void> substituirTudo(List<Cliente> novos) async {
    await _repository.substituirTudo(novos);
    await carregar();
  }
}
