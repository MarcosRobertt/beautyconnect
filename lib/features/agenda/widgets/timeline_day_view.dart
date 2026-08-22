import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/storage/whatsapp_service.dart';
import '../models/agendamento.dart';

class TimelineDayView extends StatelessWidget {
  const TimelineDayView({
    super.key,
    required this.agendamentos,
    required this.clientesPorId,
    required this.moeda,
    required this.dataReferencia,
    required this.onNovoAgendamento,
    required this.onEditar,
    required this.onConfirmar,
    required this.onConcluir,
    required this.onCancelar,
  });

  final List<Agendamento> agendamentos;
  final Map<String, String> clientesPorId;
  final NumberFormat moeda;
  final DateTime dataReferencia;
  final Function(String horaInicio) onNovoAgendamento;
  final Function(String id) onEditar;
  final Function(String id) onConfirmar;
  final Function(String id) onConcluir;
  final Function(String id) onCancelar;

  static const double _pixelsPorMinuto = 2.0;
  static const double _larguraHorarios = 60.0;

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
        return Colors.red.shade50;
    }
  }

  Widget _buildStatusBadge(AgendamentoStatus status, bool isBloqueio) {
    if (isBloqueio) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 10, color: Colors.grey.shade800),
            const SizedBox(width: 3),
            Text('Bloqueado', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ],
        ),
      );
    }

    final statusText = _getStatusText(status);
    final statusIcon = _getStatusIcon(status);
    final badgeColor = _getStatusBadgeColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 10, color: Colors.grey.shade700),
          const SizedBox(width: 3),
          Text(statusText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  String _getStatusText(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado: return 'Agendado';
      case AgendamentoStatus.confirmado: return 'Confirmado';
      case AgendamentoStatus.concluido: return 'Finalizado';
      case AgendamentoStatus.cancelado: return 'Cancelado';
    }
  }

  IconData _getStatusIcon(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado: return Icons.schedule;
      case AgendamentoStatus.confirmado: return Icons.check;
      case AgendamentoStatus.concluido: return Icons.check_circle;
      case AgendamentoStatus.cancelado: return Icons.cancel;
    }
  }

  Color _getStatusBadgeColor(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado: return Colors.blue.shade50;
      case AgendamentoStatus.confirmado: return Colors.green.shade50;
      case AgendamentoStatus.concluido: return Colors.grey.shade100;
      case AgendamentoStatus.cancelado: return Colors.red.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    int horaMinima = 9;
    int horaMaxima = 18;

    if (agendamentos.isNotEmpty) {
      for (final a in agendamentos) {
        final horaInicioInt = int.parse(a.horaInicio.split(':')[0]);
        final horaFimInt = int.parse(a.horaFim.split(':')[0]);

        if (horaInicioInt < horaMinima) horaMinima = horaInicioInt;
        if (horaFimInt > horaMaxima) horaMaxima = horaFimInt + 1;
      }
    }

    final alturaTotal = ((horaMaxima - horaMinima) * 60) * _pixelsPorMinuto;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: GestureDetector(
                onTapUp: (details) {
                  final yRelativa = details.localPosition.dy;
                  final minutosDesdeInicio = (yRelativa / _pixelsPorMinuto).toInt();
                  final minutosAbsolutos = (horaMinima * 60) + minutosDesdeInicio;
                  final horas = minutosAbsolutos ~/ 60;
                  final minutos = minutosAbsolutos % 60;
                  final minutosArredondados = (minutos ~/ 30) * 30;
                  final horaClicada = '${horas.toString().padLeft(2, '0')}:${minutosArredondados.toString().padLeft(2, '0')}';
                  onNovoAgendamento(horaClicada);
                },
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: alturaTotal,
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          for (int i = 0; i < (horaMaxima - horaMinima) * 2; i++)
                            Container(
                              height: 30 * _pixelsPorMinuto,
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ...agendamentos.map((a) {
                      final topPx = _calcularTop(a.horaInicio, horaMinima);
                      final heightPx = _calcularAltura(a.horaInicio, a.horaFim);
                      
                      final isBloqueio = a.clienteId == 'BLOQUEIO';
                      final nomeCliente = isBloqueio ? 'Compromisso Pessoal' : (clientesPorId[a.clienteId] ?? 'Cliente removido');
                      final cor = _obterCorStatus(a.status);

                      return Positioned(
                        top: topPx,
                        left: 8,
                        right: 8,
                        height: heightPx > 40 ? heightPx : 40,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onEditar(a.id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildStatusBadge(a.status, isBloqueio),
                                    const Spacer(),
                                    if (!isBloqueio) ...[
                                      // BOTÃO WHATSAPP DISPARA MENSAGEM PADRONIZADA
                                      GestureDetector(
                                        onTap: () {
                                          WhatsAppService.enviarConfirmacao(
                                            telefone: '5500000000000', // O service formata com DDI
                                            nomeCliente: nomeCliente,
                                            agendamento: a,
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4),
                                          child: Icon(Icons.chat_bubble_outline, size: 18, color: Colors.green),
                                        ),
                                      ),
                                      if (a.status == AgendamentoStatus.agendado)
                                        GestureDetector(
                                          onTap: () => onConfirmar(a.id),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(Icons.verified_outlined, size: 20, color: Colors.grey.shade700),
                                          ),
                                        ),
                                      if (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado)
                                        GestureDetector(
                                          onTap: () => onConcluir(a.id),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(Icons.check_circle_outline, size: 20, color: Colors.grey.shade700),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    '${a.horaInicio}–${a.horaFim}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    a.servico,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: isBloqueio ? FontWeight.bold : FontWeight.normal),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isBloqueio)
                                  Flexible(
                                    child: Text(
                                      nomeCliente,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
