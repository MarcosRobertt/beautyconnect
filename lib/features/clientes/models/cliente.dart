import 'package:cloud_firestore/cloud_firestore.dart';

class Cliente {
  final String id;
  final String nome;
  final String telefone;
  final String observacoes;
  final String? profissao;
  final DateTime? aniversario;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 🚀 NOVOS CAMPOS: Desnormalização para Performance
  final int totalVisitas;
  final double totalGasto;
  final DateTime? ultimaVisita;

  Cliente({
    required this.id,
    required this.nome,
    required this.telefone,
    this.observacoes = '',
    this.profissao,
    this.aniversario,
    required this.createdAt,
    required this.updatedAt,
    this.totalVisitas = 0,
    this.totalGasto = 0.0,
    this.ultimaVisita,
  });

  Cliente copyWith({
    String? id,
    String? nome,
    String? telefone,
    String? observacoes,
    String? profissao,
    DateTime? aniversario,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalVisitas,
    double? totalGasto,
    DateTime? ultimaVisita,
  }) {
    return Cliente(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      observacoes: observacoes ?? this.observacoes,
      profissao: profissao ?? this.profissao,
      aniversario: aniversario ?? this.aniversario,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalVisitas: totalVisitas ?? this.totalVisitas,
      totalGasto: totalGasto ?? this.totalGasto,
      ultimaVisita: ultimaVisita ?? this.ultimaVisita,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'telefone': telefone,
      'observacoes': observacoes,
      'profissao': profissao,
      'aniversario': aniversario != null ? Timestamp.fromDate(aniversario!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'totalVisitas': totalVisitas,
      'totalGasto': totalGasto,
      'ultimaVisita': ultimaVisita != null ? Timestamp.fromDate(ultimaVisita!) : null,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map, String id) {
    return Cliente(
      id: id,
      nome: map['nome'] ?? '',
      telefone: map['telefone'] ?? '',
      observacoes: map['observacoes'] ?? '',
      profissao: map['profissao'],
      aniversario: map['aniversario'] != null ? (map['aniversario'] as Timestamp).toDate() : null,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : DateTime.now(),
      totalVisitas: map['totalVisitas'] ?? 0,
      totalGasto: (map['totalGasto'] ?? 0.0).toDouble(),
      ultimaVisita: map['ultimaVisita'] != null ? (map['ultimaVisita'] as Timestamp).toDate() : null,
    );
  }
}
