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
  final _ctrlRetencao = TextEditingController();
  bool _carregando = true;
  bool _salvando = false;

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
        _ctrlRetencao.text = doc['msg_retencao'] ?? '';
      } else {
        // Textos Padrão caso seja o primeiro acesso
        _ctrlConfirmacao.text = "Olá, [NOME]! Tudo bem? 💅\n\nPassando para confirmar o seu agendamento:\n🗓️ Data: [DATA] ([DIA_SEMANA])\n⏰ Horário: [HORA]\n✨ Serviço: [SERVICO]\n\nPodemos confirmar a sua presença?";
        _ctrlCancelamento.text = "Olá, [NOME]. Seu agendamento para [DATA] foi cancelado com sucesso. Caso queira remarcar, estamos à disposição! 🌸";
        _ctrlRetencao.text = "Olá, [NOME]! Tudo bem? Sentimos a sua falta no Studio Condeza! 🥰\n\nNotamos que faz um tempinho desde a sua última visita. Vamos agendar um horário para cuidar de você esta semana?";
      }
    } catch (e) {
      debugPrint('Erro ao carregar mensagens: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    if (_ctrlConfirmacao.text.trim().isEmpty) return;

    setState(() => _salvando = true);
    try {
      await FirebaseFirestore.instance.collection('configuracoes').doc('whatsapp').set({
        'msg_confirmacao': _ctrlConfirmacao.text.trim(),
        'msg_cancelamento': _ctrlCancelamento.text.trim(),
        'msg_retencao': _ctrlRetencao.text.trim(),
        'ultima_atualizacao': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Mensagens atualizadas com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _buildEditor(String titulo, TextEditingController controller, String descricao, String tags) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [const Icon(Icons.chat_bubble_outline, color: Color(0xFF8A2463), size: 20), const SizedBox(width: 8), Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
            const SizedBox(height: 8),
            Text(descricao, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text('Curingas permitidos: $tags', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller, maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Digite a mensagem...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white,
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
      backgroundColor: const Color(0xFFFAF0F4),
      appBar: AppBar(title: const Text('Mensagens Automáticas')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Edite o texto das mensagens. O sistema vai trocar automaticamente os textos com colchetes [ ] pelos dados reais da cliente.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 16),
                _buildEditor(
                  'Confirmação de Agendamento', _ctrlConfirmacao,
                  'Mensagem enviada no dia do procedimento ou na véspera.',
                  '[NOME], [DATA], [DIA_SEMANA], [HORA], [SERVICO]'
                ),
                _buildEditor(
                  'Mensagem de Cancelamento', _ctrlCancelamento,
                  'Enviada quando um agendamento é cancelado pelo sistema.',
                  '[NOME], [DATA], [SERVICO]'
                ),
                _buildEditor(
                  'Mensagem de Retenção (Resgate)', _ctrlRetencao,
                  'Aba Clientes > Botão WhatsApp para clientes sumidas.',
                  '[NOME], [DIAS]'
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8A2463), padding: const EdgeInsets.symmetric(vertical: 16)),
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
