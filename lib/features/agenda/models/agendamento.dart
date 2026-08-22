enum AgendamentoStatus {
  agendado('Agendado'),
  confirmado('Confirmado'),
  concluido('Concluído'),
  cancelado('Cancelado');

  const AgendamentoStatus(this.label);
  final String label;
}

enum FormaPagamento {
  pix('Pix'),
  credito('Cartão de Crédito'),
  debito('Cartão de Débito'),
  dinheiro('Dinheiro'),
  permuta('Permuta'),
  pendente('Pendente (Comanda Aberta)');

  const FormaPagamento(this.rotulo);
  final String rotulo;
}

class Agendamento {
  Agendamento({
    required this.id,
    required this.clienteId,
    this.servicoId,
    required this.servico,
    required this.valor,
    required this.data,
    required this.horaInicio,
    String? horaFim,
    required this.duracaoMinutos,
    required this.status,
    this.formaPagamento,
    this.observacao,
    this.updatedAt,
  }) : _horaFimGuardada = horaFim;

  final String id;
  final String clienteId;
  final String? servicoId;
  final String servico;
  final double valor;
  final DateTime data;
  final String horaInicio;
  final String? _horaFimGuardada;
  final int duracaoMinutos;
  final AgendamentoStatus status;
  final FormaPagamento? formaPagamento;
  final String? observacao;
  final DateTime? updatedAt;

  String get horaFim {
    if (_horaFimGuardada != null && _horaFimGuardada!.isNotEmpty) {
      return _horaFimGuardada!;
    }
    final partes = horaInicio.split(':');
    if (partes.length < 2) return horaInicio;
    final hora = int.tryParse(partes[0]) ?? 0;
    final minuto = int.tryParse(partes[1]) ?? 0;
    final inicioDt = DateTime(2026, 1, 1, hora, minuto);
    final fimDt = inicioDt.add(Duration(minutes: duracaoMinutos));
    return '${fimDt.hour.toString().padLeft(2, '0')}:${fimDt.minute.toString().padLeft(2, '0')}';
  }

  String get observacoes => observacao ?? '';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clienteId': clienteId,
      'servicoId': servicoId,
      'servico': servico,
      'valor': valor,
      'data': data.toIso8601String(),
      'horaInicio': horaInicio,
      'horaFim': horaFim,
      'duracaoMinutos': duracaoMinutos,
      'status': status.name,
      'formaPagamento': formaPagamento?.name,
      'observacao': observacao,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Agendamento.fromJson(Map<String, dynamic> json) {
    return Agendamento(
      id: json['id'] as String,
      clienteId: json['clienteId'] as String,
      servicoId: json['servicoId'] as String?,
      servico: json['servico'] as String,
      valor: (json['valor'] as num).toDouble(),
      data: DateTime.parse(json['data'] as String),
      horaInicio: json['horaInicio'] as String,
      horaFim: json['horaFim'] as String?,
      duracaoMinutos: (json['duracaoMinutos'] as num?)?.toInt() ?? 30,
      status: AgendamentoStatus.values.byName(json['status'] as String),
      formaPagamento: json['formaPagamento'] != null
          ? FormaPagamento.values.byName(json['formaPagamento'] as String)
          : null,
      observacao: json['observacao'] as String? ?? json['observacoes'] as String?,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  Agendamento copyWith({
    String? id,
    String? clienteId,
    String? servicoId,
    String? servico,
    double? valor,
    DateTime? data,
    String? horaInicio,
    String? horaFim,
    int? duracaoMinutos,
    AgendamentoStatus? status,
    FormaPagamento? formaPagamento,
    String? observacao,
    DateTime? updatedAt,
  }) {
    return Agendamento(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      servicoId: servicoId ?? this.servicoId,
      servico: servico ?? this.servico,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFim: horaFim ?? _horaFimGuardada,
      duracaoMinutos: duracaoMinutos ?? this.duracaoMinutos,
      status: status ?? this.status,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      observacao: observacao ?? this.observacao,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
