import 'package:intl/intl.dart';
// Uso nativo para abrir URLs em Flutter Web/Navegador
import 'package:url_launcher/url_launcher_string.dart';

import '../../../features/agenda/models/agendamento.dart';
import '../../../features/clientes/models/cliente.dart';

class WhatsAppService {
  static String _formatarTelefone(String telefone) {
    String apenasNumeros = telefone.replaceAll(RegExp(r'[^\d]'), '');
    if (!apenasNumeros.startsWith('55') && apenasNumeros.length <= 11) {
      apenasNumeros = '55$apenasNumeros';
    }
    return apenasNumeros;
  }

  static Future<void> _abrirWhatsApp(String telefone, String mensagem) async {
    final numeroFormatado = _formatarTelefone(telefone);
    final uriEncoded = Uri.encodeComponent(mensagem);
    final urlString = 'https://wa.me/$numeroFormatado?text=$uriEncoded';

    if (await canLaunchUrlString(urlString)) {
      await launchUrlString(urlString, mode: LaunchMode.externalApplication);
    }
  }

  /// 1. Mensagem de Confirmação do Horário
  static Future<void> enviarConfirmacao({
    required String telefone,
    required String nomeCliente,
    required Agendamento agendamento,
  }) async {
    final dataFmt = DateFormat('dd/MM (EEEE)', 'pt_BR').format(agendamento.data);
    final mensagem = 
        'Olá, $nomeCliente! Tudo bem? 💅\n\n'
        'Passando para confirmar o seu agendamento:\n'
        '🗓️ *Data:* $dataFmt\n'
        '⏰ *Horário:* ${agendamento.horaInicio}\n'
        '✨ *Serviço:* ${agendamento.servico}\n\n'
        'Podemos confirmar a sua presença?';

    await _abrirWhatsApp(telefone, mensagem);
  }

  /// 2. Mensagem de Reativação no CRM (Clientes Sumidas)
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
