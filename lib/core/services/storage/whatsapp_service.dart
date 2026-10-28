import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../../features/agenda/models/agendamento.dart';

class WhatsAppService {
  static const Map<int, String> _diasSemana = {
    1: 'segunda-feira', 2: 'terça-feira', 3: 'quarta-feira',
    4: 'quinta-feira', 5: 'sexta-feira', 6: 'sábado', 7: 'domingo',
  };

  /// MENSAGENS PADRÃO (Caso o banco de dados esteja vazio)
  static const String _msgConfirmacaoDefault = "Olá, [NOME]! Tudo bem? 💅\n\nPassando para confirmar o seu agendamento:\n🗓️ Data: [DATA] ([DIA_SEMANA])\n⏰ Horário: [HORA]\n✨ Serviço: [SERVICO]\n\nPodemos confirmar a sua presença?";
  static const String _msgCancelamentoDefault = "Olá, [NOME]. Seu agendamento para [DATA] foi cancelado com sucesso. Caso queira remarcar, estamos à disposição! 🌸";
  
  // AS 3 ABORDAGENS DE RETENÇÃO
  static const String _msgRetencao1 = "Olá, [NOME]! Tudo bem? Sentimos a sua falta no Studio Condeza! 🥰\n\nNotamos que faz [DIAS] dias desde a sua última visita. Vamos agendar um horário para cuidar de você esta semana?";
  static const String _msgRetencao2 = "Oi, [NOME]! Sumida! 👀 Passando para avisar que temos algumas novidades maravilhosas. Que tal tirar um tempinho para você e vir dar uma olhadinha na nossa agenda?";
  static const String _msgRetencao3 = "Olá, [NOME]! Tudo bem? Como faz um tempinho que não nos vemos, queríamos saber se aconteceu algo ou se podemos ajudar. Sua presença é muito importante para nós! 💖";

  static String _formatarNumero(String telefone) {
    final numLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    return numLimpo.startsWith('55') ? numLimpo : '55$numLimpo';
  }

  // 🧠 CACHE INTELIGENTE: Resolve o bloqueio de Pop-ups da Web
  static Map<String, String>? _cacheTemplates;

  static Future<String> _buscarTemplate(String tipo, String mensagemPadrao) async {
    // Se o texto já está no cache, retorna imediatamente (Evita que o navegador bloqueie a abertura)
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

  // 🚀 MOTOR DE DISPARO REFORMULADO (Com 3 camadas de segurança)
  static Future<void> _dispararWhatsApp(String telefone, String mensagem) async {
    final numero = _formatarNumero(telefone);
    
    // Usamos a API universal do WhatsApp que funciona melhor em Web/Desktop/Mobile do que o wa.me
    final uri = Uri.parse('https://api.whatsapp.com/send?phone=$numero&text=${Uri.encodeComponent(mensagem)}');

    try {
      // TENTATIVA 1: O padrão oficial. Na Web, abre nova aba. No celular, tenta abrir o app.
      bool sucesso = await launchUrl(
        uri, 
        mode: LaunchMode.platformDefault, 
        webOnlyWindowName: '_blank'
      );
      
      if (!sucesso) {
        // TENTATIVA 2: Força tentar abrir via app nativo (Útil no iOS/Android)
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // TENTATIVA 3: Fallback extremo caso o sistema recuse os modos acima
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  /// 🎯 ENVIAR CONFIRMAÇÃO DE AGENDAMENTO
  static Future<void> enviarConfirmacao({required String telefone, required String nomeCliente, required Agendamento agendamento}) async {
    final template = await _buscarTemplate('msg_confirmacao', _msgConfirmacaoDefault);
    final diaMes = DateFormat('dd/MM').format(agendamento.data);
    final diaSemana = _diasSemana[agendamento.data.weekday] ?? '';

    String mensagem = template.replaceAll('[NOME]', nomeCliente).replaceAll('[DATA]', diaMes).replaceAll('[DIA_SEMANA]', diaSemana).replaceAll('[HORA]', agendamento.horaInicio).replaceAll('[SERVICO]', agendamento.servico);
    
    await _dispararWhatsApp(telefone, mensagem);
  }

  /// 🎯 ENVIAR CANCELAMENTO
  static Future<void> enviarCancelamento({required String telefone, required String nomeCliente, required Agendamento agendamento}) async {
    final template = await _buscarTemplate('msg_cancelamento', _msgCancelamentoDefault);
    final diaMes = DateFormat('dd/MM').format(agendamento.data);
    
    String mensagem = template.replaceAll('[NOME]', nomeCliente).replaceAll('[DATA]', diaMes).replaceAll('[SERVICO]', agendamento.servico);
    
    await _dispararWhatsApp(telefone, mensagem);
  }

  /// 🎯 ENVIAR RETENÇÃO COM OPÇÃO DE ESCOLHA
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
