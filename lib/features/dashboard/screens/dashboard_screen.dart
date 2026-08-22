import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricas = ref.watch(dashboardMetricsProvider);
    final aniversariantesAsync = ref.watch(aniversariantesDoMesProvider);
    final clientesAsync = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);
    
    final hoje = DateTime.now();
    final rotuloData = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(hoje);
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    final clientesPorId = clientesAsync.maybeWhen(
      data: (lista) => {for (final c in lista) c.id: c.nome},
      orElse: () => <String, String>{},
    );

    final todosAgendamentos = todosAgendamentosAsync.value ?? [];

    final receitaHoje = todosAgendamentos.where((a) =>
        a.clienteId != 'BLOQUEIO' &&
        a.status != AgendamentoStatus.cancelado &&
        a.data.year == hoje.year &&
        a.data.month == hoje.month &&
        a.data.day == hoje.day
    ).fold(0.0, (sum, a) => sum + a.valor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
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
          final aniversariantes = aniversariantesAsync.value ?? [];

          // Envolvemos a ListView em um SafeArea para garantir que não 
          // ultrapasse os limites da tela do celular (causando a tela em branco)
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(rotuloData, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Resumo do seu dia de trabalho.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                
                // Em telas muito estreitas (celular pequeno), evitamos que a Grid estoure
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GridView.count(
                      crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: constraints.maxWidth < 360 ? 1.2 : 1.4,
                      children: [
                        _CardMetrica(
                          titulo: 'Atendimentos hoje',
                          valor: '${m.totalAgendamentosHoje}',
                          icone: Icons.calendar_today,
                        ),
                        _CardMetrica(
                          titulo: 'Próximo atendimento',
                          valor: m.proximo != null
                              ? '${m.proximo!.horaInicio} · ${clientesPorId[m.proximo!.clienteId] ?? "—"}'
                              : 'Nenhum',
                          icone: Icons.schedule,
                        ),
                        _CardMetrica(
                          titulo: 'Receita do Dia',
                          valor: moeda.format(receitaHoje),
                          icone: Icons.attach_money,
                          onTap: () => _mostrarDetalhesReceita(context, todosAgendamentos),
                        ),
                        _CardMetrica(
                          titulo: 'Aniversariante do mês',
                          valor: aniversariantes.isEmpty
                              ? 'Nenhum'
                              : aniversariantes.length == 1
                                  ? aniversariantes.first.nome
                                  : '${aniversariantes.length} clientes',
                          icone: Icons.cake_outlined,
                          onTap: aniversariantes.isEmpty
                              ? null
                              : () => _mostrarAniversariantes(context, aniversariantes.map((c) => c.nome).toList()),
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Força a coluna a não crescer infinitamente
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
                          ...m.agendaHoje.map((a) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: SizedBox(width: 48, child: Text(a.horaInicio, style: const TextStyle(fontWeight: FontWeight.w600))),
                                title: Text('${clientesPorId[a.clienteId] ?? (a.clienteId == "BLOQUEIO" ? "Compromisso Pessoal" : "Cliente removido")} — ${a.servico}'),
                                trailing: StatusChip(status: a.status),
                              )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80), // Espaço para não cobrir o final com a barra inferior
              ],
            ),
          );
        },
      ),
    );
  }

  void _mostrarAniversariantes(BuildContext context, List<String> nomes) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aniversariantes do mês'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: nomes.map((n) => ListTile(dense: true, title: Text(n))).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }

  void _mostrarDetalhesReceita(BuildContext context, List<Agendamento> agendamentos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ModalDetalhesReceita(agendamentos: agendamentos),
    );
  }
}

