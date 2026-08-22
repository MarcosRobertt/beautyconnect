import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../../features/agenda/models/agendamento.dart';
import '../../../features/clientes/models/cliente.dart';
import '../../../features/servicos/models/servico.dart';

class BackupService {
  Future<void> exportar({
    required List<Cliente> clientes,
    required List<Agendamento> agendamentos,
    List<Servico> servicos = const [],
  }) async {
    final mapaBackup = {
      'versao': 2,
      'dataCriacao': DateTime.now().toIso8601String(),
      'clientes': clientes.map((c) => c.toJson()).toList(),
      'agendamentos': agendamentos.map((a) => a.toJson()).toList(),
      'servicos': servicos.map((s) => s.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(mapaBackup);
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'backup_beautyconnect_${DateTime.now().millisecondsSinceEpoch}.json')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  Future<Map<String, dynamic>?> importar() async {
    final uploadInput = html.FileUploadInputElement()..accept = '.json';
    uploadInput.click();

    await uploadInput.onChange.first;
    if (uploadInput.files == null || uploadInput.files!.isEmpty) return null;

    final file = uploadInput.files!.first;
    final reader = html.FileReader();
    reader.readAsText(file);

    await reader.onLoadEnd.first;
    final conteudoJson = reader.result as String?;
    if (conteudoJson == null || conteudoJson.isEmpty) return null;

    return processarBackupJson(conteudoJson);
  }

  static Map<String, dynamic> processarBackupJson(String conteudoJson) {
    final Map<String, dynamic> dados = jsonDecode(conteudoJson) as Map<String, dynamic>;

    final List<Cliente> clientes = [];
    if (dados['clientes'] != null) {
      for (final item in (dados['clientes'] as List)) {
        try {
          clientes.add(Cliente.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {}
      }
    }

    final List<Agendamento> agendamentos = [];
    if (dados['agendamentos'] != null) {
      for (final item in (dados['agendamentos'] as List)) {
        try {
          agendamentos.add(Agendamento.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {}
      }
    }

    final List<Servico> servicos = [];
    if (dados['servicos'] != null) {
      for (final item in (dados['servicos'] as List)) {
        try {
          servicos.add(Servico.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {}
      }
    }

    return {
      'clientes': clientes,
      'agendamentos': agendamentos,
      'servicos': servicos,
    };
  }
}
