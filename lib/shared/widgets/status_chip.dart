import 'package:flutter/material.dart';

import '../../features/agenda/models/agendamento.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final AgendamentoStatus status;

  @override
  Widget build(BuildContext context) {
    final cores = <AgendamentoStatus, (Color, Color, IconData)>{
      AgendamentoStatus.agendado: (const Color(0xFFDEE6FF), const Color(0xFF3A5FCD), Icons.schedule),
      AgendamentoStatus.confirmado: (const Color(0xFFFFE8B8), const Color(0xFF8A5A00), Icons.verified),
      // NOVO: Azul Escuro para Comandas Finalizadas/Pagas
      AgendamentoStatus.concluido: (const Color(0xFFE3F2FD), const Color(0xFF1565C0), Icons.check_circle),
      AgendamentoStatus.cancelado: (const Color(0xFFFFD9DF), const Color(0xFFBA1A4A), Icons.cancel),
    };
    
    final (bg, fg, icon) = cores[status]!;
    
    return Chip(
      backgroundColor: bg,
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(status.label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
