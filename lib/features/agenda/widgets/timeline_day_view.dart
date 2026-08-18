import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // Altura de cada slot de 30 minutos
  static const double _slotsHeight = 60.0;

  // Horários de início e fim da timeline (em horas)
  static const int _horaInicio = 9;
  static const int _horaFim = 18;

  int _horaParaMinutos(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  String _minutosParaHora(int minutos) {
    final horas = minutos ~/ 60;
    final mins = minutos % 60;
    return '${horas.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  double _calcularPosicaoY(String hhmm) {
    final minutos = _horaParaMinutos(hhmm);
    final minutosDesdeInicio = minutos - (_horaInicio * 60);
    return (minutosDesdeInicio / 30) * _slotsHeight;
  }

  double _calcularAltura(String horaInicio, String horaFim) {
    final minInicio = _horaParaMinutos(horaInicio);
    final minFim = _horaParaMinutos(horaFim);
    final duracao = minFim - minInicio;
    return (duracao / 30) * _slotsHeight;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline container
          Stack(
            children: [
              // Linhas de horários e linhas divisórias
              Column(
                children: [
                  for (int h = _horaInicio; h <= _horaFim; h++)
                    for (int m = 0; m < 60; m += 30)
                      Column(
                        children: [
                          if (m == 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${h.toString().padLeft(2, '0')}:00',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 0.5,
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                ],
              ),

              // Agendamentos como blocos
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: SizedBox(
                  height: ((_horaFim - _horaInicio) * 120) + 100,
                  child: Stack(
                    children: [
                      // Áreas clicáveis para horários vazios
                      GestureDetector(
                        onTapDown: (details) {
                          final yRelativa = details.localPosition.dy;
                          final minutosDesdeInicio = (yRelativa / _slotsHeight) * 30;
                          final minutosAbsolutos = (_horaInicio * 60) + minutosDesdeInicio.toInt();
                          final horas = minutosAbsolutos ~/ 60;
                          final minutos = minutosAbsolutos % 60;
                          final horaClicada =
                              '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}';
                          onNovoAgendamento(horaClicada);
                        },
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),

                      // Blocos de agendamento
                      ...agendamentos.map((a) {
                        final topPx = _calcularPosicaoY(a.horaInicio);
                        final heightPx = _calcularAltura(a.horaInicio, a.horaFim);
                        final nomeClie nte = clientesPorId[a.clienteId] ?? 'Cliente removido';
                        final cor = _obterCorStatus(a.status);

                        return Positioned(
                          top: topPx,
                          left: 0,
                          right: 0,
                          height: heightPx,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12, bottom: 4),
                            child: GestureDetector(
                              onLongPress: () {
                                _mostrarMenuAgendamento(context, a);
                              },
                              child: Card(
                                margin: EdgeInsets.zero,
                                color: cor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${a.horaInicio}–${a.horaFim}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      Flexible(
                                        child: Text(
                                          nomeCliente,
                                          style: Theme.of(context).textTheme.labelSmall,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          a.servico,
                                          style: Theme.of(context).textTheme.labelSmall,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
        ],
      ),
    );
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

  void _mostrarMenuAgendamento(BuildContext context, Agendamento agendamento) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${agendamento.horaInicio}–${agendamento.horaFim} • ${agendamento.servico}'),
              subtitle: Text(clientesPorId[agendamento.clienteId] ?? 'Cliente removido'),
            ),
            const Divider(),
            if (agendamento.status == AgendamentoStatus.agendado)
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('Confirmar'),
                onTap: () {
                  Navigator.pop(context);
                  onConfirmar(agendamento.id);
                },
              ),
            if (agendamento.status == AgendamentoStatus.agendado ||
                agendamento.status == AgendamentoStatus.confirmado)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.pop(context);
                  onEditar(agendamento.id);
                },
              ),
            if (agendamento.status == AgendamentoStatus.agendado ||
                agendamento.status == AgendamentoStatus.confirmado)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Concluir'),
                onTap: () {
                  Navigator.pop(context);
                  onConcluir(agendamento.id);
                },
              ),
            if (agendamento.status == AgendamentoStatus.agendado ||
                agendamento.status == AgendamentoStatus.confirmado)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancelar'),
                onTap: () {
                  Navigator.pop(context);
                  onCancelar(agendamento.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}
