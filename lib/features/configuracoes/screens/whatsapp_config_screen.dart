import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WhatsAppConfigScreen extends StatefulWidget {
  const WhatsAppConfigScreen({super.key});

  @override
  State<WhatsAppConfigScreen> createState() => _WhatsAppConfigScreenState();
}

class _WhatsAppConfigScreenState extends State<WhatsAppConfigScreen> {
  final _ctrlConfirmacao = TextEditingController();
  final _ctrlCancelamento = TextEditingController();
  
  // 🎯 AS 3 OPÇÕES DE RETENÇÃO
  final _ctrlRetencao1 = TextEditingController();
  final _ctrlRetencao2 = TextEditingController();
  final _ctrlRetencao3 = TextEditingController();
  
  bool _carregando = true;
  bool _salvando = false;

  // 🎨 NOVA IDENTIDADE VISUAL (VERDE SÁLVIA)
  final Color _primaryColor = const Color(0xFF3A4E40); // Verde Escuro Principal
  final Color _lightAccent = const Color(0xFFE8EFEA);  // Verde Claro (Fundos)
  final Color _borderAccent = const Color(0xFFB5C4B9); // Verde Intermédio (Bordas)

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracoes').doc('whatsapp').get();
      if (doc.exists) {
        _ctrlConfirmacao.text = doc['msg_confirmacao'] ?? '';
        _ctrlCancelamento.text = doc['msg_cancelamento'] ?? '';
        _ctrlRetencao1.text = doc['msg_retencao_1'] ?? '';
        _ctrlRetencao2.text = doc['msg_retencao_2'] ?? '';
        _ctrlRetencao3.text = doc['msg_retencao_3'] ?? '';
      } else {
        _ctrlConfirmacao.text = "Olá, [NOME]! Tudo bem? 💅\n\nPassando para confirmar o seu agendamento:\n🗓️ Data: [DATA] ([DIA_SEMANA])\n⏰ Horário: [HORA]\n✨ Serviço: [SERVICO]\n\nPodemos confirmar a sua presença?";
        _ctrlCancelamento.text = "Olá, [NOME]. Seu agendamento para [DATA] foi cancelado com sucesso. Caso queira remarcar, estamos à disposição! 🌸";
      }
      
      // Se as retenções vierem vazias, injeta os padrões
      if (_ctrlRetencao1.text.isEmpty) _ctrlRetencao1.text = "Olá, [NOME]! Tudo bem? Sentimos a sua falta no Studio Condeza! 🥰\n\nNotamos que faz [DIAS] dias desde a sua última visita. Vamos agendar um horário para cuidar de você esta semana?";
      if (_ctrlRetencao2.text.isEmpty) _ctrlRetencao2.text = "Oi, [NOME]! Sumida! 👀 Passando para avisar que temos algumas novidades maravilhosas. Que tal tirar um tempinho para você e vir dar uma olhadinha na nossa agenda?";
      if (_ctrlRetencao3.text.isEmpty) _ctrlRetencao3.text = "Olá, [NOME]! Tudo bem? Como faz um tempinho que não nos vemos, queríamos saber se aconteceu algo ou se podemos ajudar. Sua presença é muito importante para nós! 💖";
      
    } catch (e) {
      debugPrint('Erro ao carregar mensagens: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    setState(() => _salvando = true);
    try {
      await FirebaseFirestore.instance.collection('configuracoes').doc('whatsapp').set({
        'msg_confirmacao': _ctrlConfirmacao.text.trim(),
        'msg_cancelamento': _ctrlCancelamento.text.trim(),
        'msg_retencao_1': _ctrlRetencao1.text.trim(),
        'msg_retencao_2': _ctrlRetencao2.text.trim(),
        'msg_retencao_3': _ctrlRetencao3.text.trim(),
        'ultima_atualizacao': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✅ Mensagens atualizadas com sucesso!'), backgroundColor: _primaryColor));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _buildEditor(String titulo, TextEditingController controller, String descricao, String tags, {IconData icone = Icons.chat_bubble_outline}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _borderAccent)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icone, color: _primaryColor, size: 20), const SizedBox(width: 8), Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
            const SizedBox(height: 8),
            Text(descricao, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _lightAccent, borderRadius: BorderRadius.circular(8)),
              child: Text('Curingas permitidos: $tags', style: TextStyle(fontSize: 11, color: _primaryColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller, maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Digite a mensagem...', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderAccent)), 
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryColor, width: 2)),
                filled: true, fillColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9), // Fundo Sálvia Muito Claro
      appBar: AppBar(
        title: const Text('Mensagens Automáticas'),
        backgroundColor: _lightAccent.withOpacity(0.5),
      ),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Edite os textos. O sistema vai trocar os colchetes [ ] pelos dados reais da cliente na hora do envio.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 16),
                
                _buildEditor('Confirmação de Agendamento', _ctrlConfirmacao, 'Enviada no dia ou na véspera.', '[NOME], [DATA], [DIA_SEMANA], [HORA], [SERVICO]', icone: Icons.check_circle_outline),
                _buildEditor('Mensagem de Cancelamento', _ctrlCancelamento, 'Enviada quando desmarcam.', '[NOME], [DATA], [SERVICO]', icone: Icons.cancel_outlined),
                
                Divider(height: 40, thickness: 2, color: _borderAccent.withOpacity(0.3)),
                Text('🎯 MENSAGENS DE RESGATE (RETENÇÃO)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primaryColor)),
                const SizedBox(height: 16),

                _buildEditor('Opção 1: Saudade (Padrão)', _ctrlRetencao1, 'Foco em mostrar que sentiu falta da cliente.', '[NOME], [DIAS]', icone: Icons.favorite_border),
                _buildEditor('Opção 2: Novidades / Mimo', _ctrlRetencao2, 'Foco em atrair com novidades ou uma promoção.', '[NOME], [DIAS]', icone: Icons.card_giftcard),
                _buildEditor('Opção 3: Feedback', _ctrlRetencao3, 'Foco em descobrir o motivo do sumiço.', '[NOME], [DIAS]', icone: Icons.help_outline),
                
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: _salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                  label: Text(_salvando ? 'Salvando...' : 'Salvar Alterações Gerais'),
                  onPressed: _salvando ? null : _salvarConfiguracoes,
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
