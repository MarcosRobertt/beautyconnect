
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceiroState {
  final DateTime mesReferencia;
  final double receitas;
  final double despesas;
  final Map<String, double> topServicos;
  final Map<String, double> formasPagamento;
  final Map<int, Map<String, double>> fluxoDiario;
  
  final int anoReferencia;
  final List<double> faturamentoAnual; // 12 meses

  FinanceiroState({
    required this.mesReferencia,
    this.receitas = 0.0,
    this.despesas = 0.0,
    this.topServicos = const {},
    this.formasPagamento = const {},
    this.fluxoDiario = const {},
    required this.anoReferencia,
    this.faturamentoAnual = const [],
  });

  double get lucro => receitas - despesas;
}

final financeiroControllerProvider = StateNotifierProvider<FinanceiroController, AsyncValue<FinanceiroState>>((ref) {
  return FinanceiroController();
});

class FinanceiroController extends StateNotifier<AsyncValue<FinanceiroState>> {
  FinanceiroController() : super(const AsyncValue.loading());
  final _db = FirebaseFirestore.instance;

  DateTime _mesAtual = DateTime.now();
  int _anoAtual = DateTime.now().year;

  Future<void> carregarDados({DateTime? mes, int? ano, bool forcarServidor = false}) async {
    try {
      state = const AsyncValue.loading();
      if (mes != null) _mesAtual = mes;
      if (ano != null) _anoAtual = ano;

      final options = forcarServidor ? const GetOptions(source: Source.server) : const GetOptions(source: Source.serverAndCache);

      // 1. LIMITES DO MÊS
      final inicioMes = DateTime(_mesAtual.year, _mesAtual.month, 1);
      final fimMes = DateTime(_mesAtual.year, _mesAtual.month + 1, 0, 23, 59, 59);

      // 2. BUSCAR AGENDAMENTOS (RECEITAS) DO MÊS
      final agendamentosSnap = await _db.collection('agendamentos')
          .where('status', isEqualTo: 'concluido')
          .where('data', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('data', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(options);

      // 3. BUSCAR DESPESAS DO MÊS
      final despesasSnap = await _db.collection('despesas')
          .where('dataVencimento', isGreaterThanOrEqualTo: inicioMes.toIso8601String())
          .where('dataVencimento', isLessThanOrEqualTo: fimMes.toIso8601String())
          .get(options);

      double totalReceitas = 0;
      Map<String, double> topServicosMap = {};
      Map<String, double> formasPgtoMap = {};
      Map<int, Map<String, double>> fluxoDiario = {}; // {dia: {'receita': X, 'despesa': Y}}

      // Inicializar dias do mês no fluxo
      for (int i = 1; i <= fimMes.day; i++) {
        fluxoDiario[i] = {'receita': 0.0, 'despesa': 0.0};
      }

      // Processar Receitas
      for (var doc in agendamentosSnap.docs) {
        final data = doc.data();
        // Fallback: se não tiver valorLiquido (comanda antiga), usa o valor cheio
        final valor = (data['valorLiquido'] ?? data['valor'] ?? 0).toDouble();
        final servico = data['servico'] ?? 'Outros';
        final forma = data['formaPagamento'] ?? 'Não informada';
        final dataAgenda = DateTime.parse(data['data']);

        totalReceitas += valor;
        
        topServicosMap[servico] = (topServicosMap[servico] ?? 0) + valor;
        formasPgtoMap[forma] = (formasPgtoMap[forma] ?? 0) + valor;
        fluxoDiario[dataAgenda.day]!['receita'] = fluxoDiario[dataAgenda.day]!['receita']! + valor;
      }

      // Processar Despesas
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

      // 4. BUSCAR FATURAMENTO ANUAL (Agendamentos do Ano)
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
        topServicos: topServicosSorted,
        formasPagamento: formasPgtoMap,
        fluxoDiario: fluxoDiario,
        anoReferencia: _anoAtual,
        faturamentoAnual: faturamentoMeses,
      ));

    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
