import 'package:hive/hive.dart';

/// Modelo de Serviço (catálogo), conforme especificação do MVP de validação:
/// nome, duração (minutos), valor e cor usada na Agenda.
class Servico {
  Servico({
    required this.id,
    required this.nome,
    required this.duracaoMin,
    required this.valor,
    required this.corValor,
    required this.createdAt,
  });

  final String id;
  final String nome;
  final int duracaoMin;
  final double valor;

  /// Cor usada para identificar visualmente este serviço na Agenda.
  /// Guardada como valor inteiro ARGB (`Color.value`), para não acoplar o
  /// modelo de domínio ao Flutter (`dart:ui`).
  final int corValor;

  final DateTime createdAt;

  Servico copyWith({
    String? nome,
    int? duracaoMin,
    double? valor,
    int? corValor,
  }) {
    return Servico(
      id: id,
      nome: nome ?? this.nome,
      duracaoMin: duracaoMin ?? this.duracaoMin,
      valor: valor ?? this.valor,
      corValor: corValor ?? this.corValor,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'duracaoMin': duracaoMin,
        'valor': valor,
        'corValor': corValor,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Servico.fromJson(Map<String, dynamic> json) => Servico(
        id: json['id'] as String,
        nome: json['nome'] as String,
        duracaoMin: json['duracaoMin'] as int,
        valor: (json['valor'] as num).toDouble(),
        corValor: json['corValor'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// typeId 3 é reservado exclusivamente para Servico neste projeto
/// (0 = Cliente, 1 = Agendamento, 2 = AgendamentoStatus).
class ServicoAdapter extends TypeAdapter<Servico> {
  @override
  final int typeId = 3;

  @override
  Servico read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Servico(
      id: fields[0] as String,
      nome: fields[1] as String,
      duracaoMin: fields[2] as int,
      valor: fields[3] as double,
      corValor: fields[4] as int,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Servico obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.duracaoMin)
      ..writeByte(3)
      ..write(obj.valor)
      ..writeByte(4)
      ..write(obj.corValor)
      ..writeByte(5)
      ..write(obj.createdAt);
  }
}
