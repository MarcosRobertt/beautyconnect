import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            'Este cliente possui agendamentos (passados ou futuros) vinculados. '
            'Cancele ou reatribua esses agendamentos antes de excluir o cliente.',
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
        content: const Text('Tem certeza que deseja excluir este cliente? Esta ação não pode ser desfeita.'),
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
      length: 4, // 4 Abas do nosso CRM
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestão de Clientes'),
          bottom: const TabBar(
            isScrollable: true, // Permite rolar as abas para o lado no celular
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
              // Barra de Pesquisa Mantida Intacta
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
                  error: (e, _) => Center(child: Text('Erro ao carregar clientes: $e')),
                  data: (lista) {
                    if (lista.isEmpty) {
                      return const Center(child: Text('Nenhum cliente encontrado.'));
                    }
                    
                    final todosAgendamentos = todosAgendamentosAsync.value ?? [];
                    final hoje = DateTime.now();
                    
                    final ativas = <Cliente>[];
                    final recorrencia = <Cliente>[];
                    final inativas = <Cliente>[];
                    final vips = <Cliente>[];

                    final stats = <String, Map<String, dynamic>>{};

                    // MATEMÁTICA DO CRM
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

                      double totalGasto = passados.fold(0.0, (sum, a) => sum + a.valor);
                      int frequencia = passados.length;

                      stats[c.id] = {'dias': diasAusente, 'gasto': totalGasto, 'freq': frequencia};

                      // Distribui nas Abas
                      if (futuros.isNotEmpty || diasAusente <= 15) {
                        ativas.add(c);
                      } else if (diasAusente <= 30) {
                        recorrencia.add(c);
                      } else {
                        inativas.add(c);
                      }
                      
                      // Todos entram nos VIPs para o ranking
                      vips.add(c);
                    }

                    // Ordenações inteligentes
                    ativas.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase())); // Ordem alfabética
                    recorrencia.sort((a, b) => stats[b.id]!['dias'].compareTo(stats[a.id]!['dias'])); // Quem tá sumida a mais tempo primeiro
                    inativas.sort((a, b) => stats[b.id]!['dias'].compareTo(stats[a.id]!['dias'])); // Sumidas há mais tempo no topo
                    
                    // Ordena os VIPs: Quem gastou mais dinheiro primeiro. Desempate pela frequência.
                    vips.sort((a, b) {
                      int compGasto = stats[b.id]!['gasto'].compareTo(stats[a.id]!['gasto']);
                      if (compGasto != 0) return compGasto; // Descendente por valor
                      return stats[b.id]!['freq'].compareTo(stats[a.id]!['freq']);
                    });

                    // FUNÇÃO PARA RENDERIZAR AS GRADES
                    Widget buildGrid(List<Cliente> listaClientes, String emptyMsg) {
                      if (listaClientes.isEmpty) {
                        return Center(child: Text(emptyMsg, style: TextStyle(color: Colors.grey.shade600)));
                      }
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
                          final agendamentosDoCliente = todosAgendamentos.where((a) => a.clienteId == cliente.id).toList();
                          return ClienteCard(
                            cliente: cliente,
                            inteligencia: InteligenciaService.calcularParaCliente(agendamentosDoCliente),
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
                        buildGrid(inativas, 'Nenhuma cliente inativa. Excelente taxa de retenção!'),
                        buildGrid(vips, 'Sem dados financeiros para ranquear.'),
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
