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

  final List<String> _categorias = [
    'Transporte', 'Alimentação', 'Insumos', 'Juros de Cartão',
    'Equipamentos', 'Saúde', 'Cuidados Pessoais', 'Vestuário',
    'Manutenção', 'Lazer', 'Outras Despesas'
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
          final despesas = despesasRaw.where((d) {
            if (_filtroStatus == 'PAGAS') return d.status == 'PAGO';
            if (_filtroStatus == 'NAO_PAGAS') return d.status == 'PENDENTE';
            return true;
          }).toList();

          final totalMes = despesasRaw.fold(0.0, (sum, item) => sum + item.valor);
          final totalAPagar = despesasRaw.where((d) => d.status == 'PENDENTE').fold(0.0, (sum, item) => sum + item.valor);

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
                            Text(_filtroStatus.replaceAll('_', ' '), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
                            PopupMenuButton<String>(
                              initialValue: _filtroStatus,
                              icon: const Icon(Icons.tune, color: primaryColor),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _CardResumo(titulo: 'Total do Mês', valor: totalMes, cor: Colors.blueGrey)),
                        const SizedBox(width: 12),
                        Expanded(child: _CardResumo(titulo: 'A Pagar', valor: totalAPagar, cor: Colors.redAccent)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: despesas.length,
                  itemBuilder: (context, index) {
                    final d = despesas[index];
                    final subtipo = d.tipo == 'PARCELADA' ? 'PARCELADA (${d.parcelaAtual}/${d.totalParcelas})' : d.tipo;
                    final pago = d.status == 'PAGO';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(d.descricao, style: const TextStyle(fontWeight: FontWeight.bold))),
                            Text('R\$ ${d.valor.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0), // Ajustado de EdgeInsets.top para EdgeInsets.only
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🏷️ $subtipo • ${d.categoria}', style: const TextStyle(fontSize: 11)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(DateFormat('dd/MM').format(d.dataVencimento), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: pago ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                                    child: Text(pago ? 'PAGO ✅' : 'NÃO PAGO ⏳', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pago ? Colors.green.shade700 : Colors.orange.shade700)),
                                  )
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
  const _FormularioDespesa({required this.categorias, required this.mesReferencia});
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

  void _salvar() async {
    if (_descController.text.isEmpty || _valorController.text.isEmpty || _categoriaSelecionada == null) return;
    
    setState(() => _salvando = true);
    final valorStr = _valorController.text.replaceAll(',', '.');
    
    final despesa = Despesa(
      id: '',
      descricao: _descController.text.trim(),
      valor: double.tryParse(valorStr) ?? 0.0,
      categoria: _categoriaSelecionada!,
      tipo: _tipo,
      dataVencimento: DateTime.now(),
      dataPagamento: _pago ? DateTime.now() : null,
      status: _pago ? 'PAGO' : 'PENDENTE',
      totalParcelas: _tipo == 'PARCELADA' ? int.tryParse(_parcelasController.text) : null,
    );

    await ref.read(despesaControllerProvider.notifier).salvarDespesa(despesa);
    await ref.read(despesaControllerProvider.notifier).carregarDespesasMes(widget.mesReferencia);
    
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('➕ Nova Despesa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8A2463))),
          const SizedBox(height: 16),
          TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()), textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 16),
          
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'REGULAR', label: Text('Regular')),
              ButtonSegment(value: 'FIXA', label: Text('Fixa')),
              ButtonSegment(value: 'PARCELADA', label: Text('Parcelada')),
            ],
            selected: {_tipo},
            onSelectionChanged: (val) => setState(() => _tipo = val.first),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: TextField(controller: _valorController, decoration: const InputDecoration(labelText: 'Valor Total (R\$)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              if (_tipo == 'PARCELADA') ...[
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _parcelasController, decoration: const InputDecoration(labelText: 'Nº Parcelas', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
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
                child: _salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('SALVAR DESPESA')
              ),
            ],
          )
        ],
      ),
    );
  }
}
