
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(financeiroControllerProvider.notifier).carregarDados());
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF8A2463);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF0F4),
        appBar: AppBar(
          title: const Text('Resultados Financeiros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          bottom: const TabBar(
            labelColor: primaryColor,
            indicatorColor: primaryColor,
            tabs: [
              Tab(icon: Icon(Icons.pie_chart_outline), text: 'Visão Geral'),
              Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Caixa Diário'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Anual'),
            ],
          ),
        ),
        body: ref.watch(financeiroControllerProvider).when(
          loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
          error: (err, stack) => Center(child: Text('Erro ao carregar: $err')),
          data: (state) {
            return TabBarView(
              children: [
                _buildVisaoGeral(state, primaryColor),
                _buildCaixaDiario(state),
                _buildVisaoAnual(state, primaryColor),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVisaoGeral(FinanceiroState state, Color primaryColor) {
    final formatMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Seletor de Mês
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left), 
              onPressed: () => ref.read(financeiroControllerProvider.notifier).carregarDados(mes: DateTime(state.mesReferencia.year, state.mesReferencia.month - 1))
            ),
            Text(DateFormat('MMMM yyyy', 'pt_BR').format(state.mesReferencia).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.chevron_right), 
              onPressed: () => ref.read(financeiroControllerProvider.notifier).carregarDados(mes: DateTime(state.mesReferencia.year, state.mesReferencia.month + 1))
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cards de Receita e Despesa
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                child: Column(
                  children: [
                    const Text('Receitas (Líquidas)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(formatMoeda.format(state.receitas), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  children: [
                    const Text('Despesas Totais', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(formatMoeda.format(state.despesas), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Lucro Líquido
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              const Text('LUCRO LÍQUIDO DO MÊS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(formatMoeda.format(state.lucro), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text('🏆 Top Serviços', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...state.topServicos.entries.take(5).map((e) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.star, color: Colors.amber, size: 20),
          title: Text(e.key),
          trailing: Text(formatMoeda.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
        
        const SizedBox(height: 24),
        const Text('🏦 Formas de Recebimento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...state.formasPagamento.entries.map((e) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.payments_outlined, size: 20),
          title: Text(e.key),
          trailing: Text(formatMoeda.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
      ],
    );
  }

  Widget _buildCaixaDiario(FinanceiroState state) {
    final formatMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    // Filtrar apenas dias que tiveram alguma movimentação para não poluir
    final diasMovimentados = state.fluxoDiario.entries.where((e) => e.value['receita']! > 0 || e.value['despesa']! > 0).toList()..sort((a,b) => b.key.compareTo(a.key)); // Ordem decrescente

    if (diasMovimentados.isEmpty) {
      return const Center(child: Text('Nenhuma movimentação neste mês.'));
    }

    return ListView.builder(
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
                    Text('Entradas: ${formatMoeda.format(receita)}', style: const TextStyle(color: Colors.green, fontSize: 13)),
                    Text('Saídas: ${formatMoeda.format(despesa)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saldo do dia:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formatMoeda.format(saldo), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: corSaldo)),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisaoAnual(FinanceiroState state, Color primaryColor) {
    final formatMoeda = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');
    final meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    double maxValor = state.faturamentoAnual.reduce((a, b) => a > b ? a : b);
    if (maxValor == 0) maxValor = 1; // Previne divisão por zero

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(financeiroControllerProvider.notifier).carregarDados(ano: state.anoReferencia - 1)),
              Text('Faturamento ${state.anoReferencia}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          child: Text(formatMoeda.format(valor), style: const TextStyle(fontSize: 9, color: Colors.blueGrey), textAlign: TextAlign.center, overflow: TextOverflow.visible),
                        ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 200 * alturaPercent,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(valor > 0 ? 0.8 : 0.1),
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
          const Text('Gráfico representa Receita Líquida (Entradas das comandas)', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
