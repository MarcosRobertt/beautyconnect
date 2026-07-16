import '../../../core/services/storage/storage_service.dart';
import '../models/cliente.dart';

/// Repository de Cliente. Nenhuma tela ou controller deve chamar o Hive
/// diretamente — tudo passa por aqui, que por sua vez usa o StorageService.
class ClienteRepository {
  ClienteRepository(this._storage);

  final StorageService<Cliente> _storage;

  Future<List<Cliente>> listar() async {
    final lista = _storage.listar();
    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return lista;
  }

  Future<Cliente?> buscar(String id) async => _storage.buscar(id);

  Future<void> salvar(Cliente cliente) async => _storage.salvar(cliente.id, cliente);

  Future<void> editar(Cliente cliente) async => _storage.editar(cliente.id, cliente);

  Future<void> excluir(String id) async => _storage.excluir(id);

  Future<List<Cliente>> pesquisar(String texto) async {
    final termo = texto.trim().toLowerCase();
    if (termo.isEmpty) return listar();
    return _storage.pesquisar(
      (c) => c.nome.toLowerCase().contains(termo) || c.telefone.contains(termo),
    );
  }

  /// Substitui toda a base de clientes (usado ao restaurar um backup.json).
  Future<void> substituirTudo(List<Cliente> novos) async {
    await _storage.limparTudo();
    for (final c in novos) {
      await _storage.salvar(c.id, c);
    }
  }
}
