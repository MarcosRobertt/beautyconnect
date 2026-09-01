import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agendamento.dart';

// --- CLASSE AUXILIAR DE FERIADOS (PRIVADA) ---
class _FeriadosHelper {
  static DateTime _calcularPascoa(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static String? verificarFeriado(DateTime data) {
    final d = data.day;
    final m = data.month;
    final y = data.year;

    if (d == 1 && m == 1) return 'Confraternização Universal';
    if (d == 21 && m == 4) return 'Tiradentes';
    if (d == 1 && m == 5) return 'Dia do Trabalhador';
    if (d == 9 && m == 7) return 'Rev. Constitucionalista (SP)';
    if (d == 7 && m == 9) return 'Independência do Brasil';
    if (d == 12 && m == 10) return 'Nossa Sra. Aparecida';
    if (d == 2 && m == 11) return 'Finados';
    if (d == 15 && m == 11) return 'Proclamação da República';
    if (d == 20 && m == 11) return 'Consciência Negra';
    if (d == 25 && m == 12) return 'Natal';

    final pascoa = _calcularPascoa(y);
    final carnaval = pascoa.subtract(const Duration(days: 47));
    final sextaSanta = pascoa.subtract(const Duration(days: 2));
    final corpusChristi = pascoa.add(const Duration(days: 60));

    if (d == carnaval.day && m == carnaval.month) return 'Carnaval';
    if (d == sextaSanta.day && m == sextaSanta.month) return 'Paixão de Cristo';
    if (d == corpusChristi.day && m == corpusChristi.month) return 'Corpus Christi';

    return null;
  }
}

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: _larguraHorarios),
            ...diasSemana.map((dia) {
              final ehHoje = dia.year == DateTime.now().year &&
                  dia.month == DateTime.now().month &&
                  dia.day == DateTime.now().day;
              
              final nomeFeriado = _FeriadosHelper.verificarFeriado(dia);
                  
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
                      mainAxisSize: MainAxisSize.min,
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
                        if (nomeFeriado != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.shade300, width: 0.5),
                              ),
                              child: Text(
                                nomeFeriado,
                                style: TextStyle(
                                  fontSize: 7,
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
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
