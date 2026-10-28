Widget _buildVisaoGeral(FinanceiroState state) {
    // 1. Cálculos de Inteligência Financeira
    final lucroServicos = state.receitasServicos - state.despesas;
    final lucroLoja = state.receitasProdutos - state.cmv;
    
    double margemLoja = 0.0;
    if (state.receitasProdutos > 0) {
      margemLoja = (lucroLoja / state.receitasProdutos) * 100;
    }

    final totalCustosGlobais = state.despesas + state.cmv + state.taxasPagas;
    final faturamentoBruto = state.receitasServicos + state.receitasProdutos; // Faturamento Operacional
    
    double percentualCustos = 0.0;
    double percentualLucro = 0.0;
    
    if (faturamentoBruto > 0) {
      percentualCustos = (totalCustosGlobais / faturamentoBruto).clamp(0.0, 1.0);
      percentualLucro = 1.0 - percentualCustos;
    } else {
      percentualCustos = 1.0;
    }

    // O Resultado Final (Lucro da Operação + Sobras Avulsas - Faltas Avulsas)
    // O state.receitasAvulsas traz as sobras registradas na conciliação
    final saldoLivreFinal = state.lucro + state.receitasAvulsas;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSeletorMes(state),
        const SizedBox(height: 16),

        // 2. Os Dois Cards Inteligentes Lado a Lado
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARD DE SERVIÇOS
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple.shade200, width: 1.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.spa, size: 14, color: Colors.purple.shade700),
                        const SizedBox(width: 4),
                        Text('SERVIÇOS', style: TextStyle(fontSize: 11, color: Colors.purple.shade900, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_formatMoeda.format(lucroServicos), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: lucroServicos >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
                    const SizedBox(height: 4),
                    Text('Faturamento: ${_formatMoeda.format(state.receitasServicos)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('Despesas: -${_formatMoeda.format(state.despesas)}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // CARD DA LOJA
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200, width: 1.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shopping_bag, size: 14, color: Colors.teal.shade700),
                            const SizedBox(width: 4),
                            Text('LOJA', style: TextStyle(fontSize: 11, color: Colors.teal.shade900, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ],
                        ),
                        // Badge da Margem da Loja
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: margemLoja > 0 ? Colors.green.shade100 : (margemLoja < 0 ? Colors.red.shade100 : Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
                          child: Text('${margemLoja.toStringAsFixed(0)}% MG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: margemLoja > 0 ? Colors.green.shade800 : (margemLoja < 0 ? Colors.red.shade800 : Colors.grey.shade700))),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_formatMoeda.format(lucroLoja), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: lucroLoja >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
                    const SizedBox(height: 4),
                    Text('Vendas: ${_formatMoeda.format(state.receitasProdutos)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('Custo: -${_formatMoeda.format(state.cmv)}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. O Grande Lucro Operacional (Serviços + Loja)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight
            ), 
            borderRadius: BorderRadius.circular(16)
          ),
          child: Column(
            children: [
              const Text('LUCRO LÍQUIDO OPERACIONAL', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
        
        const SizedBox(height: 16),

        // 4. Barra de Saúde Financeira (Custos vs Receita)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('SAÚDE DO NEGÓCIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    if (percentualLucro > 0)
                      Expanded(flex: (percentualLucro * 100).toInt(), child: Container(height: 12, color: Colors.green.shade400)),
                    if (percentualCustos > 0)
                      Expanded(flex: (percentualCustos * 100).toInt(), child: Container(height: 12, color: Colors.red.shade400)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${(percentualLucro * 100).toStringAsFixed(0)}% Margem', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      Text('Faturamento: ${_formatMoeda.format(faturamentoBruto)}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(percentualCustos * 100).toStringAsFixed(0)}% Custos', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                      Text('Saídas: -${_formatMoeda.format(totalCustosGlobais)}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ],
              )
            ],
          )
        ),
        
        const SizedBox(height: 16),

        // 5. NOVO CARD: CAIXA LÍQUIDO FINAL (Soma tudo: Operação + Entradas Extras da Conciliação)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.blueGrey.shade900, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            children: [
              const Text('FECHAMENTO DE CAIXA (SALDO LIVRE)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text(_formatMoeda.format(saldoLivreFinal), style: TextStyle(color: saldoLivreFinal >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold)),
              
              if (state.receitasAvulsas > 0 || state.taxasPagas > 0) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white24, height: 1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lucro da Operação:', style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12)),
                    Text(_formatMoeda.format(state.lucro), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (state.receitasAvulsas > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Entradas Extras (Conciliação):', style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12)),
                        Text('+ ${_formatMoeda.format(state.receitasAvulsas)}', style: TextStyle(color: Colors.greenAccent.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                if (state.taxasPagas > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taxas de Maquininha:', style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12)),
                        Text('- ${_formatMoeda.format(state.taxasPagas)}', style: TextStyle(color: Colors.redAccent.shade100, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
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
