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

// MOTOR DE INTELIGÊNCIA: Gera dicas baseadas na profissão
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
  String _filtroPlanoVoo = 'Hoje';

  @override
  Widget build(BuildContext context) {
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
    
    // NOTIFICAÇÕES (Aniversários e Inativas)
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

    // CÁLCULOS COMPARATIVOS DA IA
    final inicioSemanaAtual = hoje.subtract(Duration(days: hoje.weekday % 7));
    final inicioSemanaAnterior = inicioSemanaAtual.subtract(const Duration(days: 7));
    
    double receitaSemanaAtual = 0;
    double receitaSemanaAnterior = 0;
    int atendimentosSemanaAtual = 0;
    int atendimentosSemanaAnterior = 0;

    for (final a in todosAgendamentos) {
      if (a.clienteId == 'BLOQUEIO' || a.status == AgendamentoStatus.cancelado) continue;
      
      if (a.data.isAfter(inicioSemanaAtual.subtract(const Duration(seconds: 1)))) {
        receitaSemanaAtual += a.valor;
        atendimentosSemanaAtual++;
      } else if (a.data.isAfter(inicioSemanaAnterior.subtract(const Duration(seconds: 1))) && 
                 a.data.isBefore(inicioSemanaAtual)) {
        receitaSemanaAnterior += a.valor;
        atendimentosSemanaAnterior++;
      }
    }

    final ticketMedioAtual = atendimentosSemanaAtual > 0 ? receitaSemanaAtual / atendimentosSemanaAtual : 0.0;
    final ticketMedioAnterior = atendimentosSemanaAnterior > 0 ? receitaSemanaAnterior / atendimentosSemanaAnterior : 0.0;

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
          // Filtragem da lista do "Plano de Voo"
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

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(rotuloData, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Painel Estratégico de Desempenho.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              
              // GRID DE MÉTRICAS COMPARATIVAS
              GridView.count(
                crossAxisCount: larguraTela > 800 ? 4 : (larguraTela < 360 ? 1 : 2),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: larguraTela < 360 ? 2.5 : 1.4,
                children: [
                  _CardMetricaInteligente(
                    titulo: 'Faturamento (Semana)',
                    valor: formatarMoeda(receitaSemanaAtual),
                    icone: Icons.account_balance_wallet,
                    valorAnterior: receitaSemanaAnterior,
                    valorAtual: receitaSemanaAtual,
                    ehMoeda: true,
                    onTap: () => _mostrarDetalhesReceita(context, todosAgendamentos),
                  ),
                  _CardMetricaInteligente(
                    titulo: 'Ticket Médio (Semana)',
                    valor: formatarMoeda(ticketMedioAtual),
                    icone: Icons.monetization_on,
                    valorAnterior: ticketMedioAnterior,
                    valorAtual: ticketMedioAtual,
                    ehMoeda: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 1. LISTA ORIGINAL: AGENDA DE HOJE
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
              const SizedBox(height: 16),
              
              // 2. PLANO DE VOO (DENTRO DO CARD EXPANSÍVEL)
              Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: const Text('Plano de Voo Estratégico', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Dicas da IA e Checklist de Vendas'),
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade50,
                    child: const Icon(Icons.psychology, color: Colors.purple),
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Hoje', label: Text('Hoje', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: 'Amanhã', label: Text('Amanhã', style: TextStyle(fontSize: 11))),
                          ],
                          selected: {_filtroPlanoVoo},
                          onSelectionChanged: (set) => setState(() => _filtroPlanoVoo = set.first),
                          style: SegmentedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (agendaFiltro.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('Nenhum agendamento para este dia.'),
                      ))
                    else
                      ...agendaFiltro.map((a) {
                        final isBloqueio = a.clienteId == "BLOQUEIO";
                        final cliente = isBloqueio ? null : clientesPorId[a.clienteId];
                        final nomeCliente = isBloqueio ? "Compromisso Pessoal" : (cliente?.nome ?? "Cliente removido");
                        final profissao = cliente?.profissao?.isNotEmpty == true ? cliente!.profissao! : 'Profissão não informada';
                        
                        if (isBloqueio) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              tileColor: Colors.grey.shade50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              leading: SizedBox(width: 48, child: Text(a.horaInicio, style: const TextStyle(fontWeight: FontWeight.w600))),
                              title: Text(nomeCliente, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              subtitle: Text(a.servico),
                              trailing: StatusChip(status: a.status),
                            ),
                          );
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.purple.shade100, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: Text(a.horaInicio, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(nomeCliente, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        Text('$profissao • ${a.servico}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                      ],
                                    ),
                                  ),
                                  StatusChip(status: a.status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // DICA IA
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.tips_and_updates, color: Colors.amber, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        gerarDicaEstrategica(cliente, a),
                                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // CHECKLIST DE ATENDIMENTO
                              Text('Checklist Padrão Ouro:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                              const SizedBox(height: 4),
                              const _ChecklistItem(texto: 'Chamar pelo nome e consultar restrições/observações.'),
                              const _ChecklistItem(texto: 'Oferecer um serviço complementar focado na necessidade dela.'),
                              const _ChecklistItem(texto: 'Agendar o retorno antes dela sair da cadeira.'),
                            ],
                          ),
                        );
                      }),
                  ],
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

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_box_outline_blank, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: Colors.grey.shade800))),
        ],
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
    this.onTap,
  });
  
  final String titulo;
  final String valor;
  final IconData icone;
  final double valorAnterior;
  final double valorAtual;
  final bool ehMoeda;
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
              const SizedBox(height: 8),
              Text(titulo, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                valor,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
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
