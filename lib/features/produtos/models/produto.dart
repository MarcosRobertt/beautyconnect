class Produto {
  final String id;
  final String nome;
  final String emoji;
  final double custo;
  final double precoVenda;
  final int estoque;
  final String categoria;
  final DateTime dataCompra;
  final bool temValidade; // 📅 NOVO
  final DateTime? dataValidade; // 📅 NOVO

  Produto({
    required this.id,
    required this.nome,
    required this.emoji,
    required this.custo,
    required this.precoVenda,
    required this.estoque,
    required this.categoria,
    required this.dataCompra,
    required this.temValidade,
    this.dataValidade,
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
      'temValidade': temValidade,
      'dataValidade': dataValidade?.toIso8601String(),
    };
  }

  factory Produto.fromMap(Map<String, dynamic> map, String docId) {
    return Produto(
      id: docId,
      nome: map['nome'] ?? '',
      emoji: map['emoji'] ?? '🛍️',
      custo: (map['custo'] ?? 0.0).toDouble(),
      precoVenda: (map['precoVenda'] ?? 0.0).toDouble(),
      estoque: map['estoque'] ?? 0,
      categoria: map['categoria'] ?? 'Outros',
      dataCompra: map['dataCompra'] != null ? DateTime.parse(map['dataCompra']) : DateTime.now(),
      // 🛡️ MITIGAÇÃO: Produtos velhos assumem que não têm validade marcada
      temValidade: map['temValidade'] ?? false,
      dataValidade: map['dataValidade'] != null ? DateTime.parse(map['dataValidade']) : null,
    );
  }
}
