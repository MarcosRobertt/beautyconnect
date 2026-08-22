import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/servico.dart';
import '../repositories/servico_repository.dart';

// Repositório do Firestore desacoplado do Hive
final servicoRepositoryProvider = Provider<ServicoRepository>((ref) {
  return ServicoRepository(null as dynamic);
});

final servicoControllerProvider =
    StateNotifierProvider<ServicoController, AsyncValue<List<Servico>>>((ref) {
  return ServicoController(ref.watch(servicoRepositoryProvider));
});

class ServicoController extends StateNotifier<AsyncValue<List<Servico>>> {
  ServicoController(this._repository) : super(const AsyncValue.loading()) {
    carregar();
  }

  final ServicoRepository _repository;

  Future<void> carregar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.listar());
  }

  Future<void> salvar(Servico servico) async {
    await _repository.salvar(servico);
    await carregar();
  }

  Future<void> editar(Servico servico) async {
    await _repository.editar(servico);
    await carregar();
  }

  Future<void> excluir(String id) async {
    await _repository.excluir(id);
    await carregar();
  }

  Future<Servico?> buscar(String id) => _repository.buscar(id);

  /// Usado pela tela de Configurações após restaurar um backup.
  Future<void> substituirTudo(List<Servico> novos) async {
    await _repository.substituirTudo(novos);
    await carregar();
  }
}
