import 'dart:html' as html;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/agenda/models/agendamento.dart';

class WhatsAppService {
  static const Map<int, String> _diasSemana = {
    1: 'segunda-feira',
    2: 'terça-feira',
    3: 'quarta-feira',
    4: 'quinta-feira',
    5: 'sexta-feira',
    6: 'sábado',
    7: 'domingo',
  };

  /// MENSAGENS PADRÃO (Caso o Firebase esteja offline ou vazio)
  static const String _msgConfirmacaoDefault = "Olá, [NOME]! Tudo bem? 💅\n\nPassando para confirmar o seu agendamento:\n🗓️ Data: [DATA] ([DIA_SEMANA])\n⏰ Horário: [HORA]\n✨ Serviço: [SERVICO]\n\nPodemos confirmar a sua presença?";
  static const String _msgCancelamentoDefault = "Olá, [NOME]. Seu agendamento para [DATA] foi cancelado com sucesso. Caso queira remarcar, estamos à disposição! 🌸";
  static const String _msgRetencaoDefault = "Olá, [NOME]! Tudo bem? Sentimos a sua falta no Studio Condeza! 🥰\n\nNotamos que faz um tempinho desde a sua última visita. Vamos agendar um horário para cuidar de você esta semana?";

  /// Limpa e formata o número de telefone para o padrão internacional (Brasil)
  static String _formatarNumero(String telefone) {
    final numLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    return numLimpo.startsWith('55') ? numLimpo : '55$numLimpo';
  }

  /// Busca o modelo de mensagem configurado no banco de dados
  static Future<String> _buscarTemplate(String tipo, String mensagemPadrao) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracoes').doc('whatsapp').get();
      if (doc.exists && doc.data()!.containsKey(tipo)) {
        final texto = doc[tipo].toString();
        if (texto.isNotEmpty) return texto;
      }
    } catch (_) {}
    return mensagemPadrao;
  }

  /// 🎯 ENVIAR CONFIRMAÇÃO DE AGENDAMENTO
  static Future<void> enviarConfirmacao({
    required String telefone,
    required String nomeCliente,
    required Agendamento agendamento,
  }) async {
    final template = await _buscarTemplate('msg_confirmacao', _msgConfirmacaoDefault);
    
    final diaMes = DateFormat('dd/MM').format(agendamento.data);
    final diaSemana = _diasSemana[agendamento.data.weekday] ?? '';

    // Troca as TAGs Inteligentes pelos dados reais!
    String mensagem = template
        .replaceAll('[NOME]', nomeCliente)
        .replaceAll('[DATA]', diaMes)
        .replaceAll('[DIA_SEMANA]', diaSemana)
        .replaceAll('[HORA]', agendamento.horaInicio)
        .replaceAll('[SERVICO]', agendamento.servico);

    final numeroFormatado = _formatarNumero(telefone);
    final url = 'https://wa.me/$numeroFormatado?text=${Uri.encodeComponent(mensagem)}';
    
    html.window.open(url, '_blank');
  }

  /// 🎯 ENVIAR CANCELAMENTO
  static Future<void> enviarCancelamento({
    required String telefone,
    required String nomeCliente,
    required Agendamento agendamento,
  }) async {
    final template = await _buscarTemplate('msg_cancelamento', _msgCancelamentoDefault);
    
    final diaMes = DateFormat('dd/MM').format(agendamento.data);
    
    String mensagem = template
        .replaceAll('[NOME]', nomeCliente)
        .replaceAll('[DATA]', diaMes)
        .replaceAll('[SERVICO]', agendamento.servico);

    final numeroFormatado = _formatarNumero(telefone);
    final url = 'https://wa.me/$numeroFormatado?text=${Uri.encodeComponent(mensagem)}';
    
    html.window.open(url, '_blank');
  }

  /// 🎯 ENVIAR MENSAGEM DE RESGATE/RETENÇÃO (Para clientes sumidas)
  static Future<void> enviarRetencao({
    required String telefone,
    required String nomeCliente,
    int diasAusente = 0,
  }) async {
    final template = await _buscarTemplate('msg_retencao', _msgRetencaoDefault);
    
    String mensagem = template
        .replaceAll('[NOME]', nomeCliente)
        .replaceAll('[DIAS]', diasAusente.toString());

    final numeroFormatado = _formatarNumero(telefone);
    final url = 'https://wa.me/$numeroFormatado?text=${Uri.encodeComponent(mensagem)}';
    
    html.window.open(url, '_blank');
  }
}
