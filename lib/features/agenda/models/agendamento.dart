import 'package:hive/hive.dart';

/// Status possíveis de um agendamento, conforme documento técnico.
enum AgendamentoStatus { agendado, confirmado, concluido, cancelado }

extension AgendamentoStatusLabel on AgendamentoStatus {
  String get label {
    switch (this) {
      case AgendamentoStatus.agendado:
        return 'Agendado';
      case AgendamentoStatus.confirmado:
        return 'Confirmado';
      case AgendamentoStatus.concluido:
        return 'Concluído';
      case AgendamentoStatus.cancelado:
        return 'Cancelado';
    }
  }
}

/// Modelo de Agendamento.
///
/// NOTA (MVP validação com manicure real): campo `servicoId` foi adicionado
/// para vincular o agendamento ao catálogo de Serviços. `servico` (nome) e
/// `valor` continuam existindo e são preenchidos como uma "foto" do serviço
/// no momento do agendamento — isso é intencional: se o preço do serviço for
/// alterado no catálogo depois, o histórico antigo não muda retroativamente.
/// `servicoId` é opcional (nullable) de propósito, para que agendamentos
/// já existentes (criados antes deste campo existir) continuem funcionando
/// normalmente, sem nenhuma migração de dados necessária.
class Agendamento {
  Agendamento({
    required this.id,
    required this.clienteId,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    required this.servico,
    required this.valor,
    required this.status,
    this.observacao = '',
    required this.createdAt,
    required this.updatedAt,
    this.servicoId,
  });

  final String id;
  final String clienteId;
  final DateTime data;

  /// Guardado como texto "HH:mm" para simplificar comparação e edição.
  final String horaInicio;
  final String horaFim;

  final String servico;
  final double valor;
  final AgendamentoStatus status;
  final String observacao;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Referência ao catálogo de Serviços. Pode ser nulo em registros antigos.
  final String? servicoId;

  Agendamento copyWith({
    String? clienteId,
    DateTime? data,
    String? horaInicio,
    String? horaFim,
    String? servico,
    double? valor,
    AgendamentoStatus? status,
    String? observacao,
    DateTime? updatedAt,
    String? servicoId,
  }) {
    return Agendamento(
      id: id,
      clienteId: clienteId ?? this.clienteId,
      data: data ?? this.data,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFim: horaFim ?? this.horaFim,
      servico: servico ?? this.servico,
      valor: valor ?? this.valor,
      status: status ?? this.status,
      observacao: observacao ?? this.observacao,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      servicoId: servicoId ?? this.servicoId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clienteId': clienteId,
        'data': data.toIso8601String(),
        'horaInicio': horaInicio,
        'horaFim': horaFim,
        'servico': servico,
        'valor': valor,
        'status': status.name,
        'observacao': observacao,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'servicoId': servicoId,
      };

  factory Agendamento.fromJson(Map<String, dynamic> json) => Agendamento(
        id: json['id'] as String,
        clienteId: json['clienteId'] as String,
        data: DateTime.parse(json['data'] as String),
        horaInicio: json['horaInicio'] as String,
        horaFim: json['horaFim'] as String,
        servico: json['servico'] as String,
        valor: (json['valor'] as num).toDouble(),
        status: AgendamentoStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AgendamentoStatus.agendado,
        ),
        observacao: (json['observacao'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        servicoId: json['servicoId'] as String?,
      );
}

/// typeId 1 é reservado exclusivamente para Agendamento neste projeto.
class AgendamentoAdapter extends TypeAdapter<Agendamento> {
  @override
  final int typeId = 1;

  @override
  Agendamento read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Agendamento(
      id: fields[0] as String,
      clienteId: fields[1] as String,
      data: fields[2] as DateTime,
      horaInicio: fields[3] as String,
      horaFim: fields[4] as String,
      servico: fields[5] as String,
      valor: fields[6] as double,
      status: fields[7] as AgendamentoStatus,
      observacao: fields[8] as String,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      // Campo novo: registros gravados antes desta versão simplesmente não
      // têm a chave 11 no mapa, então o resultado é null automaticamente.
      servicoId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Agendamento obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clienteId)
      ..writeByte(2)
      ..write(obj.data)
      ..writeByte(3)
      ..write(obj.horaInicio)
      ..writeByte(4)
      ..write(obj.horaFim)
      ..writeByte(5)
      ..write(obj.servico)
      ..writeByte(6)
      ..write(obj.valor)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.observacao)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.servicoId);
  }
}

/// typeId 2 é reservado exclusivamente para o enum AgendamentoStatus.
class AgendamentoStatusAdapter extends TypeAdapter<AgendamentoStatus> {
  @override
  final int typeId = 2;

  @override
  AgendamentoStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AgendamentoStatus.agendado;
      case 1:
        return AgendamentoStatus.confirmado;
      case 2:
        return AgendamentoStatus.concluido;
      case 3:
        return AgendamentoStatus.cancelado;
      default:
        return AgendamentoStatus.agendado;
    }
  }

  @override
  void write(BinaryWriter writer, AgendamentoStatus obj) {
    switch (obj) {
      case AgendamentoStatus.agendado:
        writer.writeByte(0);
        break;
      case AgendamentoStatus.confirmado:
        writer.writeByte(1);
        break;
      case AgendamentoStatus.concluido:
        writer.writeByte(2);
        break;
      case AgendamentoStatus.cancelado:
        writer.writeByte(3);
        break;
    }
  }
}
