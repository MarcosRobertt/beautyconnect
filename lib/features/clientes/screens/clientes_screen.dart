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
class ClienteAgregado {
  final Cliente cliente;
  final int totalVisitas; // Agora calculado por DIAS ÚNICOS
  final double faturamentoTotal; // Nova métrica de valor
  final DateTime? ultimaVisita;
  final bool temAgendamentoAtivoFuturo;
  final int diasSemAgendar;

  ClienteAgregado({
    required this.cliente,
    required this.totalVisitas,
    required this.faturamentoTotal,
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
  late TabController _tabController;
  final TextEditingController _buscaController = TextEditingController();
  
  // Controle do filtro da aba "Top Clientes"
  String _filtroTop = 'faturamento'; // Pode ser 'faturamento' ou 'frequencia'

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
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
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

          // 1. Processamento de Histórico e Métricas Financeiras
          List<ClienteAgregado> agregados = todosClientes.map((cliente) {
            Set<DateTime> diasUnicosDeVisita = {}; // Garante que 2 serviços no mesmo dia valem por 1 visita
            double faturamento = 0.0;
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

              // Conta visitas concluídas por dia único e soma faturamento
              if (ag.status == AgendamentoStatus.concluido) {
                diasUnicosDeVisita.add(dataAgZerada);
                faturamento += ag.valor;
                
                if (ultimaConcluida == null || ag.data.isAfter(ultimaConcluida)) {
                  ultimaConcluida = ag.data;
                }
              }
            }

            final dataReferencia = ultimaConcluida ?? cliente.createdAt;
            final refZerada = DateTime(dataReferencia.year, dataReferencia.month, dataReferencia.day);
            final diasSemAgendar = hojeZerado.difference(refZerada).inDays;

            return ClienteAgregado(
              cliente: cliente,
              totalVisitas: diasUnicosDeVisita.length,
              faturamentoTotal: faturamento,
              ultimaVisita: ultimaConcluida,
              temAgendamentoAtivoFuturo: temFuturo,
              diasSemAgendar: diasSemAgendar,
            );
          }).toList();

          // 2. Distribuição das Listas (Regras de Negócio)
          final topClientes = List<ClienteAgregado>.from(agregados.where((c) => c.totalVisitas > 0));
          if (_filtroTop == 'faturamento') {
            topClientes.sort((a, b) => b.faturamentoTotal.compareTo(a.faturamentoTotal));
          } else {
            topClientes.sort((a, b) => b.totalVisitas.compareTo(a.totalVisitas));
          }

          final recorrencia = agregados.where((c) => 
            !c.temAgendamentoAtivoFuturo && c.diasSemAgendar >= 15 && c.diasSemAgendar < 30
          ).toList();

          final inativos = agregados.where((c) => 
            !c.temAgendamentoAtivoFuturo && c.diasSemAgendar >= 30
          ).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _construirAbaCliente(agregados, null, moeda),
              _construirAbaTopClientes(topClientes, moeda), // Aba especial com botão de filtro
              _construirAbaCliente(recorrencia, 'Clientes que não agendaram em até 15 dias', moeda),
              _construirAbaCliente(inativos, 'Clientes que não agendaram em 30 dias ou mais', moeda),
            ],
          );
        },
      ),
    );
  }

  Widget _construirAbaTopClientes(List<ClienteAgregado> listaTop, NumberFormat moeda) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // BOTÃO DE SELEÇÃO: Faturamento vs Visitas
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'faturamento', label: Text('Maior Gasto (R\$)', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: 'frequencia', label: Text('Mais Visitas', style: TextStyle(fontSize: 12))),
            ],
            selected: {_filtroTop},
            onSelectionChanged: (set) => setState(() => _filtroTop = set.first),
          ),
          const SizedBox(height: 12),
          Expanded(child: _construirLista(listaTop, moeda)),
        ],
      ),
    );
  }

  Widget _construirAbaCliente(List<ClienteAgregado> listaAgregada, String? textoSubtitulo, NumberFormat moeda) {
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
          Expanded(child: _construirLista(listaAgregada, moeda)),
        ],
      ),
    );
  }

  Widget _construirLista(List<ClienteAgregado> listaBase, NumberFormat moeda) {
    final textoBusca = _buscaController.text.trim().toLowerCase();
    final filtrados = textoBusca.isEmpty
        ? listaBase
        : listaBase.where((a) =>
            a.cliente.nome.toLowerCase().contains(textoBusca) || 
            a.cliente.telefone.contains(textoBusca)
          ).toList();

    if (filtrados.isEmpty) {
      return const Center(child: Text('Nenhuma cliente encontrada.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      itemCount: filtrados.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final agregado = filtrados[index];
        final cliente = agregado.cliente;
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
              // CARD MODERNO MOSTRANDO AS DUAS MÉTRICAS SIMULTANEAMENTE
              Text(
                '🔄 Visitas: ${agregado.totalVisitas} • 💰 Gasto: ${moeda.format(agregado.faturamentoTotal)}\n📅 Última visita: $dataFormatada', 
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
    );
  }
}
