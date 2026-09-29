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
  // 🛡️ NOVO CAMPO: Pode ser nulo para não quebrar o histórico antigo
  final String? formaPagamento; 

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
    this.formaPagamento,
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
      'formaPagamento': formaPagamento, // Salva no Firebase
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
      // 🛡️ LÊ COM SEGURANÇA: Se não existir no banco, assume nulo automaticamente
      formaPagamento: map['formaPagamento'], 
    );
  }
}
