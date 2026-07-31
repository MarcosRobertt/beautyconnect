import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agendamento.dart';

/// Visualização mensal da Agenda em formato grid (7 colunas × ~6 linhas).
/// Cada célula representa um dia, exibindo agendamentos de forma compacta.
class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    super.key,
    required this.dataReferencia,
    required this.agendamentos,
    required this.clientesNomes,
    required this.onDiaSelecionado,
    required this.onAgendamentoTapado,
  });

  final DateTime dataReferencia;
  final List<Agendamento> agendamentos;
  final Map<String, String> clientesNomes;
  final Function(DateTime dia) onDiaSelecionado;
  final Function(Agendamento agendamento) onAgendamentoTapado;

  /// Retorna lista de células do mês, incluindo dias do mês anterior/seguinte
  /// para preencher a grid.
  List<DateTime> _construirGrid() {
    final primeiro = DateTime(dataReferencia.year, dataReferencia.month, 1);
    final ultimo = DateTime(dataReferencia.year, dataReferencia.month + 1, 0);

    // Preenche com dias do mês anterior
    final inicioGrid = primeiro.subtract(Duration(days: primeiro.weekday % 7));
    final grid = <DateTime>[];

    var atual = inicioGrid;
    while (atual.isBefore(ultimo.add(const Duration(days: 1))) || grid.length % 7 != 0) {
      grid.add(atual);
      atual = atual.add(const Duration(days: 1));
      if (grid.length % 7 == 0 && atual.isAfter(ultimo)) break;
    }

    return grid;
  }

  /// Retorna agendamentos do dia específico
  List<Agendamento> _agendamentosDoDia(DateTime dia) {
    return agendamentos
        .where((a) => a.data.year == dia.year && a.data.month == dia.month && a.data.day == dia.day)
        .toList();
  }

  /// Retorna cor do status do agendamento
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

  @override
  Widget build(BuildContext context) {
    final grid = _construirGrid();
    final hoje = DateTime.now();
    final ehTelaLarga = MediaQuery.of(context).size.width >= 800;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Linha de dias da semana (dom-sab)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab']
                    .map((dia) => Expanded(
                          child: Text(
                            dia,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ))
                    .toList(),
              ),
            ),
            // Grid de dias
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: grid.length,
              itemBuilder: (context, index) {
                final dia = grid[index];
                final diaAgendamentos = _agendamentosDoDia(dia);
                final ehDiaDoMes = dia.month == dataReferencia.month;
                final ehHoje = dia.year == hoje.year && dia.month == hoje.month && dia.day == hoje.day;

                return GestureDetector(
                  onTap: ehDiaDoMes ? () => onDiaSelecionado(dia) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ehHoje
                            ? Theme.of(context).colorScheme.primary
                            : (ehDiaDoMes ? Colors.grey[300]! : Colors.grey[200]!),
                        width: ehHoje ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: ehHoje
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : (ehDiaDoMes ? Colors.white : Colors.grey[50]),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Número do dia
                          Text(
                            dia.day.toString(),
                            style: TextStyle(
                              fontWeight: ehHoje || ehDiaDoMes ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                              color: ehDiaDoMes ? Colors.black : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Agendamentos do dia (chips compactos)
                          Expanded(
                            child: diaAgendamentos.isEmpty
                                ? const SizedBox()
                                : SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        for (int i = 0; i < (diaAgendamentos.length > 2 ? 2 : diaAgendamentos.length); i++)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: GestureDetector(
                                              onTap: () => onAgendamentoTapado(diaAgendamentos[i]),
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: _corStatus(diaAgendamentos[i].status),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                                child: Text(
                                                  '${clientesNomes[diaAgendamentos[i].clienteId] ?? "?"}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 9, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (diaAgendamentos.length > 2)
                                          Text(
                                            '+${diaAgendamentos.length - 2}',
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
