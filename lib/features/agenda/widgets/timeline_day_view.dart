import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage/whatsapp_service.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../models/agendamento.dart';

// --- CLASSE AUXILIAR DE FERIADOS (BRASIL + SP) ---
class FeriadosHelper {
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
    required this.onReabrir, 
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
  final Function(String id) onReabrir; 

  static const double _pixelsPorMinuto = 1.6;
  static const double _larguraHorarios = 50.0;

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

  Color _obterCorStatus(AgendamentoStatus status, bool isBloqueio) {
    if (isBloqueio) return Colors.grey.shade300;
    switch (status) {
      case AgendamentoStatus.agendado: return Colors.blue.shade400;
      case AgendamentoStatus.confirmado: return Colors.green.shade400;
      case AgendamentoStatus.concluido: return Colors.blue.shade900; 
      case AgendamentoStatus.cancelado: return Colors.red.shade300;
    }
  }

  Widget _buildStatusBadge(AgendamentoStatus status, bool isBloqueio, {bool compact = false}) {
    if (isBloqueio) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: compact ? 10 : 12, color: Colors.grey.shade900),
            if (!compact) ...[
              const SizedBox(width: 3),
              Text('Bloqueado', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
            ]
          ],
        ),
      );
    }

    final statusText = _getStatusText(status);
    final statusIcon = _getStatusIcon(status);
    final badgeColor = _getStatusBadgeColor(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 3),
      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: compact ? 12 : 14, color: Colors.grey.shade900),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
          ]
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
      case AgendamentoStatus.agendado: return Colors.blue.shade50;
      case AgendamentoStatus.confirmado: return Colors.green.shade50;
      case AgendamentoStatus.concluido: return Colors.blue.shade100;
      case AgendamentoStatus.cancelado: return Colors.red.shade100;
    }
  }

  // 🎯 O NOVO MENU DO WHATSAPP (A GAVETA)
  void _mostrarMenuWhatsApp(BuildContext context, String telefone, String nome, Agendamento agendamento) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Escolha a mensagem para enviar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check_circle_outline, color: Colors.white, size: 20)),
                title: const Text('Confirmação de Agendamento', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Enviada no dia ou na véspera.'),
                onTap: () {
                  Navigator.pop(ctx);
                  WhatsAppService.enviarConfirmacao(telefone: telefone, nomeCliente: nome, agendamento: agendamento);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.cancel_outlined, color: Colors.white, size: 20)),
                title: const Text('Mensagem de Cancelamento', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Enviada quando desmarcam.'),
                onTap: () {
                  Navigator.pop(ctx);
                  WhatsAppService.enviarCancelamento(telefone: telefone, nomeCliente: nome, agendamento: agendamento);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final telefonesPorId = clientesAsync.maybeWhen(
      data: (lista) => {for (final c in lista) c.id: c.telefone},
      orElse: () => <String, String>{},
    );

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

    final int horasVisiveis = (horaMaxima - horaMinima) + 1;
    final alturaTotal = (horasVisiveis * 60) * _pixelsPorMinuto;
    
    final agora = DateTime.now();
    final isHoje = dataReferencia.year == agora.year && 
                   dataReferencia.month == agora.month && 
                   dataReferencia.day == agora.day;

    final nomeFeriado = FeriadosHelper.verificarFeriado(dataReferencia);

    Set<String> horariosExibir = {};
    for (int h = horaMinima; h <= horaMaxima; h++) {
      horariosExibir.add('${h.toString().padLeft(2, '0')}:00');
    }
    for (final a in agendamentosAtivos) {
      if (!a.horaInicio.endsWith(':00')) horariosExibir.add(a.horaInicio);
      if (!a.horaFim.endsWith(':00')) horariosExibir.add(a.horaFim);
    }

    return SingleChildScrollView(
      key: const PageStorageKey('agenda_scroll_dia_global'), 
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nomeFeriado != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade300)),
              child: Row(
                children: [
                  Icon(Icons.park, color: Colors.orange.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FERIADO: $nomeFeriado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                        const SizedBox(height: 2),
                        Text('A grade está aberta. Cuidado ao agendar.', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _larguraHorarios,
                height: alturaTotal,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: horariosExibir.map((timeStr) {
                    final topPx = _calcularTop(timeStr, horaMinima);
                    final isHoraCheia = timeStr.endsWith(':00');
                    return Positioned(
                      top: topPx - 7,
                      left: 0,
                      right: 8,
                      child: Text(
                        timeStr,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: isHoraCheia ? 11 : 9,
                          fontWeight: isHoraCheia ? FontWeight.bold : FontWeight.w600,
                          color: isHoraCheia ? Colors.black87 : Colors.grey.shade500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              Expanded(
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
                  child: Container(
                    height: alturaTotal,
                    color: Colors.transparent,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          children: [
                            for (int i = 0; i < horasVisiveis; i++)
                              Container(
                                height: 60 * _pixelsPorMinuto,
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                                ),
                              ),
                          ],
                        ),

                        ...agendamentosAtivos.map((a) {
                          final topPx = _calcularTop(a.horaInicio, horaMinima);
                          final heightPx = _calcularAltura(a.horaInicio, a.horaFim);
                          
                          final isBloqueio = a.clienteId == 'BLOQUEIO';
                          final nomeCliente = isBloqueio ? 'Compromisso Pessoal' : (clientesPorId[a.clienteId] ?? 'Cliente removido');
                          final telefoneCliente = telefonesPorId[a.clienteId] ?? '';
                          final cor = _obterCorStatus(a.status, isBloqueio);

                          final bool isDark = a.status == AgendamentoStatus.concluido && !isBloqueio;
                          final Color corTexto = isDark ? Colors.white : Colors.black87;
                          final Color corIcone = isDark ? Colors.white70 : Colors.black54;

                          final bool isMuitoCurto = heightPx < 55;

                          return Positioned(
                            top: topPx,
                            left: 4,
                            right: 4,
                            height: heightPx > 46 ? heightPx : 46, 
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onEditar(a.id),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade400, width: 1), 
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: isMuitoCurto
                                    // ==========================================
                                    // MODO ULTRA-COMPACTO
                                    // ==========================================
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text('${a.horaInicio}-${a.horaFim}', style: TextStyle(fontSize: 10, color: corTexto, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(nomeCliente, style: TextStyle(fontSize: 11, color: corTexto, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ),
                                              const SizedBox(width: 4),
                                              _buildStatusBadge(a.status, isBloqueio, compact: true),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(isBloqueio ? Icons.lock : Icons.back_hand, size: 10, color: corIcone),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(a.servico, style: TextStyle(fontSize: 10, color: corTexto), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ),
                                              if (!isBloqueio) ...[
                                                if (a.status != AgendamentoStatus.concluido)
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => _mostrarMenuWhatsApp(context, telefoneCliente, nomeCliente, a),
                                                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.chat_bubble_outline, size: 18, color: isDark ? Colors.greenAccent : Colors.green.shade900)),
                                                  ),
                                                if (a.status == AgendamentoStatus.agendado)
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => onConfirmar(a.id),
                                                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.verified_outlined, size: 18, color: isDark ? Colors.white : Colors.grey.shade900)),
                                                  ),
                                                if (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado)
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => onConcluir(a.id),
                                                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.check_circle_outline, size: 18, color: isDark ? Colors.white : Colors.grey.shade900)),
                                                  ),
                                                if (a.status == AgendamentoStatus.concluido)
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => onReabrir(a.id),
                                                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.settings_backup_restore, size: 18, color: Colors.blue.shade100)),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      )
                                    // ==========================================
                                    // MODO NORMAL
                                    // ==========================================
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${a.horaInicio} - ${a.horaFim}',
                                                style: TextStyle(fontSize: 10, color: corTexto, fontWeight: FontWeight.bold),
                                              ),
                                              const Spacer(),
                                              if (!isBloqueio) ...[
                                                if (a.status != AgendamentoStatus.concluido)
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => _mostrarMenuWhatsApp(context, telefoneCliente, nomeCliente, a),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      child: Icon(Icons.chat_bubble_outline, size: 20, color: isDark ? Colors.greenAccent : Colors.green.shade900), 
                                                    ),
                                                  ),
                                                if (a.status == AgendamentoStatus.agendado)
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => onConfirmar(a.id),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      child: Icon(Icons.verified_outlined, size: 20, color: isDark ? Colors.white : Colors.grey.shade900),
                                                    ),
                                                  ),
                                                if (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado)
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => onConcluir(a.id),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      child: Icon(Icons.check_circle_outline, size: 20, color: isDark ? Colors.white : Colors.grey.shade900),
                                                    ),
                                                  ),
                                                if (a.status == AgendamentoStatus.concluido)
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => onReabrir(a.id),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      child: Icon(Icons.settings_backup_restore, size: 20, color: Colors.blue.shade100),
                                                    ),
                                                  ),
                                              ],
                                              _buildStatusBadge(a.status, isBloqueio),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Flexible(
                                            child: Row(
                                              children: [
                                                Icon(isBloqueio ? Icons.lock : Icons.person, size: 14, color: corIcone),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(nomeCliente, style: TextStyle(fontSize: 13, color: corTexto, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          if (a.servico.isNotEmpty && !isBloqueio)
                                            Flexible(
                                              child: Row(
                                                children: [
                                                  Icon(Icons.back_hand, size: 12, color: corIcone),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(a.servico, style: TextStyle(fontSize: 12, color: corTexto), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            ),
                          );
                        }),
                        
                        if (isHoje)
                          StreamBuilder(
                            stream: Stream.periodic(const Duration(minutes: 1)),
                            builder: (context, snapshot) {
                              final tempoAtual = DateTime.now();
                              final minutosAtual = tempoAtual.hour * 60 + tempoAtual.minute;
                              
                              if (minutosAtual < horaMinima * 60 || minutosAtual > (horaMaxima + 1) * 60) {
                                return const SizedBox.shrink();
                              }
                              
                              final topPxAtual = (minutosAtual - (horaMinima * 60)) * _pixelsPorMinuto;
                              
                              return Positioned(
                                top: topPxAtual - 4,
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
        ],
      ),
    );
  }
}
