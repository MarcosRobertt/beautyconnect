import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../controllers/estoque_controller.dart';
import '../models/insumo.dart';

// 💅 LISTA ESPECIALIZADA ATUALIZADA
const List<String> _listaServicosSalao = [
  'Alongamento', 'Banho em gel', 'Blindagem mão', 'Blindagem pé', 
  'Esmaltação', 'Manutenção 15 dias', 'Manutenção 20 dias', 
  'Manutenção banho em gel', 'Mão', 'Pé', 'Mão e pé', 
  'Plástica dos pés', 'Remoção', 'Spa dos pés', 'Unha quebrada'
];

class EstoqueScreen extends ConsumerStatefulWidget {
  const EstoqueScreen({super.key});

  @override
  ConsumerState<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends ConsumerState<EstoqueScreen> {
  String _filtroBusca = '';
  int _abaSelecionada = 0; 
  String _categoriaSelecionada = 'Todas';
  bool _mostrarApenasAlertas = false;
  DateTime _mesFiltro = DateTime.now(); // 📅 Controlador central do mês

  void _abrirModalInsumo(BuildContext context, [Insumo? insumoExistente]) {
    final nomeController = TextEditingController(text: insumoExistente?.nome ?? '');
    final categoriaController = TextEditingController(text: insumoExistente?.categoria ?? 'Géis e Acrílicos');
    final quantidadeController = TextEditingController(text: insumoExistente?.quantidade.toString() ?? '1');
    
    bool semEstoqueMinimo = (insumoExistente?.estoqueMinimo ?? 1) < 0;
    final estoqueMinimoController = TextEditingController(text: semEstoqueMinimo ? '0' : (insumoExistente?.estoqueMinimo.toString() ?? '1'));
    final precoController = TextEditingController(text: insumoExistente?.precoPago.toStringAsFixed(2) ?? '0.00');
    DateTime dataCompra = insumoExistente?.dataCompra ?? DateTime.now();
    
    List<String> servicosVinculados = insumoExistente != null ? List.from(insumoExistente.servicosVinculados) : [];
    bool usadoEmTodos = servicosVinculados.contains('Todos');

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
                    Text(insumoExistente == null ? 'Novo Insumo / Produto' : 'Editar Insumo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categoriaController.text, decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                      items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) { if (v != null) setModalState(() => categoriaController.text = v); },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8), color: Colors.blue.shade50),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.smart_toy_outlined, size: 18, color: Colors.blue.shade800), const SizedBox(width: 8), Text('Vínculo Inteligente (IA)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))]),
                          const SizedBox(height: 8),
                          const Text('Quais serviços consomem este produto?', style: TextStyle(fontSize: 12)),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero, title: const Text('Usado em TODOS os serviços', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Ex: Algodão, Água, Luvas', style: TextStyle(fontSize: 11)), value: usadoEmTodos,
                            onChanged: (val) { setModalState(() { usadoEmTodos = val; if (val) { servicosVinculados = ['Todos']; } else { servicosVinculados.clear(); } }); },
                          ),
                          if (!usadoEmTodos)
                            Wrap(
                              spacing: 6, runSpacing: -8,
                              children: _listaServicosSalao.map((serv) {
                                final isSelected = servicosVinculados.contains(serv);
                                return FilterChip(label: Text(serv, style: const TextStyle(fontSize: 11)), selected: isSelected, onSelected: (val) { setModalState(() { if (val) { servicosVinculados.add(serv); } else { servicosVinculados.remove(serv); } }); });
                              }).toList(),
                            )
                        ],
                      ),
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
                      controlAffinity: ListTileControlAffinity.leading, onChanged: (val) { setModalState(() { semEstoqueMinimo = val ?? false; estoqueMinimoController.text = semEstoqueMinimo ? '0' : '1'; }); },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: precoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço Pago (R\$)', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: InkWell(onTap: () async { final picked = await showDatePicker(context: context, initialDate: dataCompra, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setModalState(() => dataCompra = picked); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Data Compra', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(dataCompra), style: const TextStyle(fontSize: 13))))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.check), label: Text(insumoExistente == null ? 'Cadastrar Produto' : 'Salvar Alterações'),
                      onPressed: () {
                        if (nomeController.text.trim().isEmpty) return;
                        
                        final novoInsumo = Insumo(
                          id: insumoExistente?.id ?? '', 
                          nome: nomeController.text.trim(), 
                          categoria: categoriaController.text,
                          quantidade: int.tryParse(quantidadeController.text) ?? 1, 
                          estoqueMinimo: semEstoqueMinimo ? -1 : (int.tryParse(estoqueMinimoController.text) ?? 1),
                          precoPago: double.tryParse(precoController.text.replaceAll(',', '.')) ?? 0.0, 
                          dataCompra: dataCompra,
                          servicosVinculados: servicosVinculados, 
                          ciclosDeUso: insumoExistente?.ciclosDeUso ?? [], 
                        );

                        ref.read(estoqueControllerProvider.notifier).salvar(novoInsumo);
                        Navigator.pop(context);
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

  void _confirmarIniciaPote(Insumo i) {
    if (i.quantidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você não tem unidades fechadas no estoque!'), backgroundColor: Colors.red));
      return;
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Abrir Novo Pote'), content: Text('Tem certeza que deseja pegar um(a) ${i.nome} novo do estoque e começar a usar hoje?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.green), onPressed: () { Navigator.pop(ctx); ref.read(estoqueControllerProvider.notifier).iniciarPote(i); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pote iniciado! A IA já está contando.'), backgroundColor: Colors.green)); }, child: const Text('Sim, Iniciar')),
      ],
    ));
  }

  void _confirmarFimPote(Insumo i) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Produto Acabou'), content: Text('O seu pote de ${i.nome} chegou ao fim? A IA fechará o ciclo de cálculo de gastos.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () { Navigator.pop(ctx); ref.read(estoqueControllerProvider.notifier).finalizarPoteAberto(i); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ciclo finalizado. Custo rateado!'), backgroundColor: Colors.orange)); }, child: const Text('Sim, Acabou')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF8A2463);
    final estoqueAsync = ref.watch(estoqueControllerProvider);
    final fmtMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fmtData = DateFormat('dd/MM/yyyy');

    // 📅 NOVO: Seletor de Mês isolado e seguro
    final controleMes = Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: primaryColor), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month - 1)); }),
          Text(DateFormat('MMMM yyyy', 'pt_BR').format(_mesFiltro).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
          IconButton(icon: const Icon(Icons.chevron_right, color: primaryColor), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + 1)); }),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0F4),
      appBar: AppBar(
        title: const Text('Estoque e Insumos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _abrirModalInsumo(context), icon: const Icon(Icons.add), label: const Text('Novo Insumo'), backgroundColor: primaryColor, foregroundColor: Colors.white),
      body: estoqueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            
            // 💰 Gasto Dinâmico (Soma as compras feitas apenas NO MÊS filtrado e DA CATEGORIA filtrada)
            bool condicaoCat = _categoriaSelecionada == 'Todas' || i.categoria == _categoriaSelecionada;
            if (i.dataCompra.isAfter(inicioMes.subtract(const Duration(seconds: 1))) && 
                i.dataCompra.isBefore(fimMes.add(const Duration(seconds: 1))) && condicaoCat) {
              gastoMes += (i.precoPago * i.quantidade); // Calcula o valor investido naquele lote
            }
          }

          final List<String> listaCategorias = categoriasSet.toList()..sort();
          if (!listaCategorias.contains(_categoriaSelecionada)) _categoriaSelecionada = 'Todas';

          // Lista final para a tela Lista & Uso
          final insumosGeral = insumos.where((i) {
            final condicaoBusca = i.nome.toLowerCase().contains(_filtroBusca.toLowerCase()) || i.categoria.toLowerCase().contains(_filtroBusca.toLowerCase());
            final condicaoAlerta = _mostrarApenasAlertas ? (i.emAlerta && i.estoqueMinimo >= 0) : true;
            final condicaoCategoria = _categoriaSelecionada == 'Todas' || i.categoria == _categoriaSelecionada;
            return condicaoBusca && condicaoAlerta && condicaoCategoria;
          }).toList();

          return Column(
            children: [
              controleMes, // Mostra o Mês no Topo
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Card(elevation: 0, color: Colors.deepOrange.shade50, child: Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Compras no Mês', style: TextStyle(fontSize: 11, color: Colors.deepOrange.shade900, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(fmtMoeda.format(gastoMes), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade900))])))),
                        const SizedBox(width: 8),
                        Expanded(child: Card(elevation: _mostrarApenasAlertas ? 2 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _mostrarApenasAlertas ? Colors.red.shade400 : Colors.transparent, width: _mostrarApenasAlertas ? 2 : 0)), color: itensEmAlerta > 0 ? Colors.red.shade50 : Colors.green.shade50, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () { setState(() { _mostrarApenasAlertas = !_mostrarApenasAlertas; if (_mostrarApenasAlertas) _abaSelecionada = 0; }); }, child: Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Alertas', style: TextStyle(fontSize: 11, color: itensEmAlerta > 0 ? Colors.red.shade900 : Colors.green.shade900, fontWeight: FontWeight.bold)), if (_mostrarApenasAlertas) Icon(Icons.filter_alt, size: 14, color: Colors.red.shade900)]), const SizedBox(height: 4), Text('$itensEmAlerta produtos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: itensEmAlerta > 0 ? Colors.red.shade900 : Colors.green.shade900))]))))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('📦 Lista & Uso', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 1, label: Text('🧠 IA Custeio', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {_abaSelecionada},
                      onSelectionChanged: (set) => setState(() => _abaSelecionada = set.first),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _abaSelecionada == 0 
                  ? _buildAbaLista(insumosGeral, listaCategorias, fmtData, primaryColor) 
                  : _buildAbaRelatorioIA(fmtMoeda),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAbaLista(List<Insumo> insumosFiltrados, List<String> listaCategorias, DateFormat fmtData, Color primaryColor) {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), child: TextField(decoration: const InputDecoration(hintText: 'Buscar insumo por nome...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), filled: true, fillColor: Colors.white), onChanged: (v) => setState(() => _filtroBusca = v))),
        
        // 🏷️ NOVO: Filtro Rápido de Categorias na Tela de Uso
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
                  selected: isSelected, selectedColor: primaryColor, backgroundColor: Colors.white,
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: insumosFiltrados.length,
            itemBuilder: (context, index) {
              final item = insumosFiltrados[index];
              final isAlerta = item.emAlerta && item.estoqueMinimo >= 0;
              final temAberto = item.temPoteAberto;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: temAberto ? Colors.blue.shade200 : Colors.grey.shade200)),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(backgroundColor: isAlerta ? Colors.red.shade100 : Colors.blueGrey.shade50, child: Icon(isAlerta ? Icons.warning_amber : Icons.inventory_2, color: isAlerta ? Colors.red.shade800 : Colors.blueGrey, size: 20)),
                      title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.categoria} • Armário: ${item.quantidade} un', style: TextStyle(color: isAlerta ? Colors.red.shade700 : Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(onTap: () => _abrirModalInsumo(context, item), child: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey)),
                          const SizedBox(width: 12),
                          InkWell(onTap: () => ref.read(estoqueControllerProvider.notifier).deletar(item.id), child: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: temAberto ? Colors.blue.shade50 : Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(temAberto ? '🔵 POTE ABERTO EM USO' : 'Nenhum pote aberto.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: temAberto ? Colors.blue.shade800 : Colors.grey)),
                          temAberto
                            ? FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(0, 32)), onPressed: () => _confirmarFimPote(item), icon: const Icon(Icons.stop_circle_outlined, size: 16), label: const Text('ACABOU', style: TextStyle(fontSize: 11)))
                            : FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(0, 32)), onPressed: () => _confirmarIniciaPote(item), icon: const Icon(Icons.play_circle_outline, size: 16), label: const Text('ABRIR NOVO', style: TextStyle(fontSize: 11))),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbaRelatorioIA(NumberFormat fmtMoeda) {
    // 🧠 A Tela invoca a IA enviando o _mesFiltro (Mês selecionado lá no topo!)
    final iaAsync = ref.watch(iaRelatorioProvider(_mesFiltro));

    return iaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro ao carregar IA: $err')),
      data: (relatorios) {
        if (relatorios.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.smart_toy, size: 64, color: Colors.blue.shade200),
                const SizedBox(height: 16),
                const Text('A Inteligência Artificial está analisando!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('Nenhum pote fechado foi encontrado no mês de ${DateFormat('MMMM yyyy', 'pt_BR').format(_mesFiltro)}.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                Card(color: Colors.blue.shade50, elevation: 0, child: const Padding(padding: EdgeInsets.all(16.0), child: Text('Lembre-se: A IA gera o relatório cruzando as comandas da agenda na exata data em que o botão "Acabou" é pressionado.', style: TextStyle(fontSize: 12, color: Colors.blueGrey), textAlign: TextAlign.center)))
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: relatorios.length,
          itemBuilder: (context, index) {
            final rel = relatorios[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0, color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: rel.alertaCustoAlto ? Colors.orange.shade300 : Colors.blue.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(rel.alertaCustoAlto ? Icons.warning_rounded : Icons.lightbulb, color: rel.alertaCustoAlto ? Colors.orange : Colors.blue, size: 24),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Análise: ${rel.insumo.nome}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(rel.insightTexto, style: const TextStyle(fontSize: 14, height: 1.4)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Custo p/ Cliente', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(fmtMoeda.format(rel.custoPorProcedimento), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: rel.alertaCustoAlto ? Colors.red : Colors.green)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Aplicações (Média)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('${rel.totalServicos} clientes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
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
}
