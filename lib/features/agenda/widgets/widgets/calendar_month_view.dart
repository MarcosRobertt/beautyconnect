import 'package:flutter/material.dart';
import '../models/agendamento.dart';

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
  bool _visaoContador = true; // Inicia na Visão Contador
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
    // Matemática do Calendário
    final primeiroDiaDoMes = DateTime(widget.dataReferencia.year, widget.dataReferencia.month, 1);
    final ultimoDiaDoMes = DateTime(widget.dataReferencia.year, widget.dataReferencia.month + 1, 0);
    
    // 0 = Domingo, 1 = Segunda... (no Dart, Segunda = 1, Domingo = 7)
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
              childAspectRatio: 0.65, // Proporção da célula (mais alta que larga)
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              int diaMes = index - diasAntes + 1;
              bool pertenceAoMes = diaMes > 0 && diaMes <= ultimoDiaDoMes.day;

              if (!pertenceAoMes) {
                return Container(); // Célula vazia para alinhar os dias
              }

              final dataAtual = DateTime(widget.dataReferencia.year, widget.dataReferencia.month, diaMes);
              final agendamentosDia = _agendamentosDoDia(dataAtual);
              
              final isHoje = dataAtual.year == DateTime.now().year &&
                  dataAtual.month == DateTime.now().month &&
                  dataAtual.day == DateTime.now().day;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onIrParaDia(dataAtual),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    color: isHoje ? Colors.purple.shade50 : Colors.white,
                  ),
                  child: _visaoContador
                      ? _buildVisaoContador(diaMes, agendamentosDia)
                      : _buildVisaoLista(diaMes, agendamentosDia),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // WIDGET: CÉLULA VISÃO CONTADOR
  Widget _buildVisaoContador(int dia, List<Agendamento> agendamentos) {
    int total = agendamentos.length;
    int confirmados = agendamentos.where((a) => a.status == AgendamentoStatus.confirmado).length;
    double progresso = total / _metaDiaria;
    if (progresso > 1.0) progresso = 1.0;

    return Padding(
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
                decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                child: Text('$confirmados', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  // WIDGET: CÉLULA VISÃO LISTA
  Widget _buildVisaoLista(int dia, List<Agendamento> agendamentos) {
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
