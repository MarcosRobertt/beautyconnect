import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../../features/agenda/models/agendamento.dart';

class WhatsAppService {
  static const Map<int, String> _diasSemana = {
    1: 'segunda-feira', 2: 'terça-feira', 3: 'quarta-feira',
    4: 'quinta-feira', 5: 'sexta-feira', 6: 'sábado', 7: 'domingo',
  };

  static const String _msgConfirmacaoDefault = "Olá, [NOME]! Tudo bem? 💅\n\nPassando para confirmar o seu agendamento:\n🗓️ Data: [DATA] ([DIA_SEMANA])\n⏰ Horário: [HORA]\n✨ Serviço: [SERVICO]\n\nPodemos confirmar a sua presença?";
  static const String _msgCancelamentoDefault = "Olá, [NOME]. Seu agendamento para [DATA] foi cancelado com sucesso. Caso queira remarcar, estamos à disposição! 🌸";
  
  static const String _msgRetencao1 = "Olá, [NOME]! Tudo bem? Sentimos a sua falta no Studio Condeza! 🥰\n\nNotamos que faz [DIAS] dias desde a sua última visita. Vamos agendar um horário para cuidar de você esta semana?";
  static const String _msgRetencao2 = "Oi, [NOME]! Sumida! 👀 Passando para avisar que temos algumas novidades maravilhosas. Que tal tirar um tempinho para você e vir dar uma olhadinha na nossa agenda?";
  static const String _msgRetencao3 = "Olá, [NOME]! Tudo bem? Como faz um tempinho que não nos vemos, queríamos saber se aconteceu algo ou se podemos ajudar. Sua presença é muito importante para nós! 💖";

  static String _formatarNumero(String telefone) {
    final numLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    return numLimpo.startsWith('55') ? numLimpo : '55$numLimpo';
  }

  // Cache para leitura instantânea e evitar atrasos que o navegador possa bloquear
  static Map<String, String>? _cacheTemplates;

  static Future<String> _buscarTemplate(String tipo, String mensagemPadrao) async {
    if (_cacheTemplates != null && _cacheTemplates!.containsKey(tipo)) {
      final texto = _cacheTemplates![tipo]!;
      if (texto.isNotEmpty) return texto;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('configuracoes').doc('whatsapp').get();
      if (doc.exists && doc.data() != null) {
        _cacheTemplates = {};
        doc.data()!.forEach((key, value) {
          _cacheTemplates![key] = value.toString();
        });

        if (_cacheTemplates!.containsKey(tipo)) {
          final texto = _cacheTemplates![tipo]!;
          if (texto.isNotEmpty) return texto;
        }
      }
    } catch (_) {}
    
    return mensagemPadrao;
  }

  // 🚀 O DISPARO SEGURO PARA PWA/iOS
  static Future<void> _dispararWhatsApp(String telefone, String mensagem) async {
    final numero = _formatarNumero(telefone);
    final url = 'https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}';
    final uri = Uri.parse(url);

    try {
      // O truque de mestre: webOnlyWindowName: '_self'
      // Isto impede que o iOS bloqueie o pop-up e força a abertura da App nativa!
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self', 
      );
    } catch (e) {
      // Se por algum motivo falhar, tenta o fallback externo
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  static Future<void> enviarConfirmacao({required String telefone, required String nomeCliente, required Agendamento agendamento}) async {
    final template = await _buscarTemplate('msg_confirmacao', _msgConfirmacaoDefault);
    final diaMes = DateFormat('dd/MM').format(agendamento.data);
    final diaSemana = _diasSemana[agendamento.data.weekday] ?? '';

    String mensagem = template.replaceAll('[NOME]', nomeCliente).replaceAll('[DATA]', diaMes).replaceAll('[DIA_SEMANA]', diaSemana).replaceAll('[HORA]', agendamento.horaInicio).replaceAll('[SERVICO]', agendamento.servico);
    
    await _dispararWhatsApp(telefone, mensagem);
  }

  static Future<void> enviarCancelamento({required String telefone, required String nomeCliente, required Agendamento agendamento}) async {
    final template = await _buscarTemplate('msg_cancelamento', _msgCancelamentoDefault);
    final diaMes = DateFormat('dd/MM').format(agendamento.data);
    
    String mensagem = template.replaceAll('[NOME]', nomeCliente).replaceAll('[DATA]', diaMes).replaceAll('[SERVICO]', agendamento.servico);
    
    await _dispararWhatsApp(telefone, mensagem);
  }

  static Future<void> enviarRetencao({required String telefone, required String nomeCliente, int diasAusente = 0, required int variante}) async {
    String chaveDb = 'msg_retencao_1';
    String defaultMsg = _msgRetencao1;

    if (variante == 2) { chaveDb = 'msg_retencao_2'; defaultMsg = _msgRetencao2; }
    if (variante == 3) { chaveDb = 'msg_retencao_3'; defaultMsg = _msgRetencao3; }

    final template = await _buscarTemplate(chaveDb, defaultMsg);
    
    String mensagem = template.replaceAll('[NOME]', nomeCliente).replaceAll('[DIAS]', diasAusente.toString());
    
    await _dispararWhatsApp(telefone, mensagem);
  }
}
