import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';

// Provedor temporário para Fallback de Clientes Antigos que ainda estão com 0 no Firebase
final _agendamentosFallbackProvider = FutureProvider.autoDispose<List<Agendamento>>((ref) async {
  return await ref.read(agendamentoControllerProvider.notifier).todos();
});

// Classe auxiliar local para padronizar exibição (Unifica dados do Banco com o Fallback)
class _ClienteExibicao {
  final Cliente cliente;
  final int totalVisitas;
  final double totalGasto;
  final DateTime? ultimaVisita;

  _ClienteExibicao({
    required this.cliente,
    required this.totalVisitas,
    required this.totalGasto,
    this.ultimaVisita,
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

  // Filtros de Estado
  String _filtroTop = 'faturamento';
  String _filtroTodos = 'todos'; // 'todos' ou 'recentes'
  String _filtroInativos = 'todos_inativos'; // 'todos_inativos', '45', '90'

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

  void _abrirModalImportacao() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => const _ModalImportacaoContatos(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final agendamentosAsync = ref.watch(_agendamentosFallbackProvider);
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          TextButton.icon(
            onPressed: _abrirModalImportacao,
            icon: const Icon(Icons.contact_phone, color: Colors.purple, size: 20),
            label: const Text('Importar', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
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
          return agendamentosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _construirTelaComBase(todosClientes, [], moeda),
            data: (agendamentos) => _construirTelaComBase(todosClientes, agendamentos, moeda),
          );
        },
      ),
    );
  }

