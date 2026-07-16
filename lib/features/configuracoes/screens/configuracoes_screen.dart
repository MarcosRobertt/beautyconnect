import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage/backup_service.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../clientes/controllers/cliente_controller.dart';

/// Tela Configurações → Exportar/Importar backup.json, conforme documento
/// técnico. Esta é a persistência "de segurança": a persistência do dia a
/// dia já acontece sozinha no Hive/IndexedDB a cada ação do usuário.
class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  final _backupService = BackupService();
  bool _processando = false;
  String? _mensagem;
  bool _erro = false;

  Future<void> _exportar() async {
    setState(() {
      _processando = true;
      _mensagem = null;
    });
    try {
      final clientes = ref.read(clienteControllerProvider).value ?? [];
      final agendamentos = await ref.read(agendamentoControllerProvider.notifier).todos();
      await _backupService.exportar(clientes: clientes, agendamentos: agendamentos);
      setState(() {
        _mensagem = 'Backup exportado com sucesso. Guarde o arquivo em um local seguro.';
        _erro = false;
      });
    } catch (e) {
      setState(() {
        _mensagem = 'Não foi possível exportar o backup ($e).';
        _erro = true;
      });
    } finally {
      setState(() => _processando = false);
    }
  }

  Future<void> _importar() async {
    setState(() {
      _processando = true;
      _mensagem = null;
    });
    try {
      final payload = await _backupService.importar();
      if (payload == null) {
        setState(() => _processando = false);
        return; // usuário cancelou a seleção do arquivo
      }
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restaurar backup'),
          content: Text(
            'Isso vai substituir todos os ${'clientes e agendamentos atuais'} pelos '
            '${payload.clientes.length} cliente(s) e ${payload.agendamentos.length} agendamento(s) '
            'do arquivo selecionado. Deseja continuar?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar')),
          ],
        ),
      );
      if (confirmar != true) {
        setState(() => _processando = false);
        return;
      }

      await ref.read(clienteControllerProvider.notifier).substituirTudo(payload.clientes);
      await ref.read(agendamentoControllerProvider.notifier).substituirTudo(payload.agendamentos);

      setState(() {
        _mensagem = 'Backup restaurado com sucesso.';
        _erro = false;
      });
    } catch (e) {
      setState(() {
        _mensagem = 'Não foi possível importar o backup ($e).';
        _erro = true;
      });
    } finally {
      setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalClientes = ref.watch(clienteControllerProvider).maybeWhen(data: (l) => l.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Backup dos dados', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Este app funciona sem servidor: os dados ficam salvos localmente no '
                        'navegador (IndexedDB, via Hive). Use exportar/importar para guardar uma '
                        'cópia de segurança ou transferir os dados para outro computador.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Text('$totalClientes cliente(s) cadastrados no momento.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _processando ? null : _exportar,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Exportar backup.json'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _processando ? null : _importar,
                            icon: const Icon(Icons.upload_outlined),
                            label: const Text('Importar backup.json'),
                          ),
                        ],
                      ),
                      if (_processando) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                      if (_mensagem != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _erro
                                ? Theme.of(context).colorScheme.errorContainer
                                : const Color(0xFFD9F2E3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_mensagem!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
