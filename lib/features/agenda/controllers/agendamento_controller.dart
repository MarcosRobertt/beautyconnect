import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/storage_service.dart';
import '../models/agendamento.dart';
import '../repositories/agendamento_repository.dart';

enum VisaoAgenda { dia, semana, mes }

final agendamentoBoxProvider = Provider<Box<Agendamento>>((ref) {
  return Hive.box<Agendamento>(HiveBoxes.agendamentos);
});

final agendamentoRepositoryProvider = Provider<AgendamentoRepository>((ref) {
  final box = ref.watch(agendamentoBoxProvider);
  return AgendamentoRepository(StorageService<Agendamento>(box, nomeCaixa: HiveBoxes.agendamentos));
});

/// Estado da tela de Agenda: visão atual (dia/semana/mês), data de referência
/// e lista de agendamentos já filtrada para o período selecionado.
class AgendaState {
  AgendaState({
    required this.visao,
    required this.dataReferencia,
    required this.lista,
  });

  final VisaoAgenda visao;
  final DateTime dataReferencia;
  final List<Agendamento> lista;

  AgendaState copyWith({
    VisaoAgenda? visao,
    DateTime? dataReferencia,
    List<Agendamento>? lista,
  }) {
    return AgendaState(
      visao: visao ?? this.visao,
      dataReferencia: dataReferencia ?? this.dataReferencia,
      lista: lista ?? this.lista,
    );
  }
}

final agendamentoControllerProvider =
    StateNotifierProvider<AgendamentoController, AsyncValue<AgendaState>>((ref) {
  return AgendamentoController(ref.watch(agendamentoRepositoryProvider));
});

/// Todos os agendamentos (sem filtro de período), de forma reativa —
/// reaproveitado pelo Dashboard, Clientes (último atendimento/próximo
/// retorno), Histórico do Cliente e Agenda Inteligente.
final todosAgendamentosProvider = FutureProvider<List<Agendamento>>((ref) async {
  ref.watch(agendamentoControllerProvider); // gatilho: recalcula após qualquer mudança
  final repository = ref.watch(agendamentoRepositoryProvider);
  return repository.listarTodos();
});

class AgendamentoController extends StateNotifier<AsyncValue<AgendaState>> {
  AgendamentoController(this._repository) : super(const AsyncValue.loading()) {
    carregar();
  }

  final AgendamentoRepository _repository;
  VisaoAgenda _visao = VisaoAgenda.dia;
  DateTime _dataReferencia = DateTime.now();

  Future<void> carregar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final lista = await _buscarPorVisao();
      return AgendaState(visao: _visao, dataReferencia: _dataReferencia, lista: lista);
    });
  }

  Future<List<Agendamento>> _buscarPorVisao() {
    switch (_visao) {
      case VisaoAgenda.dia:
        return _repository.listarDia(_dataReferencia);
      case VisaoAgenda.semana:
        return _repository.listarSemana(_dataReferencia);
      case VisaoAgenda.mes:
        return _repository.listarMes(_dataReferencia);
    }
  }

  Future<void> mudarVisao(VisaoAgenda visao) async {
    _visao = visao;
    await carregar();
  }

  Future<void> irPara(DateTime data) async {
    _dataReferencia = data;
    await carregar();
  }

  Future<void> avancar() async {
    // CORREÇÃO (Sprint 1): a visão "Mês" andava em blocos fixos de 30 dias,
    // o que causava deriva de data ao longo de várias navegações (ex.:
    // 31/jan + 30 dias = 02/mar, não 01/fev). Agora anda por mês de
    // calendário de verdade.
    switch (_visao) {
      case VisaoAgenda.dia:
        _dataReferencia = _dataReferencia.add(const Duration(days: 1));
        break;
      case VisaoAgenda.semana:
        _dataReferencia = _dataReferencia.add(const Duration(days: 7));
        break;
      case VisaoAgenda.mes:
        // dia fixado em 1: a visão de mês só usa year/month (ver
        // AgendamentoRepository.listarMes), então isso evita que dias como
        // 29/30/31 estourem para o mês seguinte em meses mais curtos.
        _dataReferencia = DateTime(_dataReferencia.year, _dataReferencia.month + 1, 1);
        break;
    }
    await carregar();
  }

  Future<void> voltar() async {
    switch (_visao) {
      case VisaoAgenda.dia:
        _dataReferencia = _dataReferencia.subtract(const Duration(days: 1));
        break;
      case VisaoAgenda.semana:
        _dataReferencia = _dataReferencia.subtract(const Duration(days: 7));
        break;
      case VisaoAgenda.mes:
        _dataReferencia = DateTime(_dataReferencia.year, _dataReferencia.month - 1, 1);
        break;
    }
    await carregar();
  }

  /// Retorna `null` em sucesso, ou uma mensagem de erro (ex.: conflito de horário).
  Future<String?> salvar(Agendamento agendamento, {required bool novo}) async {
    try {
      if (novo) {
        await _repository.novo(agendamento);
      } else {
        await _repository.editar(agendamento);
      }
      await carregar();
      return null;
    } on StateError catch (e) {
      return e.message;
    }
  }

  Future<void> confirmar(String id) async {
    await _repository.confirmar(id);
    await carregar();
  }

  Future<void> concluir(String id) async {
    await _repository.concluir(id);
    await carregar();
  }

  Future<void> cancelar(String id) async {
    await _repository.cancelar(id);
    await carregar();
  }

  Future<List<Agendamento>> todos() => _repository.listarTodos();

  /// Usado pela tela de Configurações após restaurar um backup.
  Future<void> substituirTudo(List<Agendamento> novos) async {
    await _repository.substituirTudo(novos);
    await carregar();
  }
}
