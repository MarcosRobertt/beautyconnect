// Botão Copiar para o Próximo Mês
IconButton(
  icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.blueGrey),
  tooltip: 'Copiar para o próximo mês',
  constraints: const BoxConstraints(),
  padding: EdgeInsets.zero,
  onPressed: () async {
    await ref.read(despesaControllerProvider.notifier).duplicarDespesaProximoMes(d, _mesSelecionado);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${d.descricao}" copiada para o próximo mês! 📋'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  },
),
const SizedBox(width: 8),
