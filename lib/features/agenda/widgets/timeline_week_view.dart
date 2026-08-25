import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agendamento.dart';

class TimelineWeekView extends StatefulWidget {
  const TimelineWeekView({
    super.key,
    required this.agendamentos,
    required this.dataReferencia,
    required this.onIrParaDia,
  });

  final List<Agendamento> agendamentos;
  final DateTime dataReferencia;
  final Function(DateTime) onIrParaDia;

  @override
  State<TimelineWeekView> createState() => _TimelineWeekViewState();
}

class _TimelineWeekViewState extends State<TimelineWeekView> {
  static const double _pixelsPorMinuto = 1.5;
  static const double _larguraHorarios = 45.0;
  
  bool _mostrarCancelados = false; // Controle do Modo Fantasma

  int _horaParaMinutos(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
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
        return Colors.red.withOpacity(0.15); // Cor Modo Fantasma
    }
  }

  @override
  Widget build(BuildContext context) {
    final int diasParaDomingo = widget.dataReferencia.weekday == 7 ? 0 : widget.dataReferencia.weekday;
    final DateTime domingo = widget.dataReferencia.subtract(Duration(days: diasParaDomingo));
    final List<DateTime> diasSemana = List.generate(7, (index) => domingo.add(Duration(days: index)));

    final agendamentosSemana = widget.agendamentos.where((a) {
      return a.data.isAfter(domingo.subtract(const Duration(days: 1))) &&
             a.data.isBefore(domingo.add(const Duration(days: 7)));
    }).toList();

    final canceladosSemana = agendamentosSemana.where((a) => a.status == AgendamentoStatus.cancelado).toList();
    
    // Filtra o que será exibido na grade
    final agendamentosVisiveis = agendamentosSemana.where((a) => 
      a.status != AgendamentoStatus.cancelado || _mostrarCancelados
    ).toList();

    int horaMinima = 8;
    int horaMaxima = 19;

    if (agendamentosVisiveis.isNotEmpty) {
      for (final a in agendamentosVisiveis) {
        final horaInicioInt = int.parse(a.horaInicio.split(':')[0]);
        final horaFimInt = int.parse(a.horaFim.split(':')[0]);

        if (horaInicioInt < horaMinima) horaMinima = horaInicioInt;
        if (horaFimInt > horaMaxima) horaMaxima = horaFimInt + 1;
      }
    }

    final alturaTotal = ((horaMaxima - horaMinima) * 60) * _pixelsPorMinuto;

    return Column(
      children: [
        if (canceladosSemana.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${canceladosSemana.length} cancelamentos nesta semana',
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text('Ver na grade', style: TextStyle(color: Colors.red.shade800, fontSize: 10)),
                Switch(
                  value: _mostrarCancelados,
                  onChanged: (v) => setState(() => _mostrarCancelados = v),
                  activeColor: Colors.red,
                ),
              ],
            ),
          ),
          
        Row(
          children: [
            const SizedBox(width: _larguraHorarios),
            ...diasSemana.map((dia) {
              final ehHoje = dia.year == DateTime.now().year &&
                  dia.month == DateTime.now().month &&
                  dia.day == DateTime.now().day;
                  
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onIrParaDia(dia),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                      color: ehHoje ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4) : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('E', 'pt_BR').format(dia).toUpperCase().replaceAll('.', ''),
                          style: TextStyle(
                            fontSize: 10,
                            color: ehHoje ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
                            fontWeight: ehHoje ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dia.day}',
                          style: TextStyle(
                            fontSize: 14,
                            color: ehHoje ? Theme.of(context).colorScheme.primary : Colors.black87,
                            fontWeight: ehHoje ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _larguraHorarios,
                  child: Column(
                    children: [
                      for (int h = horaMinima; h <= horaMaxima; h++)
                        SizedBox(
                          height: 60 * _pixelsPorMinuto,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ...diasSemana.map((dia) {
                  final agendamentosDoDia = agendamentosVisiveis.where((a) =>
                      a.data.year == dia.year &&
                      a.data.month == dia.month &&
                      a.data.day == dia.day).toList();

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (_) => widget.onIrParaDia(dia),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                        ),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: alturaTotal,
                              width: double.infinity,
                              child: Column(
                                children: [
                                  for (int i = 0; i < (horaMaxima - horaMinima); i++)
                                    Container(
                                      height: 60 * _pixelsPorMinuto,
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ...agendamentosDoDia.map((a) {
                              final topPx = _calcularTop(a.horaInicio, horaMinima);
                              final heightPx = _calcularAltura(a.horaInicio, a.horaFim);
                              final cor = _obterCorStatus(a.status);
                              final isCancelado = a.status == AgendamentoStatus.cancelado;

                              return Positioned(
                                top: topPx,
                                left: 1,
                                right: 1,
                                height: heightPx > 20 ? heightPx : 20,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => widget.onIrParaDia(dia),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: cor,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isCancelado ? Colors.red.withOpacity(0.5) : Colors.black12, 
                                        width: isCancelado ? 1.0 : 0.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                    child: Text(
                                      a.servico,
                                      style: TextStyle(
                                        fontSize: 8, 
                                        fontWeight: FontWeight.w600, 
                                        color: isCancelado ? Colors.red.shade800 : Colors.black87,
                                      ),
                                      maxLines: heightPx < 30 ? 1 : 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
