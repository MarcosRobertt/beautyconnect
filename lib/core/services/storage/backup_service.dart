import 'dart:convert';

import '../../../features/agenda/models/agendamento.dart';
import '../../../features/clientes/models/cliente.dart';
import '../../../features/servicos/models/servico.dart';

class BackupService {
  /// Gera a string JSON estruturada contendo Clientes, Agendamentos e Serviços.
  static String gerarTextoBackup({
    required List<Cliente> clientes,
    required List<Agendamento> agendamentos,
    required List<Servico> servicos,
  }) {
    final mapaBackup = {
      'versao': 2,
      'dataCriacao': DateTime.now().toIso8601String(),
      'clientes': clientes.map((c) => c.toJson()).toList(),
      'agendamentos': agendamentos.map((a) => a.toJson()).toList(),
      'servicos': servicos.map((s) => s.toJson()).toList(), // <--- Serviços incluídos
    };

    return const JsonEncoder.withIndent('  ').convert(mapaBackup);
  }

  /// Processa a string JSON do backup e extrai os objetos tipados.
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
