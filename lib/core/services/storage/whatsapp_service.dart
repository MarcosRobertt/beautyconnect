// Importação nativa da Web para abrir links sem dependência do pubspec.yaml
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:intl/intl.dart';

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

  static void _abrirWhatsApp(String telefone, String mensagem) {
    final numeroFormatado = _formatarTelefone(telefone);
    final uriEncoded = Uri.encodeComponent(mensagem);
    final urlString = 'https://wa.me/$numeroFormatado?text=$uriEncoded';

    // Abre o WhatsApp direto no navegador/app sem usar url_launcher
    html.window.open(urlString, '_blank');
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

    _abrirWhatsApp(telefone, mensagem);
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

    _abrirWhatsApp(cliente.telefone, mensagem);
  }
}
