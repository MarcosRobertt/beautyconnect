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

String gerarDicaEstrategica(Cliente? cliente, Agendamento agendamento) {
  if (cliente == null || cliente.id == 'BLOQUEIO') return 'Dica IA: Confirme o horário com antecedência para evitar buracos na agenda.';
  
  final profissao = cliente.profissao?.toLowerCase() ?? '';
  
  if (profissao.contains('enfermeira') || profissao.contains('médica') || profissao.contains('saúde') || profissao.contains('dentista')) {
    return 'Dica IA: Profissionais de saúde sofrem com ressecamento pelas luvas/lavagem. Ofereça um Spa de Mãos com hidratação profunda (+R\$ 25).';
  } else if (profissao.contains('advogada') || profissao.contains('executiva') || profissao.contains('bancária') || profissao.contains('empresária')) {
    return 'Dica IA: Imagem impecável é crucial e o tempo é curto. Ofereça blindagem ou esmaltação em gel para garantir durabilidade sem descascar.';
  } else if (profissao.contains('professora') || profissao.contains('vendedora') || profissao.contains('influenciadora')) {
    return 'Dica IA: Rotina exposta! Sugira cores tendências, Nail Arts ou produtos home care como canetas hidratantes de cutícula para levar na bolsa.';
  } else if (profissao.contains('estudante') || profissao.contains('recepcionista')) {
    return 'Dica IA: Foco em custo-benefício. Sugira pacotes ou combos mensais de pé e mão para garantir a recorrência.';
  }
  
  if (cliente.observacoes.isNotEmpty) {
    return 'Dica IA: Revise as observações da cliente. Use detalhes de conversas anteriores para criar conexão e oferecer um serviço complementar ao "${agendamento.servico}".';
  }
  
  return 'Dica IA: Descubra a profissão desta cliente hoje! Atualize o cadastro e, no próximo atendimento, a IA trará uma estratégia de venda exclusiva.';
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
    // 🛡️ A PONTE: Obriga o Dashboard a escutar as alterações feitas na Agenda!
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
                      child: Text(
                        '$totalNotificacoes',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
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
          List<Agendamento> agendaFiltro = [];
          if (_filtroPlanoVoo == 'Hoje') {
            agendaFiltro = m.agendaHoje;
          } else if (_filtroPlanoVoo == 'Amanhã') {
            final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
            agendaFiltro = todosAgendamentos.where((a) =>
              a.data.year == amanha.year && a.data.month == amanha.month && a.data.day == amanha.day
            ).toList();
            agendaFiltro.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
          }

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
                childAspectRatio: larguraTela < 360 ? 2.5 : 1.4,
                children: [
                  _CardMetricaOriginal(
                    titulo: 'Atendimentos hoje',
                    valor: '$totalAtendimentosReaisHoje',
                    icone: Icons.calendar_today,
                  ),
                  _CardMetricaOriginal(
                    titulo: 'Próximo atendimento',
                    valor: m.proximo != null
                        ? '${m.proximo!.horaInicio} · ${clientesPorId[m.proximo!.clienteId]?.nome ?? "—"}'
                        : 'Nenhum',
                    icone: Icons.schedule,
                  ),
                  _CardMetricaInteligente(
                    titulo: 'Faturamento',
                    valor: formatarMoeda(valFatAtual),
                    icone: Icons.account_balance_wallet,
                    valorAnterior: valFatAnt,
                    valorAtual: valFatAtual,
                    ehMoeda: true,
                    periodoSelecionado: _periodoFaturamento,
                    onPeriodoChanged: (val) => setState(() => _periodoFaturamento = val!),
                    onTap: () => _mostrarDetalhesReceita(context, todosAgendamentos),
                  ),
                  _CardMetricaInteligente(
                    titulo: 'Ticket Médio',
                    valor: formatarMoeda(valTMAtual),
                    icone: Icons.monetization_on,
                    valorAnterior: valTMAnt,
                    valorAtual: valTMAtual,
                    ehMoeda: true,
                    periodoSelecionado: _periodoTM,
                    onPeriodoChanged: (val) => setState(() => _periodoTM = val!),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (comandasPendentes.isNotEmpty) ...[
                Card(
                  color: Colors.orange.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.orange.shade300, width: 1.5),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
                    title: Text('${comandasPendentes.length} Comanda(s) pendente(s)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 14)),
                    subtitle: Text('De dias anteriores. Feche para registrar o faturamento.', style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
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
                          TextButton(
                            onPressed: () => context.go(AppRoutes.agenda),
                            child: const Text('Ver completa'),
                          ),
                        ],
                      ),
                      if (m.agendaHoje.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Nenhum agendamento para hoje.')),
                        )
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

  void _mostrarCentralNotificacoes(
    BuildContext context,
    List<Cliente> aniversariantes,
    List<Map<String, dynamic>> inativas,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _ModalCentralNotificacoes(aniversariantes: aniversariantes, inativas: inativas),
    );
  }

  void _mostrarDetalhesReceita(BuildContext context, List<Agendamento> agendamentos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _ModalDetalhesReceita(agendamentos: agendamentos),
    );
  }
}

class _ModalComandasPendentes extends ConsumerWidget {
  const _ModalComandasPendentes();

  void _abrirModalFechamento(
    BuildContext context,
    WidgetRef ref,
    Agendamento agendamento,
    String nomeCliente,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ModalFecharComandaDashboard(
        agendamento: agendamento,
        nomeCliente: nomeCliente,
        // 🛡️ MITIGAÇÃO: Função async para esperar o salvamento e forçar a atualização (F5)
        onConfirmar: (pagamentos, dataPagamento, valorFinal, houveAtraso) async {
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
            final listaDetalhes = pagamentos.map((p) => '${(p['forma'] as FormaPagamento).rotulo}: ${formataMoeda(p['valor'] as double)}').join(' | ');
            final dataBaixaStr = '${dataPagamento.day.toString().padLeft(2, '0')}/${dataPagamento.month.toString().padLeft(2, '0')}/${dataPagamento.year}';
            
            detalhePagamentoStr = '[Baixa Financeira: $dataBaixaStr -> $listaDetalhes]';
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

          // 🛡️ Salva aguardando e invalida os caches do sistema!
          await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
          ref.invalidate(todosAgendamentosProvider);
          ref.invalidate(dashboardMetricsProvider);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Comanda fechada e sistema sincronizado!'), backgroundColor: Colors.green)
            );
          }
        },
        onCancelarAtendimento: () async {
          final atualizado = agendamento.copyWith(
            status: AgendamentoStatus.cancelado,
            observacao: agendamento.observacao.isEmpty ? '[Cancelado pelo Dashboard]' : '${agendamento.observacao} | [Cancelado pelo Dashboard]',
          );
          
          // 🛡️ Salva aguardando e invalida os caches do sistema!
          await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
          ref.invalidate(todosAgendamentosProvider);
          ref.invalidate(dashboardMetricsProvider);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Agendamento cancelado!'), backgroundColor: Colors.blue)
            );
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
            const Text('Feche as comandas abaixo para que o valor seja contabilizado no seu faturamento mensal.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                                      child: Text('📅 ${diaEntry.key}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    ...diaEntry.value.map((a) {
                                      final nomeCliente = clientesPorId[a.clienteId]?.nome ?? "Cliente não encontrado";
                                      return ListTile(
                                        title: Text('${a.horaInicio} · $nomeCliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        subtitle: Text('${a.servico} — ${formatarMoeda(a.valor)}', style: const TextStyle(fontSize: 12)),
                                        trailing: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.purple,
                                            side: const BorderSide(color: Colors.purple),
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                          ),
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
  final void Function(List<Map<String, dynamic>> pagamentos, DateTime dataPagamento, double valorFinal, bool houveAtraso) onConfirmar;
  final VoidCallback onCancelarAtendimento;

  @override
  State<_ModalFecharComandaDashboard> createState() => _ModalFecharComandaDashboardState();
}

class _ModalFecharComandaDashboardState extends State<_ModalFecharComandaDashboard> {
  late double _valorTotal;
  bool _houveAtraso = false;
  
  DateTime _dataPagamento = DateTime.now();
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
        });
        _valorParcialController.text = _valorRestante.toStringAsFixed(2).replaceAll('.', ',');
      });
    }
  }

  void _removerPagamento(int index) {
    setState(() {
      _pagamentos.removeAt(index);
      _valorParcialController.text = _valorRestante.toStringAsFixed(2).replaceAll('.', ',');
    });
  }

  @override
  Widget build(BuildContext context) {
    final valorPendente = _valorRestante;
    final podeConfirmar = valorPendente <= 0.01;

    return Container(
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Fechar Comanda — ${widget.nomeCliente}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.agendamento.servico} — R\$ ${_valorTotal.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Divider(height: 32),

            const Text('Data do Pagamento (Baixa):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dataPagamento,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _dataPagamento = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text('${_dataPagamento.day.toString().padLeft(2, '0')}/${_dataPagamento.month.toString().padLeft(2, '0')}/${_dataPagamento.year}', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Pagamentos Adicionados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (_pagamentos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhum pagamento registrado ainda.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ..._pagamentos.asMap().entries.map((entry) {
              final index = entry.key;
              final p = entry.value;
              final forma = p['forma'] as FormaPagamento;
              final valor = p['valor'] as double;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                title: Text(forma.rotulo),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _removerPagamento(index),
                    ),
                  ],
                ),
              );
            }),

            if (valorPendente > 0.01) ...[
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Falta Receber:', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                    Text('R\$ ${valorPendente.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<FormaPagamento>(
                      value: _formaAtual,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                      items: FormaPagamento.values.where((f) => f != FormaPagamento.pendente).map((f) {
                        return DropdownMenuItem(value: f, child: Text(f.rotulo, style: const TextStyle(fontSize: 12)));
                      }).toList(),
                      onChanged: (v) => setState(() => _formaAtual = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _valorParcialController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(prefixText: 'R\$ ', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: FilledButton(
                      style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: _adicionarPagamento,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            CheckboxListTile(
              value: _houveAtraso,
              contentPadding: EdgeInsets.zero,
              title: const Text('Cliente chegou atrasada?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: const Text('Registra o atraso no histórico para métricas.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) => setState(() => _houveAtraso = val ?? false),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context); 
                      widget.onCancelarAtendimento(); 
                    },
                    child: const Text('Cancelar\nAtendimento', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: podeConfirmar ? null : Colors.grey,
                    ),
                    onPressed: podeConfirmar ? () {
                      if (_valorRestante > 0.01) {
                        _pagamentos.add({
                          'forma': _formaAtual,
                          'valor': _valorRestante, 
                        });
                      }
                      
                      Navigator.pop(context);
                      widget.onConfirmar(_pagamentos, _dataPagamento, _valorTotal, _houveAtraso);
                    } : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Confirmar Recebimento', textAlign: TextAlign.center, style: TextStyle(fontSize: 12), maxLines: 2),
                        ),
                      ],
                    ),
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

class _CardMetricaOriginal extends StatelessWidget {
  const _CardMetricaOriginal({required this.titulo, required this.valor, required this.icone, this.onTap});
  final String titulo;
  final String valor;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  if (onTap != null)
                    const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text(titulo, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                valor,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMetricaInteligente extends StatelessWidget {
  const _CardMetricaInteligente({
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.valorAnterior,
    required this.valorAtual,
    this.ehMoeda = false,
    this.periodoSelecionado,
    this.onPeriodoChanged,
    this.onTap,
  });
  
  final String titulo;
  final String valor;
  final IconData icone;
  final double valorAnterior;
  final double valorAtual;
  final bool ehMoeda;
  final String? periodoSelecionado;
  final ValueChanged<String?>? onPeriodoChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color corBadge = Colors.grey;
    IconData iconeSeta = Icons.remove;
    String txtEvolucao = 'Sem base';

    if (valorAnterior > 0) {
      final variacao = ((valorAtual - valorAnterior) / valorAnterior) * 100;
      txtEvolucao = '${variacao > 0 ? '+' : ''}${variacao.toStringAsFixed(1)}%';
      
      if (variacao >= 10) {
        corBadge = Colors.green;
        iconeSeta = Icons.trending_up;
      } else if (variacao <= -5) {
        corBadge = Colors.red;
        iconeSeta = Icons.trending_down;
      } else {
        corBadge = Colors.amber.shade700;
        iconeSeta = Icons.trending_flat;
      }
    } else if (valorAtual > 0) {
      corBadge = Colors.green;
      iconeSeta = Icons.trending_up;
      txtEvolucao = 'Novo!';
    }

    return Card(
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
                  if (periodoSelecionado != null)
                    SizedBox(
                      height: 20,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true,
                          value: periodoSelecionado,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                          items: ['Hoje', 'Semana', 'Mês'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: onPeriodoChanged,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(titulo, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      valor,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (valorAnterior > 0 || valorAtual > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: corBadge.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: corBadge.withOpacity(0.3))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconeSeta, size: 10, color: corBadge),
                      const SizedBox(width: 2),
                      Text(txtEvolucao, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: corBadge)),
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

class _ModalCentralNotificacoes extends StatelessWidget {
  const _ModalCentralNotificacoes({
    required this.aniversariantes,
    required this.inativas,
  });

  final List<Cliente> aniversariantes;
  final List<Map<String, dynamic>> inativas;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Central de Lembretes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  Tab(text: 'Aniversários (${aniversariantes.length})'),
                  Tab(text: 'Inativas (${inativas.length})'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    aniversariantes.isEmpty
                        ? const Center(child: Text('Nenhum aniversário nos próximos 15 dias.'))
                        : ListView.separated(
                            itemCount: aniversariantes.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final cliente = aniversariantes[index];
                              final dia = cliente.aniversario?.day.toString().padLeft(2, '0');
                              final mes = cliente.aniversario?.month.toString().padLeft(2, '0');

                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  child: Icon(Icons.cake, color: Colors.white, size: 20),
                                ),
                                title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Aniversário em: $dia/$mes'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  tooltip: 'Enviar Parabéns no WhatsApp',
                                  onPressed: () {
                                    final agendamentoNiver = Agendamento(
                                      id: 'niver',
                                      clienteId: cliente.id,
                                      data: DateTime.now(),
                                      horaInicio: '🎉',
                                      horaFim: '🎂',
                                      duracaoMinutos: 0,
                                      servico: 'Especial Aniversário',
                                      valor: 0.0,
                                      status: AgendamentoStatus.agendado,
                                      observacao: 'Feliz Aniversário!',
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                    );
                                    WhatsAppService.enviarConfirmacao(
                                      telefone: cliente.telefone,
                                      nomeCliente: cliente.nome,
                                      agendamento: agendamentoNiver,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                    inativas.isEmpty
                        ? const Center(child: Text('Nenhuma cliente inativa encontrada.'))
                        : ListView.separated(
                            itemCount: inativas.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = inativas[index];
                              final cliente = item['cliente'] as Cliente;
                              final dias = item['dias'] as int;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                                ),
                                title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Sem agendar há $dias dias'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  tooltip: 'Convidar no WhatsApp',
                                  onPressed: () {
                                    final agendamentoRetorno = Agendamento(
                                      id: 'retorno',
                                      clienteId: cliente.id,
                                      data: DateTime.now(),
                                      horaInicio: '💅',
                                      horaFim: '✨',
                                      duracaoMinutos: 0,
                                      servico: 'Retorno / Manutenção',
                                      valor: 0.0,
                                      status: AgendamentoStatus.agendado,
                                      observacao: 'Sentimos sua falta!',
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                    );
                                    WhatsAppService.enviarConfirmacao(
                                      telefone: cliente.telefone,
                                      nomeCliente: cliente.nome,
                                      agendamento: agendamentoRetorno,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
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
    final hoje = DateTime.now();
    DateTime inicio;
    DateTime fim;

    if (_opcaoFiltro == 'Hoje') {
      inicio = DateTime(hoje.year, hoje.month, hoje.day);
      fim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
    } else if (_opcaoFiltro == 'Esta Semana') {
      final inicioSemana = hoje.subtract(Duration(days: hoje.weekday % 7));
      inicio = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
      fim = inicio.add(const Duration(days: 7));
    } else if (_opcaoFiltro == 'Mês Anterior') {
      inicio = DateTime(hoje.year, hoje.month - 1, 1);
      fim = DateTime(hoje.year, hoje.month, 0, 23, 59, 59);
    } else if (_opcaoFiltro == 'vs Ano Ant.') {
      inicio = DateTime(hoje.year, hoje.month, 1);
      fim = DateTime(hoje.year, hoje.month + 1, 0, 23, 59, 59);
    } else { 
      inicio = DateTime(hoje.year, hoje.month, 1);
      fim = DateTime(hoje.year, hoje.month + 1, 0, 23, 59, 59);
    }

    final filtrados = widget.agendamentos.where((a) =>
      a.clienteId != 'BLOQUEIO' &&
      a.status != AgendamentoStatus.cancelado &&
      a.data.isAfter(inicio.subtract(const Duration(seconds: 1))) &&
      a.data.isBefore(fim.add(const Duration(seconds: 1)))
    ).toList();

    double totalConfirmado = 0.0;
    double totalPendente = 0.0;
    final totalPorForma = <FormaPagamento, double>{ for (var f in FormaPagamento.values) f: 0.0 };

    for (final a in filtrados) {
      if (a.status == AgendamentoStatus.concluido || a.status == AgendamentoStatus.confirmado) {
        totalConfirmado += a.valor;
      } else if (a.status == AgendamentoStatus.agendado) {
        totalPendente += a.valor;
      }
      final forma = a.formaPagamento ?? FormaPagamento.pendente;
      totalPorForma[forma] = (totalPorForma[forma] ?? 0.0) + a.valor;
    }

    final agrupaPorDia = <String, Map<String, dynamic>>{};
    for (final a in filtrados) {
      final chaveDia = '${a.data.year}-${a.data.month.toString().padLeft(2, '0')}-${a.data.day.toString().padLeft(2, '0')}';
      if (!agrupaPorDia.containsKey(chaveDia)) {
        agrupaPorDia[chaveDia] = {'data': a.data, 'valor': 0.0, 'qtd': 0};
      }
      agrupaPorDia[chaveDia]!['valor'] += a.valor;
      agrupaPorDia[chaveDia]!['qtd'] += 1;
    }

    final listaDias = agrupaPorDia.values.toList();
    listaDias.sort((a, b) => (b['data'] as DateTime).compareTo(a['data'] as DateTime));

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
                const Text('Análise de Receita', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Hoje', label: Text('Hoje', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'Esta Semana', label: Text('Semana', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'Este Mês', label: Text('Este Mês', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'Mês Anterior', label: Text('Mês Ant.', style: TextStyle(fontSize: 11))),
                ],
                selected: {_opcaoFiltro},
                onSelectionChanged: (set) => setState(() => _opcaoFiltro = set.first),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Realizado / Confirmado', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(formatarMoeda(totalConfirmado), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Previsto (Aguardando)', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(formatarMoeda(totalPendente), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Formas de Pagamento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: FormaPagamento.values.map((forma) {
                  final valorForma = totalPorForma[forma] ?? 0.0;
                  if (valorForma == 0.0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(forma.rotulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Text(
                          formatarMoeda(valorForma),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Detalhamento por Dia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Expanded(
              child: listaDias.isEmpty
                  ? const Center(child: Text('Nenhum faturamento registrado para este período.'))
                  : ListView.separated(
                      itemCount: listaDias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = listaDias[i];
                        final dataItem = item['data'] as DateTime;
                        final valorItem = item['valor'] as double;
                        final qtdItem = item['qtd'] as int;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${dataItem.day.toString().padLeft(2, '0')}/${dataItem.month.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text('$qtdItem atendimento(s)', style: const TextStyle(fontSize: 12)),
                          trailing: Text(
                            formatarMoeda(valorItem),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
