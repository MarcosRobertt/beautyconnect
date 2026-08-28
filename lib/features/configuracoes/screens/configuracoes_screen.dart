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

  void _abrirIA() {
    final clientes = ref.read(clienteControllerProvider).value ?? [];
    final agendamentos = ref.read(todosAgendamentosProvider).value ?? [];
    final servicos = ref.read(servicoControllerProvider).value ?? [];

    final concluidos = agendamentos.where((a) => a.status == AgendamentoStatus.concluido).toList();
    
    // --- LÓGICA DE DATAS PARA COMPARAÇÃO ---
    final hoje = DateTime.now();
    final inicioSemanaAtual = hoje.subtract(Duration(days: hoje.weekday - 1));
    final inicioSemanaPassada = inicioSemanaAtual.subtract(const Duration(days: 7));
    
    // Filtrando por períodos
    final agendamentosSemanaAtual = concluidos.where((a) => a.data.isAfter(inicioSemanaAtual) || a.data.isAtSameMomentAs(inicioSemanaAtual)).toList();
    final agendamentosSemanaPassada = concluidos.where((a) => a.data.isAfter(inicioSemanaPassada) && a.data.isBefore(inicioSemanaAtual)).toList();
    final agendamentosMes = concluidos.where((a) => a.data.year == hoje.year && a.data.month == hoje.month).toList();

    // Cálculos Financeiros
    double calcFaturamento(List<Agendamento> lista) => lista.fold(0.0, (sum, a) => sum + a.valor);
    double calcTM(List<Agendamento> lista, double fat) => lista.isEmpty ? 0.0 : fat / lista.length;

    final fatSemanaAtual = calcFaturamento(agendamentosSemanaAtual);
    final tmSemanaAtual = calcTM(agendamentosSemanaAtual, fatSemanaAtual);

    final fatSemanaPassada = calcFaturamento(agendamentosSemanaPassada);
    final tmSemanaPassada = calcTM(agendamentosSemanaPassada, fatSemanaPassada);

    final fatMes = calcFaturamento(agendamentosMes);
    final tmMes = calcTM(agendamentosMes, fatMes);

    // Prompt configurado para NÃO ser um chat, e sim um relatório direto
    final contextoIA = '''
    ATUE COMO UM CONSULTOR DE NEGÓCIOS DE UM STUDIO DE BELEZA.
    Gere um relatório de análise de desempenho direto ao ponto. Não faça perguntas ao final.
    
    DADOS FINANCEIROS:
    - Faturamento Semana Atual: R\$ ${fatSemanaAtual.toStringAsFixed(2)} | TM: R\$ ${tmSemanaAtual.toStringAsFixed(2)}
    - Faturamento Semana Passada: R\$ ${fatSemanaPassada.toStringAsFixed(2)} | TM: R\$ ${tmSemanaPassada.toStringAsFixed(2)}
    - Faturamento Mês Atual: R\$ ${fatMes.toStringAsFixed(2)} | TM: R\$ ${tmMes.toStringAsFixed(2)}
    - Total de Clientes na base: ${clientes.length}
    - Total de Agendamentos no mês: ${agendamentosMes.length}

    O QUE O SEU RELATÓRIO DEVE CONTER NECESSARIAMENTE:
    1. Comparativo de Ticket Médio (TM) e faturamento da semana atual contra a semana passada (informe se melhorou ou piorou).
    2. Análise geral do mês atual (como está o ritmo de atendimentos).
    3. 3 sugestões estratégicas e curtas para melhorar os procedimentos e o agendamento da próxima semana.
    Formate a resposta com títulos, tópicos e sem saudações genéricas.
    ''';

    context.push('/consultoria-ia', extra: contextoIA);
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
        title: const Text('Menu'),
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
                    leading: const Icon(Icons.analytics, color: Colors.deepPurple),
                    title: const Text('Relatório Gerencial (IA)'),
                    subtitle: const Text('Gera análise automática de TM e faturamento do Studio'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _abrirIA, 
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
