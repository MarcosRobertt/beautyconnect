class Produto {
  final String id;
  final String nome;
  final String emoji;
  final double custo;
  final double precoVenda;
  final int estoque;
  final String categoria; // 🏷️ NOVO
  final DateTime dataCompra; // 📅 NOVO

  Produto({
    required this.id,
    required this.nome,
    required this.emoji,
    required this.custo,
    required this.precoVenda,
    required this.estoque,
    required this.categoria,
    required this.dataCompra,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'emoji': emoji,
      'custo': custo,
      'precoVenda': precoVenda,
      'estoque': estoque,
      'categoria': categoria,
      'dataCompra': dataCompra.toIso8601String(),
    };
  }

  factory Produto.fromMap(Map<String, dynamic> map, String documentId) {
    return Produto(
      id: documentId,
      nome: map['nome'] ?? '',
      emoji: map['emoji'] ?? '🛍️',
      custo: (map['custo'] ?? 0.0).toDouble(),
      precoVenda: (map['precoVenda'] ?? 0.0).toDouble(),
      estoque: map['estoque'] ?? 0,
      // 🛡️ MITIGAÇÃO: Se o produto for antigo e não tiver esses campos, define padrões seguros
      categoria: map['categoria'] ?? 'Outros', 
      dataCompra: map['dataCompra'] != null ? DateTime.parse(map['dataCompra']) : DateTime.now(),
    );
  }
}
