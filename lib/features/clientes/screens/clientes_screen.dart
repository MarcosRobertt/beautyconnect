import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../agenda/services/inteligencia_service.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';
import '../widgets/cliente_card.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _buscaController = TextEditingController();

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _confirmarExclusao(BuildContext context, WidgetRef ref, String id) async {
    final todosAgendamentos = await ref.read(agendamentoControllerProvider.notifier).todos();
    final possuiAgendamentos = todosAgendamentos.any((a) => a.clienteId == id);

    if (possuiAgendamentos) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Não é possível excluir'),
          content: const Text(
            'Este cliente possui agendamentos vinculados. '
            'Cancele ou reatribua esses agendamentos antes de excluir.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cliente'),
        content: const Text('Tem certeza que deseja excluir? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar == true) {
      await ref.read(clienteControllerProvider.notifier).excluir(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(clienteControllerProvider);
    final todosAgendamentosAsync = ref.watch(todosAgendamentosProvider);

    return DefaultTabController(
      length: 4, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestão de Clientes'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.purple,
            indicatorColor: Colors.purple,
            tabs: [
              Tab(text: 'Ativos'),
              Tab(text: 'Recorrência (15d+)'),
              Tab(text: 'Inativos (30d+)'),
              Tab(icon: Icon(Icons.star, size: 16), text: 'Top Clientes'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.clienteNovo),
          icon: const Icon(Icons.add),
          label: const Text('Novo Cliente'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _buscaController,
                decoration: const InputDecoration(
                  hintText: 'Pesquisar cliente por nome ou WhatsApp...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (texto) => ref.read(clienteControllerProvider.notifier).pesquisar(texto),
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: estado.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
                  data: (lista) {
                    if (lista.isEmpty) {
                      return const Center(child: Text('Nenhum cliente encontrado.'));
                    }
                    
                    final todosAgendamentos = todosAgendamentosAsync.value ?? [];
                    final hoje = DateTime.now();
                    
                    final ativas = <Cliente>[];
                    final recorrencia = <Cliente>[];
                    final inativas = <Cliente>[];

                    final stats = <String, Map<String, dynamic>>{};

                    for (final c in lista) {
                      final agDoCliente = todosAgendamentos.where((a) => a.clienteId == c.id).toList();
                      final passados = agDoCliente.where((a) => 
                          a.status == AgendamentoStatus.concluido && 
                          a.data.isBefore(hoje.add(const Duration(days: 1)))).toList();
                      final futuros = agDoCliente.where((a) => 
                          (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado) && 
                          a.data.isAfter(hoje.subtract(const Duration(days: 1)))).toList();

                      passados.sort((a, b) => b.data.compareTo(a.data));
                      int diasAusente = passados.isNotEmpty 
                        ? hoje.difference(passados.first.data).inDays 
                        : hoje.difference(c.createdAt).inDays;

                      stats[c.id] = {'dias': diasAusente};

                      if (futuros.isNotEmpty || diasAusente <= 15) {
                        ativas.add(c);
                      } else if (diasAusente <= 30) {
                        recorrencia.add(c);
                      } else {
                        inativas.add(c);
                      }
                    }

                    ativas.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
                    recorrencia.sort((a, b) => stats[b.id]!['dias'].compareTo(stats[a.id]!['dias']));
                    inativas.sort((a, b) => stats[b.id]!['dias'].compareTo(stats[a.id]!['dias']));

                    Widget buildGrid(List<Cliente> listaClientes, String emptyMsg) {
                      if (listaClientes.isEmpty) return Center(child: Text(emptyMsg, style: TextStyle(color: Colors.grey.shade600)));
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisExtent: 210,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: listaClientes.length,
                        itemBuilder: (context, i) {
                          final cliente = listaClientes[i];
                          final ags = todosAgendamentos.where((a) => a.clienteId == cliente.id).toList();
                          return ClienteCard(
                            cliente: cliente,
                            inteligencia: InteligenciaService.calcularParaCliente(ags),
                            onEditar: () => context.push('${AppRoutes.clienteEditar}/${cliente.id}'),
                            onExcluir: () => _confirmarExclusao(context, ref, cliente.id),
                            onHistorico: () => context.push('${AppRoutes.clienteHistorico}/${cliente.id}'),
                          );
                        },
                      );
                    }

                    return TabBarView(
                      children: [
                        buildGrid(ativas, 'Nenhuma cliente ativa no momento.'),
                        buildGrid(recorrencia, 'Nenhuma cliente em risco de evasão (15 a 30 dias).'),
                        buildGrid(inativas, 'Nenhuma cliente inativa. Excelente retenção!'),
                        // NOVA ABA: TOP CLIENTES (Tabela igual ao print)
                        _TopClientesView(clientes: lista, agendamentos: todosAgendamentos),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// WIDGET DO RANKING: TOP CLIENTES
// =========================================================================
class _TopClientesView extends StatefulWidget {
  const _TopClientesView({required this.clientes, required this.agendamentos});
  final List<Cliente> clientes;
  final List<Agendamento> agendamentos;

  @override
  State<_TopClientesView> createState() => _TopClientesViewState();
}

class _TopClientesViewState extends State<_TopClientesView> {
  String _periodo = 'Últimos 12 meses';
  String _tipo = 'Receita';

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final hoje = DateTime.now();

    // 1. Filtro de Data
    DateTime dataCorte;
    switch (_periodo) {
      case 'Últimos 30 dias': dataCorte = hoje.subtract(const Duration(days: 30)); break;
      case 'Últimos 6 meses': dataCorte = hoje.subtract(const Duration(days: 180)); break;
      case 'Últimos 12 meses': dataCorte = hoje.subtract(const Duration(days: 365)); break;
      default: dataCorte = DateTime(2000); // Sempre
    }

    final agendamentosValidos = widget.agendamentos.where((a) =>
        a.status == AgendamentoStatus.concluido && a.data.isAfter(dataCorte)).toList();

    // 2. Cálculo dos Dados (Receita e Frequência)
    final stats = <String, Map<String, dynamic>>{};
    for (final c in widget.clientes) {
      stats[c.id] = {'receita': 0.0, 'frequencia': 0};
    }

    for (final a in agendamentosValidos) {
      if (stats.containsKey(a.clienteId)) {
        stats[a.clienteId]!['receita'] += a.valor;
        stats[a.clienteId]!['frequencia'] += 1;
      }
    }

    // 3. Ordenação
    final clientesOrdenados = List<Cliente>.from(widget.clientes);
    clientesOrdenados.sort((a, b) {
      if (_tipo == 'Receita') {
        int comp = stats[b.id]!['receita'].compareTo(stats[a.id]!['receita']);
        if (comp != 0) return comp;
        return stats[b.id]!['frequencia'].compareTo(stats[a.id]!['frequencia']);
      } else {
        int comp = stats[b.id]!['frequencia'].compareTo(stats[a.id]!['frequencia']);
        if (comp != 0) return comp;
        return stats[b.id]!['receita'].compareTo(stats[a.id]!['receita']);
      }
    });

    // Remove quem tem valor zero para não poluir o ranking
    clientesOrdenados.removeWhere((c) => stats[c.id]![_tipo.toLowerCase()] == 0);
    
    // Pega as 30 melhores
    final top30 = clientesOrdenados.take(30).toList();
    
    // KPI Novos Clientes (Cadastradas no período selecionado)
    final novosClientes = widget.clientes.where((c) => c.createdAt.isAfter(dataCorte)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KPIs (Cartões Superiores)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text('Total de Clientes', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${widget.clientes.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              Column(
                children: [
                  const Text('Novos Clientes', style: TextStyle(color: Colors.purple, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('$novosClientes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filtros (Período e Tipo)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _periodo,
                decoration: const InputDecoration(labelText: 'Período', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: ['Últimos 30 dias', 'Últimos 6 meses', 'Últimos 12 meses', 'Sempre'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _periodo = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: ['Receita', 'Frequência'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text('Rank top 30 melhores clientes por ${_tipo.toLowerCase()}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 8),

        // Cabeçalho da Tabela
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              SizedBox(width: 30, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade900))),
              Expanded(child: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade900))),
              SizedBox(width: 90, child: Text(_tipo, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade900))),
            ],
          ),
        ),

        // Lista do Ranking
        Expanded(
          child: top30.isEmpty
            ? Center(child: Text('Nenhum agendamento concluído neste período.', style: TextStyle(color: Colors.grey.shade500)))
            : ListView.separated(
                padding: const EdgeInsets.only(top: 8),
                itemCount: top30.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, i) {
                  final c = top30[i];
                  final val = stats[c.id]![_tipo.toLowerCase()];
                  final displayVal = _tipo == 'Receita' ? moeda.format(val) : '$val visitas';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Row(
                      children: [
                        SizedBox(width: 30, child: Text('${i+1}º', style: const TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(
                          child: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                        ),
                        SizedBox(
                          width: 90, 
                          child: Text(displayVal, textAlign: TextAlign.right, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
