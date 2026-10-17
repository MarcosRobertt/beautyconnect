import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
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

  // Filtros de Estado
  String _filtroTop = 'faturamento';
  String _filtroTodos = 'todos'; 
  String _filtroRetencao = 'todos_risco'; 

  // 🎯 TRAVA INTELIGENTE: Lista de IDs de clientes com agendamentos futuros
  List<String> _clientesComAgendamentoFuturo = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _buscarAgendamentosFuturos(); // Aciona a trava de segurança ao abrir a tela
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  // 🎯 O MOTOR DA TRAVA INTELIGENTE
  Future<void> _buscarAgendamentosFuturos() async {
    try {
      final hoje = DateTime.now();
      final hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);
      
      // Busca hiper leve: Pega apenas do dia de hoje para frente
      final snap = await FirebaseFirestore.instance.collection('agendamentos')
          .where('data', isGreaterThanOrEqualTo: hojeZerado.toIso8601String())
          .get();
          
      final setFuturos = <String>{};
      for(var doc in snap.docs) {
        final status = doc.data().containsKey('status') ? doc['status'].toString().toLowerCase() : '';
        // Se a cliente tem algo marcado para o futuro (Pendente ou Confirmado), ela está salva!
        if (status == 'pendente' || status == 'confirmado') {
          if (doc.data().containsKey('clienteId')) {
            setFuturos.add(doc['clienteId'].toString());
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _clientesComAgendamentoFuturo = setFuturos.toList();
        });
      }
    } catch (e) {
      debugPrint('Erro na trava de agendamentos futuros: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clienteControllerProvider);
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
            Tab(text: '🎯 Retenção'), 
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
          final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

          // Top Clientes
          final topClientes = List<Cliente>.from(todosClientes.where((c) => c.totalVisitas > 0));
          if (_filtroTop == 'faturamento') {
            topClientes.sort((a, b) => b.totalGasto.compareTo(a.totalGasto));
          } else {
            topClientes.sort((a, b) => b.totalVisitas.compareTo(a.totalVisitas));
          }

          // 🎯 O NOVO FUNIL DE RETENÇÃO BLINDADO
          final clientesEmRisco = <Cliente>[];
          for (var c in todosClientes) {
            final dataRef = c.ultimaVisita ?? c.createdAt;
            final refZerada = DateTime(dataRef.year, dataRef.month, dataRef.day);
            final dias = hojeZerado.difference(refZerada).inDays;

            // Se sumiu há 20 dias E NÃO TEM agendamento futuro marcado
            if (dias >= 20 && !_clientesComAgendamentoFuturo.contains(c.id)) {
              clientesEmRisco.add(c);
            }
          }
          // Ordenar as mais críticas primeiro (as que não vêm há mais tempo)
          clientesEmRisco.sort((a, b) {
            final dataA = a.ultimaVisita ?? a.createdAt;
            final dataB = b.ultimaVisita ?? b.createdAt;
            return dataA.compareTo(dataB); 
          });

          return TabBarView(
            controller: _tabController,
            children: [
              _construirAbaTodos(todosClientes, moeda),
              _construirAbaTopClientes(topClientes, moeda),
              _construirAbaRetencao(clientesEmRisco), 
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // ABA 1: TODOS (Catálogo Limpo)
  // =========================================================================
  Widget _construirAbaTodos(List<Cliente> listaBase, NumberFormat moeda) {
    List<Cliente> filtradosPorChip = listaBase;
    if (_filtroTodos == 'recentes') {
      filtradosPorChip = listaBase.where((c) {
        final diff = DateTime.now().difference(c.createdAt).inDays;
        return diff <= 7;
      }).toList();
    }

    final textoBusca = _buscaController.text.trim().toLowerCase();
    final listaFinal = textoBusca.isEmpty
        ? filtradosPorChip
        : filtradosPorChip.where((c) =>
            c.nome.toLowerCase().contains(textoBusca) ||
            c.telefone.contains(textoBusca)
          ).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _buscaController,
            decoration: InputDecoration(
              hintText: 'Buscar cliente por nome ou telefone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: textoBusca.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _buscaController.clear(); setState(() {}); })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Mostrar Todas', style: TextStyle(fontSize: 12)),
                  selected: _filtroTodos == 'todos',
                  selectedColor: Colors.purple.shade100,
                  onSelected: (val) => setState(() => _filtroTodos = 'todos'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cadastradas Recentemente', style: TextStyle(fontSize: 12)),
                  selected: _filtroTodos == 'recentes',
                  selectedColor: Colors.purple.shade100,
                  onSelected: (val) => setState(() => _filtroTodos = 'recentes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: listaFinal.isEmpty
                ? const Center(child: Text('Nenhuma cliente encontrada.', style: TextStyle(color: Colors.grey)))
                : _construirListView(listaFinal, moeda, mostrarMetricas: false), 
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ABA 2: TOP CLIENTES
  // =========================================================================
  Widget _construirAbaTopClientes(List<Cliente> listaTop, NumberFormat moeda) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'faturamento', label: Text('Maior Gasto (R\$)', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: 'frequencia', label: Text('Mais Visitas', style: TextStyle(fontSize: 12))),
            ],
            selected: {_filtroTop},
            onSelectionChanged: (set) => setState(() => _filtroTop = set.first),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: listaTop.isEmpty
                ? const Center(child: Text('Nenhuma cliente com histórico de visitas.', style: TextStyle(color: Colors.grey)))
                : _construirListView(listaTop, moeda),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🎯 ABA 3: RETENÇÃO (BLINDADA CONTRA FALSOS POSITIVOS)
  // =========================================================================
  Widget _construirAbaRetencao(List<Cliente> listaBase) {
    final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    List<Cliente> filtradosPorChip = listaBase.where((c) {
      final ref = c.ultimaVisita ?? c.createdAt;
      final dias = hojeZerado.difference(DateTime(ref.year, ref.month, ref.day)).inDays;

      if (_filtroRetencao == '20') return dias >= 20 && dias <= 29;
      if (_filtroRetencao == '30') return dias == 30 || dias == 31;
      if (_filtroRetencao == '31_mais') return dias > 31;
      return true; // 'todos_risco'
    }).toList();

    final textoBusca = _buscaController.text.trim().toLowerCase();
    final listaFinal = textoBusca.isEmpty
        ? filtradosPorChip
        : filtradosPorChip.where((c) =>
            c.nome.toLowerCase().contains(textoBusca) ||
            c.telefone.contains(textoBusca)
          ).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _buscaController,
            decoration: InputDecoration(
              hintText: 'Buscar cliente sumida...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: textoBusca.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _buscaController.clear(); setState(() {}); })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Risco Geral', style: TextStyle(fontSize: 12)),
                  selected: _filtroRetencao == 'todos_risco',
                  selectedColor: Colors.orange.shade100,
                  onSelected: (val) => setState(() => _filtroRetencao = 'todos_risco'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🟡 20 a 29 Dias', style: TextStyle(fontSize: 12)),
                  selected: _filtroRetencao == '20',
                  selectedColor: Colors.yellow.shade600,
                  onSelected: (val) => setState(() => _filtroRetencao = '20'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🟠 30 Dias', style: TextStyle(fontSize: 12)),
                  selected: _filtroRetencao == '30',
                  selectedColor: Colors.orange.shade400,
                  onSelected: (val) => setState(() => _filtroRetencao = '30'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🔴 + de 31 Dias', style: TextStyle(fontSize: 12, color: Colors.white)),
                  selected: _filtroRetencao == '31_mais',
                  selectedColor: Colors.red.shade700,
                  backgroundColor: Colors.red.shade100,
                  onSelected: (val) => setState(() => _filtroRetencao = '31_mais'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (listaFinal.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('⚠️ ${listaFinal.length} Clientes necessitam de contato', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
            ),
          Expanded(
            child: listaFinal.isEmpty
                ? const Center(child: Text('Nenhuma cliente em risco encontrada! Parabéns!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                : ListView.builder(
                    itemCount: listaFinal.length,
                    itemBuilder: (context, index) {
                      return _buildCartaoRetencao(listaFinal[index], hojeZerado);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 🎯 CARTÃO DE RESGATE
  Widget _buildCartaoRetencao(Cliente cliente, DateTime hojeZerado) {
    final ref = cliente.ultimaVisita ?? cliente.createdAt;
    final dias = hojeZerado.difference(DateTime(ref.year, ref.month, ref.day)).inDays;
    
    Color corAlerta = Colors.orange.shade700;
    String nivel = 'ATENÇÃO';
    if (dias > 31) {
      corAlerta = Colors.red.shade700;
      nivel = 'CRÍTICO';
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: corAlerta.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: corAlerta.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('⏳ $dias dias ($nivel)', style: TextStyle(color: corAlerta, fontWeight: FontWeight.bold, fontSize: 11)),
                )
              ],
            ),
            const SizedBox(height: 4),
            Text('📱 ${cliente.telefone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('agendamentos')
                  .where('clienteId', isEqualTo: cliente.id)
                  .where('status', isEqualTo: 'concluido')
                  .orderBy('data', descending: true)
                  .limit(2)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Procurando últimos serviços...', style: TextStyle(fontSize: 12, color: Colors.grey));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('Nenhum serviço registrado nas comandas.', style: TextStyle(fontSize: 12, color: Colors.grey));
                }

                final servicos = snapshot.data!.docs.map((doc) => doc['servico']?.toString() ?? 'Serviço').toList();
                return RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    children: [
                      const TextSpan(text: '💅 Últimos procedimentos: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: servicos.join(', ')),
                    ],
                  ),
                );
              },
            ),
            
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('WhatsApp'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abrir WhatsApp para ${cliente.telefone}'), backgroundColor: Colors.green));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Histórico'),
                    onPressed: () => context.push('${AppRoutes.clienteHistorico}/${cliente.id}'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // WIDGET LISTVIEW REUTILIZÁVEL (Usado na Aba Todos e Top Clientes)
  // =========================================================================
  Widget _construirListView(List<Cliente> lista, NumberFormat moeda, {bool mostrarMetricas = true}) {
    final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return ListView.separated(
      itemCount: lista.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final cliente = lista[index];
        
        final dataFormatada = cliente.ultimaVisita != null 
            ? DateFormat('dd/MM/yyyy').format(cliente.ultimaVisita!) 
            : 'Nenhum atendimento';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cliente.nome, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('📱 ${cliente.telefone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              
              if (mostrarMetricas) ...[
                Row(
                  children: [
                    Text('🔄 Visitas: ${cliente.totalVisitas}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(width: 16),
                    Text('💰 Gasto: ${moeda.format(cliente.totalGasto)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '📅 Última visita: $dataFormatada', 
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          side: const BorderSide(color: Colors.purple),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.history, size: 14),
                        label: const Text('HISTÓRICO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        onPressed: () => context.push('${AppRoutes.clienteHistorico}/${cliente.id}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                        tooltip: 'Editar Cliente',
                        onPressed: () => context.push('${AppRoutes.clienteEditar}/${cliente.id}'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
