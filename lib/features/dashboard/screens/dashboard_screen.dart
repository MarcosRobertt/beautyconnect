import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/whatsapp_service.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../../clientes/models/cliente.dart';
import '../controllers/dashboard_controller.dart';

String formatarMoeda(double valor) {
  return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
}

String formatarData(DateTime data) {
  final meses = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  final diasSemana = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
  return '${diasSemana[data.weekday - 1]}, ${data.day} de ${meses[data.month - 1]}';
}

String _formatarMesAno(DateTime data) {
  final meses = ['JANEIRO', 'FEVEREIRO', 'MARÇO', 'ABRIL', 'MAIO', 'JUNHO', 'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'];
  return '${meses[data.month - 1]} DE ${data.year}';
}

String _formatarDiaCurto(DateTime data) {
  final diasSemana = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
  return '${diasSemana[data.weekday - 1]}, ${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final String _filtroPlanoVoo = 'Hoje';
  String _periodoFaturamento = 'Hoje';
  String _periodoTM = 'Hoje';

  // =========================================================
  // 🎯 CONFIGURAÇÃO DAS METAS (Pode alterar esses valores)
  // =========================================================
  final int metaAtendimentosDia = 8;
  final double metaFaturamentoDia = 800.0;
  // =========================================================

  @override
  Widget build(BuildContext context) {
    ref.watch(agendamentoControllerProvider);

    final metricas = ref.watch(dashboardMetricsProvider);
    final clientesAsync = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    
    final hoje = DateTime.now();
    final rotuloData = formatarData(hoje);
    final larguraTela = MediaQuery.of(context).size.width;

    final clientes = clientesAsync.value ?? [];
    final clientesPorId = {for (final c in clientes) c.id: c};
    final todosAgendamentos = todosAgendamentosAsync.value ?? [];

    final hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);
    
    final aniversariantesProximos = clientes.where((c) {
      if (c.aniversario == null) return false;
      var niverEsteAno = DateTime(hoje.year, c.aniversario!.month, c.aniversario!.day);
      if (niverEsteAno.isBefore(hojeZerado)) {
        niverEsteAno = DateTime(hoje.year + 1, c.aniversario!.month, c.aniversario!.day);
      }
      final diff = niverEsteAno.difference(hojeZerado).inDays;
      return diff >= 0 && diff <= 15;
    }).toList();

    final inativas = <Map<String, dynamic>>[];
    for (final c in clientes) {
      final agendamentosCliente = todosAgendamentos.where((a) =>
        a.clienteId == c.id && a.status != AgendamentoStatus.cancelado
      ).toList();

      if (agendamentosCliente.isNotEmpty) {
        agendamentosCliente.sort((a, b) => b.data.compareTo(a.data));
        final ultimoAgendamento = agendamentosCliente.first;
        final diasSemVir = hojeZerado.difference(DateTime(ultimoAgendamento.data.year, ultimoAgendamento.data.month, ultimoAgendamento.data.day)).inDays;

        if (diasSemVir > 25) {
          inativas.add({'cliente': c, 'dias': diasSemVir, 'ultimaData': ultimoAgendamento.data});
        }
      }
    }
    final totalNotificacoes = aniversariantesProximos.length + inativas.length;

    final ontemZerado = hojeZerado.subtract(const Duration(days: 1));
    final inicioSemanaAtual = hojeZerado.subtract(Duration(days: hojeZerado.weekday - 1));
    final inicioSemanaAnterior = inicioSemanaAtual.subtract(const Duration(days: 7));
    final fimSemanaAnterior = inicioSemanaAtual.subtract(const Duration(seconds: 1));
    final inicioMesAtual = DateTime(hoje.year, hoje.month, 1);
    final inicioMesAnterior = DateTime(hoje.year, hoje.month - 1, 1);
    final fimMesAnterior = DateTime(hoje.year, hoje.month, 0, 23, 59, 59);
    
    double fatHoje = 0, fatOntem = 0;
    double fatSemana = 0, fatSemanaAnt = 0;
    double fatMes = 0, fatMesAnt = 0;
    
    int qtdHoje = 0, qtdOntem = 0;
    int qtdSemana = 0, qtdSemanaAnt = 0;
    int qtdMes = 0, qtdMesAnt = 0;

    for (final a in todosAgendamentos) {
      if (a.clienteId == 'BLOQUEIO' || a.status == AgendamentoStatus.cancelado) continue;
      final d = a.data;
      final val = a.valor;
      
      if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
        fatHoje += val; qtdHoje++;
      } else if (d.year == ontemZerado.year && d.month == ontemZerado.month && d.day == ontemZerado.day) {
        fatOntem += val; qtdOntem++;
      }

      if (!d.isBefore(inicioSemanaAtual)) {
        fatSemana += val; qtdSemana++;
      } else if (!d.isBefore(inicioSemanaAnterior) && !d.isAfter(fimSemanaAnterior)) {
        fatSemanaAnt += val; qtdSemanaAnt++;
      }

      if (!d.isBefore(inicioMesAtual)) {
        fatMes += val; qtdMes++;
      } else if (!d.isBefore(inicioMesAnterior) && !d.isAfter(fimMesAnterior)) {
        fatMesAnt += val; qtdMesAnt++;
      }
    }

    final tmHoje = qtdHoje > 0 ? fatHoje / qtdHoje : 0.0;
    final tmOntem = qtdOntem > 0 ? fatOntem / qtdOntem : 0.0;
    final tmSemana = qtdSemana > 0 ? fatSemana / qtdSemana : 0.0;
    final tmSemanaAnt = qtdSemanaAnt > 0 ? fatSemanaAnt / qtdSemanaAnt : 0.0;
    final tmMes = qtdMes > 0 ? fatMes / qtdMes : 0.0;
    final tmMesAnt = qtdMesAnt > 0 ? fatMesAnt / qtdMesAnt : 0.0;

    final valFatAtual = _periodoFaturamento == 'Hoje' ? fatHoje : (_periodoFaturamento == 'Semana' ? fatSemana : fatMes);
    final valFatAnt = _periodoFaturamento == 'Hoje' ? fatOntem : (_periodoFaturamento == 'Semana' ? fatSemanaAnt : fatMesAnt);
    final valTMAtual = _periodoTM == 'Hoje' ? tmHoje : (_periodoTM == 'Semana' ? tmSemana : tmMes);
    final valTMAnt = _periodoTM == 'Hoje' ? tmOntem : (_periodoTM == 'Semana' ? tmSemanaAnt : tmMesAnt);

    final metaAtivaFaturamento = _periodoFaturamento == 'Hoje' 
        ? metaFaturamentoDia 
        : (_periodoFaturamento == 'Semana' ? (metaFaturamentoDia * 5) : (metaFaturamentoDia * 20));

    final comandasPendentes = todosAgendamentos.where((a) =>
        a.clienteId != 'BLOQUEIO' &&
        a.status == AgendamentoStatus.agendado &&
        a.data.isBefore(hojeZerado)
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.water_drop, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('BeautyConnect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('by studio condeza', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Central de Lembretes',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (totalNotificacoes > 0)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text('$totalNotificacoes', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            onPressed: () => _mostrarCentralNotificacoes(context, aniversariantesProximos, inativas),
          ),
          IconButton(
            tooltip: 'Agenda Inteligente',
            icon: const Icon(Icons.auto_graph),
            onPressed: () => context.push(AppRoutes.agendaInteligente),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.agendaNovo),
        child: const Icon(Icons.add),
      ),
      body: metricas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (m) {
          final totalAtendimentosReaisHoje = m.agendaHoje.where((a) => a.clienteId != 'BLOQUEIO').length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(rotuloData, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Painel Estratégico de Desempenho.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              
              GridView.count(
                crossAxisCount: larguraTela > 800 ? 4 : (larguraTela < 360 ? 1 : 2),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: larguraTela < 360 ? 2.2 : 1.15,
                children: [
                  _CardMetaAtendimentos(
                    atual: totalAtendimentosReaisHoje, 
                    meta: metaAtendimentosDia
                  ),
                  _CardMetricaOriginal(
                    titulo: 'Próximo atendimento',
                    valor: m.proximo != null ? m.proximo!.horaInicio : 'Livre',
                    subvalor: m.proximo != null ? (clientesPorId[m.proximo!.clienteId]?.nome?.split(" ").first ?? "—") : 'Nenhum agendado',
                    icone: Icons.schedule,
                  ),
                  _CardMetricaInteligente(
                    titulo: 'Faturamento', valor: formatarMoeda(valFatAtual), icone: Icons.account_balance_wallet,
                    valorAnterior: valFatAnt, valorAtual: valFatAtual,
                    periodoSelecionado: _periodoFaturamento,
                    metaAtual: metaAtivaFaturamento,
                    onPeriodoChanged: (val) => setState(() => _periodoFaturamento = val!),
                    onTap: () => _mostrarDetalhesReceita(context, todosAgendamentos),
                  ),
                  _CardMetricaInteligente(
                    titulo: 'Ticket Médio', valor: formatarMoeda(valTMAtual), icone: Icons.monetization_on,
                    valorAnterior: valTMAnt, valorAtual: valTMAtual,
                    periodoSelecionado: _periodoTM,
                    onPeriodoChanged: (val) => setState(() => _periodoTM = val!),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (comandasPendentes.isNotEmpty) ...[
                Card(
                  color: Colors.orange.shade50, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade300, width: 1.5)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
                    title: Text('${comandasPendentes.length} Comanda(s) pendente(s)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 14)),
                    subtitle: Text('De dias anteriores. Feche para registrar o faturamento.', style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context, isScrollControlled: true,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                          builder: (context) => const _ModalComandasPendentes(),
                        );
                      },
                      child: const Text('VER'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Agenda de hoje', style: Theme.of(context).textTheme.titleMedium),
                          TextButton(onPressed: () => context.go(AppRoutes.agenda), child: const Text('Ver completa')),
                        ],
                      ),
                      if (m.agendaHoje.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Nenhum agendamento para hoje.')))
                      else
                        ...m.agendaHoje.map((a) {
                          final nomeCliente = clientesPorId[a.clienteId]?.nome ?? (a.clienteId == "BLOQUEIO" ? "Compromisso Pessoal" : "Cliente removido");
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox(width: 48, child: Text(a.horaInicio, style: const TextStyle(fontWeight: FontWeight.w600))),
                            title: Text('$nomeCliente — ${a.servico}'),
                            trailing: StatusChip(status: a.status),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }

  void _mostrarCentralNotificacoes(BuildContext context, List<Cliente> aniversariantes, List<Map<String, dynamic>> inativas) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _ModalCentralNotificacoes(aniversariantes: aniversariantes, inativas: inativas),
    );
  }

  void _mostrarDetalhesReceita(BuildContext context, List<Agendamento> agendamentos) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _ModalDetalhesReceita(agendamentos: agendamentos),
    );
  }
}

// ============================================================================
// 🎯 NOVOS WIDGETS DE GAMIFICAÇÃO DAS METAS
// ============================================================================

class _CardMetaAtendimentos extends StatelessWidget {
  const _CardMetaAtendimentos({required this.atual, required this.meta});
  final int atual;
  final int meta;

  @override
  Widget build(BuildContext context) {
    double pct = atual / meta;
    if (pct > 1.0) pct = 1.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 6),
                Text('Atendimentos', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                SizedBox(
                  height: 38, width: 38,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey.shade200,
                        color: pct >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
                        strokeWidth: 4.5,
                      ),
                      Center(child: Text('$atual', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Meta: $meta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      Text(atual >= meta ? 'Meta Batida! 🎉' : 'Faltam ${meta - atual}', style: TextStyle(fontSize: 10, color: atual >= meta ? Colors.green : Colors.grey)),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMetricaOriginal extends StatelessWidget {
  const _CardMetricaOriginal({required this.titulo, required this.valor, required this.icone, this.subvalor, this.onTap});
  final String titulo;
  final String valor;
  final String? subvalor;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icone, color: Theme.of(context).colorScheme.primary, size: 20),
                  if (onTap != null) const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
              const Spacer(),
              Text(titulo, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(valor, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subvalor != null)
                Text(subvalor!, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMetricaInteligente extends StatelessWidget {
  const _CardMetricaInteligente({
    required this.titulo, required this.valor, required this.icone,
    required this.valorAnterior, required this.valorAtual, this.periodoSelecionado, 
    this.metaAtual, this.onPeriodoChanged, this.onTap
  });
  
  final String titulo; final String valor; final IconData icone; final double valorAnterior; final double valorAtual; 
  final String? periodoSelecionado; final double? metaAtual; final ValueChanged<String?>? onPeriodoChanged; final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color corBadge = Colors.grey; IconData iconeSeta = Icons.remove; String txtEvolucao = 'Sem base';
    if (valorAnterior > 0) {
      final variacao = ((valorAtual - valorAnterior) / valorAnterior) * 100;
      txtEvolucao = '${variacao > 0 ? '+' : ''}${variacao.toStringAsFixed(1)}%';
      if (variacao >= 10) { corBadge = Colors.green; iconeSeta = Icons.trending_up; } 
      else if (variacao <= -5) { corBadge = Colors.red; iconeSeta = Icons.trending_down; } 
      else { corBadge = Colors.amber.shade700; iconeSeta = Icons.trending_flat; }
    } else if (valorAtual > 0) { corBadge = Colors.green; iconeSeta = Icons.trending_up; txtEvolucao = 'Novo!'; }

    double pct = 0;
    if (metaAtual != null && metaAtual! > 0) {
      pct = valorAtual / metaAtual!;
      if (pct > 1.0) pct = 1.0;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icone, color: Theme.of(context).colorScheme.primary, size: 20),
                  if (periodoSelecionado != null)
                    SizedBox(
                      height: 20,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true, value: periodoSelecionado, icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                          items: ['Hoje', 'Semana', 'Mês'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                          onChanged: onPeriodoChanged,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(titulo, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  Expanded(child: Text(valor, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (metaAtual == null && (valorAnterior > 0 || valorAtual > 0))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: corBadge.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: corBadge.withOpacity(0.3))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(iconeSeta, size: 10, color: corBadge), const SizedBox(width: 2), Text(txtEvolucao, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: corBadge))]),
                    ),
                ]
              ),
              if (metaAtual != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade200,
                    color: pct >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: pct >= 1.0 ? Colors.green : Colors.grey.shade700)),
                    Text('Meta: R\$ ${metaAtual!.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                  ],
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODAIS INTACTOS DO SISTEMA
// ============================================================================

class _ModalCentralNotificacoes extends StatelessWidget {
  const _ModalCentralNotificacoes({required this.aniversariantes, required this.inativas});
  final List<Cliente> aniversariantes; final List<Map<String, dynamic>> inativas;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75, padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Central de Lembretes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
              const SizedBox(height: 12),
              TabBar(labelColor: Theme.of(context).colorScheme.primary, unselectedLabelColor: Colors.grey, indicatorColor: Theme.of(context).colorScheme.primary, tabs: [Tab(text: 'Aniversários (${aniversariantes.length})'), Tab(text: 'Inativas (${inativas.length})')]),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    aniversariantes.isEmpty ? const Center(child: Text('Nenhum aniversário nos próximos 15 dias.')) : ListView.separated(itemCount: aniversariantes.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) { final cliente = aniversariantes[index]; final dia = cliente.aniversario?.day.toString().padLeft(2, '0'); final mes = cliente.aniversario?.month.toString().padLeft(2, '0'); return ListTile(leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.cake, color: Colors.white, size: 20)), title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Aniversário em: $dia/$mes'), trailing: IconButton(icon: const Icon(Icons.chat, color: Colors.green), tooltip: 'Enviar Parabéns no WhatsApp', onPressed: () { final agendamentoNiver = Agendamento(id: 'niver', clienteId: cliente.id, data: DateTime.now(), horaInicio: '🎉', horaFim: '🎂', duracaoMinutos: 0, servico: 'Especial Aniversário', valor: 0.0, status: AgendamentoStatus.agendado, observacao: 'Feliz Aniversário!', createdAt: DateTime.now(), updatedAt: DateTime.now()); WhatsAppService.enviarConfirmacao(telefone: cliente.telefone, nomeCliente: cliente.nome, agendamento: agendamentoNiver); })); }),
                    inativas.isEmpty ? const Center(child: Text('Nenhuma cliente inativa encontrada.')) : ListView.separated(itemCount: inativas.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) { final item = inativas[index]; final cliente = item['cliente'] as Cliente; final dias = item['dias'] as int; return ListTile(leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20)), title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Sem agendar há $dias dias'), trailing: IconButton(icon: const Icon(Icons.chat, color: Colors.green), tooltip: 'Convidar no WhatsApp', onPressed: () { final agendamentoRetorno = Agendamento(id: 'retorno', clienteId: cliente.id, data: DateTime.now(), horaInicio: '💅', horaFim: '✨', duracaoMinutos: 0, servico: 'Retorno / Manutenção', valor: 0.0, status: AgendamentoStatus.agendado, observacao: 'Sentimos sua falta!', createdAt: DateTime.now(), updatedAt: DateTime.now()); WhatsAppService.enviarConfirmacao(telefone: cliente.telefone, nomeCliente: cliente.nome, agendamento: agendamentoRetorno); })); }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalDetalhesReceita extends StatefulWidget {
  const _ModalDetalhesReceita({required this.agendamentos});
  final List<Agendamento> agendamentos;

  @override
  State<_ModalDetalhesReceita> createState() => _ModalDetalhesReceitaState();
}

class _ModalDetalhesReceitaState extends State<_ModalDetalhesReceita> {
  String _opcaoFiltro = 'Este Mês';

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now(); DateTime inicio; DateTime fim;
    if (_opcaoFiltro == 'Hoje') { inicio = DateTime(hoje.year, hoje.month, hoje.day); fim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59); } 
    else if (_opcaoFiltro == 'Esta Semana') { final inicioSemana = hoje.subtract(Duration(days: hoje.weekday % 7)); inicio = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day); fim = inicio.add(const Duration(days: 7)); } 
    else if (_opcaoFiltro == 'Mês Anterior') { inicio = DateTime(hoje.year, hoje.month - 1, 1); fim = DateTime(hoje.year, hoje.month, 0, 23, 59, 59); } 
    else if (_opcaoFiltro == 'vs Ano Ant.') { inicio = DateTime(hoje.year, hoje.month, 1); fim = DateTime(hoje.year, hoje.month + 1, 0, 23, 59, 59); } 
    else { inicio = DateTime(hoje.year, hoje.month, 1); fim = DateTime(hoje.year, hoje.month + 1, 0, 23, 59, 59); }

    final filtrados = widget.agendamentos.where((a) => a.clienteId != 'BLOQUEIO' && a.status != AgendamentoStatus.cancelado && a.data.isAfter(inicio.subtract(const Duration(seconds: 1))) && a.data.isBefore(fim.add(const Duration(seconds: 1)))).toList();
    double totalConfirmado = 0.0; double totalPendente = 0.0; final totalPorForma = <FormaPagamento, double>{ for (var f in FormaPagamento.values) f: 0.0 };

    for (final a in filtrados) {
      if (a.status == AgendamentoStatus.concluido || a.status == AgendamentoStatus.confirmado) { totalConfirmado += a.valor; } 
      else if (a.status == AgendamentoStatus.agendado) { totalPendente += a.valor; }
      final forma = a.formaPagamento ?? FormaPagamento.pendente; totalPorForma[forma] = (totalPorForma[forma] ?? 0.0) + a.valor;
    }

    final agrupaPorDia = <String, Map<String, dynamic>>{};
    for (final a in filtrados) {
      final chaveDia = '${a.data.year}-${a.data.month.toString().padLeft(2, '0')}-${a.data.day.toString().padLeft(2, '0')}';
      if (!agrupaPorDia.containsKey(chaveDia)) { agrupaPorDia[chaveDia] = {'data': a.data, 'valor': 0.0, 'qtd': 0}; }
      agrupaPorDia[chaveDia]!['valor'] += a.valor; agrupaPorDia[chaveDia]!['qtd'] += 1;
    }

    final listaDias = agrupaPorDia.values.toList();
    listaDias.sort((a, b) => (b['data'] as DateTime).compareTo(a['data'] as DateTime));

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8, padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Análise de Receita', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'Hoje', label: Text('Hoje', style: TextStyle(fontSize: 11))), ButtonSegment(value: 'Esta Semana', label: Text('Semana', style: TextStyle(fontSize: 11))), ButtonSegment(value: 'Este Mês', label: Text('Este Mês', style: TextStyle(fontSize: 11))), ButtonSegment(value: 'Mês Anterior', label: Text('Mês Ant.', style: TextStyle(fontSize: 11)))], selected: {_opcaoFiltro}, onSelectionChanged: (set) => setState(() => _opcaoFiltro = set.first))),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Realizado / Confirmado', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(formatarMoeda(totalConfirmado), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green))]))), const SizedBox(width: 8), Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Previsto (Aguardando)', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(formatarMoeda(totalPendente), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue))]))) ]),
            const SizedBox(height: 16),
            const Text('Formas de Pagamento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: FormaPagamento.values.map((forma) { final valorForma = totalPorForma[forma] ?? 0.0; if (valorForma == 0.0) return const SizedBox.shrink(); return Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(forma.rotulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(width: 6), Text(formatarMoeda(valorForma), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple))])); }).toList())),
            const SizedBox(height: 16),
            const Text('Detalhamento por Dia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Expanded(child: listaDias.isEmpty ? const Center(child: Text('Nenhum faturamento registrado para este período.')) : ListView.separated(itemCount: listaDias.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) { final item = listaDias[i]; final dataItem = item['data'] as DateTime; final valorItem = item['valor'] as double; final qtdItem = item['qtd'] as int; return ListTile(contentPadding: EdgeInsets.zero, title: Text('${dataItem.day.toString().padLeft(2, '0')}/${dataItem.month.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: Text('$qtdItem atendimento(s)', style: const TextStyle(fontSize: 12)), trailing: Text(formatarMoeda(valorItem), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple))); })),
          ],
        ),
      ),
    );
  }
}

