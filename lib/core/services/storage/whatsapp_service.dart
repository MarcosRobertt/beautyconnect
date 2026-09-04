import 'package:url_launcher/url_launcher.dart';
import '../../../features/agenda/models/agendamento.dart';

class WhatsAppService {
  static Future<void> enviarConfirmacao({
    required String telefone,
    required String nomeCliente,
    required Agendamento agendamento,
  }) async {
    final numLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    final mensagem = Uri.encodeComponent(
      'Olá, $nomeCliente! Confirmamos seu agendamento no BeautyConnect para o dia ${agendamento.data.day}/${agendamento.data.month} às ${agendamento.horaInicio}.',
    );
    final url = Uri.parse('https://wa.me/55$numLimpo?text=$mensagem');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
