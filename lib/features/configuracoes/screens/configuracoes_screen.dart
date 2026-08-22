Future<void> _importarBackup() async {
    setState(() => _processando = true);
    try {
      final payload = await _backupService.importar();
      if (payload == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importação cancelada ou nenhum arquivo selecionado.')),
          );
        }
        return;
      }

      final clientes = payload['clientes'] as List<Cliente>? ?? [];
      final agendamentos = payload['agendamentos'] as List<Agendamento>? ?? [];
      final servicos = payload['servicos'] as List<Servico>? ?? [];

      // Importacao em lote paralela para evitar travamento do navegador
      await Future.wait(servicos.map((s) => ref.read(servicoControllerProvider.notifier).salvar(s)));
      await Future.wait(clientes.map((c) => ref.read(clienteControllerProvider.notifier).salvar(c)));
      await Future.wait(agendamentos.map((a) => ref.read(agendamentoControllerProvider.notifier).salvar(a, novo: true)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup restaurado: ${clientes.length} cliente(s), ${servicos.length} serviço(s) e ${agendamentos.length} agendamento(s).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar backup: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }
