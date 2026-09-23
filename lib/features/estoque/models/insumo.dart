
import 'package:cloud_firestore/cloud_firestore.dart';

class Insumo {
  final String id;
  final String nome;
  final String categoria;
  final int quantidade;
  final int estoqueMinimo;
  final double precoPago;
  final DateTime dataCompra;

  Insumo({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.quantidade,
    required this.estoqueMinimo,
    required this.precoPago,
    required this.dataCompra,
  });

  bool get emAlerta => quantidade <= estoqueMinimo;

  Insumo copyWith({
    String? id,
    String? nome,
    String? categoria,
    int? quantidade,
    int? estoqueMinimo,
    double? precoPago,
    DateTime? dataCompra,
  }) {
    return Insumo(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      quantidade: quantidade ?? this.quantidade,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
      precoPago: precoPago ?? this.precoPago,
      dataCompra: dataCompra ?? this.dataCompra,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'categoria': categoria,
      'quantidade': quantidade,
      'estoqueMinimo': estoqueMinimo,
      'precoPago': precoPago,
      'dataCompra': dataCompra.toIso8601String(),
    };
  }

  factory Insumo.fromMap(Map<String, dynamic> map) {
    DateTime parseData(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Insumo(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      categoria: map['categoria'] ?? 'Gerais',
      quantidade: (map['quantidade'] as num?)?.toInt() ?? 0,
      estoqueMinimo: (map['estoqueMinimo'] as num?)?.toInt() ?? 1,
      precoPago: (map['precoPago'] as num?)?.toDouble() ?? 0.0,
      dataCompra: parseData(map['dataCompra']),
    );
  }
}
