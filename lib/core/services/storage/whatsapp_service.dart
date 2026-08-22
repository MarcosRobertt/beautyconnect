import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/agenda/models/agendamento.dart';
import '../../features/clientes/models/cliente.dart';

class WhatsAppService {
  /// Limpa caracteres não numéricos e garante o DDI 55 do Brasil
  static String _formatarTelefone(String telefone) {
    String apenasNumeros = telefone.replaceAll(RegExp(r'[^\d]'), '');
    if (!apenasNumeros.startsWith('55') && apenasNumeros.length <= 11) {
      apenasNumeros = '55$apenasNumeros';
    }
    return apenasNumeros;
  }

  /// Acessa o link universal do WhatsApp
  static Future<void> _abrirWhatsApp(String telefone, String mensagem) async {
    final numeroFormatado = _formatarTelefone(telefone);
    final uriEncoded = Uri.encodeComponent(mensagem);
    final url = Uri.parse('https://wa.me/$numeroFormatado?text=$uriEncoded');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// 1. Envia Confirmação do Agendamento
  static Future<void> enviarConfirmacao({
    required Cliente cliente,
    required Agendamento agendamento,
  }) async {
    final dataFmt = DateFormat('dd/MM (EEEE)', 'pt_BR').format(agendamento.data);
    final mensagem = 
        'Olá, ${cliente.nome}! Tudo bem? 💅\n\n'
        'Passando para confirmar o seu agendamento:\n'
        '🗓️ *Data:* $dataFmt\n'
        '⏰ *Horário:* ${agendamento.horaInicio}\n'
        '✨ *Serviço:* ${agendamento.servico}\n\n'
        'Podemos confirmar a sua presença?';

    await _abrirWhatsApp(cliente.telefone, mensagem);
  }

  /// 2. Envia Mensagem de Reativação para Cliente Sumida
  static Future<void> enviarReativacao({
    required Cliente cliente,
    required int diasAusente,
  }) async {
    final mensagem = 
        'Oi, ${cliente.nome}! Saudades de você por aqui! ❤️\n\n'
        'Reparei que já faz $diasAusente dias desde a sua última visita. '
        'Como estão suas unhas? Vamos agendar um horário para esta semana?';

    await _abrirWhatsApp(cliente.telefone, mensagem);
  }
}
