import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agendamento.dart';
import '../repositories/agendamento_repository.dart';

enum VisaoAgenda { dia, semana, mes }

// Repositório do Firestore desacoplado do Hive
final agendamentoRepositoryProvider = Provider<AgendamentoRepository>((ref) {
  return AgendamentoRepository(null as dynamic);
});

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

final todosAgendamentosProvider = FutureProvider<List<Agendamento>>((ref) async {
  ref.watch(agendamentoControllerProvider); 
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

  Future<void> mudarData(DateTime data) async {
    _dataReferencia = data;
    await carregar();
  }

  Future<void> irPara(DateTime data) async {
    _dataReferencia = data;
    await carregar();
  }

  Future<void> avancar() async {
    switch (_visao) {
      case VisaoAgenda.dia:
        _dataReferencia = _dataReferencia.add(const Duration(days: 1));
        break;
      case VisaoAgenda.semana:
        _dataReferencia = _dataReferencia.add(const Duration(days: 7));
        break;
      case VisaoAgenda.mes:
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

  // =========================================================================
  // 🛡️ MODO DIAGNÓSTICO: Captura os erros e devolve como Relatório de Texto
  // =========================================================================
  
  Future<String?> salvar(Agendamento agendamento, {required bool novo}) async {
    try {
      if (novo) {
        await _repository.novo(agendamento);
      } else {
        await _repository.editar(agendamento);
      }
      await carregar();
      return null; // Retorna nulo se deu tudo certo (Sucesso)
    } catch (e, stackTrace) {
      // Devolve o relatório brutal de erros para o pop-up da tela
      return "🔥 ERRO FIREBASE (Salvar):\n\n$e\n\n🛠️ RASTREIO TÉCNICO:\n$stackTrace";
    }
  }

  Future<String?> cancelar(String id) async {
    try {
      await _repository.cancelar(id);
      await carregar();
      return null; // Retorna nulo se deu tudo certo (Sucesso)
    } catch (e, stackTrace) {
      // Devolve o relatório brutal de erros para o pop-up da tela
      return "🔥 ERRO FIREBASE (Excluir):\n\n$e\n\n🛠️️ RASTREIO TÉCNICO:\n$stackTrace";
    }
  }

  // =========================================================================

  // Mantivemos o método antigo intocado para não quebrar telas que ainda o usam.
  Future<void> confirmar(String id) async {
    await _repository.confirmar(id);
    await carregar();
  }

  // Mantivemos o método antigo intocado para não quebrar telas que ainda o usam.
  Future<void> concluir(String id) async {
    await _repository.concluir(id);
    await carregar();
  }

  // --- MODO DIAGNÓSTICO APLICADO TAMBÉM AO FECHAR COMANDAS COM TAXAS ---
  Future<String?> concluirComanda(Agendamento agendamento, FormaPagamento pagamento) async {
    try {
      final agendamentoFechado = agendamento.fecharComanda(pagamento);
      await _repository.editar(agendamentoFechado); 
      await carregar();
      return null; // Sucesso
    } catch (e, stackTrace) {
      return "🔥 ERRO FIREBASE (Fechar Comanda com Taxa):\n\n$e\n\n🛠️ RASTREIO TÉCNICO:\n$stackTrace";
    }
  }

  Future<List<Agendamento>> todos() => _repository.listarTodos();

  Future<void> substituirTudo(List<Agendamento> novos) async {
    await _repository.substituirTudo(novos);
    await carregar();
  }
}
