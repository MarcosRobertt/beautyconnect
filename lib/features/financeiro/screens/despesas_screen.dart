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

  final List<String> _categorias = [
    'Insumos de Atendimento',
    'Estrutura & Ocupação',
    'Equipamentos & Manutenção',
    'Taxas & Tarifas Financeiras',
    'Marketing & Divulgação',
    'Sistemas & Operacional',
    'Retirada & Pró-Labore',
    'Despesas Gerais',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(despesaControllerProvider.notifier).carregarDespesasMes(_mesSelecionado));
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
          Navigator.pop(context); // Fecha o modal primeiro
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

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF8A2463);
    final despesasAsync = ref.watch(despesaControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0F4),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (despesasRaw) {
          final despesasFiltradas = despesasRaw.where((d) {
            final bateStatus = _filtroStatus == 'TODAS' ||
                (_filtroStatus == 'PAGAS' && d.status == 'PAGO') ||
                (_filtroStatus == 'NAO_PAGAS' && d.status == 'PENDENTE');
            final bateCategoria = _filtroCategoria == 'TODAS' || d.categoria == _filtroCategoria;
            return bateStatus && bateCategoria;
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
                          'Exibindo: ${_filtroStatus.replaceAll('_', ' ')} • $_filtroCategoria',
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
                    ? Center(child: Text('Nenhuma despesa encontrada.', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: despesasFiltradas.length,
                        itemBuilder: (context, index) {
                          final d = despesasFiltradas[index];
                          final subtipo = d.tipo == 'PARCELADA' ? 'PARCELADA (${d.parcelaAtual}/${d.totalParcelas})' : d.tipo;
                          final pago = d.status == 'PAGO';

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
                                    Text('🏷️ $subtipo • ${d.categoria}', style: const TextStyle(fontSize: 11)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(DateFormat('dd/MM').format(d.dataVencimento), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        const Spacer(),
                                        // O botão "Marcar Pago" continua aqui pois é uma ação muito usada
                                        InkWell(
                                          onTap: () => ref.read(despesaControllerProvider.notifier).alternarStatusDespesa(d, _mesSelecionado),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('R\$ ${valor.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor)),
        ],
      ),
    );
  }
}

class _FormularioDespesa extends ConsumerStatefulWidget {
  final List<String> categorias;
  final DateTime mesReferencia;
  
  // Variáveis extras para injetar dados na Edição
  final Despesa? despesaEdit;
  final VoidCallback? onExcluir;
  final VoidCallback? onCopiar;

  const _FormularioDespesa({
    required this.categorias, 
    required this.mesReferencia, 
    this.despesaEdit, 
    this.onExcluir, 
    this.onCopiar
  });
  
  @override
  ConsumerState<_FormularioDespesa> createState() => _FormularioDespesaState();
}

class _FormularioDespesaState extends ConsumerState<_FormularioDespesa> {
  String _tipo = 'REGULAR'; 
  String? _categoriaSelecionada;
  final _descController = TextEditingController();
  final _valorController = TextEditingController();
  final _parcelasController = TextEditingController(text: '1');
  bool _pago = false;
  bool _salvando = false;
  late DateTime _dataSelecionada;

  @override
  void initState() {
    super.initState();
    
    // Se for uma Edição, preenche todos os campos com os dados existentes!
    if (widget.despesaEdit != null) {
      final d = widget.despesaEdit!;
      _descController.text = d.descricao;
      _valorController.text = d.valor.toStringAsFixed(2).replaceAll('.', ',');
      _categoriaSelecionada = d.categoria;
      _tipo = d.tipo == 'PARCELADA' ? 'PARCELADA' : d.tipo;
      _pago = d.status == 'PAGO';
      _dataSelecionada = d.dataVencimento;
      if (d.totalParcelas != null) {
        _parcelasController.text = d.totalParcelas.toString();
      }
    } else {
      // Se for uma Nova Despesa
      final hoje = DateTime.now();
      if (widget.mesReferencia.year == hoje.year && widget.mesReferencia.month == hoje.month) {
        _dataSelecionada = hoje;
      } else {
        _dataSelecionada = DateTime(widget.mesReferencia.year, widget.mesReferencia.month, 1);
      }
    }
  }

  void _salvar() async {
    if (_descController.text.isEmpty || _valorController.text.isEmpty || _categoriaSelecionada == null) return;
    
    setState(() => _salvando = true);
    final valorStr = _valorController.text.replaceAll(',', '.');

    final despesa = Despesa(
      id: widget.despesaEdit?.id ?? '', // Se tiver editando, mantem o ID original!
      descricao: _descController.text.trim(),
      valor: double.tryParse(valorStr) ?? 0.0,
      categoria: _categoriaSelecionada!,
      tipo: _tipo,
      dataVencimento: _dataSelecionada, // Campo atualizado
      dataPagamento: _pago ? _dataSelecionada : null,
      status: _pago ? 'PAGO' : 'PENDENTE',
      
      // Preserva informações vitais de parcelamento caso seja uma edição
      totalParcelas: widget.despesaEdit?.totalParcelas ?? (_tipo == 'PARCELADA' ? int.tryParse(_parcelasController.text) : null),
      parcelaAtual: widget.despesaEdit?.parcelaAtual,
      idAgrupador: widget.despesaEdit?.idAgrupador,
    );

    await ref.read(despesaControllerProvider.notifier).salvarDespesa(despesa);
    await ref.read(despesaControllerProvider.notifier).carregarDespesasMes(widget.mesReferencia, forcarServidor: true);
    
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ehEdicao = widget.despesaEdit != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // CABEÇALHO COM AÇÕES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ehEdicao ? '✏️ Editar Despesa' : '➕ Nova Despesa', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8A2463))
              ),
              if (ehEdicao)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.blueGrey),
                      tooltip: 'Copiar para o próximo mês',
                      onPressed: widget.onCopiar,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Excluir Lançamento',
                      onPressed: widget.onExcluir,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // CAMPO: Data de Vencimento
          InkWell(
            onTap: () async {
              final dt = await showDatePicker(
                context: context,
                initialDate: _dataSelecionada,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(primary: Color(0xFF8A2463)),
                    ),
                    child: child!,
                  );
                },
              );
              if (dt != null) setState(() => _dataSelecionada = dt);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data de Vencimento', // Renomeado para fluxo de caixa mais claro
                border: OutlineInputBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('dd/MM/yyyy').format(_dataSelecionada), style: const TextStyle(fontSize: 16)),
                  const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _descController, 
            decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()), 
            textCapitalization: TextCapitalization.sentences
          ),
          const SizedBox(height: 16),
          
          // Se for edição, desabilita a mudança de "Tipo" para não desconfigurar parcelas em lote
          IgnorePointer(
            ignoring: ehEdicao,
            child: Opacity(
              opacity: ehEdicao ? 0.6 : 1.0,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'REGULAR', label: Text('Regular')),
                  ButtonSegment(value: 'FIXA', label: Text('Fixa')),
                  ButtonSegment(value: 'PARCELADA', label: Text('Parcelada')),
                ],
                selected: {_tipo},
                onSelectionChanged: (val) => setState(() => _tipo = val.first),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: TextField(
                controller: _valorController, 
                decoration: const InputDecoration(labelText: 'Valor Total (R\$)', border: OutlineInputBorder()), 
                keyboardType: const TextInputType.numberWithOptions(decimal: true)
              )),
              if (_tipo == 'PARCELADA') ...[
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _parcelasController, 
                  decoration: const InputDecoration(labelText: 'Nº Parcelas', border: OutlineInputBorder()), 
                  keyboardType: TextInputType.number,
                  enabled: !ehEdicao, // Bloqueia alterar qtde parcelas na edição
                )),
              ]
            ],
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
            value: _categoriaSelecionada,
            items: widget.categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _categoriaSelecionada = val),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Já está pago?'),
            value: _pago,
            onChanged: (val) => setState(() => _pago = val),
            activeColor: const Color(0xFF8A2463),
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8A2463)), 
                onPressed: _salvando ? null : _salvar, 
                child: _salvando 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text(ehEdicao ? 'ATUALIZAR DESPESA' : 'SALVAR DESPESA')
              ),
            ],
          )
        ],
      ),
    );
  }
}
