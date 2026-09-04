import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class BackupService {
  static String gerarJsonBackup({
    required List<dynamic> clientes,
    required List<dynamic> servicos,
    required List<dynamic> agendamentos,
  }) {
    final Map<String, dynamic> backupData = {
      'version': '1.1',
      'exportedAt': DateTime.now().toIso8601String(),
      'clientes': clientes.map((c) => c is Map ? c : c.toJson()).toList(),
      'servicos': servicos.map((s) => s is Map ? s : s.toJson()).toList(),
      'agendamentos': agendamentos.map((a) => a is Map ? a : a.toJson()).toList(),
    };

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

  static Future<int> restaurarBackup(String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final firestore = FirebaseFirestore.instance;

    final List<dynamic> clientes = data['clientes'] ?? [];
    final List<dynamic> servicos = data['servicos'] ?? [];
    final List<dynamic> agendamentos = data['agendamentos'] ?? [];

    WriteBatch batch = firestore.batch();
    int operacoes = 0;
    int totalRestaurado = 0;

    Future<void> commitSeNecessario() async {
      if (operacoes >= 400) {
        await batch.commit();
        batch = firestore.batch();
        operacoes = 0;
      }
    }

    for (var c in clientes) {
      final docId = c['id'] ?? firestore.collection('clientes').doc().id;
      final docRef = firestore.collection('clientes').doc(docId);
      final dadosLimpos = _converterStringsParaTimestamp(Map<String, dynamic>.from(c));
      
      batch.set(docRef, dadosLimpos);
      operacoes++;
      totalRestaurado++;
      await commitSeNecessario();
    }

    for (var s in servicos) {
      final docId = s['id'] ?? firestore.collection('servicos').doc().id;
      final docRef = firestore.collection('servicos').doc(docId);
      final dadosLimpos = _converterStringsParaTimestamp(Map<String, dynamic>.from(s));

      batch.set(docRef, dadosLimpos);
      operacoes++;
      totalRestaurado++;
      await commitSeNecessario();
    }

    for (var a in agendamentos) {
      final docId = a['id'] ?? firestore.collection('agendamentos').doc().id;
      final docRef = firestore.collection('agendamentos').doc(docId);
      final dadosLimpos = _converterStringsParaTimestamp(Map<String, dynamic>.from(a));

      batch.set(docRef, dadosLimpos);
      operacoes++;
      totalRestaurado++;
      await commitSeNecessario();
    }

    if (operacoes > 0) {
      await batch.commit();
    }

    return totalRestaurado;
  }

  static Map<String, dynamic> _converterStringsParaTimestamp(Map<String, dynamic> mapa) {
    final novoMapa = <String, dynamic>{};
    final regexDataISO = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}');

    mapa.forEach((chave, valor) {
      if (valor is String && regexDataISO.hasMatch(valor)) {
        final dataConvertida = DateTime.tryParse(valor);
        if (dataConvertida != null) {
          novoMapa[chave] = Timestamp.fromDate(dataConvertida);
          return;
        }
      } 
      else if (valor is Map<String, dynamic>) {
        novoMapa[chave] = _converterStringsParaTimestamp(valor);
        return;
      }
      novoMapa[chave] = valor;
    });

    return novoMapa;
  }
}