class _ModalComandasPendentes extends ConsumerWidget {
  const _ModalComandasPendentes();

  void _abrirModalFechamento(BuildContext context, WidgetRef ref, Agendamento agendamento, String nomeCliente) {
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _ModalFecharComandaDashboard(
        agendamento: agendamento,
        nomeCliente: nomeCliente,
        onConfirmar: (pagamentos, valorFinal, houveAtraso) async {
          
          try {
            final docVerificacao = await FirebaseFirestore.instance
                .collection('agendamentos')
                .doc(agendamento.id)
                .get(const GetOptions(source: Source.server));
                
            if (docVerificacao.exists) {
              final statusBanco = docVerificacao.data()?['status']?.toString().toLowerCase() ?? '';
              
              if (statusBanco.contains('concluido') && agendamento.status != AgendamentoStatus.concluido) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.gpp_bad_rounded, color: Colors.orange.shade800, size: 28),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Duplicidade Evitada!', style: TextStyle(color: Colors.orange.shade900, fontSize: 18))),
                        ],
                      ),
                      content: const Text('O sistema interceptou esta ação porque a comanda já consta como FECHADA no banco de dados.\n\nA ação foi bloqueada e nenhum valor extra foi lançado.'),
                      actions: [
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.invalidate(todosAgendamentosProvider);
                            ref.invalidate(dashboardMetricsProvider);
                          },
                          child: const Text('Entendi, Atualizar Tela'),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }
            }
          } catch (e) { }

          final obsAtual = agendamento.observacao;
          String novaObs = obsAtual;
          
          if (houveAtraso && !novaObs.contains('[Cliente Atrasou]')) {
            novaObs = novaObs.isEmpty ? '[Cliente Atrasou]' : '$novaObs | [Cliente Atrasou]';
          }

          FormaPagamento formaPrincipal = FormaPagamento.pix;
          String detalhePagamentoStr = '';

          if (pagamentos.isNotEmpty) {
            final maiorPagamento = pagamentos.reduce((a, b) => (a['valor'] as double) > (b['valor'] as double) ? a : b);
            formaPrincipal = maiorPagamento['forma'] as FormaPagamento;
            
            final formataMoeda = (double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
            
            final listaDetalhes = pagamentos.map((p) {
              final d = p['data'] as DateTime;
              final dStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
              final f = (p['forma'] as FormaPagamento).rotulo;
              final v = formataMoeda(p['valor'] as double);
              return '[$dStr] $f: $v';
            }).join(' | ');
            
            detalhePagamentoStr = '[Baixa Financeira: $listaDetalhes]';
          }

          if (detalhePagamentoStr.isNotEmpty) {
             novaObs = novaObs.isEmpty ? detalhePagamentoStr : '$novaObs\n$detalhePagamentoStr';
          }

          final atualizado = agendamento.copyWith(
            status: AgendamentoStatus.concluido,
            formaPagamento: formaPrincipal,
            valor: valorFinal,
            observacao: novaObs,
          );

          final relatorioDeErro = await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
          
          if (context.mounted) {
            if (relatorioDeErro != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $relatorioDeErro'), backgroundColor: Colors.red));
            } else {
              ref.invalidate(todosAgendamentosProvider);
              ref.invalidate(dashboardMetricsProvider);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Comanda fechada e sistema sincronizado!'), backgroundColor: Colors.green));
            }
          }
        },
        onCancelarAtendimento: () async {
          final atualizado = agendamento.copyWith(
            status: AgendamentoStatus.cancelado,
            observacao: agendamento.observacao.isEmpty ? '[Cancelado pelo Dashboard]' : '${agendamento.observacao} | [Cancelado pelo Dashboard]',
          );
          await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
          ref.invalidate(todosAgendamentosProvider);
          ref.invalidate(dashboardMetricsProvider);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Agendamento cancelado!'), backgroundColor: Colors.blue));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    final clientesAsync = ref.watch(clienteControllerProvider);

    final clientes = clientesAsync.value ?? [];
    final clientesPorId = {for (final c in clientes) c.id: c};
    final hoje = DateTime.now();
    final hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);

    final pendentes = (todosAgendamentosAsync.value ?? []).where((a) =>
        a.clienteId != 'BLOQUEIO' &&
        a.status == AgendamentoStatus.agendado &&
        a.data.isBefore(hojeZerado)
    ).toList();

    pendentes.sort((a, b) {
      int cmp = a.data.compareTo(b.data);
      if (cmp == 0) return a.horaInicio.compareTo(b.horaInicio);
      return cmp;
    });

    final mapMes = <String, Map<String, List<Agendamento>>>{};
    for (var a in pendentes) {
      final mesStr = _formatarMesAno(a.data);
      final diaStr = _formatarDiaCurto(a.data);
      mapMes.putIfAbsent(mesStr, () => {});
      mapMes[mesStr]!.putIfAbsent(diaStr, () => []);
      mapMes[mesStr]![diaStr]!.add(a);
    }

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Resolva suas Pendências', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Feche as comandas abaixo para que o valor seja contabilizado.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            Expanded(
              child: pendentes.isEmpty
                  ? const Center(child: Text('Tudo certo! Nenhuma comanda pendente.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                  : ListView(
                      children: mapMes.entries.map((mesEntry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8),
                              child: Text('🗓️ ${mesEntry.key}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 12)),
                            ),
                            ...mesEntry.value.entries.map((diaEntry) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12), elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                                      child: Text('📅 ${diaEntry.key}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    ...diaEntry.value.map((a) {
                                      final nomeCliente = clientesPorId[a.clienteId]?.nome ?? "Cliente não encontrado";
                                      return ListTile(
                                        title: Text('${a.horaInicio} · $nomeCliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        subtitle: Text('${a.servico} — ${formatarMoeda(a.valor)}', style: const TextStyle(fontSize: 12)),
                                        trailing: OutlinedButton(
                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, side: const BorderSide(color: Colors.purple), padding: const EdgeInsets.symmetric(horizontal: 12)),
                                          onPressed: () => _abrirModalFechamento(context, ref, a, nomeCliente),
                                          child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalFecharComandaDashboard extends StatefulWidget {
  const _ModalFecharComandaDashboard({
    required this.agendamento,
    required this.nomeCliente,
    required this.onConfirmar,
    required this.onCancelarAtendimento,
  });

  final Agendamento agendamento;
  final String nomeCliente;
  final void Function(List<Map<String, dynamic>> pagamentos, double valorFinal, bool houveAtraso) onConfirmar;
  final VoidCallback onCancelarAtendimento;

  @override
  State<_ModalFecharComandaDashboard> createState() => _ModalFecharComandaDashboardState();
}

class _ModalFecharComandaDashboardState extends State<_ModalFecharComandaDashboard> {
  late double _valorTotal;
  bool _houveAtraso = false;
  
  DateTime _dataPagamentoAtual = DateTime.now();
  final List<Map<String, dynamic>> _pagamentos = [];
  FormaPagamento _formaAtual = FormaPagamento.pix;
  final TextEditingController _valorParcialController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _valorTotal = widget.agendamento.valor;
    _valorParcialController.text = _valorTotal.toStringAsFixed(2).replaceAll('.', ',');
  }

  double get _valorRestante {
    final pago = _pagamentos.fold<double>(0, (soma, p) => soma + (p['valor'] as double));
    return _valorTotal - pago;
  }

  void _adicionarPagamento() {
    final valorDigitado = double.tryParse(_valorParcialController.text.replaceAll(',', '.')) ?? 0.0;
    if (valorDigitado > 0 && valorDigitado <= _valorRestante) {
      setState(() {
        _pagamentos.add({
          'forma': _formaAtual,
          'valor': valorDigitado,
          'data': _dataPagamentoAtual 
        });
        _valorParcialController.text = _valorRestante.toStringAsFixed(2).replaceAll('.', ',');
        _dataPagamentoAtual = DateTime.now();
      });
    }
  }

  void _removerPagamento(int index) {
    setState(() { _pagamentos.removeAt(index); _valorParcialController.text = _valorRestante.toStringAsFixed(2).replaceAll('.', ','); });
  }

  @override
  Widget build(BuildContext context) {
    final valorPendente = _valorRestante;
    final podeConfirmar = valorPendente <= 0.01;

    return Container(
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Fechar Comanda — ${widget.nomeCliente}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${widget.agendamento.servico} — R\$ ${_valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const Divider(height: 32),

            const Text('Pagamentos Registrados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (_pagamentos.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum pagamento registrado ainda.', style: TextStyle(fontSize: 12, color: Colors.grey))),
            ..._pagamentos.asMap().entries.map((entry) {
              final index = entry.key; final p = entry.value; 
              final forma = p['forma'] as FormaPagamento; 
              final valor = p['valor'] as double;
              final dataP = p['data'] as DateTime;
              final dataStr = '${dataP.day.toString().padLeft(2,'0')}/${dataP.month.toString().padLeft(2,'0')}';

              return ListTile(
                contentPadding: EdgeInsets.zero, dense: true,
                leading: Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                title: Text('${forma.rotulo} ($dataStr)'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _removerPagamento(index))]),
              );
            }),

            if (valorPendente > 0.01) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12), color: Colors.orange.shade50,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Falta Receber:', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)), Text('R\$ ${valorPendente.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16))]),
              ),
              const SizedBox(height: 24),
              
              const Text('Registrar Entrada / Recebimento:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _dataPagamentoAtual, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) setState(() => _dataPagamentoAtual = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text('Data: ${_dataPagamentoAtual.day.toString().padLeft(2, '0')}/${_dataPagamentoAtual.month.toString().padLeft(2, '0')}/${_dataPagamentoAtual.year}', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 2, child: DropdownButtonFormField<FormaPagamento>(value: _formaAtual, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)), items: FormaPagamento.values.where((f) => f != FormaPagamento.pendente).map((f) => DropdownMenuItem(value: f, child: Text(f.rotulo, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => _formaAtual = v!))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(controller: _valorParcialController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixText: 'R\$ ', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)))),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: FilledButton(style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _adicionarPagamento, child: const Icon(Icons.add))),
                ],
              ),
            ],

            const SizedBox(height: 24),
            CheckboxListTile(value: _houveAtraso, contentPadding: EdgeInsets.zero, title: const Text('Cliente chegou atrasada?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)), subtitle: const Text('Registra o atraso no histórico para métricas.', style: TextStyle(fontSize: 11, color: Colors.grey)), controlAffinity: ListTileControlAffinity.leading, onChanged: (val) => setState(() => _houveAtraso = val ?? false)),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () { Navigator.pop(context); widget.onCancelarAtendimento(); }, child: const Text('Cancelar\nAtendimento', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: podeConfirmar ? Colors.green.shade700 : Colors.grey),
                    onPressed: podeConfirmar ? () {
                      if (_valorRestante > 0.01) { _pagamentos.add({'forma': _formaAtual, 'valor': _valorRestante, 'data': _dataPagamentoAtual}); }
                      Navigator.pop(context);
                      widget.onConfirmar(_pagamentos, _valorTotal, _houveAtraso);
                    } : null,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.check_circle_outline, size: 18, color: Colors.white), SizedBox(width: 6), Expanded(child: Text('Confirmar Recebimento', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white), maxLines: 2))]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
