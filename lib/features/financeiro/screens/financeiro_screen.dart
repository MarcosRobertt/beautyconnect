import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/financeiro_controller.dart';

class FinanceiroScreen extends ConsumerStatefulWidget {
  const FinanceiroScreen({super.key});
  @override
  ConsumerState<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends ConsumerState<FinanceiroScreen> {
  final _formatMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final Color _primaryColor = const Color(0xFF8A2463);

  // 🎯 CONTROLES DE ESTADO PARA A CONCILIAÇÃO BANCÁRIA
  final Map<String, TextEditingController> _realControllers = {};
  final Map<String, TextEditingController> _taxaControllers = {};
  String? _mesAberto; // Rastreador para saber quando o mês mudou e atualizar os inputs

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(financeiroControllerProvider.notifier).carregarDados());
  }

  @override
  void dispose() {
    for (var c in _realControllers.values) { c.dispose(); }
    for (var c in _taxaControllers.values) { c.dispose(); }
    super.dispose();
  }

  TextEditingController _getRealController(String forma) {
    if (!_realControllers.containsKey(forma)) {
      _realControllers[forma] = TextEditingController();
      _realControllers[forma]!.addListener(() => setState(() {}));
    }
    return _realControllers[forma]!;
  }

  TextEditingController _getTaxaController(String forma) {
    if (!_taxaControllers.containsKey(forma)) {
      _taxaControllers[forma] = TextEditingController();
      _taxaControllers[forma]!.addListener(() => setState(() {}));
    }
    return _taxaControllers[forma]!;
  }

  Widget _buildIndicador(double percentual, {bool inverteCores = false}) {
    if (percentual == 0) return const SizedBox.shrink();
    
    final bool subiu = percentual > 0;
    final bool positivo = inverteCores ? !subiu : subiu;
    
    final cor = positivo ? Colors.green.shade700 : Colors.red.shade700;
    final icone = subiu ? Icons.arrow_upward : Icons.arrow_downward;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 12, color: cor),
        Text(
          ' ${percentual.abs().toStringAsFixed(1)}%', 
          style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.bold)
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, 
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF0F4),
        appBar: AppBar(
          title: const Text('Resultados Financeiros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          bottom: TabBar(
            labelColor: _primaryColor,
            indicatorColor: _primaryColor,
            isScrollable: true, 
            tabs: const [
              Tab(icon: Icon(Icons.pie_chart_outline), text: 'Visão Geral'),
              Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Caixa Diário'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Anual'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Conciliação'), 
            ],
          ),
        ),
        body: ref.watch(financeiroControllerProvider).when(
          loading: () => Center(child: CircularProgressIndicator(color: _primaryColor)),
          error: (err, stack) => Center(child: Text('Erro ao carregar: $err')),
          data: (state) {
            return TabBarView(
              children: [
                _buildVisaoGeral(state),
                _buildCaixaDiario(state),
                _buildVisaoAnual(state),
                _buildConciliacao(state), 
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeletorMes(FinanceiroState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left), 
          onPressed: () => ref.read(financeiroControllerProvider.notifier).carregarDados(mes: DateTime(state.mesReferencia.year, state.mesReferencia.month - 1))
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final dataSelecionada = await showDatePicker(
              context: context,
              initialDate: state.mesReferencia,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              helpText: 'IR PARA O MÊS',
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(primary: _primaryColor),
                  ),
                  child: child!,
                );
              },
            );
            
            if (dataSelecionada != null) {
              ref.read(financeiroControllerProvider.notifier).carregarDados(
                mes: DateTime(dataSelecionada.year, dataSelecionada.month, 1)
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('MMMM yyyy', 'pt_BR').format(state.mesReferencia).toUpperCase(), 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryColor)
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: _primaryColor),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right), 
          onPressed: () => ref.read(financeiroControllerProvider.notifier).carregarDados(mes: DateTime(state.mesReferencia.year, state.mesReferencia.month + 1))
        ),
      ],
    );
  }

  // ===========================================================================
  // 🎯 MÓDULO 4: CONCILIAÇÃO BANCÁRIA
  // ===========================================================================
  Widget _buildConciliacao(FinanceiroState state) {
    // Lógica para repovoar os campos de texto se mudarmos de mês
    final mesStr = '${state.mesReferencia.year}-${state.mesReferencia.month}';
    if (_mesAberto != mesStr) {
      _mesAberto = mesStr;
      
      for (var forma in state.formasPagamento.keys) {
        final rCtrl = _getRealController(forma);
        final tCtrl = _getTaxaController(forma);
        
        if (state.conciliacaoReais.containsKey(forma) && state.conciliacaoReais[forma]! > 0) {
          rCtrl.text = state.conciliacaoReais[forma]!.toStringAsFixed(2).replaceAll('.', ',');
        } else {
          rCtrl.text = '';
        }
        
        if (state.conciliacaoTaxas.containsKey(forma) && state.conciliacaoTaxas[forma]! > 0) {
          tCtrl.text = state.conciliacaoTaxas[forma]!.toStringAsFixed(2).replaceAll('.', ',');
        } else {
          tCtrl.text = '';
        }
      }
    }

    double totalSistema = state.formasPagamento.values.fold(0.0, (a, b) => a + b);
    double totalReal = 0.0;
    double totalTaxasInformadas = 0.0;
    
    for (var entry in state.formasPagamento.entries) {
      final realCtrl = _getRealController(entry.key);
      final taxaCtrl = _getTaxaController(entry.key);
      totalReal += double.tryParse(realCtrl.text.replaceAll(',', '.')) ?? 0.0;
      totalTaxasInformadas += double.tryParse(taxaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    }

    final double divergencia = (totalReal + totalTaxasInformadas) - totalSistema;
    
    Color corDivergencia = Colors.green.shade700;
    String statusTexto = '🟢 Tudo Conciliado! (R\$ 0,00)';
    IconData iconDivergencia = Icons.check_circle;

    if (divergencia < -0.05) {
      corDivergencia = Colors.red.shade700;
      statusTexto = '⚠️ Faltam: ${_formatMoeda.format(divergencia.abs())}';
      iconDivergencia = Icons.warning_amber_rounded;
    } else if (divergencia > 0.05) {
      corDivergencia = Colors.blue.shade700;
      statusTexto = '🔵 Sobraram: ${_formatMoeda.format(divergencia)}';
      iconDivergencia = Icons.info_outline;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSeletorMes(state),
        const SizedBox(height: 16),

        // 📊 CARTÃO DE RESUMO
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📊 RESUMO DO MÊS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
              const Divider(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('📈 Total Bruto (Sistema):', style: TextStyle(color: Colors.black87)), Text(_formatMoeda.format(totalSistema), style: const TextStyle(fontWeight: FontWeight.bold))]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('📉 Taxas de Maquininha:', style: TextStyle(color: Colors.red)), Text('- ${_formatMoeda.format(totalTaxasInformadas)}', style: const TextStyle(color: Colors.red))]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('🏦 Total Líquido (Real):', style: TextStyle(color: Colors.black87)), Text(_formatMoeda.format(totalReal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
              const Divider(height: 24),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: corDivergencia.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(iconDivergencia, color: corDivergencia, size: 20), const SizedBox(width: 8), Text(statusTexto, style: TextStyle(color: corDivergencia, fontWeight: FontWeight.bold, fontSize: 14))])),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text('Confronte os valores com o seu extrato:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
        const SizedBox(height: 12),

        if (state.formasPagamento.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Nenhum recebimento registrado neste mês.', style: TextStyle(color: Colors.grey)))),
          
        ...state.formasPagamento.entries.map((e) {
          final forma = e.key;
          final valorEsperado = e.value;
          final realCtrl = _getRealController(forma);
          final taxaCtrl = _getTaxaController(forma);

          final valReal = double.tryParse(realCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final valTaxa = double.tryParse(taxaCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final diffForma = (valReal + valTaxa) - valorEsperado;

          Color corStatusForma = Colors.green;
          String txtStatusForma = '✅ Bateu certo!';
          if (diffForma < -0.05) {
            corStatusForma = Colors.red;
            txtStatusForma = '⚠️ Faltam: ${_formatMoeda.format(diffForma.abs())}';
          } else if (diffForma > 0.05) {
            corStatusForma = Colors.blue;
            txtStatusForma = '🔵 Sobraram: ${_formatMoeda.format(diffForma)}';
          }

          IconData iconeForma = Icons.payments;
          if (forma.toLowerCase().contains('pix')) iconeForma = Icons.pix;
          if (forma.toLowerCase().contains('cartão') || forma.toLowerCase().contains('credito') || forma.toLowerCase().contains('debito')) iconeForma = Icons.credit_card;
          if (forma.toLowerCase().contains('dinheiro')) iconeForma = Icons.attach_money;

          final bool aceitaTaxa = forma.toLowerCase().contains('cartão') || forma.toLowerCase().contains('credito') || forma.toLowerCase().contains('debito');

          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: CircleAvatar(backgroundColor: Colors.grey.shade100, child: Icon(iconeForma, color: _primaryColor, size: 20)),
              title: Text(forma, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Vendido: ${_formatMoeda.format(valorEsperado)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: realCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor no Extrato / Gaveta', prefixText: 'R\$ ', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    if (aceitaTaxa) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: taxaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'Taxas da Maquininha', prefixText: 'R\$ ', border: const OutlineInputBorder(), isDense: true, fillColor: Colors.red.shade50, filled: true),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: corStatusForma.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(txtStatusForma, style: TextStyle(color: corStatusForma, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 16),
                
                const Text('Ajustes e Verificações:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Ver Comandas', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        // Pop-up de Segurança / Informação
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Ação de Verificação'),
                            content: Text('Isso abrirá o relatório das comandas de $forma deste mês para auditoria. Deseja prosseguir?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                              FilledButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo em construção.'), backgroundColor: Colors.blue)); }, child: const Text('Sim, Prosseguir'))
                            ]
                          )
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.arrow_downward, size: 16, color: Colors.red.shade700),
                      label: Text('Lançar Despesa', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade200)),
                      onPressed: () {
                        // Pop-up de Segurança
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Lançar Saída Avulsa'),
                            content: const Text('Você está prestes a lançar uma saída/despesa avulsa que afetará o saldo deste caixa. Confirmar?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                              FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo em construção.'), backgroundColor: Colors.red)); }, child: const Text('Sim, Lançar'))
                            ]
                          )
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.arrow_upward, size: 16, color: Colors.green.shade700),
                      label: Text('Lançar Entrada', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.green.shade200)),
                      onPressed: () {
                        // Pop-up de Segurança
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Lançar Entrada Avulsa'),
                            content: const Text('Você está prestes a lançar uma entrada avulsa que não pertence a nenhuma comanda (Ex: Venda extra, Gorjeta). Confirmar?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                              FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.green), onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo em construção.'), backgroundColor: Colors.green)); }, child: const Text('Sim, Lançar'))
                            ]
                          )
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 24),
        
        // 🎯 O BOTÃO PRINCIPAL COM PROTEÇÃO (POP-UP DE CONFIRMAÇÃO)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          icon: const Icon(Icons.save),
          label: const Text('Salvar Conciliação do Mês', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: () {
            // POP-UP DE SEGURANÇA OBRIGATÓRIO ANTES DE SALVAR NO BANCO
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.save_as, color: _primaryColor),
                    const SizedBox(width: 8),
                    const Text('Confirmar Atualização?'),
                  ],
                ),
                content: const Text(
                  'Você está prestes a salvar os valores de extrato e taxas informados.\n\n'
                  'Isso registrará a conciliação do caixa deste mês na base de dados. Deseja continuar?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text('Revisar Valores')
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _primaryColor),
                    onPressed: () async {
                      Navigator.pop(ctx); // Fecha o aviso
                      
                      // 1. Coleta os valores digitados na tela
                      Map<String, double> reaisSalvar = {};
                      Map<String, double> taxasSalvar = {};
                      
                      for (var forma in state.formasPagamento.keys) {
                        final r = double.tryParse(_getRealController(forma).text.replaceAll(',', '.')) ?? 0.0;
                        final t = double.tryParse(_getTaxaController(forma).text.replaceAll(',', '.')) ?? 0.0;
                        reaisSalvar[forma] = r;
                        taxasSalvar[forma] = t;
                      }

                      // 2. Aciona o Cérebro para salvar na Nuvem ⚡
                      await ref.read(financeiroControllerProvider.notifier).salvarConciliacao(reaisSalvar, taxasSalvar);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Conciliação salva com sucesso no Banco de Dados!'), backgroundColor: Colors.green)
                        );
                      }
                    }, 
                    child: const Text('Sim, Salvar Conciliação')
                  )
                ],
              )
            );
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ===========================================================================
  // MÉTODOS ANTERIORES INTACTOS
  // ===========================================================================

  Widget _buildVisaoGeral(FinanceiroState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSeletorMes(state),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.spa, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        const Text('Serviços', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_formatMoeda.format(state.receitasServicos), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_bag, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        const Text('Loja/Produtos', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_formatMoeda.format(state.receitasProdutos), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.money_off, size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        const Text('Despesas', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_formatMoeda.format(state.despesas), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        const Text('Custo Loja (CMV)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_formatMoeda.format(state.cmv), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              const Text('LUCRO LÍQUIDO DO MÊS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_formatMoeda.format(state.lucro), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              if (state.variacaoLucroMes != 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(state.variacaoLucroMes > 0 ? Icons.trending_up : Icons.trending_down, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      '${state.variacaoLucroMes > 0 ? '+' : ''}${state.variacaoLucroMes.toStringAsFixed(1)}% em relação ao mês anterior', 
                      style: const TextStyle(color: Colors.white70, fontSize: 12)
                    ),
                  ],
                )
              ]
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text('🏦 Formas de Recebimento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...state.formasPagamento.entries.map((e) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.payments_outlined, size: 20, color: Colors.blueGrey),
          title: Text(e.key),
          trailing: Text(_formatMoeda.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.money_off, size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Text('Taxas Retidas (Maquininha)', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                ],
              ),
              Text(_formatMoeda.format(state.taxasPagas), style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text('🏆 Top 5 Serviços Rápido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (state.topServicos.isEmpty)
           const Text('Nenhum serviço concluído neste mês.', style: TextStyle(color: Colors.grey)),
        ...state.topServicos.entries.take(5).map((e) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.star, color: Colors.amber, size: 20),
          title: Text(e.key),
          trailing: Text(_formatMoeda.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCaixaDiario(FinanceiroState state) {
    final diasMovimentados = state.fluxoDiario.entries.where((e) => e.value['receita']! > 0 || e.value['despesa']! > 0).toList()..sort((a,b) => b.key.compareTo(a.key));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: _buildSeletorMes(state), 
        ),
        Expanded(
          child: diasMovimentados.isEmpty
            ? const Center(child: Text('Nenhuma movimentação neste mês.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: diasMovimentados.length,
                itemBuilder: (context, index) {
                  final dia = diasMovimentados[index].key;
                  final receita = diasMovimentados[index].value['receita']!;
                  final despesa = diasMovimentados[index].value['despesa']!;
                  final saldo = receita - despesa;
                  final corSaldo = saldo >= 0 ? Colors.green : Colors.red;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dia ${dia.toString().padLeft(2, '0')} de ${DateFormat('MMMM', 'pt_BR').format(state.mesReferencia)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Entradas: ${_formatMoeda.format(receita)}', style: const TextStyle(color: Colors.green, fontSize: 13)),
                              Text('Saídas: ${_formatMoeda.format(despesa)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Saldo do dia:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(_formatMoeda.format(saldo), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: corSaldo)),
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
    );
  }

  Widget _buildVisaoAnual(FinanceiroState state) {
    final meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    double maxValor = state.faturamentoAnual.reduce((a, b) => a > b ? a : b);
    if (maxValor == 0) maxValor = 1;

    String formatK(double valor) {
      if (valor == 0) return '';
      if (valor >= 1000) {
        return '${(valor / 1000).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')}k';
      }
      return valor.toStringAsFixed(0);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(financeiroControllerProvider.notifier).carregarDados(ano: state.anoReferencia - 1)),
              
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Selecione o Ano"),
                        content: SizedBox(
                          width: 300,
                          height: 300,
                          child: YearPicker(
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            selectedDate: DateTime(state.anoReferencia, 1),
                            onChanged: (DateTime dateTime) {
                              Navigator.pop(context);
                              ref.read(financeiroControllerProvider.notifier).carregarDados(ano: dateTime.year);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Faturamento ${state.anoReferencia}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryColor)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: _primaryColor),
                    ],
                  ),
                ),
              ),

              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => ref.read(financeiroControllerProvider.notifier).carregarDados(ano: state.anoReferencia + 1)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(12, (index) {
                final valor = state.faturamentoAnual[index];
                final alturaPercent = valor / maxValor;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (valor > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            formatK(valor), 
                            style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold), 
                            maxLines: 1, 
                            softWrap: false,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 200 * alturaPercent,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(valor > 0 ? 0.8 : 0.1),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(meses[index], style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 40),
          const Text('Gráfico representa Receitas Globais (Serviços + Produtos)', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