class _CardMetrica extends StatelessWidget {
  const _CardMetrica({required this.titulo, required this.valor, required this.icone, this.onTap});
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
          padding: const EdgeInsets.all(10), // Reduzi um pouco o padding para celulares
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
              const SizedBox(height: 6),
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

// MODAL DE ANÁLISE FINANCEIRA DETALHADA + COMPARATIVO ANUAL MANTIDO INTACTO
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
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');
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
    } else { // Este Mês
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

    for (final a in filtrados) {
      if (a.status == AgendamentoStatus.concluido || a.status == AgendamentoStatus.confirmado) {
        totalConfirmado += a.valor;
      } else if (a.status == AgendamentoStatus.agendado) {
        totalPendente += a.valor;
      }
    }

    final inicioAnoAnterior = DateTime(hoje.year - 1, hoje.month, 1);
    final fimAnoAnterior = DateTime(hoje.year - 1, hoje.month + 1, 0, 23, 59, 59);

    final filtradosAnoAnterior = widget.agendamentos.where((a) =>
      a.clienteId != 'BLOQUEIO' &&
      a.status != AgendamentoStatus.cancelado &&
      a.data.isAfter(inicioAnoAnterior.subtract(const Duration(seconds: 1))) &&
      a.data.isBefore(fimAnoAnterior.add(const Duration(seconds: 1)))
    ).toList();

    double totalAnoAnterior = filtradosAnoAnterior.fold(0.0, (sum, a) => sum + a.valor);
    int qtdAnoAnterior = filtradosAnoAnterior.length;
    double ticketMedioAnoAnterior = qtdAnoAnterior > 0 ? totalAnoAnterior / qtdAnoAnterior : 0.0;

    double totalMesAtual = totalConfirmado + totalPendente;
    int qtdMesAtual = filtrados.length;
    double ticketMedioMesAtual = qtdMesAtual > 0 ? totalMesAtual / qtdMesAtual : 0.0;

    double percentualCrescimento = 0.0;
    if (totalAnoAnterior > 0) {
      percentualCrescimento = ((totalMesAtual - totalAnoAnterior) / totalAnoAnterior) * 100;
    } else if (totalMesAtual > 0) {
      percentualCrescimento = 100.0;
    }

    final agrupaPorDia = <String, Map<String, dynamic>>{};
    for (final a in filtrados) {
      final chaveDia = DateFormat('yyyy-MM-dd').format(a.data);
      if (!agrupaPorDia.containsKey(chaveDia)) {
        agrupaPorDia[chaveDia] = {'data': a.data, 'valor': 0.0, 'qtd': 0};
      }
      agrupaPorDia[chaveDia]!['valor'] += a.valor;
      agrupaPorDia[chaveDia]!['qtd'] += 1;
    }

    final listaDias = agrupaPorDia.values.toList();
    listaDias.sort((a, b) => (b['data'] as DateTime).compareTo(a['data'] as DateTime));

    final nomeMesAtual = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(hoje);
    final nomeMesAnoAnterior = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(inicioAnoAnterior);

    return SafeArea( // Adicionado SafeArea aqui também por segurança do Modal
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
                  ButtonSegment(value: 'vs Ano Ant.', label: Text('vs Ano Ant.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
                selected: {_opcaoFiltro},
                onSelectionChanged: (set) => setState(() => _opcaoFiltro = set.first),
              ),
            ),
            const SizedBox(height: 16),
      
            if (_opcaoFiltro == 'vs Ano Ant.') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Comparativo ($nomeMesAtual)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: percentualCrescimento >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${percentualCrescimento >= 0 ? '+' : ''}${percentualCrescimento.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: percentualCrescimento >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nomeMesAtual, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(moeda.format(totalMesAtual), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                              const SizedBox(height: 4),
                              Text('$qtdMesAtual atendimento(s)', style: const TextStyle(fontSize: 11)),
                              Text('Ticket médio: ${moeda.format(ticketMedioMesAtual)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 60, color: Colors.purple.shade200),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nomeMesAnoAnterior, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(moeda.format(totalAnoAnterior), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                              const SizedBox(height: 4),
                              Text('$qtdAnoAnterior atendimento(s)', style: const TextStyle(fontSize: 11)),
                              Text('Ticket médio: ${moeda.format(ticketMedioAnoAnterior)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
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
                          Text(moeda.format(totalConfirmado), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
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
                          Text(moeda.format(totalPendente), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
      
            Text(
              _opcaoFiltro == 'vs Ano Ant.' ? 'Detalhamento do Mês Atual por Dia' : 'Detalhamento por Dia',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
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
                            DateFormat("EEEE, dd/MM", 'pt_BR').format(dataItem),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text('$qtdItem atendimento(s)', style: const TextStyle(fontSize: 12)),
                          trailing: Text(
                            moeda.format(valorItem),
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
