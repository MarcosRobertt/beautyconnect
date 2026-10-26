import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceiroState {
  final DateTime mesReferencia;
  final double receitas; 
  final double receitasServicos; 
  final double receitasProdutos;
  final double receitasAvulsas; 
  final double despesas;
  final double cmv; 
  final double taxasPagas;
  final Map<String, double> topServicos;
  final Map<String, double> formasPagamento;
  final Map<int, Map<String, double>> fluxoDiario;
  
  final double receitasMesAnterior;
  final double despesasMesAnterior;
  final double cmvMesAnterior; 
  final double receitasAnoAnterior;
  final double despesasAnoAnterior;
  final double cmvAnoAnterior; 

  final int anoReferencia;
  final List<double> faturamentoAnual;

  final Map<String, double> conciliacaoReais;
  final Map<String, double> conciliacaoTaxas;
  final Map<String, List<Map<String, dynamic>>> ajustesConciliacao;

  FinanceiroState({
    required this.mesReferencia,
    this.receitas = 0.0,
    this.receitasServicos = 0.0,
    this.receitasProdutos = 0.0,
    this.receitasAvulsas = 0.0,
    this.despesas = 0.0,
    this.cmv = 0.0,
    this.taxasPagas = 0.0,
    this.topServicos = const {},
    this.formasPagamento = const {},
    this.fluxoDiario = const {},
    this.receitasMesAnterior = 0.0,
    this.despesasMesAnterior = 0.0,
    this.cmvMesAnterior = 0.0,
    this.receitasAnoAnterior = 0.0,
    this.despesasAnoAnterior = 0.0,
    this.cmvAnoAnterior = 0.0,
    required this.anoReferencia,
    this.faturamentoAnual = const [],
    this.conciliacaoReais = const {},
    this.conciliacaoTaxas = const {},
    this.ajustesConciliacao = const {},
  });

  double get lucro => receitas - despesas - cmv;
  double get lucroMesAnterior => receitasMesAnterior - despesasMesAnterior - cmvMesAnterior;

  double _calcVariacao(double atual, double anterior) {
    if (anterior == 0) return atual > 0 ? 100.0 : 0.0;
    return ((atual - anterior) / anterior) * 100;
  }

  double get variacaoReceitaMes => _calcVariacao(receitas, receitasMesAnterior);
  double get variacaoDespesaMes => _calcVariacao(despesas, despesasMesAnterior);
  double get variacaoLucroMes => _calcVariacao(lucro, lucroMesAnterior);
  
  double get variacaoReceitaAno => _calcVariacao(receitas, receitasAnoAnterior);
  double get variacaoDespesaAno => _calcVariacao(despesas, despesasAnoAnterior);

  FinanceiroState copyWith({
    Map<String, double>? conciliacaoReais,
    Map<String, double>? conciliacaoTaxas,
    Map<String, List<Map<String, dynamic>>>? ajustesConciliacao,
  }) {
    return FinanceiroState(
      mesReferencia: mesReferencia,
      receitas: receitas,
      receitasServicos: receitasServicos,
      receitasProdutos: receitasProdutos,
      receitasAvulsas: receitasAvulsas,
      despesas: despesas,
      cmv: cmv,
      taxasPagas: taxasPagas,
      topServicos: topServicos,
      formasPagamento: formasPagamento,
      fluxoDiario: fluxoDiario,
      receitasMesAnterior: receitasMesAnterior,
      despesasMesAnterior: despesasMesAnterior,
      cmvMesAnterior: cmvMesAnterior,
      receitasAnoAnterior: receitasAnoAnterior,
      despesasAnoAnterior: despesasAnoAnterior,
      cmvAnoAnterior: cmvAnoAnterior,
      anoReferencia: anoReferencia,
      faturamentoAnual: faturamentoAnual,
      conciliacaoReais: conciliacaoReais ?? this.conciliacaoReais,
      conciliacaoTaxas: conciliacaoTaxas ?? this.conciliacaoTaxas,
      ajustesConciliacao: ajustesConciliacao ?? this.ajustesConciliacao,
    );
  }
}

