import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/dashboard_controller.dart';

/// Dashboard do MVP de validação — conforme especificação, mostra apenas:
/// atendimentos de hoje, próximo atendimento, horários vagos e cliente
/// aniversariante do mês.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatarMinutos(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricas = ref.watch(dashboardMetricsProvider);
    final aniversariantesAsync = ref.watch(aniversariantesDoMesProvider);
    final clientesAsync = ref.watch(clienteControllerProvider);
    final hoje = DateTime.now();
    final rotuloData = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(hoje);

    final clientesPorId = clientesAsync.maybeWhen(
      data: (lista) => {for (final c in lista) c.id: c.nome},
      orElse: () => <String, String>{},
    );

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.agendaNovo),
        icon: const Icon(Icons.add),
        label: const Text('Novo Agendamento'),
      ),
      body: metricas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar dashboard: $e')),
        data: (m) {
          final aniversariantes = aniversariantesAsync.value ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(rotuloData, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Resumo do seu dia de trabalho.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
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
                    titulo: 'Horários vagos hoje',
                    valor: _formatarMinutos(m.minutosLivresHoje),
                    icone: Icons.event_available,
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
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Agenda de hoje', style: Theme.of(context).textTheme.titleMedium),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.agenda),
                            child: const Text('Ver agenda completa'),
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
                              title: Text('${clientesPorId[a.clienteId] ?? "Cliente removido"} — ${a.servico}'),
                              trailing: StatusChip(status: a.status),
                            )),
                    ],
                  ),
                ),
              ),
            ],
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(titulo, style: Theme.of(context).textTheme.bodySmall),
              Text(
                valor,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
