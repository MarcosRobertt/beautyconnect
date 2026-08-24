import 'package:flutter/material.dart';

class AnaliseIaScreen extends StatefulWidget {
  final String? contextoMetricas;

  const AnaliseIaScreen({super.key, this.contextoMetricas});

  @override
  State<AnaliseIaScreen> createState() => _AnaliseIaScreenState();
}

class _AnaliseIaScreenState extends State<AnaliseIaScreen> {
  final List<String> _mensagens = [];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // A IA já "lê" os dados do seu Studio assim que a tela abre
    if (widget.contextoMetricas != null) {
      _mensagens.add("Bem-vindo à Consultoria Estratégica do BeautyConnect!\n\nAcabei de analisar seus dados de faturamento, Ticket Médio e retenção de clientes. Como posso te ajudar a melhorar o desempenho do seu Studio hoje?");
      
      // TODO: Aqui você envia a variável `widget.contextoMetricas` invisivelmente 
      // para a API da sua IA (Gemini/OpenAI) como "system instruction" ou prompt inicial.
    }
  }

  void _enviarMensagem() {
    if (_chatController.text.trim().isEmpty) return;
    
    setState(() {
      _mensagens.add("Você: ${_chatController.text}");
      // TODO: Conectar o envio para a API da IA aqui e receber a resposta
      _mensagens.add("IA: (Conecte sua API de IA para responder sobre a estratégia de negócios baseada no Ticket Médio e Agendamentos...)");
    });
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultoria Inteligente'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mensagens.length,
              itemBuilder: (context, index) {
                final isUser = _mensagens[index].startsWith("Você:");
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_mensagens[index]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Pergunte como aumentar o lucro...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _enviarMensagem,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
