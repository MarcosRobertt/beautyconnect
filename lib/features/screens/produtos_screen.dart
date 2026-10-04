import 'package:flutter/material.dart';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF8A2463);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF0F4),
        appBar: AppBar(
          title: const Text('Loja & Revenda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          bottom: const TabBar(
            labelColor: primaryColor,
            indicatorColor: primaryColor,
            tabs: [
              Tab(icon: Icon(Icons.storefront), text: 'Vitrine (Estoque)'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Histórico de Vendas'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: primaryColor, size: 28),
              tooltip: 'Cadastrar Novo Produto',
              onPressed: () {
                // Em breve: Modal para cadastrar o Produto com Emoji, Custo e Venda
              },
            )
          ],
        ),
        body: const TabBarView(
          children: [
            // ABA 1: VITRINE
            Center(
              child: Text(
                'Sua vitrine está vazia.\nClique no + para cadastrar o primeiro produto.', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Colors.grey)
              ),
            ),
            // ABA 2: HISTÓRICO
            Center(
              child: Text(
                'Nenhuma venda registrada ainda.', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Colors.grey)
              ),
            ),
          ],
        ),
      ),
    );
  }
}
