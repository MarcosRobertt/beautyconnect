enum AgendamentoStatus { agendado, confirmado, concluido, cancelado }

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
    required this.servico,
    required this.valor,
    required this.data,
    required this.horaInicio,
    required this.duracaoMinutos,
    required this.status,
    this.formaPagamento,
    this.observacoes,
  });

  final String id;
  final String clienteId;
  final String servico;
  final double valor;
  final DateTime data;
  final String horaInicio;
  final int duracaoMinutos;
  final AgendamentoStatus status;
  final FormaPagamento? formaPagamento;
  final String? observacoes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clienteId': clienteId,
      'servico': servico,
      'valor': valor,
      'data': data.toIso8601String(),
      'horaInicio': horaInicio,
      'duracaoMinutos': duracaoMinutos,
      'status': status.name,
      'formaPagamento': formaPagamento?.name,
      'observacoes': observacoes,
    };
  }

  factory Agendamento.fromJson(Map<String, dynamic> json) {
    return Agendamento(
      id: json['id'] as String,
      clienteId: json['clienteId'] as String,
      servico: json['servico'] as String,
      valor: (json['valor'] as num).toDouble(),
      data: DateTime.parse(json['data'] as String),
      horaInicio: json['horaInicio'] as String,
      duracaoMinutos: json['duracaoMinutos'] as int,
      status: AgendamentoStatus.values.byName(json['status'] as String),
      formaPagamento: json['formaPagamento'] != null
          ? FormaPagamento.values.byName(json['formaPagamento'] as String)
          : null,
      observacoes: json['observacoes'] as String?,
    );
  }

  Agendamento copyWith({
    String? id,
    String? clienteId,
    String? servico,
    double? valor,
    DateTime? data,
    String? horaInicio,
    int? duracaoMinutos,
    AgendamentoStatus? status,
    FormaPagamento? formaPagamento,
    String? observacoes,
  }) {
    return Agendamento(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      servico: servico ?? this.servico,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      horaInicio: horaInicio ?? this.horaInicio,
      duracaoMinutos: duracaoMinutos ?? this.duracaoMinutos,
      status: status ?? this.status,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}
