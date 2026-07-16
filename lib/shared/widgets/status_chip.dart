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
      AgendamentoStatus.concluido: (const Color(0xFFD9F2E3), const Color(0xFF2E7D4F), Icons.check_circle),
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
