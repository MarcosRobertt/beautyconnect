import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final financeiroControllerProvider = StateNotifierProvider<FinanceiroController, AsyncValue<Map<String, dynamic>>>((ref) {
  return FinanceiroController();
});

class FinanceiroController extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  FinanceiroController() : super(const AsyncValue.loading());

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Formas de pagamento suportadas no sistema
  static const List<String> formasPagamentoDisponiveis = [
    'Pix',
    'Dinheiro',
    'Cartão de Crédito',
    'Cartão de Débito',
  ];

  /// Calcula a taxa aplicada conforme a forma de pagamento (Dinheiro e Pix possuem 0% de taxa)
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

  /// Consolida o faturamento separando o Dinheiro dos demais métodos
  Map<String, double> calcularTotaisPorForma(List<Map<String, dynamic>> comandas) {
    final Map<String, double> totais = {
      'Pix': 0.0,
      'Dinheiro': 0.0,
      'Cartão de Crédito': 0.0,
      'Cartão de Débito': 0.0,
    };

    for (final c in comandas) {
      final forma = c['formaPagamento']?.toString() ?? 'Dinheiro';
      final valor = (c['valor'] as num?)?.toDouble() ?? 0.0;

      if (totais.containsKey(forma)) {
        totais[forma] = totais[forma]! + valor;
      } else {
        totais['Dinheiro'] = totais['Dinheiro']! + valor;
      }
    }

    return totais;
  }
}
