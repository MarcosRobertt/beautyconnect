import '../models/agendamento.dart';

/// Resultado da análise de frequência de um cliente específico.
class InteligenciaCliente {
  InteligenciaCliente({
    required this.ultimoAtendimento,
    required this.frequenciaMediaDias,
    required this.proximaDataSugerida,
    required this.atrasado,
  });

  final DateTime? ultimoAtendimento;
  final int? frequenciaMediaDias;
  final DateTime? proximaDataSugerida;
  final bool atrasado;
}

/// Uma faixa de horário livre em um dia.
class FaixaLivre {
  FaixaLivre({required this.inicio, required this.fim});
  final String inicio; // "HH:mm"
  final String fim; // "HH:mm"
}

int _paraMinutos(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String _paraHora(int minutos) {
  final h = (minutos ~/ 60) % 24;
  final m = minutos % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Serviço de "Agenda Inteligente": cálculos derivados a partir do
/// histórico de agendamentos. Não é um Repository (não acessa o Hive) — são
/// funções puras que operam sobre listas já carregadas, reaproveitáveis pelo
/// Dashboard, pela tela de Clientes e pela tela de Agenda Inteligente.
class InteligenciaService {
  /// Horário de expediente padrão usado para calcular horários livres.
  /// Assunção do MVP: expediente único das 08:00 às 20:00, sem intervalos
  /// configuráveis. Pode ser revisado numa sprint futura se a manicure
  /// trabalhar em outro horário.
  static const horaAbertura = '08:00';
  static const horaFechamento = '20:00';

  /// Calcula último atendimento, frequência média de retorno, próxima data
  /// sugerida e se o cliente está atrasado, a partir de TODOS os
  /// agendamentos de um único cliente (já filtrados por clienteId).
  static InteligenciaCliente calcularParaCliente(List<Agendamento> agendamentosDoCliente) {
    final concluidos = agendamentosDoCliente.where((a) => a.status == AgendamentoStatus.concluido).toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    if (concluidos.isEmpty) {
      return InteligenciaCliente(
        ultimoAtendimento: null,
        frequenciaMediaDias: null,
        proximaDataSugerida: null,
        atrasado: false,
      );
    }

    final ultimo = concluidos.last.data;

    int? frequencia;
    if (concluidos.length >= 2) {
      final intervalos = <int>[];
      for (var i = 1; i < concluidos.length; i++) {
        intervalos.add(concluidos[i].data.difference(concluidos[i - 1].data).inDays);
      }
      final soma = intervalos.fold<int>(0, (s, v) => s + v);
      frequencia = (soma / intervalos.length).round();
    }

    DateTime? proxima;
    var atrasado = false;
    if (frequencia != null && frequencia > 0) {
      proxima = DateTime(ultimo.year, ultimo.month, ultimo.day).add(Duration(days: frequencia));
      final hoje = DateTime.now();
      atrasado = DateTime(hoje.year, hoje.month, hoje.day).isAfter(proxima);
    }

    return InteligenciaCliente(
      ultimoAtendimento: ultimo,
      frequenciaMediaDias: frequencia,
      proximaDataSugerida: proxima,
      atrasado: atrasado,
    );
  }

  /// Calcula as faixas de horário livre num dia, dado o expediente padrão e
  /// os agendamentos não cancelados daquele dia (de todos os clientes).
  static List<FaixaLivre> horariosLivresNoDia(List<Agendamento> agendamentosDoDia) {
    final ocupados = agendamentosDoDia.where((a) => a.status != AgendamentoStatus.cancelado).toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

    final livres = <FaixaLivre>[];
    var cursor = _paraMinutos(horaAbertura);
    final fechamento = _paraMinutos(horaFechamento);

    for (final a in ocupados) {
      final inicio = _paraMinutos(a.horaInicio);
      final fim = _paraMinutos(a.horaFim);
      if (inicio > cursor) {
        livres.add(FaixaLivre(inicio: _paraHora(cursor), fim: _paraHora(inicio)));
      }
      if (fim > cursor) cursor = fim;
    }
    if (cursor < fechamento) {
      livres.add(FaixaLivre(inicio: _paraHora(cursor), fim: _paraHora(fechamento)));
    }
    return livres;
  }

  /// Quantidade de minutos livres entre agora e o fim do expediente de hoje
  /// (usado no card "Horários vagos" do Dashboard). Se já passou do
  /// expediente, retorna 0.
  static int minutosLivresRestantesHoje(List<Agendamento> agendamentosDeHoje) {
    final agora = DateTime.now();
    final minutoAtual = agora.hour * 60 + agora.minute;
    final fechamento = _paraMinutos(horaFechamento);
    if (minutoAtual >= fechamento) return 0;

    final ocupados = agendamentosDeHoje.where((a) => a.status != AgendamentoStatus.cancelado).toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

    var cursor = minutoAtual < _paraMinutos(horaAbertura) ? _paraMinutos(horaAbertura) : minutoAtual;
    var livres = 0;
    for (final a in ocupados) {
      final inicio = _paraMinutos(a.horaInicio);
      final fim = _paraMinutos(a.horaFim);
      if (fim <= cursor) continue;
      final inicioEfetivo = inicio < cursor ? cursor : inicio;
      if (inicioEfetivo > cursor) livres += inicioEfetivo - cursor;
      cursor = fim > cursor ? fim : cursor;
    }
    if (fechamento > cursor) livres += fechamento - cursor;
    return livres;
  }
}
