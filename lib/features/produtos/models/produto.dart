class Produto {
  final String id;
  final String nome;
  final String emoji;
  final double custo;
  final double precoVenda;
  final int estoque;

  Produto({
    required this.id,
    required this.nome,
    required this.emoji,
    required this.custo,
    required this.precoVenda,
    required this.estoque,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'emoji': emoji, // 🛡️ A MÁGICA: Salva apenas 1 caractere no Firebase em vez de fotos pesadas!
      'custo': custo,
      'precoVenda': precoVenda,
      'estoque': estoque,
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
    );
  }
}
