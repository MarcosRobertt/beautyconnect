import '../../../core/services/storage/storage_service.dart';
import '../models/agendamento.dart';

bool _mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _inicioDaSemana(DateTime data) {
  final d = DateTime(data.year, data.month, data.day);
  return d.subtract(Duration(days: d.weekday % 7)); // domingo como início
}

/// Repository de Agendamento. Concentra as regras de negócio da Agenda:
/// listagem por período e checagem de conflito de horário.
class AgendamentoRepository {
  AgendamentoRepository(this._storage);

  final StorageService<Agendamento> _storage;

  Future<List<Agendamento>> listarDia(DateTime dia) async {
    final lista = _storage.pesquisar((a) => _mesmoDia(a.data, dia));
    lista.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    return lista;
  }

  Future<List<Agendamento>> listarSemana(DateTime referencia) async {
    final inicio = _inicioDaSemana(referencia);
    final fim = inicio.add(const Duration(days: 6));
    final lista = _storage.pesquisar(
      (a) => !a.data.isBefore(inicio) && !a.data.isAfter(fim),
    );
    lista.sort((a, b) {
      final cmpData = a.data.compareTo(b.data);
      return cmpData != 0 ? cmpData : a.horaInicio.compareTo(b.horaInicio);
    });
    return lista;
  }

  Future<List<Agendamento>> listarMes(DateTime referencia) async {
    final lista = _storage.pesquisar(
      (a) => a.data.year == referencia.year && a.data.month == referencia.month,
    );
    lista.sort((a, b) {
      final cmpData = a.data.compareTo(b.data);
      return cmpData != 0 ? cmpData : a.horaInicio.compareTo(b.horaInicio);
    });
    return lista;
  }

  Future<List<Agendamento>> listarTodos() async => _storage.listar();

  /// Converte "HH:mm" para minutos desde 00:00
  int _horaParaMinutos(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  /// Verifica se dois períodos de tempo se sobrepõem.
  /// Dois períodos se sobrepõem se: inicio1 < fim2 AND inicio2 < fim1
  bool _temSobreposicao(
    String inicio1,
    String fim1,
    String inicio2,
    String fim2,
  ) {
    final min1 = _horaParaMinutos(inicio1);
    final min2 = _horaParaMinutos(fim1);
    final min3 = _horaParaMinutos(inicio2);
    final min4 = _horaParaMinutos(fim2);

    // Sobreposição ocorre se: min1 < min4 AND min3 < min2
    return min1 < min4 && min3 < min2;
  }

  /// Regra: não permitir dois agendamentos não cancelados no mesmo dia
  /// que se sobreponham no tempo.
  ///
  /// Permite agendamentos encostados (ex: 10:00-11:00 e 11:00-12:00).
  /// Bloqueia agendamentos que se sobrepõem (ex: 10:00-12:00 e 11:00-12:30).
  bool existeConflito(Agendamento novo, {String? ignorarId}) {
    return _storage.listar().any((a) =>
        a.id != ignorarId &&
        a.status != AgendamentoStatus.cancelado &&
        _mesmoDia(a.data, novo.data) &&
        _temSobreposicao(a.horaInicio, a.horaFim, novo.horaInicio, novo.horaFim));
  }

  Future<void> novo(Agendamento agendamento) async {
    if (existeConflito(agendamento)) {
      throw StateError(
        'Já existe um agendamento não cancelado nesse dia e horário.',
      );
    }
    await _storage.salvar(agendamento.id, agendamento);
  }

  Future<void> editar(Agendamento agendamento) async {
    if (existeConflito(agendamento, ignorarId: agendamento.id)) {
      throw StateError(
        'Já existe um agendamento não cancelado nesse dia e horário.',
      );
    }
    await _storage.editar(agendamento.id, agendamento);
  }

  Future<void> cancelar(String id) async {
    final atual = _storage.buscar(id);
    if (atual == null) return;
    await _storage.editar(
      id,
      atual.copyWith(status: AgendamentoStatus.cancelado, updatedAt: DateTime.now()),
    );
  }

  Future<void> confirmar(String id) async {
    final atual = _storage.buscar(id);
    if (atual == null) return;
    await _storage.editar(
      id,
      atual.copyWith(status: AgendamentoStatus.confirmado, updatedAt: DateTime.now()),
    );
  }

  Future<void> concluir(String id) async {
    final atual = _storage.buscar(id);
    if (atual == null) return;
    await _storage.editar(
      id,
      atual.copyWith(status: AgendamentoStatus.concluido, updatedAt: DateTime.now()),
    );
  }

  /// Substitui toda a base de agendamentos (usado ao restaurar um backup.json).
  /// Ignora a checagem de conflito de horário, pois assume-se que o backup já
  /// era um estado válido no momento em que foi exportado.
  Future<void> substituirTudo(List<Agendamento> novos) async {
    await _storage.limparTudo();
    for (final a in novos) {
      await _storage.salvar(a.id, a);
    }
  }
}
