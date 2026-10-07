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
import '../../configuracoes/screens/metas_screen.dart'; // 🎯 Conexão com o Motor de Metas

String formatarMoeda(double valor) {
  return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
}

String formatarData(DateTime data) {
  final meses = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  final diasSemana = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
  return '${diasSemana[data.weekday - 1]}, ${data.day} de${meses[data.month - 1]}';
}

String _formatarMesAno(DateTime data) {
  final meses = ['JANEIRO', 'FEVEREIRO', 'MARÇO', 'ABRIL', 'MAIO', 'JUNHO', 'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'];
  return '${meses[data.month - 1]} DE${data.year}';
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

  @override
  Widget build(BuildContext context) {
    ref.watch(agendamentoControllerProvider);

    // 🧠 Consulta em Tempo Real as Metas Configuradas para este Mês
    final metasNuvem = ref.watch(metasControllerProvider).value ?? {};
    final hoje = DateTime.now();
    final chaveMesAtual = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}';
    
    // Se não tiver meta configurada, assume um padrão de sobrevivência leve
    final metaAtiva = metasNuvem[chaveMesAtual] ?? MetaMensal(
      faturamentoMensal: 6000, faturamentoDiario: 250, 
      atendimentosMensal: 80, atendimentosDiario: 4
    );

    final int metaAtendimentosDia = metaAtiva.atendimentosDiario > 0 ? metaAtiva.atendimentosDiario : 1; 
    final double metaFaturamentoDia = metaAtiva.faturamentoDiario > 0 ? metaAtiva.faturamentoDiario : 1.0;
    final double metaFaturamentoSemana = metaFaturamentoDia * 5;
    final double metaFaturamentoMes = metaAtiva.faturamentoMensal > 0 ? metaAtiva.faturamentoMensal : (metaFaturamentoDia * 20);

    final metricas = ref.watch(dashboardMetricsProvider);
    final clientesAsync = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    
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
        : (_periodoFaturamento == 'Semana' ? metaFaturamentoSemana : metaFaturamentoMes);

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
                            title: Text('$nomeCliente —${a.servico}'),
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
      final variacao = ((valorAtual - valorAnterior) / valorAnterior) * 1
