import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';
import 'historico_cliente_screen.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  void _abrirHistorico(BuildContext context, String clienteId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoricoClienteScreen(clienteId: clienteId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final agendamentosAsync = ref.watch(todosAgendamentosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Ativos'),
            Tab(text: 'Recorrência'),
            Tab(text: 'Inativos'),
            Tab(text: 'Top Clientes'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.clienteNovo),
        child: const Icon(Icons.add),
      ),
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar clientes: $e')),
        data: (clientes) {
          final agendamentos = agendamentosAsync.value ?? [];
          final textoBusca = _buscaController.text.trim().toLowerCase();

          final filtrados = clientes.where((c) {
            if (textoBusca.isEmpty) return true;
            return c.nome.toLowerCase().contains(textoBusca) ||
                c.telefone.contains(textoBusca);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _buscaController,
                  decoration: InputDecoration(
                    labelText: 'Buscar cliente',
                    hintText: 'Nome ou telefone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: textoBusca.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _buscaController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _construirListaAtivos(filtrados, agendamentos),
                    _construirListaRecorrencia(filtrados, agendamentos),
                    _construirListaInativos(filtrados, agendamentos),
                    _construirListaTopClientes(filtrados, agendamentos),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _construirListaAtivos(
      List<Cliente> clientes, List<Agendamento> agendamentos) {
    final hoje = DateTime.now();
    final ativos = clientes.where((c) {
      final agsCliente = agendamentos.where((a) =>
          a.clienteId == c.id && a.status != AgendamentoStatus.cancelado);
      if (agsCliente.isEmpty) return true;
      final ultimaData = agsCliente
          .map((a) => a.data)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return hoje.difference(ultimaData).inDays <= 30;
    }).toList();

    return _construirListaPadrao(ativos);
  }

  Widget _construirListaRecorrencia(
      List<Cliente> clientes, List<Agendamento> agendamentos) {
    final hoje = DateTime.now();
    final recorrentes = clientes.where((c) {
      final agsCliente = agendamentos.where((a) =>
          a.clienteId == c.id && a.status != AgendamentoStatus.cancelado);
      if (agsCliente.isEmpty) return false;
      final ultimaData = agsCliente
          .map((a) => a.data)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return hoje.difference(ultimaData).inDays <= 15;
    }).toList();

    return _construirListaPadrao(recorrentes);
  }

  Widget _construirListaInativos(
      List<Cliente> clientes, List<Agendamento> agendamentos) {
    final hoje = DateTime.now();
    final inativos = clientes.where((c) {
      final agsCliente = agendamentos.where((a) =>
          a.clienteId == c.id && a.status != AgendamentoStatus.cancelado);
      if (agsCliente.isEmpty) return false;
      final ultimaData = agsCliente
          .map((a) => a.data)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return hoje.difference(ultimaData).inDays > 30;
    }).toList();

    return _construirListaPadrao(inativos);
  }

  Widget _construirListaPadrao(List<Cliente> lista) {
    if (lista.isEmpty) {
      return const Center(child: Text('Nenhum cliente nesta categoria.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final cliente = lista[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                cliente.nome.isNotEmpty ? cliente.nome[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              cliente.nome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(cliente.telefone),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _abrirHistorico(context, cliente.id),
          ),
        );
      },
    );
  }

  Widget _construirListaTopClientes(
      List<Cliente> clientes, List<Agendamento> agendamentos) {
    final ranking = clientes.map((c) {
      final ags = agendamentos.where((a) =>
          a.clienteId == c.id && a.status == AgendamentoStatus.concluido);
      final totalGasto = ags.fold(0.0, (sum, a) => sum + a.valor);
      final totalVisitas = ags.length;
      return {
        'cliente': c,
        'gasto': totalGasto,
        'visitas': totalVisitas,
      };
    }).toList();

    ranking.sort((a, b) => (b['gasto'] as double).compareTo(a['gasto'] as double));

    if (ranking.isEmpty) {
      return const Center(child: Text('Nenhum cliente registrado.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: ranking.length,
      itemBuilder: (context, i) {
        final item = ranking[i];
        final cliente = item['cliente'] as Cliente;
        final gasto = item['gasto'] as double;
        final visitas = item['visitas'] as int;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: i < 3 ? Colors.amber.shade100 : Colors.grey.shade200,
              child: Text(
                '#${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: i < 3 ? Colors.amber.shade900 : Colors.black87,
                ),
              ),
            ),
            title: Text(
              cliente.nome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('$visitas visita(s) · R\$ ${gasto.toStringAsFixed(2).replaceAll('.', ',')}'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _abrirHistorico(context, cliente.id),
          ),
        );
      },
    );
  }
}
