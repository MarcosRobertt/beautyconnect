import '../../../core/services/storage/storage_service.dart';
import '../models/servico.dart';

class ServicoRepository {
  ServicoRepository(this._storage);

  final StorageService<Servico> _storage;

  Future<List<Servico>> listar() async {
    final lista = _storage.listar();
    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return lista;
  }

  Future<Servico?> buscar(String id) async => _storage.buscar(id);

  Future<void> salvar(Servico servico) async => _storage.salvar(servico.id, servico);

  Future<void> editar(Servico servico) async => _storage.editar(servico.id, servico);

  Future<void> excluir(String id) async => _storage.excluir(id);

  /// Substitui todo o catálogo (usado ao restaurar um backup.json).
  Future<void> substituirTudo(List<Servico> novos) async {
    await _storage.limparTudo();
    for (final s in novos) {
      await _storage.salvar(s.id, s);
    }
  }
}
