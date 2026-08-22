import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agendamento.dart';

class TimelineWeekView extends StatelessWidget {
  const TimelineWeekView({
    super.key,
    required this.agendamentos,
    required this.dataReferencia,
    required this.onIrParaDia,
  });

  final List<Agendamento> agendamentos;
  final DateTime dataReferencia;
  final Function(DateTime data) onIrParaDia;

  static const double _pixelsPorMinuto = 2.0;
  static const double _larguraHorarios = 45.0;

  int _horaParaMinutos(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  DateTime _obterDomingoSemana(DateTime data) {
    return data.subtract(Duration(days: data.weekday % 7));
  }

  List<Agendamento> _agendamentosDoDia(DateTime dia) {
    return agendamentos.where((a) {
      return a.data.year == dia.year && a.data.month == dia.month && a.data.day == dia.day;
    }).toList();
  }

  double _calcularTop(String horaInicio, int horaMinima) {
    final minutos = _horaParaMinutos(horaInicio);
    final minutosDesdeInicio = minutos - (horaMinima * 60);
    return minutosDesdeInicio * _pixelsPorMinuto;
  }

  double _calcularAltura(String horaInicio, String horaFim) {
    final minInicio = _horaParaMinutos(horaInicio);
    final minFim = _horaParaMinutos(horaFim);
    return (minFim - minInicio) * _pixelsPorMinuto;
  }

  Color _obterCorStatus(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado:
        return Colors.blue.shade100;
      case AgendamentoStatus.confirmado:
        return Colors.green.shade100;
      case AgendamentoStatus.concluido:
        return Colors.grey.shade100;
      case AgendamentoStatus.cancelado:
        return Colors.red.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    final domingo = _obterDomingoSemana(dataReferencia);
    final dias = List.generate(7, (i) => domingo.add(Duration(days: i)));

    int horaMinima = 8;
    int horaMaxima = 18;

    for (final a in agendamentos) {
      final horaInicioInt = int.parse(a.horaInicio.split(':')[0]);
      final horaFimInt = int.parse(a.horaFim.split(':')[0]);

      if (horaInicioInt < horaMinima) {
        horaMinima = horaInicioInt;
      }
      if (horaFimInt > horaMaxima) {
        horaMaxima = horaFimInt + 1;
      }
    }

    final alturaTotal = ((horaMaxima - horaMinima) * 60) * _pixelsPorMinuto;
    final nomesDias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'];

    return Column(
      children: [
        // Header
        SizedBox(
          height: 60,
          child: Row(
            children: [
              SizedBox(width: _larguraHorarios),
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onIrParaDia(dias[i]),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: i < 6
                              ? BorderSide(color: Colors.grey.shade300, width: 0.5)
                              : BorderSide.none,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              nomesDias[i],
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              dias[i].day.toString(),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Body
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna de Horários
                SizedBox(
                  width: _larguraHorarios,
                  child: Column(
                    children: [
                      for (int h = horaMinima; h <= horaMaxima; h++)
                        for (int m = 0; m < 60; m += 30)
                          SizedBox(
                            height: 30 * _pixelsPorMinuto,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),

                // Colunas dos Dias
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: i < 6
                              ? BorderSide(color: Colors.grey.shade300, width: 0.5)
                              : BorderSide.none,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Grid de fundo
                          Column(
                            children: [
                              for (int j = 0; j < (horaMaxima - horaMinima) * 2; j++)
                                Container(
                                  height: 30 * _pixelsPorMinuto,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Eventos do dia
                          ..._agendamentosDoDia(dias[i]).map((a) {
                            final topPx = _calcularTop(a.horaInicio, horaMinima);
                            final heightPx = _calcularAltura(a.horaInicio, a.horaFim);
                            final cor = _obterCorStatus(a.status);

                            return Positioned(
                              top: topPx,
                              left: 2,
                              right: 2,
                              height: heightPx > 20 ? heightPx : 20,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onIrParaDia(dias[i]),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cor,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 0.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Text(
                                    '${a.servico}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
