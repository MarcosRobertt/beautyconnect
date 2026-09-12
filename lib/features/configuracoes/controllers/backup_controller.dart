import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backupControllerProvider = Provider<BackupController>((ref) {
  return BackupController();
});

class BackupController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Lê as coleções do Firebase e baixa um arquivo JSON no dispositivo de forma segura para a Web
  Future<void> exportarBackupJson() async {
    final Map<String, dynamic> colecoesMap = {};
    final colecoes = ['agendamentos', 'despesas', 'clientes', 'servicos'];

    for (final colecao in colecoes) {
      final snapshot = await _db.collection(colecao).get();
      // Converte a estrutura interna do Firestore Web para um Map genérico sem estourar cast na minificação
      final listaDocumentos = snapshot.docs.map((doc) {
        final data = doc.data();
        return Map<String, dynamic>.from(data);
      }).toList();
      
      colecoesMap[colecao] = listaDocumentos;
    }

    final Map<String, dynamic> backupData = {
      'versao': '1.0',
      'dataExportacao': DateTime.now().toIso8601String(),
      'colecoes': colecoesMap,
    };

    final jsonString = jsonEncode(backupData);
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final dataFormatada = DateTime.now().toIso8601String().split('T').first;
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'backup_beautyconnect_$dataFormatada.json')
      ..click();
      
    html.Url.revokeObjectUrl(url);
  }

  /// Lê um arquivo JSON selecionado pelo usuário e grava os dados de volta no Firestore via WriteBatch
  Future<void> restaurarBackupJson() async {
    final uploadInput = html.FileUploadInputElement()..accept = '.json';
    uploadInput.click();

    await uploadInput.onChange.first;
    final files = uploadInput.files;

    if (files == null || files.isEmpty) return;

    final reader = html.FileReader();
    reader.readAsText(files[0]!);

    await reader.onLoadEnd.first;
    final content = reader.result as String;
    final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(content) as Map);

    if (!data.containsKey('colecoes')) {
      throw Exception('Arquivo de backup inválido.');
    }

    final colecoes = Map<String, dynamic>.from(data['colecoes'] as Map);

    for (final entry in colecoes.entries) {
      final nomeColecao = entry.key;
      final List<dynamic> documentos = entry.value as List<dynamic>;

      WriteBatch batch = _db.batch();
      int contador = 0;

      for (final docData in documentos) {
        final Map<String, dynamic> mapDoc = Map<String, dynamic>.from(docData as Map);
        final String id = mapDoc['id'] ?? _db.collection(nomeColecao).doc().id;
        final docRef = _db.collection(nomeColecao).doc(id);
        
        batch.set(docRef, mapDoc, SetOptions(merge: true));
        contador++;

        // Limite de segurança do Firestore (máximo 500 operações por batch)
        if (contador == 450) {
          await batch.commit();
          batch = _db.batch();
          contador = 0;
        }
      }

      if (contador > 0) {
        await batch.commit();
      }
    }
  }
}
