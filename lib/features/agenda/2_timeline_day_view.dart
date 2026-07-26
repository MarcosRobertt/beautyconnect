import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agendamento.dart';

/// Visualização diária da Agenda em formato timeline (slots de 30 minutos).
/// Cada agendamento ocupa altura proporcional à sua duração.
class TimelineDayView extends StatelessWidget {
  const TimelineDayView({
    super.key,
    required this.agendamentos,
    required this.clientesNomes,
    required this.onHorarioLivreSelecionado,
    required this.onAgendamentoTapado,
  });

  final List<Agendamento> agendamentos;
  final Map<String, String> clientesNomes;
  final Function(TimeOfDay horario) onHorarioLivreSelecionado;
  final Function(Agendamento agendamento) onAgendamentoTapado;

  // Horário de funcionamento: 08:00 - 20:00
  static const int _horaInicio = 8;
  static const int _horaFim = 20;
  static const int _intervaloMinutos = 30;

  /// Converte string "HH:MM" para minutos desde a meia-noite
  int _horaParaMinutos(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  /// Retorna cor do status
  Color _corStatus(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado:
        return const Color(0xFF4DD0E1); // cyan
      case AgendamentoStatus.confirmado:
        return const Color(0xFF66BB6A); // green
      case AgendamentoStatus.concluido:
        return const Color(0xFF78909C); // gray
      case AgendamentoStatus.cancelado:
        return const Color(0xFFEF5350); // red
    }
  }

  /// Calcula a duração em minutos entre dois horários no formato "HH:MM"
  int _calcularDuracao(String horaInicio, String horaFim) {
    final minInicio = _horaParaMinutos(horaInicio);
    final minFim = _horaParaMinutos(horaFim);
    return minFim - minInicio;
  }

  /// Calcula a altura proporcional do agendamento em pixels
  /// Cada hora = ~60px, cada 30min = ~30px
  double _calcularAltura(int duracaoMin) {
    return (duracaoMin / 30) * 30;
  }

  /// Calcula o offset do topo (posição Y) do agendamento
  double _calcularOffset(String horaInicio) {
    final minutos = _horaParaMinutos(horaInicio);
    final minutosDesdeInicio = minutos - (_horaInicio * 60);
    return (minutosDesdeInicio / 30) * 30;
  }

  /// Gera lista de slots de 30 minutos para exibição
  List<String> _gerarSlots() {
    final slots = <String>[];
    for (int h = _horaInicio; h < _horaFim; h++) {
      for (int m = 0; m < 60; m += _intervaloMinutos) {
        slots.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _gerarSlots();
    final ehTelaLarga = MediaQuery.of(context).size.width >= 800;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            // Linha de horários (esquerda)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna de horários
                SizedBox(
                  width: 50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: slots
                        .map((slot) => SizedBox(
                              height: 30,
                              child: Text(
                                slot,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.right,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                // Coluna de timeline
                Expanded(
                  child: Stack(
                    children: [
                      // Linhas de separação (slots)
                      Column(
                        children: slots
                            .map((_) => Container(
                                  height: 30,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey[300]!),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      // Agendamentos
                      ...agendamentos.map((a) {
                        final duracao = _calcularDuracao(a.horaInicio, a.horaFim);
                        final altura = _calcularAltura(duracao);
                        final offset = _calcularOffset(a.horaInicio);

                        return Positioned(
                          top: offset,
                          left: 0,
                          right: 0,
                          height: altura,
                          child: GestureDetector(
                            onTap: () => onAgendamentoTapado(a),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                              decoration: BoxDecoration(
                                color: _corStatus(a.status),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _corStatus(a.status).withOpacity(0.7)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clientesNomes[a.clienteId] ?? 'Cliente',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      a.servico,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Horários livres (clicáveis)
                      ...slots.asMap().entries.map((entry) {
                        final index = entry.key;
                        final slot = entry.value;
                        final temAgendamento = agendamentos.any((a) => a.horaInicio == slot);

                        if (!temAgendamento) {
                          return Positioned(
                            top: index * 30.0,
                            left: 0,
                            right: 0,
                            height: 30,
                            child: GestureDetector(
                              onTap: () {
                                final partes = slot.split(':');
                                onHorarioLivreSelecionado(
                                  TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1])),
                                );
                              },
                              child: Container(
                                color: Colors.transparent,
                                child: Tooltip(
                                  message: 'Novo agendamento às $slot',
                                  child: Center(
                                    child: Opacity(
                                      opacity: 0,
                                      child: Container(
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
