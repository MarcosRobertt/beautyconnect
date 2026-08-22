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
    html.window.location.reload();
  }

  // --- FUNÇÃO DA IA COM MÉTRICAS ADICIONADA AQUI ---
  void _abrirIA() {
    final clientes = ref.read(clienteControllerProvider).value ?? [];
    final agendamentos = ref.read(todosAgendamentosProvider).value ?? [];
    final servicos = ref.read(servicoControllerProvider).value ?? [];

    final concluidos = agendamentos.where((a) => a.status == AgendamentoStatus.concluido).toList();
    final faturamentoTotal = concluidos.fold(0.0, (sum, a) => sum + a.valor);
    final ticketMedio = concluidos.isEmpty ? 0.0 : faturamentoTotal / concluidos.length;
    
    final ativos = clientes.where((c) {
      final agsCliente = concluidos.where((a) => a.clienteId == c.id);
      if (agsCliente.isEmpty) return false;
      final ultima = agsCliente.map((a) => a.data).reduce((a, b) => a.isAfter(b) ? a : b);
      return DateTime.now().difference(ultima).inDays <= 30;
    }).length;

    final contextoIA = '''
    ATUALIZAÇÃO DE MÉTRICAS DO STUDIO:
    - Total de Clientes Cadastrados: ${clientes.length} (Ativos: $ativos)
    - Agendamentos Concluídos: ${concluidos.length}
    - Faturamento Total: R\$ ${faturamentoTotal.toStringAsFixed(2)}
    - Ticket Médio (TM): R\$ ${ticketMedio.toStringAsFixed(2)}
    - Serviços Oferecidos: ${servicos.length}
    
    DIRETRIZES DE ANÁLISE:
    Analise os dados e sugira:
    1. Estratégias práticas para aumentar o Ticket Médio (combos de serviços).
    2. Mensagens para reativar os clientes inativos.
    3. Ações para preencher horários ociosos na agenda.
    ''';

    context.push(AppRoutes.agendaInteligente, extra: contextoIA);
  }
  // ------------------------------------------------

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
      if (payload == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importação cancelada ou arquivo inválido.')),
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
                const Text(
                  'Inteligência Artificial',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                    title: const Text('Consultoria Inteligente (IA)'), // Título atualizado
                    subtitle: const Text('Analisa TM, Retenção e sugere melhorias para o Studio'), // Subtítulo atualizado
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _abrirIA, // Chamada para a nova função
                  ),
                ),
                const SizedBox(height: 24),
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
