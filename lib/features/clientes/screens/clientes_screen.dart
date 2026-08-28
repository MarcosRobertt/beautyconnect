import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';

// --- CLASSE DE AGREGAÇÃO PARA ALTA PERFORMANCE ---
// Junta os dados da cliente com seu histórico processado para exibição rápida
class ClienteAgregado {
  final Cliente cliente;
  final int totalVisitas;
  final DateTime? ultimaVisita;
  final bool temAgendamentoAtivoFuturo;
  final int diasSemAgendar;

  ClienteAgregado({
    required this.cliente,
    required this.totalVisitas,
    this.ultimaVisita,
    required this.temAgendamentoAtivoFuturo,
    required this.diasSemAgendar,
  });
}

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> with SingleTickerProviderStateMixin {
  // RESTAURADO: 4 Abas (Todos, Top Clientes, Recorrência, Inativos)
  late TabController _tabController;
  final TextEditingController _buscaController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final estadoAgendaAsync = ref.watch(agendamentoControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Permite rolar as abas horizontalmente se a tela for pequena
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Top Clientes'),
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
          final agendamentos = estadoAgendaAsync.value?.lista ?? [];
          final hoje = DateTime.now();
          final hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);

          // 1. Processamento de Histórico (Restauração da Visibilidade)
          List<ClienteAgregado> agregados = todosClientes.map((cliente) {
            int concluidos = 0;
            DateTime? ultimaConcluida;
            bool temFuturo = false;

            for (final ag in agendamentos) {
              if (ag.clienteId != cliente.id) continue;

              final dataAgZerada = DateTime(ag.data.year, ag.data.month, ag.data.day);

              // Validação da Eliza: Tem agendamento ativo para hoje ou futuro?
              if ((ag.status == AgendamentoStatus.agendado || ag.status == AgendamentoStatus.confirmado) &&
                  (dataAgZerada.isAfter(hojeZerado) || dataAgZerada.isAtSameMomentAs(hojeZerado))) {
                temFuturo = true;
              }

              // Conta visitas concluídas e descobre a última
              if (ag.status == AgendamentoStatus.concluido) {
                concluidos++;
                if (ultimaConcluida == null || ag.data.isAfter(ultimaConcluida)) {
                  ultimaConcluida = ag.data;
                }
              }
            }

            // Cálculo exato de dias inativos
            final dataReferencia = ultimaConcluida ?? cliente.createdAt;
            final refZerada = DateTime(dataReferencia.year, dataReferencia.month, dataReferencia.day);
            final diasSemAgendar = hojeZerado.difference(refZerada).inDays;

            return ClienteAgregado(
              cliente: cliente,
              totalVisitas: concluidos,
              ultimaVisita: ultimaConcluida,
              temAgendamentoAtivoFuturo: temFuturo,
              diasSemAgendar: diasSemAgendar,
            );
          }).toList();

          // 2. Distribuição das Listas (Regras de Negócio)
          final topClientes = List<ClienteAgregado>.from(agregados)
            ..sort((a, b) => b.totalVisitas.compareTo(a.totalVisitas)); // Maior número de visitas no topo

          final recorrencia = agregados.where((c) => 
            !c.temAgendamentoAtivoFuturo && c.diasSemAgendar >= 15 && c.diasSemAgendar < 30
          ).toList();

          final inativos = agregados.where((c) => 
            !c.temAgendamentoAtivoFuturo && c.diasSemAgendar >= 30
          ).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _construirAbaCliente(agregados, null),
              _construirAbaCliente(topClientes.where((c) => c.totalVisitas > 0).toList(), 'Ranking dos clientes com mais atendimentos concluídos'),
              _construirAbaCliente(recorrencia, 'Clientes que não agendaram em até 15 dias'),
              _construirAbaCliente(inativos, 'Clientes que não agendaram em 30 dias ou mais'),
            ],
          );
        },
      ),
    );
  }

  Widget _construirAbaCliente(List<ClienteAgregado> listaAgregada, String? textoSubtitulo) {
    final textoBusca = _buscaController.text.trim().toLowerCase();
    
    final filtrados = textoBusca.isEmpty
        ? listaAgregada
        : listaAgregada.where((a) =>
            a.cliente.nome.toLowerCase().contains(textoBusca) || 
            a.cliente.telefone.contains(textoBusca)
          ).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      final agregado = filtrados[index];
                      final cliente = agregado.cliente;
                      
                      // RESTAURAÇÃO: Formatação do Resumo Histórico
                      final dataFormatada = agregado.ultimaVisita != null 
                          ? DateFormat('dd/MM/yyyy').format(agregado.ultimaVisita!) 
                          : 'Nenhum atendimento';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('📱 ${cliente.telefone}', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 2),
                            // EXIBIÇÃO DO HISTÓRICO DIRETAMENTE NO CARD DA LISTA
                            Text(
                              '📅 Última visita: $dataFormatada • 🔄 Visitas: ${agregado.totalVisitas}', 
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history, color: Colors.purple),
                              tooltip: 'Ver Histórico Completo',
                              onPressed: () => context.push('${AppRoutes.clienteHistorico}/${cliente.id}'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                              tooltip: 'Editar Cliente',
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
