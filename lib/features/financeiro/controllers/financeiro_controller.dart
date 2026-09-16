import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceiroState {
  final DateTime mesReferencia;
  final double receitas;
  final double despesas;
  final double taxasPagas;
  final Map<String, double> topServicos;
  final Map<String, double> formasPagamento;
  final Map<int, Map<String, double>> fluxoDiario;
  
  // Comparativos
  final double receitasMesAnterior;
  final double despesasMesAnterior;
  final double receitasAnoAnterior;
  final double despesasAnoAnterior;

  final int anoReferencia;
  final List<double> faturamentoAnual;

  FinanceiroState({
    required this.mesReferencia,
    this.receitas = 0.0,
    this.despesas = 0.0,
    this.taxasPagas = 0.0,
    this.topServicos = const {},
    this.formasPagamento = const {},
    this.fluxoDiario = const {},
    this.receitasMesAnterior = 0.0,
    this.despesasMesAnterior = 0.0,
    this.receitasAnoAnterior = 0.0,
    this.despesasAnoAnterior = 0.0,
    required this.anoReferencia,
    this.faturamentoAnual = const [],
  });

  double get lucro => receitas - despesas;
  double get lucroMesAnterior => receitasMesAnterior - despesasMesAnterior;

  // Cálculos de variação percentual
  double _calcVariacao(double atual, double anterior) {
    if (anterior == 0) return atual > 0 ? 100.0 : 0.0;
    return ((atual - anterior) / anterior) * 100;
  }

  double get variacaoReceitaMes => _calcVariacao(receitas, receitasMesAnterior);
  double get variacaoDespesaMes => _calcVariacao(despesas, despesasMesAnterior);
  double get variacaoLucroMes => _calcVariacao(lucro, lucroMesAnterior);
  
  double get variacaoReceitaAno => _calcVariacao(receitas, receitasAnoAnterior);
  double get variacaoDespesaAno => _calcVariacao(despesas, despesasAnoAnterior);
}

final financeiroControllerProvider = StateNotifierProvider<FinanceiroController, AsyncValue<FinanceiroState>>((ref) {
  return FinanceiroController();
});

class FinanceiroController extends StateNotifier<AsyncValue<FinanceiroState>> {
  FinanceiroController() : super(const AsyncValue.loading());
  final _db = FirebaseFirestore.instance;

  DateTime _mesAtual = DateTime.now();
  int _anoAtual = DateTime.now().year;

  /// NOVA LÓGICA DE TAXAS: Dinheiro e Pix = 0% de taxa
  static double calcularTaxa(String forma, double valorBruto) {
    final f = forma.trim().toLowerCase();
    if (f == 'dinheiro' || f == 'pix') {
      return 0.0;
    } else if (f.contains('crédito') || f.contains('credito')) {
      return valorBruto * 0.0399; // Exemplo: 3.99% de taxa de crédito
    } else if (f.contains('débito') || f.contains('debito')) {
      return valorBruto * 0.0199; // Exemplo: 1.99% de taxa de débito
    }
    return 0.0;
  }

  // Função auxiliar para buscar totais sem sujar o código principal
  Future<Map<String, double>> _buscarTotaisPeriodo(DateTime inicio, DateTime fim, GetOptions options) async {
    double rec = 0; double des = 0;
    
    final agendamentos = await _db.collection('agendamentos')
        .where('status', isEqualTo: 'concluido')
        .where('data', isGreaterThanOrEqualTo: inicio.toIso8601String())
        .where('data', isLessThanOrEqualTo: fim.toIso8601String())
        .get(options);
    for (var doc in agendamentos.docs) {
      rec += (doc.data()['valorLiquido'] ?? doc.data()['valor'] ?? 0).toDouble();
    }

    final despesas = await _db.collection('despesas')
        .where('dataVencimento', isGreaterThanOrEqualTo: inicio.toIso8601String())
        .where('dataVencimento', isLessThanOrEqualTo: fim.toIso8601String())
        .get(options);
    for (var doc in despesas.docs) {
      des += (doc.data()['valor'] ?? 0).toDouble();
    }
    return {'receitas': rec, 'despesas': des};
  }

