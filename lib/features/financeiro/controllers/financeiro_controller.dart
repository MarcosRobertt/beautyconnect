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

  Future<Map<String, double>> _buscarTotaisPeriodo(DateTime inicio, DateTime fim, GetOptions options) async {
    double rec = 0; double des = 0;
    
    final agendamentos = await _db.collection('agendamentos')
        .where('status', isEqualTo: 'concluido')
        .where('data', isGreaterThanOrEqualTo: inicio.toIso8601String())
        .where('data', isLessThanOrEqualTo: fim.toIso8601String())
        .get(options);
        
    for (var doc in agendamentos.docs) {
      final data = doc.data();
      // 🛡️ IGNORA COMANDAS CANCELADAS NA BUSCA DE COMPARAÇÃO
      if (data['status']?.toString().toLowerCase() == 'cancelado') continue;
      
      final bruto = (data['valor'] ?? 0).toDouble();
      final formaRaw = data['formaPagamento']?.toString() ?? 'Outros';
      
      final taxa = calcularTaxa(formaRaw, bruto);
      final liquido = bruto - taxa;
      rec += liquido; 
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

      final inicioMes = DateTime(_mesAtual.year, _mesAtual.month, 1);
      final fimMes = DateTime(_mesAtual.year, _mesAtual.month + 1, 0, 23, 59, 59);

      final agendamentosSnap = await _db.collection('agendamentos')
          .where('status', isEqualTo: 'concluido')
          .where('data', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('data', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(options);

      final despesasSnap = await _db.collection('despesas')
          .where('dataVencimento', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('dataVencimento', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(options);

      double totalReceitasLiquidas = 0;
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

      for (var doc in agendamentosSnap.docs) {
        final data = doc.data();
        
        // 🛡️ A MÁGICA: Protege o Caixa Diário e a Visão Geral de ler comandas "Fantasmas/Canceladas"
        if (data['status']?.toString().toLowerCase() == 'cancelado') continue;

        final valorBruto = (data['valor'] ?? 0).toDouble();
        final servico = data['servico'] ?? 'Outros';
        final formaRaw = data['formaPagamento']?.toString() ?? 'Outros';
        final formaNormalizada = _normalizarFormaPagamento(formaRaw);
        final dataAgenda = DateTime.parse(data['data']);

        final taxaCalculada = calcularTaxa(formaRaw, valorBruto);
        final valorLiquido = valorBruto - taxaCalculada;

        totalReceitasLiquidas += valorLiquido;
        totalTaxasRetidas += taxaCalculada;
        topServicosMap[servico] = (topServicosMap[servico] ?? 0) + valorLiquido;
        
        if (formasPgtoMap.containsKey(formaNormalizada)) {
          formasPgtoMap[formaNormalizada] = formasPgtoMap[formaNormalizada]! + valorLiquido;
        } else {
          formasPgtoMap[formaNormalizada] = valorLiquido;
        }
        
        fluxoDiario[dataAgenda.day]!['receita'] = fluxoDiario[dataAgenda.day]!['receita']! + valorLiquido;
      }

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

      final inicioMesAnt = DateTime(_mesAtual.year, _mesAtual.month - 1, 1);
      final fimMesAnt = DateTime(_mesAtual.year, _mesAtual.month, 0, 23, 59, 59);
      final totaisMesAnt = await _buscarTotaisPeriodo(inicioMesAnt, fimMesAnt, options);

      final inicioAnoAnt = DateTime(_mesAtual.year - 1, _mesAtual.month, 1);
      final fimAnoAnt = DateTime(_mesAtual.year - 1, _mesAtual.month + 1, 0, 23, 59, 59);
      final totaisAnoAnt = await _buscarTotaisPeriodo(inicioAnoAnt, fimAnoAnt, options);

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
        
        // 🛡️️ A MÁGICA: Protege o Gráfico Anual de ler comandas Canceladas
        if (data['status']?.toString().toLowerCase() == 'cancelado') continue;

        final bruto = (data['valor'] ?? 0).toDouble();
        final formaRaw = data['formaPagamento']?.toString() ?? 'Outros';
        
        final taxa = calcularTaxa(formaRaw, bruto);
        final liquido = bruto - taxa;

        final dt = DateTime.parse(data['data']);
        faturamentoMeses[dt.month - 1] += liquido; 
      }

      var topServicosSorted = Map.fromEntries(
        topServicosMap.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value))
      );

      state = AsyncValue.data(FinanceiroState(
        mesReferencia: _mesAtual,
        receitas: totalReceitasLiquidas,
        despesas: totalDespesas,
        taxasPagas: totalTaxasRetidas,
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
