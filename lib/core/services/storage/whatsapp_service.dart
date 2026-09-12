import 'dart:html' as html;
import 'package:intl/intl.dart';
import '../../../features/agenda/models/agendamento.dart';

class WhatsAppService {
  /// Mapeamento dos dias da semana por extenso em português
  static const Map<int, String> _diasSemana = {
    1: 'segunda-feira',
    2: 'terça-feira',
    3: 'quarta-feira',
    4: 'quinta-feira',
    5: 'sexta-feira',
    6: 'sábado',
    7: 'domingo',
  };

  /// Envia a mensagem de confirmação de agendamento no padrão exato solicitado
  static void enviarConfirmacao({
    required String telefone,
    required String nomeCliente,
    required Agendamento agendamento,
  }) {
    // Sanitiza o número removendo caracteres não numéricos
    final numLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    
    // Trata o DDD e código do país (assume Brasil 55 caso não informado)
    final numeroFormatado = numLimpo.startsWith('55') ? numLimpo : '55$numLimpo';

    // Formata a data no padrão "DD/MM (dia da semana)"
    final diaMes = DateFormat('dd/MM').format(agendamento.data);
    final diaSemana = _diasSemana[agendamento.data.weekday] ?? '';

    final mensagem = '''
Olá, $nomeCliente! Tudo bem? 💅

Passando para confirmar o seu agendamento:
🗓️ Data: $diaMes ($diaSemana)
⏰ Horário: ${agendamento.horaInicio}
✨ Serviço: ${agendamento.servico}

Podemos confirmar a sua presença?''';

    final url = 'https://wa.me/$numeroFormatado?text=${Uri.encodeComponent(mensagem)}';
    
    // Abre a conversa no WhatsApp Web / App
    html.window.open(url, '_blank');
  }
}
