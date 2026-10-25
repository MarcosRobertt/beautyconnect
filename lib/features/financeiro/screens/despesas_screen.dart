import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/despesa_controller.dart';
import '../models/despesa.dart';

class DespesasScreen extends ConsumerStatefulWidget {
  const DespesasScreen({super.key});
  @override
  ConsumerState<DespesasScreen> createState() => _DespesasScreenState();
}

class _DespesasScreenState extends ConsumerState<DespesasScreen> {
  DateTime _mesSelecionado = DateTime.now();
  String _filtroStatus = 'TODAS'; 
  String _filtroCategoria = 'TODAS';
  
  // 🎯 NOVO: Controlador para a barra de pesquisa
  final TextEditingController _buscaController = TextEditingController();

  // 🛡️ A NOVA CATEGORIA ESTÁ AQUI
  final List<String> _categorias = [
    'Insumos Studio',
    'Insumos de Atendimento',
    'Estrutura & Ocupação',
    'Equipamentos & Manutenção',
    'Taxas & Tarifas Financeiras',
    'Marketing & Divulgação',
    'Sistemas & Operacional',
    'Retirada & Pró-Labore',
    'Despesas Gerais',
    'Ajuste de Caixa / Estorno', 
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(despesaControllerProvider.notifier).carregarDespesasMes(_mesSelecionado));
  }
  
  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _abrirModalNovaDespesa() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _FormularioDespesa(categorias: _categorias, mesReferencia: _mesSelecionado),
    );
  }

  void _abrirModalEdicao(Despesa despesa) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _FormularioDespesa(
        categorias: _categorias, 
        mesReferencia: _mesSelecionado,
        despesaEdit: despesa,
        onExcluir: () {
          Navigator.pop(context); 
          _confirmarExclusao(despesa.id);
        },
        onCopiar: () async {
          await ref.read(despesaControllerProvider.notifier).duplicarDespesaProximoMes(despesa, _mesSelecionado);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiada para o próximo mês! 📋')));
          }
        },
      ),
    );
  }

  void _confirmarExclusao(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Despesa'),
        content: const Text('Tem certeza que deseja remover este lançamento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(despesaControllerProvider.notifier).excluirDespesa(id, _mesSelecionado);
            },
            child: const Text('EXCLUIR', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _alternarStatusPagamentoRapido(Despesa d) {
    if (d.status == 'PAGO') {
      final atualizada = Despesa(
        id: d.id, descricao: d.descricao, valor: d.valor, categoria: d.categoria,
        tipo: d.tipo, dataVencimento: d.dataVencimento, 
        dataPagamento: null, status: 'PENDENTE', 
        parcelaAtual: d.parcelaAtual, totalParcelas: d.totalParcelas, 
        idAgrupador: d.idAgrupador, formaPagamento: null,
      );
      ref.read(despesaControllerProvider.notifier).salvarDespesa(atualizada).then((_) {
        ref.read(despesaControllerProvider.notifier).carregarDespesasMes(_mesSelecionado);
      });
    } else {
      String formaSelecionada = 'Pix';
      final List<String> formas = ['Pix', 'Dinheiro', 'Cartão de Débito', 'Cartão de Crédito','Boleto', 'Outros'];

      showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Confirmar Baixa', style: TextStyle(fontSize: 18)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Como a despesa "${d.descricao}" foi paga?'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Forma de Pagamento', 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      value: formaSelecionada,
                      items: formas.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (val) => setStateDialog(() => formaSelecionada = val!),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      Navigator.pop(ctx);
                      
                      final atualizada = Despesa(
                        id: d.id, descricao: d.descricao, valor: d.valor, categoria: d.categoria,
                        tipo: d.tipo, dataVencimento: d.dataVencimento, 
                        dataPagamento: DateTime.now(), 
                        status: 'PAGO', 
                        parcelaAtual: d.parcelaAtual, totalParcelas: d.totalParcelas, 
                        idAgrupador: d.idAgrupador, 
                        formaPagamento: formaSelecionada, 
                      );
                      
                      ref.read(despesaControllerProvider.notifier).salvarDespesa(atualizada).then((_) {
                        ref.read(despesaControllerProvider.notifier).carregarDespesasMes(_mesSelecionado);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Despesa paga com sucesso!'), backgroundColor: Colors.green));
                      });
                    },
                    child: const Text('Confirmar'),
                  ),
                ],
              );
            }
          );
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF627970); // 🟢 Atualizado para Verde Condeza
    final despesasAsync = ref.watch(despesaControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F4), // 🟢 Atualizado para Fundo Creme Condeza
      appBar: AppBar(
        title: const Text('Gestão de Despesas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: primaryColor, size: 28),
            onPressed: _abrirModalNovaDespesa,
          )
        ],
      ),
      body: despesasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (despesasRaw) {
          
          final textoBusca = _buscaController.text.trim().toLowerCase();
          
          final despesasFiltradas = despesasRaw.where((d) {
            // Filtro por Nome
            final bateNome = textoBusca.isEmpty || d.descricao.toLowerCase().contains(textoBusca);
            
            // Filtros Originais
            final bateStatus = _filtroStatus == 'TODAS' ||
                (_filtroStatus == 'PAGAS' && d.status == 'PAGO') ||
                (_filtroStatus == 'NAO_PAGAS' && d.status == 'PENDENTE');
            final bateCategoria = _filtroCategoria == 'TODAS' || d.categoria == _filtroCategoria;
            
            return bateNome && bateStatus && bateCategoria;
          }).toList();

          final totalFiltrado = despesasFiltradas.fold(0.0, (sum, item) => sum + item.valor);
          final totalAPagarFiltrado = despesasFiltradas
              .where((d) => d.status == 'PENDENTE')
              .fold(0.0, (sum, item) => sum + item.valor);

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    // 🎯 NOVA BARRA DE PESQUISA
                    TextField(
                      controller: _buscaController,
                      decoration: InputDecoration(
                        hintText: 'Buscar despesa pelo nome...',
                        prefixIcon: const Icon(Icons.search, color: primaryColor),
                        suffixIcon: textoBusca.isNotEmpty 
                          ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _buscaController.clear(); setState(() {}); }) 
                          : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        filled: true,
                        fillColor: const Color(0xFFF7F8F4),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
                              setState(() => _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1));
                              ref.read(despesaControllerProvider.notifier).carregarDespesasMes(_mesSelecionado);
                            }),
                            Text(
                              DateFormat('MMMM yyyy', 'pt_BR').format(_mesSelecionado).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
                              setState(() => _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1));
                              ref.read(despesaControllerProvider.notifier).carregarDespesasMes(_mesSelecionado);
                            }),
                          ],
                        ),
                        Row(
                          children: [
                            PopupMenuButton<String>(
                              initialValue: _filtroCategoria,
                              icon: Icon(Icons.category_outlined, color: _filtroCategoria != 'TODAS' ? primaryColor : Colors.grey),
                              tooltip: 'Filtrar Categoria',
                              onSelected: (val) => setState(() => _filtroCategoria = val),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'TODAS', child: Text('Todas as Categorias')),
                                const PopupMenuDivider(),
                                ..._categorias.map((c) => PopupMenuItem(value: c, child: Text(c))),
                              ],
                            ),
                            PopupMenuButton<String>(
                              initialValue: _filtroStatus,
                              icon: const Icon(Icons.tune, color: primaryColor),
                              tooltip: 'Filtrar Status',
                              onSelected: (val) => setState(() => _filtroStatus = val),
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'TODAS', child: Text('Todas as Despesas')),
                                PopupMenuItem(value: 'PAGAS', child: Text('Apenas Pagas ✅')),
                                PopupMenuItem(value: 'NAO_PAGAS', child: Text('Apenas Não Pagas ⏳')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_filtroStatus != 'TODAS' || _filtroCategoria != 'TODAS')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Exibindo: ${_filtroStatus.replaceAll('_', ' ')} •$_filtroCategoria',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _CardResumo(titulo: 'Total (Filtrado)', valor: totalFiltrado, cor: Colors.blueGrey)),
                        const SizedBox(width: 12),
                        Expanded(child: _CardResumo(titulo: 'A Pagar', valor: totalAPagarFiltrado, cor: Colors.redAccent)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: despesasFiltradas.isEmpty
                    ? Center(child: Text(textoBusca.isNotEmpty ? 'Nenhuma despesa com esse nome.' : 'Nenhuma despesa encontrada.', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: despesasFiltradas.length,
                        itemBuilder: (context, index) {
                          final d = despesasFiltradas[index];
                          final subtipo = d.tipo == 'PARCELADA' ? 'PARCELADA (${d.parcelaAtual}/${d.totalParcelas})' : d.tipo;
                          final pago = d.status == 'PAGO';
                          
                          final txtFormaPgto = pago ? ' • 💳 ${d.formaPagamento ?? "Não informado"}' : '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                            child: ListTile(
                              onTap: () => _abrirModalEdicao(d),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              trailing: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(d.descricao, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  Text('R\$ ${d.valor.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('🏷️ $subtipo • ${d.categoria}$txtFormaPgto', style: const TextStyle(fontSize: 11)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(DateFormat('dd/MM').format(d.dataVencimento), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        const Spacer(),
                                        
                                        InkWell(
                                          onTap: () => _alternarStatusPagamentoRapido(d),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: pago ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                                            child: Text(pago ? 'PAGO ✅' : 'MARCAR PAGO ⏳', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pago ? Colors.green.shade700 : Colors.orange.shade700)),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          );
        },
      ),
    );
  }
}

class _CardResumo extends StatelessWidget {
  final String titulo; final double valor; final Color cor;
  const _CardResumo({required this.titulo, required this.valor, required this.cor});
  @override
  Widget build(
