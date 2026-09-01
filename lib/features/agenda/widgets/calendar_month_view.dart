import 'package:flutter/material.dart';
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

class CalendarMonthView extends StatefulWidget {
  const CalendarMonthView({
    super.key,
    required this.agendamentos,
    required this.dataReferencia,
    required this.onIrParaDia,
  });

  final List<Agendamento> agendamentos;
  final DateTime dataReferencia;
  final Function(DateTime) onIrParaDia;

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  // CORREÇÃO: Adicionado 'static' para preservar a escolha na memória do aplicativo
  static bool _visaoContador = true; 
  static const int _metaDiaria = 10; // 100% = 10 atendimentos

  List<Agendamento> _agendamentosDoDia(DateTime dia) {
    return widget.agendamentos.where((a) =>
        a.data.year == dia.year &&
        a.data.month == dia.month &&
        a.data.day == dia.day).toList();
  }

  Color _obterCorStatus(AgendamentoStatus status) {
    switch (status) {
      case AgendamentoStatus.agendado:
        return Colors.blue.shade300;
      case AgendamentoStatus.confirmado:
        return Colors.green.shade400;
      case AgendamentoStatus.concluido:
        return Colors.grey.shade400;
      case AgendamentoStatus.cancelado:
        return Colors.red.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primeiroDiaDoMes = DateTime(widget.dataReferencia.year, widget.dataReferencia.month, 1);
    final ultimoDiaDoMes = DateTime(widget.dataReferencia.year, widget.dataReferencia.month + 1, 0);
    
    int diasAntes = primeiroDiaDoMes.weekday == 7 ? 0 : primeiroDiaDoMes.weekday;
    int totalDias = diasAntes + ultimoDiaDoMes.day;
    int totalCelulas = (totalDias / 7).ceil() * 7;

    return Column(
      children: [
        // CONTROLES DE VISÃO (Contador / Lista)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Radio<bool>(
                value: true,
                groupValue: _visaoContador,
                activeColor: Colors.purple,
                onChanged: (val) => setState(() => _visaoContador = val!),
              ),
              const Text('Visão Contador', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              Radio<bool>(
                value: false,
                groupValue: _visaoContador,
                activeColor: Colors.purple,
                onChanged: (val) => setState(() => _visaoContador = val!),
              ),
              const Text('Visão Lista', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        
        // CABEÇALHO DOS DIAS DA SEMANA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
              .map((dia) => Expanded(
                    child: Center(
                      child: Text(dia, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),

        // GRADE DO CALENDÁRIO
        Expanded(
          child: GridView.builder(
            itemCount: totalCelulas,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.65, // Proporção da célula
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              int diaMes = index - diasAntes + 1;
              bool pertenceAoMes = diaMes > 0 && diaMes <= ultimoDiaDoMes.day;

              if (!pertenceAoMes) {
                return Container(); // Célula vazia
              }

              final dataAtual = DateTime(widget.dataReferencia.year, widget.dataReferencia.month, diaMes);
              final agendamentosDia = _agendamentosDoDia(dataAtual);
              
              final isHoje = dataAtual.year == DateTime.now().year &&
                  dataAtual.month == DateTime.now().month &&
                  dataAtual.day == DateTime.now().day;

              final nomeFeriado = _FeriadosHelper.verificarFeriado(dataAtual);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onIrParaDia(dataAtual),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    color: isHoje ? Colors.purple.shade50 : Colors.white,
                  ),
                  child: _visaoContador
                      ? _buildVisaoContador(diaMes, agendamentosDia, nomeFeriado)
                      : _buildVisaoLista(diaMes, agendamentosDia, nomeFeriado),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // WIDGET: CÉLULA VISÃO CONTADOR
  Widget _buildVisaoContador(int dia, List<Agendamento> agendamentos, String? nomeFeriado) {
    int total = agendamentos.length;
    int confirmados = agendamentos.where((a) => a.status == AgendamentoStatus.confirmado).length;
    double progresso = total / _metaDiaria;
    if (progresso > 1.0) progresso = 1.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progresso Circular
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : progresso,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                ),
              ),
              // Número do dia no centro
              Text('$dia', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              
              // Badge Cinza (Total)
              if (total > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: Colors.grey.shade600, shape: BoxShape.circle),
                    child: Text('$total', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ),
                
              // Badge Azul (Confirmados)
              if (confirmados > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: Text('$confirmados', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
        if (nomeFeriado != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.shade300, width: 0.5),
            ),
            child: Text(
              nomeFeriado,
              style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // WIDGET: CÉLULA VISÃO LISTA
  Widget _buildVisaoLista(int dia, List<Agendamento> agendamentos, String? nomeFeriado) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(2.0),
          child: Text(
            '$dia',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        if (nomeFeriado != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.orange.shade300, width: 0.5),
            ),
            child: Text(
              nomeFeriado,
              style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: agendamentos.length > 4 ? 4 : agendamentos.length,
            itemBuilder: (context, i) {
              if (i == 3 && agendamentos.length > 4) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(2)),
                  child: Text('+${agendamentos.length - 3}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                );
              }
              final a = agendamentos[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: _obterCorStatus(a.status),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  a.servico, // Mostra serviço abreviado
                  style: const TextStyle(fontSize: 7, color: Colors.black87, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