class ItemParcelaPagamento {
  final String forma;
  final double valor;
  final DateTime data;

  ItemParcelaPagamento({required this.forma, required this.valor, required this.data});
}

final financeiroControllerProvider = StateNotifierProvider<FinanceiroController, AsyncValue<FinanceiroState>>((ref) {
  return FinanceiroController();
});

class FinanceiroController extends StateNotifier<AsyncValue<FinanceiroState>> {
  FinanceiroController() : super(const AsyncValue.loading());
  final _db = FirebaseFirestore.instance;

  DateTime _mesAtual = DateTime.now();
  int _anoAtual = DateTime.now().year;

  // Curinga Universal para clientes velhas e novas
  final List<String> _statusConcluidos = ['concluido', 'Concluído', 'Concluido'];

  static double calcularTaxa(String forma, double valorBruto) {
    final f = forma.trim().toLowerCase();
    if (f == 'dinheiro' || f == 'pix') return 0.0;
    if (f.contains('crédito') || f.contains('credito')) return valorBruto * 0.0315; 
    if (f.contains('débito') || f.contains('debito')) return valorBruto * 0.0089; 
    return 0.0;
  }

  String _normalizarFormaPagamento(String formaOriginal) {
    final f = formaOriginal.trim().toLowerCase();
    if (f == 'pix') return 'Pix';
    if (f == 'dinheiro') return 'Dinheiro';
    if (f.contains('crédito') || f.contains('credito')) return 'Cartão de Crédito';
    if (f.contains('débito') || f.contains('debito')) return 'Cartão de Débito';
    if (f == 'pendente') return 'Pendente';
    
    if (formaOriginal.isEmpty) return 'Outros';
    return formaOriginal[0].toUpperCase() + formaOriginal.substring(1).toLowerCase();
  }

