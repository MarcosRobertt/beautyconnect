// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/backup_service.dart';
import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../../servicos/controllers/servico_controller.dart';

class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
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

  // 🚀 Download de Arquivo (Interface/Web) chamando o Serviço
  Future<void> _exportarBackup() async {
    setState(() => _processando = true);
    try {
      final clientes = ref.read(clienteControllerProvider).value ?? [];
      final agendamentos = ref.read(todosAgendamentosProvider).value ?? [];
      final servicos = ref.read(servicoControllerProvider).value ?? [];

      // Gera a string limpa direto do serviço
      final jsonString = BackupService.gerarJsonBackup(
        clientes: clientes,
        agendamentos: agendamentos,
        servicos: servicos,
      );

      // Download nativo no navegador usando html.AnchorElement
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "beautyconnect_backup_${DateTime.now().millisecondsSinceEpoch}.json")
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup gerado e baixado com sucesso!'), backgroundColor: Colors.green),
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

  // 🚀 Upload de Arquivo (Interface/Web) injetando no Serviço
  void _importarBackup() {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'application/json';
    uploadInput.click();

    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      setState(() => _processando = true);

      final reader = html.FileReader();
      reader.readAsText(files[0]);
      
      reader.onLoadEnd.listen((e) async {
        try {
          final jsonString = reader.result as String;
          
          // O Serviço envia direto pro Firebase e nos retorna a quantidade
          final totalRestaurado = await BackupService.restaurarBackup(jsonString);

          // Atualiza as listas na tela
          ref.invalidate(clienteControllerProvider);
          ref.invalidate(servicoControllerProvider);
          ref.invalidate(todosAgendamentosProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sucesso! $totalRestaurado registros importados no banco de dados.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro arquivo inválido ou corrompido: $error'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _processando = false);
        }
      });
    });
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
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 16),
                  Text('Processando dados de backup no Firebase...'),
                ],
              ),
            )
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
