import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/storage_service.dart';
import '../models/servico.dart';
import '../repositories/servico_repository.dart';

final servicoBoxProvider = Provider<Box<Servico>>((ref) {
  return Hive.box<Servico>(HiveBoxes.servicos);
});

final servicoRepositoryProvider = Provider<ServicoRepository>((ref) {
  final box = ref.watch(servicoBoxProvider);
  return ServicoRepository(StorageService<Servico>(box, nomeCaixa: HiveBoxes.servicos));
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
