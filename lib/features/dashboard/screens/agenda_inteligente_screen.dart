import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';

class AgendaInteligenteScreen extends ConsumerWidget {
  const AgendaInteligenteScreen({super.key});

  int _parseHora(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  // Retorna os horários livres num dia, ou 'LIVRE' (se 100%), ou 'LOTADO' (se 0%)
  List<String> _calcularHorariosLivres(DateTime data, List<Agendamento> todos) {
    if (data.weekday == DateTime.monday || data.weekday == DateTime.sunday) return [];

    final agendsDoDia = todos.where((a) =>
      a.status != AgendamentoStatus.cancelado &&
      a.data.year == data.year && a.data.month == data.month && a.data.day == data.day
    ).toList();

    List<String> livres = [];
    for (int h = 9; h < 18; h++) {
      for (int m = 0; m < 60; m += 30) {
        int slotStart = h * 60 + m;
        int slotEnd = slotStart + 30;
        bool conflito = false;

        for (var a in agendsDoDia) {
          int aStart = _parseHora(a.horaInicio);
          int aEnd = _parseHora(a.horaFim);
          if (slotStart < aEnd && slotEnd > aStart) {
            conflito = true;
            break;
          }
        }
        if (!conflito) {
          livres.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
        }
      }
    }

    if (livres.isEmpty) return ['LOTADO'];
    if (livres.length == 18) return ['LIVRE']; // 9h às 18h = 18 slots de 30min
    return livres;
  }

  // Calcula % Livre da semana (Ter-Sáb = 5 dias * 9h = 2700 min)
  double _calcularPctSemana(DateTime segundaFeiraDaSemana, List<Agendamento> agendamentos) {
    int ocupado = 0;
    for (var a in agendamentos) {
      if (a.status == AgendamentoStatus.cancelado) continue;
      if (a.data.weekday == DateTime.monday || a.data.weekday == DateTime.sunday) continue;
      
      final segundaDoAgendamento = a.data.subtract(Duration(days: a.data.weekday - 1));
      if (segundaDoAgendamento.year == segundaFeiraDaSemana.year &&
          segundaDoAgendamento.month == segundaFeiraDaSemana.month &&
          segundaDoAgendamento.day == segundaFeiraDaSemana.day) {
        
        int start = _parseHora(a.horaInicio);
        int end = _parseHora(a.horaFim);
        if (start < 9 * 60) start = 9 * 60;
        if (end > 18 * 60) end = 18 * 60;
        
        if (end > start) ocupado += (end - start);
      }
    }
    
    final pct = ((2700 - ocupado) / 2700) * 100;
    return pct.clamp(0.0, 100.0);
  }

  Widget _buildBadge(double pct) {
    Color cor;
    String statusTexto;
    if (pct < 30) {
      cor = Colors.red; statusTexto = 'Quase Lotada';
    } else if (pct < 60) {
      cor = Colors.amber.shade700; statusTexto = 'Ritmo Normal';
    } else {
      cor = Colors.green; statusTexto = 'Precisando Encaixes';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: cor.withOpacity(0.3))),
      child: Text('${pct.toStringAsFixed(0)}% Livre — $statusTexto', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cor)),
    );
  }

  Widget _buildDiaRow(DateTime dia, List<String> slots) {
    final diasStr = ['Seg', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Dom'];
    final rotulo = '${diasStr[dia.weekday - 1]} (${dia.day.toString().padLeft(2,'0')}/${dia.month.toString().padLeft(2,'0')})';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(rotulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 6),
          if (slots.first == 'LOTADO')
            const Text('Agenda totalmente lotada! 🔥', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic))
          else if (slots.first == 'LIVRE')
            const Text('Agenda 100% Livre (09h às 18h) ✨', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: slots.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.shade900)),
              )).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda Inteligente'),
      ),
      body: todosAgendamentosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar agendamentos: $e')),
        data: (agendamentos) {
          final hoje = DateTime.now();
          final segundaSemanaAtual = hoje.subtract(Duration(days: hoje.weekday - 1));
          final segundaProximaSemana = segundaSemanaAtual.add(const Duration(days: 7));

          final pctSemanaAtual = _calcularPctSemana(segundaSemanaAtual, agendamentos);
          final pctProximaSemana = _calcularPctSemana(segundaProximaSemana, agendamentos);

          // Dias da Semana Atual (Hoje em diante até Sábado)
          List<DateTime> diasSemanaAtual = [];
          if (hoje.weekday <= DateTime.saturday) {
            for (int i = hoje.weekday; i <= DateTime.saturday; i++) {
              if (i != DateTime.monday && i != DateTime.sunday) {
                diasSemanaAtual.add(segundaSemanaAtual.add(Duration(days: i - 1)));
              }
            }
          }

          // Dias da Próxima Semana (Terça a Sábado)
          List<DateTime> diasProximaSemana = [];
          for (int i = DateTime.tuesday; i <= DateTime.saturday; i++) {
            diasProximaSemana.add(segundaProximaSemana.add(Duration(days: i - 1)));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Acompanhe sua taxa de ocupação e horários livres.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 24),

              // MÓDULO: SEMANA ATUAL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('👇 SEMANA ATUAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  _buildBadge(pctSemanaAtual),
                ],
              ),
              const SizedBox(height: 16),
              if (diasSemanaAtual.isEmpty)
                const Text('Semana atual finalizada.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))
              else
                ...diasSemanaAtual.map((dia) => _buildDiaRow(dia, _calcularHorariosLivres(dia, agendamentos))),
              
              const Divider(height: 32),

              // MÓDULO: PRÓXIMA SEMANA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('⏭️ PRÓXIMA SEMANA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  _buildBadge(pctProximaSemana),
                ],
              ),
              const SizedBox(height: 16),
              ...diasProximaSemana.map((dia) => _buildDiaRow(dia, _calcularHorariosLivres(dia, agendamentos))),
            ],
          );
        },
      ),
    );
  }
}
