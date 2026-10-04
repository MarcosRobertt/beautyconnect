class VendaProduto {
  final String id;
  final String produtoId;
  final String produtoNome;
  final String emoji;
  final double custoHistorico; // 🚨 MITIGAÇÃO: Protege o lucro de mudanças futuras de preço
  final double precoVendido;
  final int quantidade;
  final String clienteNome;
  final DateTime dataVenda;

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
  });

  double get lucroTotal => (precoVendido - custoHistorico) * quantidade;
  double get valorTotal => precoVendido * quantidade;

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
    };
  }

  factory VendaProduto.fromMap(Map<String, dynamic> map, String documentId) {
    return VendaProduto(
      id: documentId,
      produtoId: map['produtoId'] ?? '',
      produtoNome: map['produtoNome'] ?? '',
      emoji: map['emoji'] ?? '🛍️',
      custoHistorico: (map['custoHistorico'] ?? 0.0).toDouble(),
      precoVendido: (map['precoVendido'] ?? 0.0).toDouble(),
      quantidade: map['quantidade'] ?? 1,
      clienteNome: map['clienteNome'] ?? 'Avulso',
      dataVenda: DateTime.parse(map['dataVenda']),
    );
  }
}
