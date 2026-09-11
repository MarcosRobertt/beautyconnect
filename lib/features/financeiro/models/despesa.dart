
class Despesa {
  final String id;
  final String descricao;
  final double valor;
  final String categoria;
  final String tipo; // REGULAR, FIXA, PARCELADA
  final DateTime dataVencimento;
  final DateTime? dataPagamento;
  final String status; // PENDENTE, PAGO
  final int? parcelaAtual;
  final int? totalParcelas;
  final String? idAgrupador;

  Despesa({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.categoria,
    required this.tipo,
    required this.dataVencimento,
    this.dataPagamento,
    required this.status,
    this.parcelaAtual,
    this.totalParcelas,
    this.idAgrupador,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'valor': valor,
      'categoria': categoria,
      'tipo': tipo,
      'dataVencimento': dataVencimento.toIso8601String(),
      'dataPagamento': dataPagamento?.toIso8601String(),
      'status': status,
      'parcelaAtual': parcelaAtual,
      'totalParcelas': totalParcelas,
      'idAgrupador': idAgrupador,
    };
  }

  factory Despesa.fromMap(Map<String, dynamic> map, String documentId) {
    return Despesa(
      id: documentId,
      descricao: map['descricao'] ?? '',
      valor: (map['valor'] ?? 0.0).toDouble(),
      categoria: map['categoria'] ?? '',
      tipo: map['tipo'] ?? 'REGULAR',
      dataVencimento: DateTime.parse(map['dataVencimento']),
      dataPagamento: map['dataPagamento'] != null ? DateTime.parse(map['dataPagamento']) : null,
      status: map['status'] ?? 'PENDENTE',
      parcelaAtual: map['parcelaAtual'],
      totalParcelas: map['totalParcelas'],
      idAgrupador: map['idAgrupador'],
    );
  }
}
