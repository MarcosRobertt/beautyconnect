import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../controllers/estoque_controller.dart';
import '../models/insumo.dart';

class EstoqueScreen extends ConsumerStatefulWidget {
  const EstoqueScreen({super.key});

  @override
  ConsumerState<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends ConsumerState<EstoqueScreen> {
  String _filtroBusca = '';
  String _categoriaSelecionada = 'Todas';
  bool _mostrarApenasAlertas = false;
  DateTime _mesFiltro = DateTime.now(); 

  // 🎨 NOVA IDENTIDADE VISUAL (VERDE SÁLVIA)
  final Color _primaryColor = const Color(0xFF3A4E40); // Verde Escuro Principal
  final Color _lightAccent = const Color(0xFFE8EFEA);  // Verde Claro (Fundos)
  final Color _borderAccent = const Color(0xFFB5C4B9); // Verde Intermédio (Bordas)

  void _abrirModalInsumo(BuildContext context, [Insumo? insumoExistente]) {
    final nomeController = TextEditingController(text: insumoExistente?.nome ?? '');
    final categoriaController = TextEditingController(text: insumoExistente?.categoria ?? 'Géis e Acrílicos');
    final quantidadeController = TextEditingController(text: insumoExistente?.quantidade.toString() ?? '1');
    
    bool semEstoqueMinimo = (insumoExistente?.estoqueMinimo ?? 1) < 0;
    final estoqueMinimoController = TextEditingController(text: semEstoqueMinimo ? '0' : (insumoExistente?.estoqueMinimo.toString() ?? '1'));
    final precoController = TextEditingController(text: insumoExistente?.precoPago.toStringAsFixed(2) ?? '0.00');
    DateTime dataCompra = insumoExistente?.dataCompra ?? DateTime.now();
    
    final List<String> categorias = ['Géis e Acrílicos', 'Preparadores', 'Esmaltes', 'Esmalte em Gel', 'Descartáveis', 'Ferramentas', 'Móveis e Aparelhos', 'Outros'];
    if (!categorias.contains(categoriaController.text) && categoriaController.text.isNotEmpty) categorias.add(categoriaController.text);

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(insumoExistente == null ? 'Novo Insumo / Produto' : 'Editar Insumo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                    const SizedBox(height: 16),
                    TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categoriaController.text, decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                      items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) { if (v != null) setModalState(() => categoriaController.text = v); },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: quantidadeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qtd. Atual', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: estoqueMinimoController, keyboardType: TextInputType.number, enabled: !semEstoqueMinimo, decoration: InputDecoration(labelText: 'Qtd. Mínima', border: const OutlineInputBorder(), filled: semEstoqueMinimo, fillColor: Colors.grey.shade100))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: semEstoqueMinimo, contentPadding: EdgeInsets.zero, title: const Text('Não exige estoque mínimo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      activeColor: _primaryColor,
                      controlAffinity: ListTileControlAffinity.leading, onChanged: (val) { setModalState(() { semEstoqueMinimo = val ?? false; estoqueMinimoController.text = semEstoqueMinimo ? '0' : '1'; }); },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: precoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço Pago (R\$)', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async { 
                              final picked = await showDatePicker(
                                context: context, initialDate: dataCompra, firstDate: DateTime(2020), lastDate: DateTime.now(),
                                builder: (context, child) { return Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)), child: child!); }
                              ); 
                              if (picked != null) setModalState(() => dataCompra = picked); 
                            }, 
                            child: InputDecorator(decoration: const InputDecoration(labelText: 'Data Compra', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(dataCompra), style: const TextStyle(fontSize: 13)))
                          )
                        ),
                      ],
                    ),
                    
                    // 📜 BLOCO VISUAL DO HISTÓRICO DE PREÇOS (Auditoria)
                    if (insumoExistente != null && insumoExistente.historicoPrecos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [Icon(Icons.history, size: 16, color: Colors.grey), SizedBox(width: 6), Text('Histórico de Preços (Auditoria)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))]),
                            const SizedBox(height: 8),
                            ...insumoExistente.historicoPrecos.map((h) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(h, style: TextStyle(fontSize: 11, color: h.startsWith('⬆️') ? Colors.red.shade800 : Colors.blue.shade800, fontWeight: FontWeight.w500)),
                            )),
                          ],
                        )
                      )
                    ],

                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _primaryColor),
                      icon: const Icon(Icons.check), label: Text(insumoExistente == null ? 'Cadastrar Produto' : 'Salvar Alterações'),
                      onPressed: () {
                        if (nomeController.text.trim().isEmpty) return;

                        // 🧠 MATEMÁTICA DA INFLAÇÃO
                        final novoPreco = double.tryParse(precoController.text.replaceAll(',', '.')) ?? 0.0;
                        final precoAntigo = insumoExistente?.precoPago ?? novoPreco;
                        
                        List<String> historicoAuditoria = List.from(insumoExistente?.historicoPrecos ?? []);
                        String? alertaInflacao;
                        Color corDoAlerta = Colors.green;

                        if (insumoExistente != null && novoPreco != precoAntigo) {
                          final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
                          final dataAtual = DateFormat('dd/MM/yyyy').format(DateTime.now());
                          final diferenca = novoPreco - precoAntigo;
                          final porcentagem = precoAntigo > 0 ? (diferenca / precoAntigo) * 100 : 0.0;

                          if (diferenca > 0) {
                            historicoAuditoria.insert(0, '⬆️ $dataAtual: Subiu de ${fmt.format(precoAntigo)} para ${fmt.format(novoPreco)} (+${porcentagem.toStringAsFixed(1)}%)');
                            alertaInflacao = '⚠️ INFLAÇÃO DETECTADA! Produto encareceu ${porcentagem.toStringAsFixed(1)}%.';
                            corDoAlerta = Colors.orange.shade900;
                          } else {
                            historicoAuditoria.insert(0, '⬇️ $dataAtual: Caiu de ${fmt.format(precoAntigo)} para ${fmt.format(novoPreco)} (${porcentagem.toStringAsFixed(1)}%)');
                            alertaInflacao = '📉 Produto mais barato! Sua margem de lucro vai aumentar.';
                            corDoAlerta = Colors.blue.shade700;
                          }
                        }
                        
                        final novoInsumo = Insumo(
                          id: insumoExistente?.id ?? '', 
                          nome: nomeController.text.trim(), 
                          categoria: categoriaController.text,
                          quantidade: int.tryParse(quantidadeController.text) ?? 1, 
                          estoqueMinimo: semEstoqueMinimo ? -1 : (int.tryParse(estoqueMinimoController.text) ?? 1),
                          precoPago: novoPreco,  
                          dataCompra: dataCompra,
                          servicosVinculados: insumoExistente?.servicosVinculados ?? [], 
                          ciclosDeUso: insumoExistente?.ciclosDeUso ?? [], 
                          historicoPrecos: historicoAuditoria, 
                        );

                        ref.read(estoqueControllerProvider.notifier).salvar(novoInsumo);
                        Navigator.pop(context);

                        if (alertaInflacao != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(alertaInflacao, style: const TextStyle(fontWeight: FontWeight.bold)),
                            backgroundColor: corDoAlerta,
                            duration: const Duration(seconds: 6),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                          ));
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final estoqueAsync = ref.watch(estoqueControllerProvider);
    final fmtMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fmtData = DateFormat('dd/MM/yyyy');

    final controleMes = Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: Icon(Icons.chevron_left, color: _primaryColor), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month - 1)); }),
          Text(DateFormat('MMMM yyyy', 'pt_BR').format(_mesFiltro).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryColor)),
          IconButton(icon: Icon(Icons.chevron_right, color: _primaryColor), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + 1)); }),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9), // Fundo Geral Suave Sálvia
      appBar: AppBar(
        title: const Text('Estoque e Insumos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _lightAccent.withOpacity(0.5),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle, color: _primaryColor, size: 28),
            tooltip: 'Cadastrar Novo Insumo',
            onPressed: () => _abrirModalInsumo(context),
          )
        ],
      ),
      body: estoqueAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: _primaryColor)),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (insumos) {
          final inicioMes = DateTime(_mesFiltro.year, _mesFiltro.month, 1);
          final fimMes = DateTime(_mesFiltro.year, _mesFiltro.month + 1, 0, 23, 59, 59);
          
          double gastoMes = 0; 
          int itensEmAlerta = 0;
          final Set<String> categoriasSet = {'Todas'};

          for (final i in insumos) {
            if (i.emAlerta && i.estoqueMinimo >= 0) itensEmAlerta++;
            if (i.categoria.isNotEmpty) categoriasSet.add(i.categoria);
            
            bool condicaoCat = _categoriaSelecionada == 'Todas' || i.categoria == _categoriaSelecionada;
            if (i.dataCompra.isAfter(inicioMes.subtract(const Duration(seconds: 1))) && 
                i.dataCompra.isBefore(fimMes.add(const Duration(seconds: 1))) && condicaoCat) {
              gastoMes += (i.precoPago * i.quantidade); 
            }
          }

          final List<String> listaCategorias = categoriasSet.toList()..sort();
          if (!listaCategorias.contains(_categoriaSelecionada)) _categoriaSelecionada = 'Todas';

          final insumosGeral = insumos.where((i) {
            final condicaoBusca = i.nome.toLowerCase().contains(_filtroBusca.toLowerCase()) || i.categoria.toLowerCase().contains(_filtroBusca.toLowerCase());
            final condicaoAlerta = _mostrarApenasAlertas ? (i.emAlerta && i.estoqueMinimo >= 0) : true;
            final condicaoCategoria = _categoriaSelecionada == 'Todas' || i.categoria == _categoriaSelecionada;
            return condicaoBusca && condicaoAlerta && condicaoCategoria;
          }).toList();

          return Column(
            children: [
              controleMes,
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Cartão de Compras (Agora elegante neutro)
                    Expanded(
                      child: Card(
                        elevation: 0, 
                        color: Colors.blueGrey.shade50, 
                        child: Padding(
                          padding: const EdgeInsets.all(12.0), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              Text('Compras no Mês', style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold)), 
                              const SizedBox(height: 4), 
                              Text(fmtMoeda.format(gastoMes), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900))
                            ]
                          )
                        )
                      )
                    ),
                    const SizedBox(width: 8),
                    // Cartão de Alertas (Mantém semáforo verde/vermelho, mas mais leve)
                    Expanded(
                      child: Card(
                        elevation: _mostrarApenasAlertas ? 2 : 0, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _mostrarApenasAlertas ? Colors.red.shade300 : Colors.transparent, width: _mostrarApenasAlertas ? 2 : 0)), 
                        color: itensEmAlerta > 0 ? Colors.red.shade50 : _lightAccent, 
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12), 
                          onTap: () { setState(() { _mostrarApenasAlertas = !_mostrarApenasAlertas; }); }, 
                          child: Padding(
                            padding: const EdgeInsets.all(12.0), 
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                  children: [
                                    Text('Alertas', style: TextStyle(fontSize: 11, color: itensEmAlerta > 0 ? Colors.red.shade900 : _primaryColor, fontWeight: FontWeight.bold)), 
                                    if (_mostrarApenasAlertas) Icon(Icons.filter_alt, size: 14, color: Colors.red.shade900)
                                  ]
                                ), 
                                const SizedBox(height: 4), 
                                Text('$itensEmAlerta produtos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: itensEmAlerta > 0 ? Colors.red.shade900 : _primaryColor))
                              ]
                            )
                          )
                        )
                      )
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildAbaLista(insumosGeral, listaCategorias, fmtData),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAbaLista(List<Insumo> insumosFiltrados, List<String> listaCategorias, DateFormat fmtData) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), 
          child: TextField(
            decoration: const InputDecoration(hintText: 'Buscar insumo por nome...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), filled: true, fillColor: Colors.white), 
            onChanged: (v) => setState(() => _filtroBusca = v)
          )
        ),
        
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), itemCount: listaCategorias.length,
            itemBuilder: (context, index) {
              final cat = listaCategorias[index]; final isSelected = _categoriaSelecionada == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected, selectedColor: _primaryColor, backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: _borderAccent)),
                  onSelected: (selected) { if(selected) setState(() => _categoriaSelecionada = cat); }
                )
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        
        Expanded(
          child: insumosFiltrados.isEmpty 
            ? const Center(child: Text('Nenhum insumo encontrado nesta categoria.', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
            itemCount: insumosFiltrados.length,
            itemBuilder: (context, index) {
              final item = insumosFiltrados[index];
              final isAlerta = item.emAlerta && item.estoqueMinimo >= 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _borderAccent)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: isAlerta ? Colors.red.shade100 : _lightAccent, child: Icon(isAlerta ? Icons.warning_amber : Icons.inventory_2, color: isAlerta ? Colors.red.shade800 : _primaryColor, size: 20)),
                  title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.categoria} • Armário: ${item.quantidade} un', style: TextStyle(color: isAlerta ? Colors.red.shade700 : Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(onTap: () => _abrirModalInsumo(context, item), child: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey)),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Excluir Produto?'),
                              content: Text('Tem certeza que deseja excluir "${item.nome}" do estoque?\nEsta ação não poderá ser desfeita.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ref.read(estoqueControllerProvider.notifier).deletar(item.id);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto excluído com sucesso!'), backgroundColor: Colors.red));
                                  },
                                  child: const Text('Sim, Excluir'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300)
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
