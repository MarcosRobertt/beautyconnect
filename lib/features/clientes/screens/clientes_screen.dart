import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

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

  String _filtroTop = 'faturamento';
  String _filtroTodos = 'todos';
  String _filtroInativos = 'todos_inativos';

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

  void _abrirModalImportacao(List<Cliente> clientesExistentes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _ModalImportacaoContatos(clientesExistentes: clientesExistentes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clienteControllerProvider);
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return clientesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Clientes')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Clientes')),
        body: Center(child: Text('Erro ao carregar clientes: $e')),
      ),
      data: (todosClientes) {
        final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

        // Top Clientes
        final topClientes = List<Cliente>.from(todosClientes.where((c) => c.totalVisitas > 0));
        if (_filtroTop == 'faturamento') {
          topClientes.sort((a, b) => b.totalGasto.compareTo(a.totalGasto));
        } else {
          topClientes.sort((a, b) => b.totalVisitas.compareTo(a.totalVisitas));
        }

        // Recorrência e Inativos
        final recorrencia = <Cliente>[];
        final inativos = <Cliente>[];

        for (var c in todosClientes) {
          final dataRef = c.ultimaVisita ?? c.createdAt;
          final refZerada = DateTime(dataRef.year, dataRef.month, dataRef.day);
          final dias = hojeZerado.difference(refZerada).inDays;

          if (dias >= 15 && dias < 30) {
            recorrencia.add(c);
          } else if (dias >= 30) {
            inativos.add(c);
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Clientes'),
            actions: [
              TextButton.icon(
                onPressed: () => _abrirModalImportacao(todosClientes),
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
          body: TabBarView(
            controller: _tabController,
            children: [
              _construirAbaTodos(todosClientes, moeda),
              _construirAbaTopClientes(topClientes, moeda),
              _construirAbaListaSimples(recorrencia, 'Clientes sem agendar entre 15 e 30 dias', moeda),
              _construirAbaInativos(inativos, moeda),
            ],
          ),
        );
      },
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
                : _construirListView(listaFinal, moeda),
          ),
        ],
      ),
    );
  }

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
                ? const Center(child: Text('Nenhuma cliente com atendimento concluído.', style: TextStyle(color: Colors.grey)))
                : _construirListView(listaTop, moeda),
          ),
        ],
      ),
    );
  }

  Widget _construirAbaInativos(List<Cliente> listaBase, NumberFormat moeda) {
    final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    List<Cliente> filtradosPorChip = listaBase.where((c) {
      final ref = c.ultimaVisita ?? c.createdAt;
      final dias = hojeZerado.difference(DateTime(ref.year, ref.month, ref.day)).inDays;

      if (_filtroInativos == '45') return dias >= 45;
      if (_filtroInativos == '90') return dias >= 90;
      return true;
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
                  label: const Text('Todas Inativas', style: TextStyle(fontSize: 12)),
                  selected: _filtroInativos == 'todos_inativos',
                  selectedColor: Colors.purple.shade100,
                  onSelected: (val) => setState(() => _filtroInativos = 'todos_inativos'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('> 45 dias', style: TextStyle(fontSize: 12)),
                  selected: _filtroInativos == '45',
                  selectedColor: Colors.purple.shade100,
                  onSelected: (val) => setState(() => _filtroInativos = '45'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('> 90 dias', style: TextStyle(fontSize: 12)),
                  selected: _filtroInativos == '90',
                  selectedColor: Colors.purple.shade100,
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

  Widget _construirAbaListaSimples(List<Cliente> listaBase, String subtitulo, NumberFormat moeda) {
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

  Widget _construirListView(List<Cliente> lista, NumberFormat moeda, {bool isInativo = false}) {
    final hojeZerado = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return ListView.separated(
      itemCount: lista.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final cliente = lista[index];
        
        final dataFormatada = cliente.ultimaVisita != null 
            ? DateFormat('dd/MM/yyyy').format(cliente.ultimaVisita!) 
            : 'Nenhum atendimento';

        int dias = 0;
        if (cliente.ultimaVisita != null) {
           final ref = DateTime(cliente.ultimaVisita!.year, cliente.ultimaVisita!.month, cliente.ultimaVisita!.day);
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
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('📱 ${cliente.telefone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('🔄 Visitas: ${cliente.totalVisitas}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(width: 16),
                  Text('💰 Gasto: ${moeda.format(cliente.totalGasto)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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

// =========================================================================
// MODAL REAL DE IMPORTAÇÃO DE CONTATOS DO CELULAR
// =========================================================================
class _ItemContatoImportacao {
  final String nome;
  final String telefone;
  bool selecionado;
  bool jaCadastrado;

  _ItemContatoImportacao({
    required this.nome,
    required this.telefone,
    this.selecionado = false,
    this.jaCadastrado = false,
  });
}

class _ModalImportacaoContatos extends ConsumerStatefulWidget {
  final List<Cliente> clientesExistentes;

  const _ModalImportacaoContatos({required this.clientesExistentes});

  @override
  ConsumerState<_ModalImportacaoContatos> createState() => _ModalImportacaoContatosState();
}

class _ModalImportacaoContatosState extends ConsumerState<_ModalImportacaoContatos> {
  final TextEditingController _buscaController = TextEditingController();
  List<_ItemContatoImportacao> _todosContatos = [];
  List<_ItemContatoImportacao> _contatosFiltrados = [];
  bool _carregando = true;
  bool _semPermissao = false;
  bool _salvando = false;
  bool _selecionarTodos = false;

  @override
  void initState() {
    super.initState();
    _carregarContatosReais();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String _limparTelefone(String f) {
    return f.replaceAll(RegExp(r'[^\d]'), '');
  }

  Future<void> _carregarContatosReais() async {
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (mounted) setState(() { _semPermissao = true; _carregando = false; });
        return;
      }

      final contatos = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      
      final telefonesExistentes = widget.clientesExistentes
          .map((c) => _limparTelefone(c.telefone))
          .where((t) => t.isNotEmpty)
          .toSet();

      final List<_ItemContatoImportacao> lista = [];

      for (var c in contatos) {
        if (c.phones.isEmpty) continue;

        for (var phone in c.phones) {
          final rawPhone = phone.number;
          final cleanPhone = _limparTelefone(rawPhone);

          if (cleanPhone.length < 8) continue; // Descarta números inválidos

          final nomeExibicao = c.displayName.isNotEmpty 
              ? c.displayName 
              : '${c.name.first} ${c.name.last}'.trim();

          if (nomeExibicao.isEmpty) continue;

          final jaExiste = telefonesExistentes.contains(cleanPhone);

          lista.add(_ItemContatoImportacao(
            nome: nomeExibicao,
            telefone: rawPhone,
            selecionado: false,
            jaCadastrado: jaExiste,
          ));
        }
      }

      // Ordena alfabeticamente
      lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      if (mounted) {
        setState(() {
          _todosContatos = lista;
          _contatosFiltrados = lista;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _carregando = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ler agenda: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filtrarLista(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _contatosFiltrados = _todosContatos;
      } else {
        _contatosFiltrados = _todosContatos
            .where((c) => c.nome.toLowerCase().contains(q) || c.telefone.contains(q))
            .toList();
      }
    });
  }

  void _alternarTodos(bool? valor) {
    final v = valor ?? false;
    setState(() {
      _selecionarTodos = v;
      for (var c in _contatosFiltrados) {
        if (!c.jaCadastrado) {
          c.selecionado = v;
        }
      }
    });
  }

  Future<void> _importarSelecionados() async {
    final selecionados = _todosContatos.where((c) => c.selecionado && !c.jaCadastrado).toList();
    if (selecionados.isEmpty) return;

    setState(() => _salvando = true);

    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();
      int contador = 0;

      for (var item in selecionados) {
        final docRef = firestore.collection('clientes').doc();
        final novoCliente = Cliente(
          id: docRef.id,
          nome: item.nome,
          telefone: item.telefone,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        batch.set(docRef, novoCliente.toJson());
        contador++;

        if (contador >= 400) {
          await batch.commit();
          batch = firestore.batch();
          contador = 0;
        }
      }

      if (contador > 0) {
        await batch.commit();
      }

      ref.invalidate(clienteControllerProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selecionados.length} clientes importadas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selecionadosCount = _todosContatos.where((c) => c.selecionado && !c.jaCadastrado).length;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 16),
                    Text('Lendo a agenda do celular...'),
                  ],
                ),
              )
            : _semPermissao
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_cell, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('Permissão para ler contatos negada.', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Habilite a permissão de contatos nas configurações do celular.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _carregarContatosReais,
                          child: const Text('Tentar Novamente'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('📥 Importar da Agenda (${_todosContatos.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _buscaController,
                        decoration: InputDecoration(
                          hintText: 'Buscar contato na sua agenda...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _buscaController.text.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _buscaController.clear(); _filtrarLista(''); })
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: _filtrarLista,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Selecionar Todos visíveis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        value: _selecionarTodos,
                        activeColor: Colors.purple,
                        onChanged: _alternarTodos,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _contatosFiltrados.isEmpty
                            ? const Center(child: Text('Nenhum contato encontrado.', style: TextStyle(color: Colors.grey)))
                            : ListView.separated(
                                itemCount: _contatosFiltrados.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _contatosFiltrados[index];
                                  return CheckboxListTile(
                                    enabled: !item.jaCadastrado,
                                    title: Text(
                                      item.nome,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: item.jaCadastrado ? Colors.grey : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      item.jaCadastrado ? '📱 ${item.telefone} (Já cadastrada)' : '📱 ${item.telefone}',
                                      style: TextStyle(color: item.jaCadastrado ? Colors.green.shade700 : Colors.grey.shade700, fontSize: 12),
                                    ),
                                    value: item.jaCadastrado ? false : item.selecionado,
                                    activeColor: Colors.purple,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: item.jaCadastrado ? null : (bool? val) {
                                      setState(() {
                                        item.selecionado = val ?? false;
                                        _selecionarTodos = _contatosFiltrados.every((c) => c.jaCadastrado || c.selecionado);
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
                          backgroundColor: selecionadosCount > 0 ? Colors.green : Colors.grey,
                        ),
                        onPressed: (selecionadosCount > 0 && !_salvando) ? _importarSelecionados : null,
                        child: _salvando
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'IMPORTAR $selecionadosCount CLIENTE(S)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
