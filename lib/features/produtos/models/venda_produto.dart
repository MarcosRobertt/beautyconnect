class VendaProduto {
  final String id;
  final String produtoId;
  final String produtoNome;
  final String emoji;
  final double custoHistorico;
  final double precoVendido;
  final int quantidade;
  final String clienteNome;
  final DateTime dataVenda;
  final String formaPagamento; // 💰 NOVO
  final bool isPago; // 💰 NOVO
  final DateTime? dataPagamentoEsperada; // 📅 NOVO

  VendaProduto({
    required this.id,
    required this.produtoId,
    required this.produtoNome,
    required this.emoji,
    required this.custoHistorico,
    required this.precoVendido,
    required this.quantidade,
    required this.clienteNome,
    required this.dataVenda,
    required this.formaPagamento,
    required this.isPago,
    this.dataPagamentoEsperada,
  });

  double get valorTotal => precoVendido * quantidade;
  double get lucroTotal => (precoVendido - custoHistorico) * quantidade;

  Map<String, dynamic> toMap() {
    return {
      'produtoId': produtoId,
      'produtoNome': produtoNome,
      'emoji': emoji,
      'custoHistorico': custoHistorico,
      'precoVendido': precoVendido,
      'quantidade': quantidade,
      'clienteNome': clienteNome,
      'dataVenda': dataVenda.toIso8601String(),
      'formaPagamento': formaPagamento,
      'isPago': isPago,
      'dataPagamentoEsperada': dataPagamentoEsperada?.toIso8601String(),
    };
  }

  factory VendaProduto.fromMap(Map<String, dynamic> map, String docId) {
    return VendaProduto(
      id: docId,
      produtoId: map['produtoId'] ?? '',
      produtoNome: map['produtoNome'] ?? '',
      emoji: map['emoji'] ?? '🛍️',
      custoHistorico: (map['custoHistorico'] ?? 0.0).toDouble(),
      precoVendido: (map['precoVendido'] ?? 0.0).toDouble(),
      quantidade: map['quantidade'] ?? 1,
      clienteNome: map['clienteNome'] ?? '',
      dataVenda: map['dataVenda'] != null ? DateTime.parse(map['dataVenda']) : DateTime.now(),
      // 🛡️ MITIGAÇÃO: Se for venda velha, assume que pagou em dinheiro
      formaPagamento: map['formaPagamento'] ?? 'Dinheiro',
      isPago: map['isPago'] ?? true, 
      dataPagamentoEsperada: map['dataPagamentoEsperada'] != null ? DateTime.parse(map['dataPagamentoEsperada']) : null,
    );
  }
}
