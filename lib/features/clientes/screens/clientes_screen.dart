import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';

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

  void _abrirHistoricoCliente(String clienteId) {
    context.push('${AppRoutes.clientes}/$clienteId');
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
                  decoration: const InputDecoration(
                    labelText: 'Buscar cliente',
                    hintText: 'Nome ou telefone...',
                    prefixIcon: Icon(Icons.search),
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
      return hoje.difference(ultimaData).inDays <= 45;
    }).toList();

    return _construirListaPadrao(ativos);
  }

  Widget _construirListaRecorrencia(
      List<Cliente> clientes, List<Agendamento> agendamentos) {
    final recorrentes = clientes.where((c) {
      final qtd = agendamentos
          .where((a) =>
              a.clienteId == c.id && a.status == AgendamentoStatus.concluido)
          .length;
      return qtd >= 2;
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
      return hoje.difference(ultimaData).inDays > 45;
    }).toList();

    return _construirListaPadrao(inativos);
  }

  Widget _construirListaPadrao(List<Cliente> lista) {
    if (lista.isEmpty) {
      return const Center(child: Text('Nenhum cliente nesta categoria.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final cliente = lista[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            child: Text(cliente.nome.isNotEmpty ? cliente.nome[0].toUpperCase() : '?'),
          ),
          title: Text(
            cliente.nome,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(cliente.telefone),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _abrirHistoricoCliente(cliente.id),
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: ranking.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = ranking[i];
        final cliente = item['cliente'] as Cliente;
        final gasto = item['gasto'] as double;
        final visitas = item['visitas'] as int;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            backgroundColor: i < 3 ? Colors.amber.shade100 : null,
            child: Text(
              '#${i + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: i < 3 ? Colors.amber.shade900 : null,
              ),
            ),
          ),
          title: Text(
            cliente.nome,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$visitas visita(s) · R\$ ${gasto.toStringAsFixed(2).replaceAll('.', ',')}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _abrirHistoricoCliente(cliente.id),
        );
      },
    );
  }
}
