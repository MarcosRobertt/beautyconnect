Future<void> duplicarDespesaProximoMes(Despesa despesa, DateTime mesReferencia) async {
  try {
    final proximaData = DateTime(
      despesa.dataVencimento.year,
      despesa.dataVencimento.month + 1,
      despesa.dataVencimento.day,
    );

    final novaDespesa = Despesa(
      id: '',
      descricao: despesa.descricao,
      valor: despesa.valor,
      categoria: despesa.categoria,
      tipo: despesa.tipo == 'PARCELADA' ? 'REGULAR' : despesa.tipo,
      dataVencimento: proximaData,
      status: 'PENDENTE',
    );

    await salvarDespesa(novaDespesa);
    await carregarDespesasMes(mesReferencia, forcarServidor: true);
  } catch (e) {
    throw Exception('Erro ao duplicar despesa: $e');
  }
}
