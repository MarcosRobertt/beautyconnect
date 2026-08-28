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

class _ClientesScreenState extends ConsumerState<ClientesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final estadoAgendaAsync = ref.watch(agendamentoControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Recorrência'),
            Tab(text: 'Inativos'),
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
        data: (todosClientes) {
          // Extrai a lista global de agendamentos para calcular o status em tempo real
          final agendamentos = estadoAgendaAsync.value?.lista ?? [];
          
          final hoje = DateTime.now();
          final hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);

          final clientesComAgendamentoAtivo = <String>{};
          final ultimaDataPorCliente = <String, DateTime>{};

          for (final ag in agendamentos) {
            if (ag.clienteId == 'BLOQUEIO') continue;

            final dataAg = DateTime(ag.data.year, ag.data.month, ag.data.day);

            // TRAVA DA ELIZA: Se tem agendamento ativo para hoje ou futuro, marca como ATIVA
            if ((ag.status == AgendamentoStatus.agendado || ag.status == AgendamentoStatus.confirmado) &&
                (dataAg.isAfter(hojeZerado) || dataAg.isAtSameMomentAs(hojeZerado))) {
              clientesComAgendamentoAtivo.add(ag.clienteId);
            }

            // Armazena a última data de atendimento concluído
            if (ag.status == AgendamentoStatus.concluido) {
              final dataAtualGuardada = ultimaDataPorCliente[ag.clienteId];
              if (dataAtualGuardada == null || ag.data.isAfter(dataAtualGuardada)) {
                ultimaDataPorCliente[ag.clienteId] = ag.data;
              }
            }
          }

          final recorrencia = <Cliente>[];
          final inativos = <Cliente>[];

          for (final cliente in todosClientes) {
            // Se tem agendamento ativo hoje ou no futuro, NÃO entra em Recorrência nem em Inativos
            if (clientesComAgendamentoAtivo.contains(cliente.id)) {
              continue;
            }

            final ultimaData = ultimaDataPorCliente[cliente.id] ?? cliente.createdAt;
            final diasSemAgendar = hojeZerado.difference(DateTime(ultimaData.year, ultimaData.month, ultimaData.day)).inDays;

            if (diasSemAgendar >= 15 && diasSemAgendar < 30) {
              recorrencia.add(cliente);
            } else if (diasSemAgendar >= 30) {
              inativos.add(cliente);
            }
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _construirAbaCliente(todosClientes, null),
              _construirAbaCliente(recorrencia, 'clientes que não agendaram em até 15 dias'),
              _construirAbaCliente(inativos, 'clientes que não agendaram em 30 dias ou mais'),
            ],
          );
        },
      ),
    );
  }

  Widget _construirAbaCliente(List<Cliente> listaClientes, String? textoSubtitulo) {
    final textoBusca = _buscaController.text.trim().toLowerCase();
    final filtrados = textoBusca.isEmpty
        ? listaClientes
        : listaClientes.where((c) =>
            c.nome.toLowerCase().contains(textoBusca) || c.telefone.contains(textoBusca)
          ).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SUBTÍTULO INDICATIVO SOLICITADO
          if (textoSubtitulo != null) ...[
            Text(
              textoSubtitulo,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
            ),
            const SizedBox(height: 8),
          ],

          TextField(
            controller: _buscaController,
            decoration: const InputDecoration(
              hintText: 'Buscar cliente por nome ou telefone...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: filtrados.isEmpty
                ? const Center(child: Text('Nenhuma cliente encontrada.', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final cliente = filtrados[index];
                      return ListTile(
                        title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(cliente.telefone),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history, color: Colors.purple),
                              tooltip: 'Histórico',
                              onPressed: () => context.push('${AppRoutes.clienteHistorico}/${cliente.id}'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                              tooltip: 'Editar',
                              onPressed: () => context.push('${AppRoutes.clienteEditar}/${cliente.id}'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
