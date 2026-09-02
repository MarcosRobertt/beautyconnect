import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class BackupService {
  /// Gera a string JSON sanitizada para exportação de backup
  static String gerarJsonBackup({
    required List<dynamic> clientes,
    required List<dynamic> servicos,
    required List<dynamic> agendamentos,
  }) {
    final Map<String, dynamic> backupData = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'clientes': clientes.map((c) => c.toJson()).toList(),
      'servicos': servicos.map((s) => s.toJson()).toList(),
      'agendamentos': agendamentos.map((a) => a.toJson()).toList(),
    };

    // 🚀 TRATAMENTO DE SERIALIZAÇÃO: Converte Timestamp e DateTime para String ISO-8601
    return jsonEncode(
      backupData,
      toEncodable: (nonEncodable) {
        if (nonEncodable is Timestamp) {
          return nonEncodable.toDate().toIso8601String();
        }
        if (nonEncodable is DateTime) {
          return nonEncodable.toIso8601String();
        }
        return nonEncodable.toString();
      },
    );
  }
}
