import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para guardar a data que abriu e a data que acabou o pote
class CicloDeUso {
  final String id;
  final DateTime dataAbertura;
  final DateTime? dataFim;

  CicloDeUso({required this.id, required this.dataAbertura, this.dataFim});

  Map<String, dynamic> toMap() => {
    'id': id,
    'dataAbertura': dataAbertura.toIso8601String(),
    'dataFim': dataFim?.toIso8601String(),
  };

  factory CicloDeUso.fromMap(Map<String, dynamic> map) {
    return CicloDeUso(
      id: map['id'] ?? '',
      dataAbertura: map['dataAbertura'] != null ? DateTime.parse(map['dataAbertura']) : DateTime.now(),
      dataFim: map['dataFim'] != null ? DateTime.parse(map['dataFim']) : null,
    );
  }
}

class Insumo {
  final String id;
  final String nome;
  final String categoria;
  final int quantidade;
  final int estoqueMinimo;
  final double precoPago;
  final DateTime dataCompra;
  
  // 🧠 NOVOS CAMPOS PARA A IA DE PRECIFICAÇÃO
  final List<String> servicosVinculados;
  final List<CicloDeUso> ciclosDeUso;

  Insumo({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.quantidade,
    required this.estoqueMinimo,
    required this.precoPago,
    required this.dataCompra,
    required this.servicosVinculados,
    required this.ciclosDeUso,
  });

  bool get emAlerta => quantidade <= estoqueMinimo;
  
  // Verifica se existe algum pote aberto atualmente
  bool get temPoteAberto => ciclosDeUso.any((c) => c.dataFim == null);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'categoria': categoria,
      'quantidade': quantidade,
      'estoqueMinimo': estoqueMinimo,
      'precoPago': precoPago,
      'dataCompra': dataCompra.toIso8601String(),
      'servicosVinculados': servicosVinculados,
      'ciclosDeUso': ciclosDeUso.map((c) => c.toMap()).toList(),
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
      
      // 🛡️ MITIGAÇÃO: Se for insumo antigo, nasce com lista vazia sem quebrar o app
      servicosVinculados: List<String>.from(map['servicosVinculados'] ?? []),
      ciclosDeUso: (map['ciclosDeUso'] as List<dynamic>?)
              ?.map((e) => CicloDeUso.fromMap(e as Map<String, dynamic>))
              .toList() ?? [],
    );
  }
}
