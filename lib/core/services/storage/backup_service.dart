Future<Map<String, dynamic>?> importar() async {
    final uploadInput = html.FileUploadInputElement()..accept = '.json';
    uploadInput.click();

    try {
      // Adiciona um limite de tempo de 30 segundos para o usuario selecionar o arquivo
      await uploadInput.onChange.first.timeout(const Duration(seconds: 30));
    } catch (_) {
      // Se estourar o tempo ou for cancelado, cancela o carregamento
      return null;
    }

    if (uploadInput.files == null || uploadInput.files!.isEmpty) return null;

    final file = uploadInput.files!.first;
    final reader = html.FileReader();
    reader.readAsText(file);

    await reader.onLoadEnd.first;
    final conteudoJson = reader.result as String?;
    if (conteudoJson == null || conteudoJson.isEmpty) return null;

    return processarBackupJson(conteudoJson);
  }
