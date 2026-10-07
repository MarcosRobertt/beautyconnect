import 'package:cloud_firestore/cloud_firestore.dart';

class CicloDeUso {
  final String id;
  final DateTime dataAbertura;
  final DateTime? dataFim;

  CicloDeUso({required this.id, required this.dataAbertura, this.dataFim});

  factory CicloDeUso.fromMap(Map<String, dynamic> map) {
    return CicloDeUso(
      id: map['id'] ?? '',
      dataAbertura: map['dataAbertura'] is Timestamp ? (map['dataAbertura'] as Timestamp).toDate() : DateTime.parse(map['dataAbertura']),
      dataFim: map['dataFim'] != null ? (map['dataFim'] is Timestamp ? (map['dataFim'] as Timestamp).toDate() : DateTime.parse(map['dataFim'])) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'dataAbertura': dataAbertura.toIso8601String(),
    'dataFim': dataFim?.toIso8601String(),
  };
}

class Insumo {
  final String id;
  final String nome;
  final String categoria;
  final int quantidade;
  final int estoqueMinimo;
  final double precoPago;
  final DateTime dataCompra;
  final List<String> servicosVinculados;
  final List<CicloDeUso> ciclosDeUso;
  
  // 🧠 NOVO: A gaveta que vai guardar a inflação (inicia vazia para não quebrar o passado)
  final List<String> historicoPrecos; 

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
    this.historicoPrecos = const [], 
  });

  bool get emAlerta => quantidade <= estoqueMinimo;
  bool get temPoteAberto => ciclosDeUso.any((c) => c.dataFim == null);

  factory Insumo.fromMap(Map<String, dynamic> map) {
    return Insumo(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      categoria: map['categoria'] ?? '',
      quantidade: map['quantidade'] ?? 0,
      estoqueMinimo: map['estoqueMinimo'] ?? 1,
      precoPago: (map['precoPago'] ?? 0).toDouble(),
      dataCompra: map['dataCompra'] is Timestamp ? (map['dataCompra'] as Timestamp).toDate() : (map['dataCompra'] != null ? DateTime.parse(map['dataCompra']) : DateTime.now()),
      servicosVinculados: List<String>.from(map['servicosVinculados'] ?? []),
      ciclosDeUso: (map['ciclosDeUso'] as List<dynamic>? ?? []).map((c) => CicloDeUso.fromMap(c)).toList(),
      historicoPrecos: List<String>.from(map['historicoPrecos'] ?? []), // 🛡️ Proteção de leitura
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'categoria': categoria,
    'quantidade': quantidade,
    'estoqueMinimo': estoqueMinimo,
    'precoPago': precoPago,
    'dataCompra': dataCompra.toIso8601String(),
    'servicosVinculados': servicosVinculados,
    'ciclosDeUso': ciclosDeUso.map((c) => c.toMap()).toList(),
    'historicoPrecos': historicoPrecos, // ☁️ Gravação na Nuvem
  };
}
