import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agendamento.dart';

/// Visualização diária da Agenda em formato lista vertical (otimizada para celular).
/// Cada agendamento é exibido em um card com toda a informação visível.
class ListDayView extends StatelessWidget {
  const ListDayView({
    super.key,
    required this.agendamentos,
    required this.clientesNomes,
    required this.onAgendamentoTapado,
    required this.onConfirmar,
    required this.onConcluir,
    required this.onCancelar,
  });

  final List<Agendamento> agendamentos;
  final Map<String, String> clientesNomes;
  final Function(Agendamento agendamento) onAgendamentoTapado;
  final Function(String id) onConfirmar;
  final Function(String id) onConcluir;
  final Function(String id) onCancelar;

  Color _corStatus(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado:
        return const Color(0xFF4DD0E1);
      case AgendamentoStatus.confirmado:
        return const Color(0xFF66BB6A);
      case AgendamentoStatus.concluido:
        return const Color(0xFF78909C);
      case AgendamentoStatus.cancelado:
        return const Color(0xFFEF5350);
    }
  }

  String _labelStatus(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado:
        return 'Agendado';
      case AgendamentoStatus.confirmado:
        return 'Confirmado';
      case AgendamentoStatus.concluido:
        return 'Concluído';
      case AgendamentoStatus.cancelado:
        return 'Cancelado';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (agendamentos.isEmpty) {
      return const Center(child: Text('Nenhum agendamento para hoje.'));
    }

    return ListView.builder(
      itemCount: agendamentos.length,
      itemBuilder: (context, index) {
        final a = agendamentos[index];
        final nomeCliente = clientesNomes[a.clienteId] ?? 'Cliente removido';
        final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha 1: Horário e Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Horário
                    Text(
                      '${a.horaInicio}–${a.horaFim}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    // Status em Chip compacto
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _corStatus(a.status).withOpacity(0.2),
                        border: Border.all(color: _corStatus(a.status)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _labelStatus(a.status),
                        style: TextStyle(
                          color: _corStatus(a.status),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Linha 2: Cliente
                Text(
                  nomeCliente,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Linha 3: Serviço e Valor
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        a.servico,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      moeda.format(a.valor),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Linha 4: Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Botão Editar (sempre disponível)
                    Tooltip(
                      message: 'Editar',
                      child: IconButton(
                        onPressed: () => onAgendamentoTapado(a),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ),

                    // Botão Confirmar (se agendado)
                    if (a.status == AgendamentoStatus.agendado)
                      Tooltip(
                        message: 'Confirmar',
                        child: IconButton(
                          onPressed: () => onConfirmar(a.id),
                          icon: const Icon(Icons.verified_outlined, size: 20),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),

                    // Botão Concluir (se agendado ou confirmado)
                    if (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado)
                      Tooltip(
                        message: 'Concluir',
                        child: IconButton(
                          onPressed: () => onConcluir(a.id),
                          icon: const Icon(Icons.check_circle_outline, size: 20),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),

                    // Botão Cancelar (se agendado ou confirmado)
                    if (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado)
                      Tooltip(
                        message: 'Cancelar',
                        child: IconButton(
                          onPressed: () => onCancelar(a.id),
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
