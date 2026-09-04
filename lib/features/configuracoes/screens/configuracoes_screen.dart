import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/storage/backup_service.dart';

class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  bool _processandoBackup = false;

  void _confirmarSaida(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚠️ Confirmar Saída'),
        content: const Text('Deseja realmente encerrar a sessão no BeautyConnect?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Sair da Conta'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarBackup() async {
    setState(() => _processandoBackup = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final clientesSnap = await firestore.collection('clientes').get();
      final servicosSnap = await firestore.collection('servicos').get();
      final agendamentosSnap = await firestore.collection('agendamentos').get();

      final clientesList = clientesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      final servicosList = servicosSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      final agendamentosList = agendamentosSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      final jsonSanitizado = BackupService.gerarJsonBackup(
        clientes: clientesList,
        servicos: servicosList,
        agendamentos: agendamentosList,
      );

      final uri = Uri.dataFromString(
        jsonSanitizado,
        mimeType: 'application/json',
        encoding: utf8,
      );
      
      await launchUrl(uri);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup exportado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processandoBackup = false);
    }
  }

  Future<void> _importarBackup() async {
    final controller = TextEditingController();
    final jsonString = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar Backup (.json)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cole o conteúdo do seu arquivo JSON de backup no campo abaixo:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"version": "1.1", ...}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (jsonString == null || jsonString.isEmpty) return;

    setState(() => _processandoBackup = true);
    try {
      final totalRestaurado = await BackupService.restaurarBackup(jsonString);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sucesso! $totalRestaurado registros restaurados.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao restaurar backup: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processandoBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAtual = FirebaseAuth.instance.currentUser;
    final emailUsuario = usuarioAtual?.email ?? 'Usuário Autenticado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Inteligência Artificial',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Colors.purple),
                ),
                title: const Text('Relatório Gerencial (IA)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Gera análise automática de TM e faturamento do Studio', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/consultoria-ia'),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Backup e Restauração',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.download_outlined, color: Colors.blueGrey),
                    title: const Text('Exportar Backup (.json)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Salvar dados de clientes, serviços e agenda no dispositivo', style: TextStyle(fontSize: 12)),
                    onTap: _processandoBackup ? null : _exportarBackup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.upload_outlined, color: Colors.blueGrey),
                    title: const Text('Importar Backup (.json)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Restaurar clientes, serviços e agenda salvos anteriormente', style: TextStyle(fontSize: 12)),
                    onTap: _processandoBackup ? null : _importarBackup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Sessão do Usuário',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout_outlined, color: Colors.redAccent),
                ),
                title: const Text('Sair da Conta', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                subtitle: Text('Conectado como: $emailUsuario', style: const TextStyle(fontSize: 12)),
                onTap: () => _confirmarSaida(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
