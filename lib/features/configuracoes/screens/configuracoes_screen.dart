// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/backup_service.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../../clientes/models/cliente.dart';
import '../../servicos/controllers/servico_controller.dart';
import '../../servicos/models/servico.dart';

class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  final _backupService = BackupService();
  bool _processando = false;

  void _atualizarPagina() {
    // Recarrega a página web para forçar a atualização da versão
    html.window.location.reload();
  }

  Future<void> _exportarBackup() async {
    setState(() => _processando = true);
    try {
      final clientes = ref.read(clienteControllerProvider).value ?? [];
      final agendamentos = ref.read(todosAgendamentosProvider).value ?? [];
      final servicos = ref.read(servicoControllerProvider).value ?? [];

      await _backupService.exportar(
        clientes: clientes,
        agendamentos: agendamentos,
        servicos: servicos,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup gerado e baixado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar backup: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _importarBackup() async {
    setState(() => _processando = true);
    try {
      final payload = await _backupService.importar();
      if (payload != null) {
        final clientes = payload['clientes'] as List<Cliente>? ?? [];
        final agendamentos = payload['agendamentos'] as List<Agendamento>? ?? [];
        final servicos = payload['servicos'] as List<Servico>? ?? [];

        for (final s in servicos) {
          await ref.read(servicoControllerProvider.notifier).salvar(s);
        }
        for (final c in clientes) {
          await ref.read(clienteControllerProvider.notifier).salvar(c);
        }
        for (final a in agendamentos) {
          await ref.read(agendamentoControllerProvider.notifier).salvar(a, novo: true);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Backup restaurado: ${clientes.length} cliente(s), ${servicos.length} serviço(s) e ${agendamentos.length} agendamento(s).',
              ),
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Versão / Recarregar Página',
            onPressed: _atualizarPagina,
          ),
        ],
      ),
      body: _processando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- SEÇÃO IA ---
                const Text(
                  'Inteligência Artificial',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                    title: const Text('Agenda Inteligente (IA)'),
                    subtitle: const Text('Acesse e configure o assistente virtual da agenda'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.agendaInteligente),
                  ),
                ),
                
                const SizedBox(height: 24),

                // --- SEÇÃO BACKUP ---
                const Text(
                  'Backup e Restauração',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Exportar Backup (.json)'),
                    subtitle: const Text('Salvar dados de clientes, serviços e agenda no dispositivo'),
                    onTap: _exportarBackup,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.upload),
                    title: const Text('Importar Backup (.json)'),
                    subtitle: const Text('Restaurar clientes, serviços e agenda salvos anteriormente'),
                    onTap: _importarBackup,
                  ),
                ),
              ],
            ),
    );
  }
}