  Widget _construirTelaComBase(List<Cliente> clientes, List<Agendamento> agendamentosFallback, NumberFormat moeda) {
    final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // 🔄 LÓGICA DE FALLBACK: Unifica clientes antigos com o cálculo em memória se totalVisitas == 0
    final List<_ClienteExibicao> listaExibicao = clientes.map((c) {
      if (c.totalVisitas > 0 || c.totalGasto > 0 || c.ultimaVisita != null) {
        return _ClienteExibicao(
          cliente: c,
          totalVisitas: c.totalVisitas,
          totalGasto: c.totalGasto,
          ultimaVisita: c.ultimaVisita,
        );
      }

      // Cálculo em tempo de execução para dados legados
      int visitas = 0;
      double gasto = 0.0;
      DateTime? ultima;

      for (final ag in agendamentosFallback) {
        if (ag.clienteId == c.id && ag.status == AgendamentoStatus.concluido) {
          visitas++;
          gasto += ag.valor;
          if (ultima == null || ag.data.isAfter(ultima)) {
            ultima = ag.data;
          }
        }
      }

      return _ClienteExibicao(
        cliente: c,
        totalVisitas: visitas,
        totalGasto: gasto,
        ultimaVisita: ultima,
      );
    }).toList();

    // 1. TOP CLIENTES
    final topClientes = List<_ClienteExibicao>.from(listaExibicao.where((c) => c.totalVisitas > 0));
    if (_filtroTop == 'faturamento') {
      topClientes.sort((a, b) => b.totalGasto.compareTo(a.totalGasto));
    } else {
      topClientes.sort((a, b) => b.totalVisitas.compareTo(a.totalVisitas));
    }

    // 2. RECORRÊNCIA E INATIVOS
    final recorrencia = <_ClienteExibicao>[];
    final inativos = <_ClienteExibicao>[];

    for (var c in listaExibicao) {
      final dataRef = c.ultimaVisita ?? c.cliente.createdAt;
      final refZerada = DateTime(dataRef.year, dataRef.month, dataRef.day);
      final dias = hojeZerado.difference(refZerada).inDays;

      if (dias >= 15 && dias < 30) {
        recorrencia.add(c);
      } else if (dias >= 30) {
        inativos.add(c);
      }
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _construirAbaTodos(listaExibicao, moeda),
        _construirAbaTopClientes(topClientes, moeda),
        _construirAbaListaSimples(recorrencia, 'Clientes sem agendar entre 15 e 30 dias', moeda),
        _construirAbaInativos(inativos, moeda),
      ],
    );
  }

  // ABA 1: TODOS (Com Filtros Rápidos)
  Widget _construirAbaTodos(List<_ClienteExibicao> listaBase, NumberFormat moeda) {
    List<_ClienteExibicao> filtradosPorChip = listaBase;
    if (_filtroTodos == 'recentes') {
      filtradosPorChip = listaBase.where((c) {
        final diff = DateTime.now().difference(c.cliente.createdAt).inDays;
        return diff <= 7;
      }).toList();
    }

    final textoBusca = _buscaController.text.trim().toLowerCase();
    final listaFinal = textoBusca.isEmpty
        ? filtradosPorChip
        : filtradosPorChip.where((c) =>
            c.cliente.nome.toLowerCase().contains(textoBusca) ||
            c.cliente.telefone.contains(textoBusca)
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
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _buscaController.clear();
                        setState(() {});
                      },
                    )
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
                  label: const Text('Mostrar Todas'),
                  selected: _filtroTodos == 'todos',
                  onSelected: (val) => setState(() => _filtroTodos = 'todos'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cadastradas Recentemente'),
                  selected: _filtroTodos == 'recentes',
                  onSelected: (val) => setState(() => _filtroTodos = 'recentes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: listaFinal.isEmpty
                ? const Center(child: Text('Nenhuma cliente encontrada.', style: TextStyle(color: Colors.grey)))
                : _construirListView(listaFinal, moeda),
          ),
        ],
      ),
    );
  }

  // ABA 2: TOP CLIENTES
  Widget _construirAbaTopClientes(List<_ClienteExibicao> listaTop, NumberFormat moeda) {
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
                ? const Center(child: Text('Nenhum atendimento concluído registrado.', style: TextStyle(color: Colors.grey)))
                : _construirListView(listaTop, moeda),
          ),
        ],
      ),
    );
  }

  // ABA 3: INATIVOS
  Widget _construirAbaInativos(List<_ClienteExibicao> listaBase, NumberFormat moeda) {
    final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    List<_ClienteExibicao> filtradosPorChip = listaBase.where((c) {
      final ref = c.ultimaVisita ?? c.cliente.createdAt;
      final dias = hojeZerado.difference(DateTime(ref.year, ref.month, ref.day)).inDays;

      if (_filtroInativos == '45') return dias >= 45;
      if (_filtroInativos == '90') return dias >= 90;
      return true;
    }).toList();

    final textoBusca = _buscaController.text.trim().toLowerCase();
    final listaFinal = textoBusca.isEmpty
        ? filtradosPorChip
        : filtradosPorChip.where((c) =>
            c.cliente.nome.toLowerCase().contains(textoBusca) ||
            c.cliente.telefone.contains(textoBusca)
          ).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _buscaController,
            decoration: InputDecoration(
              hintText: 'Buscar nas inativas...',
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
                  label: const Text('Todas Inativas'),
                  selected: _filtroInativos == 'todos_inativos',
                  onSelected: (val) => setState(() => _filtroInativos = 'todos_inativos'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('> 45 dias'),
                  selected: _filtroInativos == '45',
                  onSelected: (val) => setState(() => _filtroInativos = '45'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('> 90 dias'),
                  selected: _filtroInativos == '90',
                  onSelected: (val) => setState(() => _filtroInativos = '90'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (listaFinal.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('⚠️ ${listaFinal.length} Clientes encontradas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
            ),
          Expanded(
            child: listaFinal.isEmpty
                ? const Center(child: Text('Nenhuma cliente inativa encontrada.', style: TextStyle(color: Colors.grey)))
                : _construirListView(listaFinal, moeda, isInativo: true),
          ),
        ],
      ),
    );
  }

  // ABA RECORRÊNCIA SIMPLES
  Widget _construirAbaListaSimples(List<_ClienteExibicao> listaBase, String subtitulo, NumberFormat moeda) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(subtitulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
          const SizedBox(height: 12),
          Expanded(child: _construirListView(listaBase, moeda)),
        ],
      ),
    );
  }

  // WIDGET LISTVIEW REUTILIZÁVEL (Sem Histórico Inline, botão isolado)
  Widget _construirListView(List<_ClienteExibicao> lista, NumberFormat moeda, {bool isInativo = false}) {
    final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return ListView.separated(
      itemCount: lista.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = lista[index];
        final cliente = item.cliente;

        final dataFormatada = item.ultimaVisita != null
            ? DateFormat('dd/MM/yyyy').format(item.ultimaVisita!)
            : 'Nenhum atendimento';

        int dias = 0;
        if (item.ultimaVisita != null) {
          final ref = DateTime(item.ultimaVisita!.year, item.ultimaVisita!.month, item.ultimaVisita!.day);
          dias = hojeZerado.difference(ref).inDays;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cliente.nome,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isInativo ? Colors.red.shade800 : Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('📱 ${cliente.telefone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('🔄 Visitas: ${item.totalVisitas}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(width: 16),
                  Text('💰 Gasto: ${moeda.format(item.totalGasto)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isInativo ? 'Sem agendar há $dias dias (Último: $dataFormatada)' : '📅 Última visita: $dataFormatada',
                      style: TextStyle(fontSize: 12, color: isInativo ? Colors.red.shade600 : Colors.grey.shade600, fontWeight: FontWeight.bold),
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

// MODAL DE IMPORTAÇÃO DA AGENDA DE CONTATOS
class _ModalImportacaoContatos extends StatefulWidget {
  const _ModalImportacaoContatos();

  @override
  State<_ModalImportacaoContatos> createState() => _ModalImportacaoContatosState();
}

class _ModalImportacaoContatosState extends State<_ModalImportacaoContatos> {
  final List<Map<String, dynamic>> _contatosCelular = [
    {'nome': 'Amanda Silva Cliente', 'telefone': '(15) 99999-1111', 'selecionado': true},
    {'nome': 'Bruna Costa (Mãe do João)', 'telefone': '(15) 98888-2222', 'selecionado': false},
    {'nome': 'Camila Unhas Gel', 'telefone': '(11) 97777-3333', 'selecionado': true},
    {'nome': 'Daniella Prima', 'telefone': '(15) 96666-4444', 'selecionado': false},
  ];

  bool _selecionarTodos = false;

  void _alternarTodos(bool? valor) {
    setState(() {
      _selecionarTodos = valor ?? false;
      for (var c in _contatosCelular) {
        c['selecionado'] = _selecionarTodos;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final contatosSelecionados = _contatosCelular.where((c) => c['selecionado'] == true).length;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📥 Importar da Agenda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar contato na sua agenda...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Selecionar Todos', style: TextStyle(fontWeight: FontWeight.bold)),
              value: _selecionarTodos,
              onChanged: _alternarTodos,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: _contatosCelular.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final contato = _contatosCelular[index];
                  return CheckboxListTile(
                    title: Text(contato['nome'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('📱 ${contato['telefone']}'),
                    value: contato['selecionado'],
                    activeColor: Colors.purple,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? value) {
                      setState(() {
                        contato['selecionado'] = value;
                        _selecionarTodos = _contatosCelular.every((c) => c['selecionado'] == true);
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: contatosSelecionados > 0 ? Colors.green : Colors.grey,
              ),
              onPressed: contatosSelecionados > 0 ? () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$contatosSelecionados clientes importados com sucesso!')),
                );
              } : null,
              child: Text(
                'IMPORTAR $contatosSelecionados CLIENTE(S) SELECIONADOS',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
