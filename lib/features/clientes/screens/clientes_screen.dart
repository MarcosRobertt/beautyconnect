import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';
import '../../../core/services/storage/whatsapp_service.dart'; 

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _buscaController = TextEditingController();

  String _filtroTop = 'faturamento';
  String _filtroTempoTop = 'sempre'; 
  String _filtroTodos = 'todos'; 
  String _filtroRetencao = 'todos_risco'; 

  List<String> _clientesComAgendamentoPendente = [];
  Map<String, int> _visitasSempre = {};
  Map<String, double> _gastosSempre = {};
  Map<String, int> _visitasAnoAtual = {};
  Map<String, double> _gastosAnoAtual = {};
  Map<String, int> _visitas6Meses = {};
  Map<String, double> _gastos6Meses = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarMetricasAgendamentos(); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  // 🎯 O NOVO CÉREBRO MATEMÁTICO (À Prova de Falhas)
  Future<void> _carregarMetricasAgendamentos() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('agendamentos')
          .where('status', whereIn: ['pendente', 'confirmado', 'concluido']).get();
          
      final setPendentes = <String>{};
      final vSempre = <String, int>{};
      final gSempre = <String, double>{};
      final vAnoAtual = <String, int>{};
      final gAnoAtual = <String, double>{};
      final v6Meses = <String, int>{};
      final g6Meses = <String, double>{};

      final hoje = DateTime.now();
      final inicioAnoAtual = DateTime(hoje.year, 1, 1);
      final inicio6Meses = DateTime(hoje.year, hoje.month - 6, hoje.day); 

      for(var doc in snap.docs) {
        final data = doc.data();
        if (!data.containsKey('clienteId')) continue;
        
        final cId = data['clienteId'].toString();
        final status = data['status']?.toString().toLowerCase() ?? '';
        
        // 🛡️ PARSE BLINDADO DO VALOR FINANCEIRO (Aceita Int, Double ou String)
        double valor = 0.0;
        final rawValor = data['valor'];
        if (rawValor != null) {
          if (rawValor is num) {
            valor = rawValor.toDouble();
          } else if (rawValor is String) {
            valor = double.tryParse(rawValor.replaceAll(',', '.')) ?? 0.0;
          }
        }
        
        // 🛡️ PARSE BLINDADO DA DATA (Timestamp do Firebase vs ISO String)
        DateTime dataAgendamento = DateTime(2000); // Passado distante por segurança
        final rawData = data['data'];
        if (rawData != null) {
          if (rawData is Timestamp) {
            dataAgendamento = rawData.toDate();
          } else if (rawData is String) {
            dataAgendamento = DateTime.tryParse(rawData) ?? DateTime(2000);
          }
        }

        if (status == 'pendente' || status == 'confirmado') {
          setPendentes.add(cId);
        }
        
        if (status == 'confirmado' || status == 'concluido') {
          // Histórico Completo
          vSempre[cId] = (vSempre[cId] ?? 0) + 1;
          gSempre[cId] = (gSempre[cId] ?? 0.0) + valor;

          // Filtro: Ano Atual
          if (dataAgendamento.year == hoje.year) {
            vAnoAtual[cId] = (vAnoAtual[cId] ?? 0) + 1;
            gAnoAtual[cId] = (gAnoAtual[cId] ?? 0.0) + valor;
          }

          // Filtro: Últimos 6 Meses
          final diffMeses = (hoje.year - dataAgendamento.year) * 12 + hoje.month - dataAgendamento.month;
          if (diffMeses <= 6 && diffMeses >= 0) {
            v6Meses[cId] = (v6Meses[cId] ?? 0) + 1;
            g6Meses[cId] = (g6Meses[cId] ?? 0.0) + valor;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _clientesComAgendamentoPendente = setPendentes.toList();
          _visitasSempre = vSempre;
          _gastosSempre = gSempre;
          _visitasAnoAtual = vAnoAtual;
          _gastosAnoAtual = gAnoAtual;
          _visitas6Meses = v6Meses;
          _gastos6Meses = g6Meses;
        });
      }
    } catch (e) {
      debugPrint('Erro no motor de métricas dinâmicas: $e');
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
          tabs: const [ Tab(text: 'Todos'), Tab(text: '🎯 Retenção'), Tab(text: '🏆 Top Clientes') ],
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

          Map<String, int> mapaVisitasAtivo;
          Map<String, double> mapaGastosAtivo;

          // 🛡️ SISTEMA DE HERANÇA PARA CLIENTES ANTIGAS
          if (_filtroTempoTop == 'ano_atual') {
            mapaVisitasAtivo = _visitasAnoAtual;
            mapaGastosAtivo = _gastosAnoAtual;
          } else if (_filtroTempoTop == '6_meses') {
            mapaVisitasAtivo = _visitas6Meses;
            mapaGastosAtivo = _gastos6Meses;
          } else {
            // Se for 'Sempre', respeita o valor oficial do perfil se a comanda antiga tiver sido apagada
            mapaVisitasAtivo = {};
            mapaGastosAtivo = {};
            for (var c in todosClientes) {
              final vCalc = _visitasSempre[c.id] ?? 0;
              final gCalc = _gastosSempre[c.id] ?? 0.0;
              mapaVisitasAtivo[c.id] = (vCalc > c.totalVisitas) ? vCalc : c.totalVisitas;
              mapaGastosAtivo[c.id] = (gCalc > c.totalGasto) ? gCalc : c.totalGasto;
            }
          }

          final topClientes = List<Cliente>.from(todosClientes.where((c) {
            final v = mapaVisitasAtivo[c.id] ?? 0;
            return v > 0; 
          }));

          if (_filtroTop == 'faturamento') {
            topClientes.sort((a, b) {
              final gA = mapaGastosAtivo[a.id] ?? 0.0;
              final gB = mapaGastosAtivo[b.id] ?? 0.0;
              return gB.compareTo(gA);
            });
          } else {
            topClientes.sort((a, b) {
              final vA = mapaVisitasAtivo[a.id] ?? 0;
              final vB = mapaVisitasAtivo[b.id] ?? 0;
              return vB.compareTo(vA);
            });
          }

          final clientesEmRisco = <Cliente>[];
          for (var c in todosClientes) {
            final dataRef = c.ultimaVisita ?? c.createdAt;
            final refZerada = DateTime(dataRef.year, dataRef.month, dataRef.day);
            final dias = hojeZerado.difference(refZerada).inDays;

            if (dias >= 20 && !_clientesComAgendamentoPendente.contains(c.id)) {
              clientesEmRisco.add(c);
            }
          }
          clientesEmRisco.sort((a, b) {
            final dataA = a.ultimaVisita ?? a.createdAt;
            final dataB = b.ultimaVisita ?? b.createdAt;
            return dataA.compareTo(dataB); 
          });

          return TabBarView(
            controller: _tabController,
            children: [
              _construirAbaTodos(todosClientes, moeda),
              _construirAbaRetencao(clientesEmRisco), 
              _construirAbaTopClientes(topClientes, moeda, mapaVisitasAtivo, mapaGastosAtivo), 
            ],
          );
        },
      ),
    );
  }

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
        : filtradosPorChip.where((c) => c.nome.toLowerCase().contains(textoBusca) || c.telefone.contains(textoBusca)).toList();

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
              suffixIcon: textoBusca.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _buscaController.clear(); setState(() {}); }) : null,
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
                ChoiceChip(label: const Text('Mostrar Todas', style: TextStyle(fontSize: 12)), selected: _filtroTodos == 'todos', selectedColor: Colors.purple.shade100, onSelected: (val) => setState(() => _filtroTodos = 'todos')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Cadastradas Recentemente', style: TextStyle(fontSize: 12)), selected: _filtroTodos == 'recentes', selectedColor: Colors.purple.shade100, onSelected: (val) => setState(() => _filtroTodos = 'recentes')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: listaFinal.isEmpty ? const Center(child: Text('Nenhuma cliente encontrada.', style: TextStyle(color: Colors.grey))) : _construirListView(listaFinal, moeda, mostrarMetricas: false)),
        ],
      ),
    );
  }

  Widget _construirAbaTopClientes(List<Cliente> listaTop, NumberFormat moeda, Map<String, int> mapaVisitas, Map<String, double> mapaGastos) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'faturamento', label: Text('🏆 Maior Gasto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ButtonSegment(value: 'frequencia', label: Text('🔄 Mais Visitas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              selected: {_filtroTop},
              style: SegmentedButton.styleFrom(selectedBackgroundColor: const Color(0xFF627970).withOpacity(0.15), foregroundColor: const Color(0xFF627970), side: BorderSide.none),
              onSelectionChanged: (set) => setState(() => _filtroTop = set.first),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(label: const Text('Todo Histórico', style: TextStyle(fontSize: 12)), selected: _filtroTempoTop == 'sempre', selectedColor: Colors.amber.shade200, onSelected: (val) => setState(() => _filtroTempoTop = 'sempre')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Últimos 6 Meses', style: TextStyle(fontSize: 12)), selected: _filtroTempoTop == '6_meses', selectedColor: Colors.amber.shade200, onSelected: (val) => setState(() => _filtroTempoTop = '6_meses')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Ano Atual', style: TextStyle(fontSize: 12)), selected: _filtroTempoTop == 'ano_atual', selectedColor: Colors.amber.shade200, onSelected: (val) => setState(() => _filtroTempoTop = 'ano_atual')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: listaTop.isEmpty
                ? Center(child: Text('Nenhum agendamento confirmado no período.', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    itemCount: listaTop.length,
                    itemBuilder: (context, index) {
                      final cliente = listaTop[index];
                      final rank = index + 1;
                      final gasto = mapaGastos[cliente.id] ?? 0.0;
                      final visitas = mapaVisitas[cliente.id] ?? 0;
                      Widget rankBadge = rank == 1 ? const Text('🥇', style: TextStyle(fontSize: 32)) : rank == 2 ? const Text('🥈', style: TextStyle(fontSize: 32)) : rank == 3 ? const Text('🥉', style: TextStyle(fontSize: 32)) : CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade300, child: Text('$rankº', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)));
                      final bool isGasto = _filtroTop == 'faturamento';
                      
                      return Card(
                        elevation: rank <= 3 ? 2 : 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: rank <= 3 ? const Color(0xFF627970).withOpacity(0.5) : Colors.grey.shade200)),
                        child: Container(
                          decoration: rank <= 3 ? BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [Colors.orange.shade50.withOpacity(0.5), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight)) : null,
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              rankBadge, const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cliente.nome, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: rank <= 3 ? const Color(0xFF627970) : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4), Text('📱 ${cliente.telefone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(isGasto ? moeda.format(gasto) : '$visitas visitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isGasto ? Colors.green.shade700 : Colors.blue.shade700)),
                                  const SizedBox(height: 4), Text(isGasto ? '🔄 $visitas visitas' : '💰 ${moeda.format(gasto)}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _construirAbaRetencao(List<Cliente> listaBase) {
    final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    List<Cliente> filtradosPorChip = listaBase.where((c) {
      final ref = c.ultimaVisita ?? c.createdAt;
      final dias = hojeZerado.difference(DateTime(ref.year, ref.month, ref.day)).inDays;
      if (_filtroRetencao == '20') return dias >= 20 && dias <= 29;
      if (_filtroRetencao == '30') return dias == 30 || dias == 31;
      if (_filtroRetencao == '31_mais') return dias > 31;
      return true; 
    }).toList();

    final textoBusca = _buscaController.text.trim().toLowerCase();
    final listaFinal = textoBusca.isEmpty ? filtradosPorChip : filtradosPorChip.where((c) => c.nome.toLowerCase().contains(textoBusca) || c.telefone.contains(textoBusca)).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _buscaController,
            decoration: InputDecoration(
              hintText: 'Buscar cliente sumida...', prefixIcon: const Icon(Icons.search),
              suffixIcon: textoBusca.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _buscaController.clear(); setState(() {}); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(label: const Text('Risco Geral', style: TextStyle(fontSize: 12)), selected: _filtroRetencao == 'todos_risco', selectedColor: Colors.orange.shade100, onSelected: (val) => setState(() => _filtroRetencao = 'todos_risco')),
                const SizedBox(width: 8), ChoiceChip(label: const Text('🟡 20 a 29 Dias', style: TextStyle(fontSize: 12)), selected: _filtroRetencao == '20', selectedColor: Colors.yellow.shade600, onSelected: (val) => setState(() => _filtroRetencao = '20')),
                const SizedBox(width: 8), ChoiceChip(label: const Text('🟠 30 Dias', style: TextStyle(fontSize: 12)), selected: _filtroRetencao == '30', selectedColor: Colors.orange.shade400, onSelected: (val) => setState(() => _filtroRetencao = '30')),
                const SizedBox(width: 8), ChoiceChip(label: const Text('🔴 + de 31 Dias', style: TextStyle(fontSize: 12, color: Colors.white)), selected: _filtroRetencao == '31_mais', selectedColor: Colors.red.shade700, backgroundColor: Colors.red.shade100, onSelected: (val) => setState(() => _filtroRetencao = '31_mais')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (listaFinal.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('⚠️ ${listaFinal.length} Clientes necessitam de contato', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800))),
          Expanded(
            child: listaFinal.isEmpty
                ? const Center(child: Text('Nenhuma cliente em risco encontrada! Parabéns!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                : ListView.builder(itemCount: listaFinal.length, itemBuilder: (context, index) { return _buildCartaoRetencao(listaFinal[index], hojeZerado); }),
          ),
        ],
      ),
    );
  }

  Widget _buildCartaoRetencao(Cliente cliente, DateTime hojeZerado) {
    final ref = cliente.ultimaVisita ?? cliente.createdAt;
    final dias = hojeZerado.difference(DateTime(ref.year, ref.month, ref.day)).inDays;
    
    Color corAlerta = Colors.orange.shade700; String nivel = 'ATENÇÃO';
    if (dias > 31) { corAlerta = Colors.red.shade700; nivel = 'CRÍTICO'; }

    return Card(
      elevation: 1, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: corAlerta.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: corAlerta.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text('⏳ $dias dias ($nivel)', style: TextStyle(color: corAlerta, fontWeight: FontWeight.bold, fontSize: 11)))
              ],
            ),
            const SizedBox(height: 4), Text('📱 ${cliente.telefone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('agendamentos').where('clienteId', isEqualTo: cliente.id).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Text('Procurando últimos serviços...', style: TextStyle(fontSize: 12, color: Colors.grey));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('Nenhum serviço registrado nas comandas.', style: TextStyle(fontSize: 12, color: Colors.grey));

                final agendamentos = snapshot.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'concluido').toList();
                if (agendamentos.isEmpty) return const Text('Nenhum serviço concluído registrado.', style: TextStyle(fontSize: 12, color: Colors.grey));

                agendamentos.sort((a, b) => ((b.data() as Map<String, dynamic>)['data']?.toString() ?? '').compareTo((a.data() as Map<String, dynamic>)['data']?.toString() ?? ''));
                final servicos = agendamentos.take(2).map((d) => (d.data() as Map<String, dynamic>)['servico']?.toString() ?? 'Serviço').toList();

                return RichText(text: TextSpan(style: TextStyle(fontSize: 12, color: Colors.grey.shade800), children: [const TextSpan(text: '💅 Últimos procedimentos: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: servicos.join(', ')),]));
              },
            ),
            
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.chat, size: 16), label: const Text('WhatsApp'),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (ctx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Escolha a abordagem para enviar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 16),
                                ListTile(
                                  leading: const CircleAvatar(backgroundColor: Colors.pinkAccent, child: Icon(Icons.favorite, color: Colors.white, size: 20)),
                                  title: const Text('Opção 1: Saudade (Padrão)', style: TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: const Text('Diga que sentiu a falta dela no Studio.'),
                                  onTap: () { Navigator.pop(ctx); WhatsAppService.enviarRetencao(telefone: cliente.telefone, nomeCliente: cliente.nome, diasAusente: dias, variante: 1); },
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.card_giftcard, color: Colors.white, size: 20)),
                                  title: const Text('Opção 2: Novidades / Mimo', style: TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: const Text('Atraia com uma promoção ou novidade.'),
                                  onTap: () { Navigator.pop(ctx); WhatsAppService.enviarRetencao(telefone: cliente.telefone, nomeCliente: cliente.nome, diasAusente: dias, variante: 2); },
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.help_outline, color: Colors.white, size: 20)),
                                  title: const Text('Opção 3: Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: const Text('Pergunte carinhosamente o motivo da ausência.'),
                                  onTap: () { Navigator.pop(ctx); WhatsAppService.enviarRetencao(telefone: cliente.telefone, nomeCliente: cliente.nome, diasAusente: dias, variante: 3); },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact), icon: const Icon(Icons.history, size: 16), label: const Text('Histórico'),
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

  Widget _construirListView(List<Cliente> lista, NumberFormat moeda, {bool mostrarMetricas = true}) {
    return ListView.separated(
      itemCount: lista.length, separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final cliente = lista[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4), Text('📱 ${cliente.telefone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('agendamentos').where('clienteId', isEqualTo: cliente.id).get(),
                      builder: (context, snapshot) {
                        DateTime? dataCalculada = cliente.ultimaVisita;

                        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          final agendamentos = snapshot.data!.docs.where((d) {
                            final status = (d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
                            return status == 'concluido' || status == 'confirmado';
                          }).toList();

                          if (agendamentos.isNotEmpty) {
                            agendamentos.sort((a, b) => ((b.data() as Map<String, dynamic>)['data']?.toString() ?? '').compareTo((a.data() as Map<String, dynamic>)['data']?.toString() ?? ''));
                            final dataStr = (agendamentos.first.data() as Map<String, dynamic>)['data']?.toString();
                            if (dataStr != null && dataStr.isNotEmpty) dataCalculada = DateTime.parse(dataStr);
                          }
                        }

                        final dataFormatada = dataCalculada != null ? DateFormat('dd/MM/yyyy').format(dataCalculada!) : 'Nenhum atendimento';
                        final textoExibicao = snapshot.connectionState == ConnectionState.waiting ? 'Buscando data...' : '📅 Última visita: $dataFormatada';

                        return Text(textoExibicao, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis);
                      },
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, side: const BorderSide(color: Colors.purple), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.history, size: 14), label: const Text('HISTÓRICO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        onPressed: () => context.push('${AppRoutes.clienteHistorico}/${cliente.id}'),
                      ),
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20), tooltip: 'Editar Cliente', onPressed: () => context.push('${AppRoutes.clienteEditar}/${cliente.id}')),
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
