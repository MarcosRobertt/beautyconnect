import 'dart:convert';
import 'dart:html' as html;

import '../../../features/agenda/models/agendamento.dart';
import '../../../features/clientes/models/cliente.dart';

/// Resultado de uma importação de backup.
class BackupPayload {
  BackupPayload({required this.clientes, required this.agendamentos});
  final List<Cliente> clientes;
  final List<Agendamento> agendamentos;
}

/// Exporta e importa backup.json, conforme o menu Configurações do documento
/// técnico (Configurações → Exportar Dados → backup.json / Restaurar).
///
/// Implementado com `dart:html` porque, nesta fase, o app roda apenas no
/// Flutter Web (sem servidor, sem banco remoto).
class BackupService {
  Future<void> exportar({
    required List<Cliente> clientes,
    required List<Agendamento> agendamentos,
  }) async {
    final payload = {
      'versao': 1,
      'exportadoEm': DateTime.now().toIso8601String(),
      'clientes': clientes.map((c) => c.toJson()).toList(),
      'agendamentos': agendamentos.map((a) => a.toJson()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = utf8.encode(jsonStr);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final dataStr = DateTime.now().toIso8601String().split('T').first;
    // ignore: unused_local_variable
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'beautyconnect-backup-$dataStr.json')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  /// Abre o seletor de arquivos do navegador e importa um backup.json.
  /// Retorna `null` se o usuário cancelar a seleção.
  Future<BackupPayload?> importar() async {
    final input = html.FileUploadInputElement()..accept = '.json,application/json';
    input.click();

    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return null;

    final file = input.files!.first;
    final reader = html.FileReader();
    reader.readAsText(file);
    await reader.onLoad.first;

    final content = reader.result as String;
    final map = jsonDecode(content) as Map<String, dynamic>;

    if (map['clientes'] is! List || map['agendamentos'] is! List) {
      throw const FormatException('Arquivo de backup em formato inesperado.');
    }

    final clientes = (map['clientes'] as List)
        .map((e) => Cliente.fromJson(e as Map<String, dynamic>))
        .toList();
    final agendamentos = (map['agendamentos'] as List)
        .map((e) => Agendamento.fromJson(e as Map<String, dynamic>))
        .toList();

    return BackupPayload(clientes: clientes, agendamentos: agendamentos);
  }
}
