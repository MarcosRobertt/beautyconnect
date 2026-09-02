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
    DateTime? createdAt, // Retirado o required para evitar erro no formulário
    DateTime? updatedAt, // Retirado o required para evitar erro no formulário
    this.totalVisitas = 0,
    this.totalGasto = 0.0,
    this.ultimaVisita,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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

  // 🔄 Renomeado de toMap para toJson (Padronização com o Backup e Repositório)
  Map<String, dynamic> toJson() {
    return {
      'id': id, 
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

  // 🔄 Renomeado de fromMap para fromJson (Padronização com o Backup e Repositório)
  factory Cliente.fromJson(Map<String, dynamic> map, [String? idOverride]) {
    return Cliente(
      id: idOverride ?? map['id'] ?? '',
      nome: map['nome'] ?? '',
      telefone: map['telefone'] ?? '',
      observacoes: map['observacoes'] ?? '',
      profissao: map['profissao'],
      aniversario: _parseDate(map['aniversario']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
      totalVisitas: map['totalVisitas'] ?? 0,
      totalGasto: (map['totalGasto'] ?? 0.0).toDouble(),
      ultimaVisita: _parseDate(map['ultimaVisita']),
    );
  }

  // Helper de segurança para converter datas que vêm do Firestore ou do Backup offline
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value); // Para o BackupService
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
