void _abrirModalCancelamento(BuildContext context, WidgetRef ref, Agendamento agendamento) {
    final motivoController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar ou Reagendar?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Você pode excluir este agendamento ou reagendá-lo para outra data.'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ex: Cliente teve imprevisto',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); 
              context.push('${AppRoutes.agenda}/editar/${agendamento.id}'); 
            },
            child: const Text('Reagendar', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            // 🛡️ MITIGAÇÃO: Função async com Try-Catch para alarmar erros no Firebase
            onPressed: () async {
              Navigator.pop(ctx);
              final motivo = motivoController.text.trim();
              
              try {
                if (motivo.isNotEmpty) {
                  final novaObs = agendamento.observacao.isEmpty
                      ? '[Cancelado: $motivo]'
                      : '${agendamento.observacao} | [Cancelado: $motivo]';
                  
                  final atualizado = agendamento.copyWith(
                    status: AgendamentoStatus.cancelado,
                    observacao: novaObs,
                  );
                  await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
                } else {
                  await ref.read(agendamentoControllerProvider.notifier).cancelar(agendamento.id);
                }
                
                // Sucesso!
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Agendamento excluído/cancelado!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                // Alarme de Erro (Evita a falha silenciosa)
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🚨 Erro ao excluir: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
                  );
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
