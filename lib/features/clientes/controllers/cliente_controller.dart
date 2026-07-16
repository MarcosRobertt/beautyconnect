import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/storage_service.dart';
import '../models/cliente.dart';
import '../repositories/cliente_repository.dart';

/// Provider da Box do Hive já aberta em main.dart (ver bootstrap).
final clienteBoxProvider = Provider<Box<Cliente>>((ref) {
  return Hive.box<Cliente>(HiveBoxes.clientes);
});

final clienteRepositoryProvider = Provider<ClienteRepository>((ref) {
  final box = ref.watch(clienteBoxProvider);
  return ClienteRepository(StorageService<Cliente>(box, nomeCaixa: HiveBoxes.clientes));
});

/// Estado exposto para as telas: lista de clientes + termo de pesquisa atual.
final clienteControllerProvider =
    StateNotifierProvider<ClienteController, AsyncValue<List<Cliente>>>((ref) {
  return ClienteController(ref.watch(clienteRepositoryProvider));
});

/// Total real de clientes cadastrados, sempre a partir do Repository —
/// deliberadamente independente do texto de busca da tela de Clientes.
///
/// CORREÇÃO (Sprint 1): antes, o card "Clientes" do Dashboard usava
/// `clienteControllerProvider` diretamente. Como esse mesmo provider também
/// guarda o resultado de uma pesquisa em andamento na tela de Clientes, se a
/// manicure deixasse um filtro de busca ativo lá, o Dashboard mostrava a
/// contagem filtrada em vez do total real de clientes. Este provider corrige
/// isso lendo sempre a lista completa.
final totalClientesProvider = FutureProvider<int>((ref) async {
  ref.watch(clienteControllerProvider); // gatilho: recalcula após salvar/editar/excluir
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
