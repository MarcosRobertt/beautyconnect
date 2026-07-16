import 'package:hive/hive.dart';

/// Modelo de Cliente, conforme especificação do documento técnico:
/// id (UUID), nome, telefone, aniversario (opcional), observacoes, createdAt.
class Cliente {
  Cliente({
    required this.id,
    required this.nome,
    required this.telefone,
    this.aniversario,
    this.observacoes = '',
    required this.createdAt,
  });

  final String id;
  final String nome;
  final String telefone;
  final DateTime? aniversario;
  final String observacoes;
  final DateTime createdAt;

  Cliente copyWith({
    String? nome,
    String? telefone,
    DateTime? aniversario,
    String? observacoes,
  }) {
    return Cliente(
      id: id,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      aniversario: aniversario ?? this.aniversario,
      observacoes: observacoes ?? this.observacoes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'telefone': telefone,
        'aniversario': aniversario?.toIso8601String(),
        'observacoes': observacoes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'] as String,
        nome: json['nome'] as String,
        telefone: json['telefone'] as String,
        aniversario: json['aniversario'] != null
            ? DateTime.parse(json['aniversario'] as String)
            : null,
        observacoes: (json['observacoes'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Adapter manual do Hive (sem build_runner) para persistir Cliente em disco/IndexedDB.
/// typeId 0 é reservado exclusivamente para Cliente neste projeto.
class ClienteAdapter extends TypeAdapter<Cliente> {
  @override
  final int typeId = 0;

  @override
  Cliente read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Cliente(
      id: fields[0] as String,
      nome: fields[1] as String,
      telefone: fields[2] as String,
      aniversario: fields[3] as DateTime?,
      observacoes: fields[4] as String,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Cliente obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.telefone)
      ..writeByte(3)
      ..write(obj.aniversario)
      ..writeByte(4)
      ..write(obj.observacoes)
      ..writeByte(5)
      ..write(obj.createdAt);
  }
}
