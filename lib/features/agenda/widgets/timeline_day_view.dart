import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage/whatsapp_service.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../models/agendamento.dart';

class TimelineDayView extends ConsumerWidget {
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
  final dynamic moeda;
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
        return Colors.blue.shade300;
      case AgendamentoStatus.confirmado:
        return Colors.green.shade300;
      case AgendamentoStatus.concluido:
        return Colors.grey.shade400;
      case AgendamentoStatus.cancelado:
        return Colors.red.shade300; // Nunca será renderizado aqui, mas mantido por segurança
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
            Icon(Icons.block, size: 10, color: Colors.grey.shade900),
            const SizedBox(width: 3),
            Text('Bloqueado', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
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
          Icon(statusIcon, size: 10, color: Colors.grey.shade900),
          const SizedBox(width: 3),
          Text(statusText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
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
      case AgendamentoStatus.agendado: return Colors.blue.shade100;
      case AgendamentoStatus.confirmado: return Colors.green.shade100;
      case AgendamentoStatus.concluido: return Colors.grey.shade200;
      case AgendamentoStatus.cancelado: return Colors.red.shade100;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final telefonesPorId = clientesAsync.maybeWhen(
      data: (lista) => {for (final c in lista) c.id: c.telefone},
      orElse: () => <String, String>{},
    );

    // FILTRO LIMPO: Oculta cancelados da visão diária para não sobrepor
    final agendamentosAtivos = agendamentos.where((a) => a.status != AgendamentoStatus.cancelado).toList();

    int horaMinima = 9;
    int horaMaxima = 18;

    if (agendamentosAtivos.isNotEmpty) {
      for (final a in agendamentosAtivos) {
        final horaInicioInt = int.parse(a.horaInicio.split(':')[0]);
        final horaFimInt = int.parse(a.horaFim.split(':')[0]);

        if (horaInicioInt < horaMinima) horaMinima = horaInicioInt;
        if (horaFimInt > horaMaxima) horaMaxima = horaFimInt + 1;
      }
    }

    final alturaTotal = ((horaMaxima - horaMinima) * 60) * _pixelsPorMinuto;
    
    // VERIFICADOR DO DIA ATUAL PARA A LINHA DO TEMPO
    final agora = DateTime.now();
    final isHoje = dataReferencia.year == agora.year && 
                   dataReferencia.month == agora.month && 
                   dataReferencia.day == agora.day;

    return SingleChildScrollView(
      key: const PageStorageKey('agenda_scroll_dia_global'), 
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
              key: const PageStorageKey('agenda_scroll_dia_interno'), 
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
                    ...agendamentosAtivos.map((a) {
                      final topPx = _calcularTop(a.horaInicio, horaMinima);
                      final heightPx = _calcularAltura(a.horaInicio, a.horaFim);
                      
                      final isBloqueio = a.clienteId == 'BLOQUEIO';
                      final nomeCliente = isBloqueio ? 'Compromisso Pessoal' : (clientesPorId[a.clienteId] ?? 'Cliente removido');
                      final telefoneCliente = telefonesPorId[a.clienteId] ?? '';
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
                              border: Border.all(color: Colors.grey.shade400, width: 1), 
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
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          WhatsAppService.enviarConfirmacao(
                                            telefone: telefoneCliente,
                                            nomeCliente: nomeCliente,
                                            agendamento: a,
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          child: Icon(Icons.chat_bubble_outline, size: 24, color: Colors.green.shade900), 
                                        ),
                                      ),
                                      if (a.status == AgendamentoStatus.agendado)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => onConfirmar(a.id),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            child: Icon(Icons.verified_outlined, size: 24, color: Colors.grey.shade900),
                                          ),
                                        ),
                                      if (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => onConcluir(a.id),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            child: Icon(Icons.check_circle_outline, size: 24, color: Colors.grey.shade900),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    '${a.horaInicio}–${a.horaFim}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.black87),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    a.servico,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, fontWeight: isBloqueio ? FontWeight.bold : FontWeight.w600, color: Colors.black87),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isBloqueio)
                                  Flexible(
                                    child: Text(
                                      nomeCliente,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, color: Colors.black87),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                    // LINHA DO TEMPO REAL SE FOR HOJE
                    if (isHoje)
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(minutes: 1)),
                        builder: (context, snapshot) {
                          final tempoAtual = DateTime.now();
                          final minutosAtual = tempoAtual.hour * 60 + tempoAtual.minute;
                          
                          // Só renderiza se estiver dentro da grade visível
                          if (minutosAtual < horaMinima * 60 || minutosAtual > horaMaxima * 60) {
                            return const SizedBox.shrink();
                          }
                          
                          final topPxAtual = (minutosAtual - (horaMinima * 60)) * _pixelsPorMinuto;
                          
                          return Positioned(
                            top: topPxAtual - 4, // Centraliza a bolinha
                            left: 0,
                            right: 0,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1.5,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
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
