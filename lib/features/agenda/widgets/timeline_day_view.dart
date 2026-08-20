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

  static const double _pixelsPorMinuto = 2.0;
  static const int _horaInicio = 9;
  static const int _horaFim = 18;
  static const double _larguraHorarios = 60.0;

  int _horaParaMinutos(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  double _calcularTop(String horaInicio) {
    final minutos = _horaParaMinutos(horaInicio);
    final minutosDesdeInicio = minutos - (_horaInicio * 60);
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
    final alturaTotal = ((_horaFim - _horaInicio) * 60) * _pixelsPorMinuto;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna de Horários (Esquerda, Fixa)
          SizedBox(
            width: _larguraHorarios,
            child: Column(
              children: [
                for (int h = _horaInicio; h <= _horaFim; h++)
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

          // Área de Eventos (Direita, Expandida)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: GestureDetector(
                onTapDown: (details) {
                  final yRelativa = details.localPosition.dy;
                  final minutosDesdeInicio = (yRelativa / _pixelsPorMinuto).toInt();
                  final minutosAbsolutos = (_horaInicio * 60) + minutosDesdeInicio;
                  final horas = minutosAbsolutos ~/ 60;
                  final minutos = minutosAbsolutos % 60;

                  // Arredondar para 30 minutos mais próximos
                  final minutosArredondados = (minutos ~/ 30) * 30;
                  final horaClicada =
                      '${horas.toString().padLeft(2, '0')}:${minutosArredondados.toString().padLeft(2, '0')}';
                  onNovoAgendamento(horaClicada);
                },
                child: Stack(
                  children: [
                    // Background com grid (opcional)
                    Container(
                      width: double.infinity,
                      height: alturaTotal,
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          for (int i = 0; i < (_horaFim - _horaInicio) * 2; i++)
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
                    ),

                    // Eventos posicionados
                    ...agendamentos.map((a) {
                      final topPx = _calcularTop(a.horaInicio);
                      final heightPx = _calcularAltura(a.horaInicio, a.horaFim);
                      final nomeCliente = clientesPorId[a.clienteId] ?? 'Cliente removido';
                      final cor = _obterCorStatus(a.status);

                      return Positioned(
                        top: topPx,
                        left: 8,
                        right: 8,
                        height: heightPx > 40 ? heightPx : 40,
                        child: GestureDetector(
                          onLongPress: () {
                            _mostrarMenuAgendamento(context, a);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: cor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${a.horaInicio}–${a.horaFim}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Flexible(
                                  child: Text(
                                    a.servico,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    nomeCliente,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