  DateTime _converterData(dynamic valor) {
    if (valor == null) return DateTime.now();
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    try {
      return DateTime.parse(valor.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  List<ItemParcelaPagamento> _extrairParcelas(Map<String, dynamic> data) {
    if (data['pagamentosDetalhados'] != null && data['pagamentosDetalhados'] is List) {
      final lista = data['pagamentosDetalhados'] as List;
      if (lista.isNotEmpty) {
        final itens = <ItemParcelaPagamento>[];
        for (var p in lista) {
          if (p is Map) {
            final v = (p['valor'] ?? 0).toDouble();
            final f = p['forma']?.toString() ?? 'Outros';
            DateTime dt = _converterData(p['data']);
            if (v > 0) {
              itens.add(ItemParcelaPagamento(forma: f, valor: v, data: dt));
            }
          }
        }
        if (itens.isNotEmpty) return itens;
      }
    }

    final obs = data['observacao']?.toString() ?? '';
    final matches = RegExp(r'\[Baixa Financeira.*?:\s*(.*?)\]').allMatches(obs);
    if (matches.isNotEmpty) {
      final conteudo = matches.last.group(1)!;
      final blocos = conteudo.split('||');
      final itens = <ItemParcelaPagamento>[];
      for (var bloco in blocos) {
        final partes = bloco.split('->');
        if (partes.length == 2) {
          final dataStr = partes[0].trim();
          final detalheStr = partes[1].trim();
          
          DateTime? dtBloco;
          try {
            final dParts = dataStr.split('/');
            if (dParts.length == 3) {
              dtBloco = DateTime(int.parse(dParts[2]), int.parse(dParts[1]), int.parse(dParts[0]));
            }
          } catch (_) {}

          if (dtBloco != null) {
            final subPagamentos = detalheStr.split('|');
            for (var sub in subPagamentos) {
              final subPartes = sub.split(':');
              if (subPartes.length >= 2) {
                final forma = subPartes[0].trim();
                final valStr = subPartes[1].replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
                final val = double.tryParse(valStr) ?? 0.0;
                if (val > 0) {
                  itens.add(ItemParcelaPagamento(forma: forma, valor: val, data: dtBloco));
                }
              }
            }
          }
        }
      }
      if (itens.isNotEmpty) return itens;
    }

    DateTime dataReal;
    if (data.containsKey('dataPagamento') && data['dataPagamento'] != null) {
      dataReal = _converterData(data['dataPagamento']);
    } else {
      dataReal = _converterData(data['data']);
    }
    final bruto = (data['valor'] ?? 0).toDouble();
    final forma = data['formaPagamento']?.toString() ?? 'Outros';
    return [ItemParcelaPagamento(forma: forma, valor: bruto, data: dataReal)];
  }

  Future<Map<String, double>> _buscarTotaisPeriodo(DateTime inicio, DateTime fim, GetOptions options) async {
    double recServicos = 0; double des = 0; double recProdutos = 0; double cmvPeriodo = 0;
    
    final fAgendamentosData = _db.collection('agendamentos').where('status', whereIn: _statusConcluidos).where('data', isGreaterThanOrEqualTo: inicio.toIso8601String()).where('data', isLessThanOrEqualTo: fim.toIso8601String()).get(options);
    final fAgendamentosPag = _db.collection('agendamentos').where('status', whereIn: _statusConcluidos).where('dataPagamento', isGreaterThanOrEqualTo: inicio.toIso8601String()).where('dataPagamento', isLessThanOrEqualTo: fim.toIso8601String()).get(options);
    
    final fVendas = _db.collection('loja_vendas').where('dataVenda', isGreaterThanOrEqualTo: inicio.toIso8601String()).where('dataVenda', isLessThanOrEqualTo: fim.toIso8601String()).get(options);
    final fDespesas = _db.collection('despesas').where('dataVencimento', isGreaterThanOrEqualTo: inicio.toIso8601String()).where('dataVencimento', isLessThanOrEqualTo: fim.toIso8601String()).get(options);

    final agendamentosDataSnap = await fAgendamentosData;
    final agendamentosPagSnap = await fAgendamentosPag;
    final vendas = await fVendas;
    final despesas = await fDespesas;
        
    final Map<String, Map<String, dynamic>> mapAgendamentos = {};
    for (var doc in agendamentosDataSnap.docs) mapAgendamentos[doc.id] = doc.data();
    for (var doc in agendamentosPagSnap.docs) mapAgendamentos[doc.id] = doc.data();

    for (var data in mapAgendamentos.values) {
      if (data['status']?.toString().toLowerCase() == 'cancelado') continue;
      
      final parcelas = _extrairParcelas(data);
      for (var p in parcelas) {
        if (p.data.isBefore(inicio) || p.data.isAfter(fim)) continue;
        final taxa = calcularTaxa(p.forma, p.valor);
        recServicos += (p.valor - taxa);
      }
    }

    for (var doc in vendas.docs) {
      final data = doc.data();
      final qtd = (data['quantidade'] ?? 1) as int;
      final preco = (data['precoVendido'] ?? 0).toDouble();
      final custo = (data['custoHistorico'] ?? 0).toDouble();
      recProdutos += (preco * qtd);
      cmvPeriodo += (custo * qtd);
    }

    for (var doc in despesas.docs) {
      des += (doc.data()['valor'] ?? 0).toDouble();
    }

    return {
      'receitas': recServicos + recProdutos, 
      'despesas': des,
      'cmv': cmvPeriodo
    };
  }

  Future<void> salvarRascunhoConciliacao(Map<String, double> valoresReais, Map<String, double> taxasInformadas, Map<String, List<Map<String, dynamic>>> ajustesConciliacao) async {
    try {
      final mesAnoStr = '${_mesAtual.year}-${_mesAtual.month.toString().padLeft(2, '0')}';
      
      await _db.collection('conciliacoes_mensais').doc(mesAnoStr).set({
        'reais': valoresReais,
        'taxas': taxasInformadas,
        'ajustes': ajustesConciliacao,
        'status': 'rascunho', 
        'ultimaAtualizacao': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (state.hasValue) {
        state = AsyncValue.data(state.value!.copyWith(
          conciliacaoReais: valoresReais,
          conciliacaoTaxas: taxasInformadas,
          ajustesConciliacao: ajustesConciliacao,
        ));
      }

    } catch (e) {
      throw Exception('Falha ao salvar rascunho: $e');
    }
  }

  Future<void> salvarConciliacao(Map<String, double> valoresReais, Map<String, double> taxasInformadas, Map<String, List<Map<String, dynamic>>> ajustesConciliacao) async {
    try {
      final mesAnoStr = '${_mesAtual.year}-${_mesAtual.month.toString().padLeft(2, '0')}';
      
      await _db.collection('conciliacoes_mensais').doc(mesAnoStr).set({
        'reais': valoresReais,
        'taxas': taxasInformadas,
        'ajustes': ajustesConciliacao,
        'status': 'finalizado', 
        'ultimaAtualizacao': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await carregarDados(forcarServidor: true);
    } catch (e) {
      throw Exception('Falha ao salvar a conciliação: $e');
    }
  }

  Future<void> carregarDados({DateTime? mes, int? ano, bool forcarServidor = false}) async {
    try {
      state = const AsyncValue.loading();
      if (mes != null) _mesAtual = mes;
      if (ano != null) _anoAtual = ano;

      final options = forcarServidor ? const GetOptions(source: Source.server) : const GetOptions(source: Source.serverAndCache);

      final inicioMes = DateTime(_mesAtual.year, _mesAtual.month, 1);
      final fimMes = DateTime(_mesAtual.year, _mesAtual.month + 1, 0, 23, 59, 59);

      final inicioMesAnt = DateTime(_mesAtual.year, _mesAtual.month - 1, 1);
      final fimMesAnt = DateTime(_mesAtual.year, _mesAtual.month, 0, 23, 59, 59);
      final inicioAnoAnt = DateTime(_mesAtual.year - 1, _mesAtual.month, 1);
      final fimAnoAnt = DateTime(_mesAtual.year - 1, _mesAtual.month + 1, 0, 23, 59, 59);
      
      final inicioAno = DateTime(_anoAtual, 1, 1);
      final fimAno = DateTime(_anoAtual, 12, 31, 23, 59, 59);
      
      final mesAnoStr = '${_mesAtual.year}-${_mesAtual.month.toString().padLeft(2, '0')}';

      final fAgendamentosMesData = _db.collection('agendamentos').where('status', whereIn: _statusConcluidos).where('data', isGreaterThanOrEqualTo: inicioMes.toIso8601String()).where('data', isLessThanOrEqualTo: fimMes.toIso8601String()).get(options);
      final fAgendamentosMesPag = _db.collection('agendamentos').where('status', whereIn: _statusConcluidos).where('dataPagamento', isGreaterThanOrEqualTo: inicioMes.toIso8601String()).where('dataPagamento', isLessThanOrEqualTo: fimMes.toIso8601String()).get(options);
      
      final fVendas = _db.collection('loja_vendas').where('dataVenda', isGreaterThanOrEqualTo: inicioMes.toIso8601String()).where('dataVenda', isLessThanOrEqualTo: fimMes.toIso8601String()).get(options);
      final fDespesas = _db.collection('despesas').where('dataVencimento', isGreaterThanOrEqualTo: inicioMes.toIso8601String()).where('dataVencimento', isLessThanOrEqualTo: fimMes.toIso8601String()).get(options);
      
      final fTotaisMesAnt = _buscarTotaisPeriodo(inicioMesAnt, fimMesAnt, options);
      final fTotaisAnoAnt = _buscarTotaisPeriodo(inicioAnoAnt, fimAnoAnt, options);

      final fAnualDataSnap = _db.collection('agendamentos').where('status', whereIn: _statusConcluidos).where('data', isGreaterThanOrEqualTo: inicioAno.toIso8601String()).where('data', isLessThanOrEqualTo: fimAno.toIso8601String()).get(options);
      final fAnualPagSnap = _db.collection('agendamentos').where('status', whereIn: _statusConcluidos).where('dataPagamento', isGreaterThanOrEqualTo: inicioAno.toIso8601String()).where('dataPagamento', isLessThanOrEqualTo: fimAno.toIso8601String()).get(options);
      
      final fAnualVendasSnap = _db.collection('loja_vendas').where('dataVenda', isGreaterThanOrEqualTo: inicioAno.toIso8601String()).where('dataVenda', isLessThanOrEqualTo: fimAno.toIso8601String()).get(options);
      final fConciliacao = _db.collection('conciliacoes_mensais').doc(mesAnoStr).get(options);

      final agendamentosMesDataSnap = await fAgendamentosMesData;
      final agendamentosMesPagSnap = await fAgendamentosMesPag;
      final vendasSnap = await fVendas;
      final despesasSnap = await fDespesas;
      final totaisMesAnt = await fTotaisMesAnt;
      final totaisAnoAnt = await fTotaisAnoAnt;
      final anualDataSnap = await fAnualDataSnap;
      final anualPagSnap = await fAnualPagSnap;
      final anualVendasSnap = await fAnualVendasSnap;
      final conciliacaoSnap = await fConciliacao;

      double totalReceitasServicos = 0;
      double totalReceitasProdutos = 0;
      double totalCMV = 0;
      double totalTaxasRetidas = 0;
      Map<String, double> topServicosMap = {};
      
      Map<String, double> formasPgtoMap = {
        'Pix': 0.0,
        'Dinheiro': 0.0,
        'Cartão de Crédito': 0.0,
        'Cartão de Débito': 0.0,
      };
      
      Map<int, Map<String, double>> fluxoDiario = {};
      for (int i = 1; i <= fimMes.day; i++) fluxoDiario[i] = {'receita': 0.0, 'despesa': 0.0};

      final Map<String, Map<String, dynamic>> mapMesAgendamentos = {};
      for (var doc in agendamentosMesDataSnap.docs) mapMesAgendamentos[doc.id] = doc.data();
      for (var doc in agendamentosMesPagSnap.docs) mapMesAgendamentos[doc.id] = doc.data();

      for (var data in mapMesAgendamentos.values) {
        if (data['status']?.toString().toLowerCase() == 'cancelado') continue;

        final parcelas = _extrairParcelas(data);
        final servico = data['servico'] ?? 'Outros';

        for (var p in parcelas) {
          if (p.data.isBefore(inicioMes) || p.data.isAfter(fimMes)) continue;

          final formaNormalizada = _normalizarFormaPagamento(p.forma);
          final taxaCalculada = calcularTaxa(p.forma, p.valor);
          final valorLiquido = p.valor - taxaCalculada;

          totalReceitasServicos += valorLiquido;
          totalTaxasRetidas += taxaCalculada;
          topServicosMap[servico] = (topServicosMap[servico] ?? 0) + valorLiquido;
          
          if (formasPgtoMap.containsKey(formaNormalizada)) {
            formasPgtoMap[formaNormalizada] = formasPgtoMap[formaNormalizada]! + valorLiquido;
          } else {
            formasPgtoMap[formaNormalizada] = valorLiquido;
          }
          
          if (fluxoDiario.containsKey(p.data.day)) {
            fluxoDiario[p.data.day]!['receita'] = fluxoDiario[p.data.day]!['receita']! + valorLiquido;
          }
        }
      }

      for (var doc in vendasSnap.docs) {
        final data = doc.data();
        final qtd = (data['quantidade'] ?? 1) as int;
        final preco = (data['precoVendido'] ?? 0).toDouble();
        final custo = (data['custoHistorico'] ?? 0).toDouble();
        final dataVenda = _converterData(data['dataVenda']);

        final totalVenda = preco * qtd;
        final custoVenda = custo * qtd;

        totalReceitasProdutos += totalVenda;
        totalCMV += custoVenda;
        
        if (fluxoDiario.containsKey(dataVenda.day)) {
          fluxoDiario[dataVenda.day]!['receita'] = fluxoDiario[dataVenda.day]!['receita']! + totalVenda;
        }
      }

      double totalDespesas = 0;
      for (var doc in despesasSnap.docs) {
        final data = doc.data();
        final valor = (data['valor'] ?? 0).toDouble();
        final dataVencimento = _converterData(data['dataVencimento']);

        totalDespesas += valor;
        if (fluxoDiario.containsKey(dataVencimento.day)) {
          fluxoDiario[dataVencimento.day]!['despesa'] = fluxoDiario[dataVencimento.day]!['despesa']! + valor;
        }
      }

      Map<String, double> conciliacaoReaisLoad = {};
      Map<String, double> conciliacaoTaxasLoad = {};
      Map<String, List<Map<String, dynamic>>> ajustesLoad = {};
      
      double totalAjustesEntrada = 0.0;
      double totalAjustesSaida = 0.0;

      if (conciliacaoSnap.exists) {
        final mapData = conciliacaoSnap.data()!;
        if (mapData['reais'] != null) {
          (mapData['reais'] as Map<String, dynamic>).forEach((key, value) => conciliacaoReaisLoad[key] = (value as num).toDouble());
        }
        if (mapData['taxas'] != null) {
          (mapData['taxas'] as Map<String, dynamic>).forEach((key, value) => conciliacaoTaxasLoad[key] = (value as num).toDouble());
        }
        if (mapData['ajustes'] != null) {
          (mapData['ajustes'] as Map<String, dynamic>).forEach((forma, lista) {
            ajustesLoad[forma] = List<Map<String, dynamic>>.from(lista);
            
            if (mapData['status'] == 'finalizado') {
              for (var ajuste in ajustesLoad[forma]!) {
                if (ajuste['tipo'] == 'entrada') totalAjustesEntrada += (ajuste['valor'] as num).toDouble();
                if (ajuste['tipo'] == 'saida') totalAjustesSaida += (ajuste['valor'] as num).toDouble();
              }
            }
          });
        }
      }

      totalDespesas += totalAjustesSaida;
      
      final Map<String, Map<String, dynamic>> mapAnualAgendamentos = {};
      for (var doc in anualDataSnap.docs) mapAnualAgendamentos[doc.id] = doc.data();
      for (var doc in anualPagSnap.docs) mapAnualAgendamentos[doc.id] = doc.data();

      List<double> faturamentoMeses = List.filled(12, 0.0);
      for (var data in mapAnualAgendamentos.values) {
        if (data['status']?.toString().toLowerCase() == 'cancelado') continue;
        
        final parcelas = _extrairParcelas(data);
        for (var p in parcelas) {
          if (p.data.isBefore(inicioAno) || p.data.isAfter(fimAno)) continue;

          final taxa = calcularTaxa(p.forma, p.valor);
          faturamentoMeses[p.data.month - 1] += (p.valor - taxa);
        }
      }

      for (var doc in anualVendasSnap.docs) {
        final data = doc.data();
        final qtd = (data['quantidade'] ?? 1) as int;
        final preco = (data['precoVendido'] ?? 0).toDouble();
        final dtVenda = _converterData(data['dataVenda']);
        faturamentoMeses[dtVenda.month - 1] += (preco * qtd); 
      }
      faturamentoMeses[_mesAtual.month - 1] += totalAjustesEntrada;

      var topServicosSorted = Map.fromEntries(
        topServicosMap.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value))
      );

      state = AsyncValue.data(FinanceiroState(
        mesReferencia: _mesAtual,
        receitas: totalReceitasServicos + totalReceitasProdutos + totalAjustesEntrada, 
        receitasServicos: totalReceitasServicos,
        receitasProdutos: totalReceitasProdutos,
        receitasAvulsas: totalAjustesEntrada,
        despesas: totalDespesas,
        cmv: totalCMV,
        taxasPagas: totalTaxasRetidas,
        topServicos: topServicosSorted,
        formasPagamento: formasPgtoMap,
        fluxoDiario: fluxoDiario,
        receitasMesAnterior: totaisMesAnt['receitas']!,
        despesasMesAnterior: totaisMesAnt['despesas']!,
        cmvMesAnterior: totaisMesAnt['cmv']!,
        receitasAnoAnterior: totaisAnoAnt['receitas']!,
        despesasAnoAnterior: totaisAnoAnt['despesas']!,
        cmvAnoAnterior: totaisAnoAnt['cmv']!,
        anoReferencia: _anoAtual,
        faturamentoAnual: faturamentoMeses,
        conciliacaoReais: conciliacaoReaisLoad, 
        conciliacaoTaxas: conciliacaoTaxasLoad, 
        ajustesConciliacao: ajustesLoad,
      ));

    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
