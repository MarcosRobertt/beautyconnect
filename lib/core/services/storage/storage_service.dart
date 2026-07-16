import 'package:hive/hive.dart';

/// StorageService<T>
///
/// Camada única responsável por falar com o Hive (que, no Flutter Web,
/// persiste automaticamente em IndexedDB). Nenhuma tela ou controller deve
/// acessar `Box` diretamente — sempre passam por um Repository, que por sua
/// vez usa este StorageService.
///
/// Responsabilidades (conforme documento técnico): Salvar, Editar, Excluir,
/// Listar, Pesquisar.
class StorageService<T> {
  StorageService(this._box, {required this.nomeCaixa});

  final Box<T> _box;
  final String nomeCaixa;

  /// Listar todos os registros da box.
  List<T> listar() {
    return _box.values.toList();
  }

  /// Buscar um registro específico pelo id (chave da box).
  T? buscar(String id) {
    return _box.get(id);
  }

  /// Salvar um novo registro na box.
  Future<void> salvar(String id, T item) async {
    await _box.put(id, item);
  }

  /// Editar um registro existente.
  Future<void> editar(String id, T item) async {
    await _box.put(id, item);
  }

  /// Excluir um registro da box pelo id.
  Future<void> excluir(String id) async {
    await _box.delete(id);
  }

  /// Pesquisar registros que atenderem a um predicado.
  List<T> pesquisar(bool Function(T) predicado) {
    return _box.values.where(predicado).toList();
  }

  /// Limpar todos os registros da box.
  Future<void> limparTudo() async {
    await _box.clear();
  }
}
