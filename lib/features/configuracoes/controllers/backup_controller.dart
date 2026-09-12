import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backupControllerProvider = Provider<BackupController>((ref) {
  return BackupController();
});

class BackupController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> exportarBackupJson() async {
    final Map<String, dynamic> backupData = {
      'versao': '1.0',
      'dataExportacao': DateTime.now().toIso8601String(),
      'colecoes': {},
    };

    final colecoes = ['agendamentos', 'despesas', 'clientes', 'servicos'];

    for (final colecao in colecoes) {
      final snapshot = await _db.collection(colecao).get();
      final listaDocumentos = snapshot.docs.map((doc) => doc.data()).toList();
      (backupData['colecoes'] as Map<String, dynamic>)[colecao] = listaDocumentos;
    }

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
    final Map<String, dynamic> data = jsonDecode(content);

    if (!data.containsKey('colecoes')) {
      throw Exception('Arquivo de backup inválido.');
    }

    final colecoes = data['colecoes'] as Map<String, dynamic>;

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