  Future<void> carregarDados({DateTime? mes, int? ano, bool forcarServidor = false}) async {
    try {
      state = const AsyncValue.loading();
      if (mes != null) _mesAtual = mes;
      if (ano != null) _anoAtual = ano;

      final options = forcarServidor ? const GetOptions(source: Source.server) : const GetOptions(source: Source.serverAndCache);

      // 1. LIMITES DO MÊS ATUAL
      final inicioMes = DateTime(_mesAtual.year, _mesAtual.month, 1);
      final fimMes = DateTime(_mesAtual.year, _mesAtual.month + 1, 0, 23, 59, 59);

      // 2. BUSCAR DADOS DO MÊS ATUAL
      final agendamentosSnap = await _db.collection('agendamentos')
          .where('status', isEqualTo: 'concluido')
          .where('data', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('data', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(options);

      final despesasSnap = await _db.collection('despesas')
          .where('dataVencimento', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('dataVencimento', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(options);

      double totalReceitas = 0;
      double totalTaxas = 0;
      Map<String, double> topServicosMap = {};
      
      // Inicializando todas as formas de pagamento zeradas
      Map<String, double> formasPgtoMap = {
        'Pix': 0.0,
        'Dinheiro': 0.0,
        'Cartão de Crédito': 0.0,
        'Cartão de Débito': 0.0,
      };
      
      Map<int, Map<String, double>> fluxoDiario = {};
      for (int i = 1; i <= fimMes.day; i++) fluxoDiario[i] = {'receita': 0.0, 'despesa': 0.0};

      // Processar Receitas do Mês
      for (var doc in agendamentosSnap.docs) {
        final data = doc.data();
        final valor = (data['valorLiquido'] ?? data['valor'] ?? 0).toDouble();
        final servico = data['servico'] ?? 'Outros';
        final forma = data['formaPagamento'] ?? 'Outros';
        final dataAgenda = DateTime.parse(data['data']);

        totalReceitas += valor;
        totalTaxas += (data['valorTaxa'] ?? 0).toDouble();
        topServicosMap[servico] = (topServicosMap[servico] ?? 0) + valor;
        
        if (formasPgtoMap.containsKey(forma)) {
          formasPgtoMap[forma] = formasPgtoMap[forma]! + valor;
        } else {
          formasPgtoMap[forma] = (formasPgtoMap[forma] ?? 0) + valor;
        }
        
        fluxoDiario[dataAgenda.day]!['receita'] = fluxoDiario[dataAgenda.day]!['receita']! + valor;
      }

      // Processar Despesas do Mês
      double totalDespesas = 0;
      for (var doc in despesasSnap.docs) {
        final data = doc.data();
        final valor = (data['valor'] ?? 0).toDouble();
        final dataVencimento = DateTime.parse(data['dataVencimento']);

        totalDespesas += valor;
        if (fluxoDiario.containsKey(dataVencimento.day)) {
          fluxoDiario[dataVencimento.day]!['despesa'] = fluxoDiario[dataVencimento.day]!['despesa']! + valor;
        }
      }

      // 3. COMPARATIVOS (Mês Anterior e Ano Anterior)
      final inicioMesAnt = DateTime(_mesAtual.year, _mesAtual.month - 1, 1);
      final fimMesAnt = DateTime(_mesAtual.year, _mesAtual.month, 0, 23, 59, 59);
      final totaisMesAnt = await _buscarTotaisPeriodo(inicioMesAnt, fimMesAnt, options);

      final inicioAnoAnt = DateTime(_mesAtual.year - 1, _mesAtual.month, 1);
      final fimAnoAnt = DateTime(_mesAtual.year - 1, _mesAtual.month + 1, 0, 23, 59, 59);
      final totaisAnoAnt = await _buscarTotaisPeriodo(inicioAnoAnt, fimAnoAnt, options);

      // 4. FATURAMENTO ANUAL
      final inicioAno = DateTime(_anoAtual, 1, 1);
      final fimAno = DateTime(_anoAtual, 12, 31, 23, 59, 59);
      final anualSnap = await _db.collection('agendamentos')
          .where('status', isEqualTo: 'concluido')
          .where('data', isGreaterThanOrEqualTo: inicioAno.toIso8601String())
          .where('data', isLessThanOrEqualTo: fimAno.toIso8601String())
          .get(options);

      List<double> faturamentoMeses = List.filled(12, 0.0);
      for (var doc in anualSnap.docs) {
        final data = doc.data();
        final valor = (data['valorLiquido'] ?? data['valor'] ?? 0).toDouble();
        final dt = DateTime.parse(data['data']);
        faturamentoMeses[dt.month - 1] += valor;
      }

      // Ordenar Top Serviços
      var topServicosSorted = Map.fromEntries(
        topServicosMap.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value))
      );

      state = AsyncValue.data(FinanceiroState(
        mesReferencia: _mesAtual,
        receitas: totalReceitas,
        despesas: totalDespesas,
        taxasPagas: totalTaxas,
        topServicos: topServicosSorted,
        formasPagamento: formasPgtoMap,
        fluxoDiario: fluxoDiario,
        receitasMesAnterior: totaisMesAnt['receitas']!,
        despesasMesAnterior: totaisMesAnt['despesas']!,
        receitasAnoAnterior: totaisAnoAnt['receitas']!,
        despesasAnoAnterior: totaisAnoAnt['despesas']!,
        anoReferencia: _anoAtual,
        faturamentoAnual: faturamentoMeses,
      ));

    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
