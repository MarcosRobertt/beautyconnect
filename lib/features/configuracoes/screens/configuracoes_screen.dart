import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../clientes/controllers/cliente_controller.dart'; 

import 'analise_ia_screen.dart';
import '../../financeiro/screens/despesas_screen.dart';
import '../../financeiro/controllers/despesa_controller.dart';
import '../../financeiro/screens/financeiro_screen.dart';
import '../../estoque/screens/estoque_screen.dart';
import '../controllers/backup_controller.dart';
import '../../produtos/screens/produtos_screen.dart'; 
import 'metas_screen.dart'; 
import 'whatsapp_config_screen.dart'; 

class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  // 🎨 NOVA IDENTIDADE VISUAL (VERDE SÁLVIA)
  final Color _primaryColor = const Color(0xFF3A4E40); // Verde Escuro Principal
  final Color _lightAccent = const Color(0xFFE8EFEA);  // Verde Claro (Fundos)
  final Color _borderAccent = const Color(0xFFB5C4B9); // Verde Intermédio (Bordas)

  void _fazerLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      context.go('/login');
    }
  }

  void _mostrarStatusBackup(BuildContext context, WidgetRef ref) {
    final backupController = ref.read(backupControllerProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cloud_done, color: _primaryColor, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Central de Backup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Os dados do Studio Condeza estão continuamente protegidos e sincronizados na nuvem do Google Cloud.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Exportar Cópia (.json)'),
                onPressed: () async {
                  try {
                    await backupController.exportarBackupJson();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Backup baixado com sucesso! 📁')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erro ao exportar: $e')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Restaurar do Arquivo (.json)'),
                onPressed: () async {
                  try {
                    await backupController.restaurarBackupJson();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Dados restaurados com sucesso! 🔄')),
                      );
                      Navigator.pop(ctx);
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erro ao restaurar: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9), // Fundo Sálvia Muito Claro
      appBar: AppBar(
        title: const Text('Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _lightAccent.withOpacity(0.5),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryColor),
            tooltip: 'Sincronizar Dados',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronizando sistema... 🔄'), duration: Duration(milliseconds: 1500)),
              );
              Future.delayed(const Duration(milliseconds: 500), () {
                // 🚀 NOVO MODO DE REFRESH SEM DART:HTML (WebAssembly Safe)
                GoRouter.of(context).refresh();
              });
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _borderAccent)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(radius: 28, backgroundColor: _lightAccent, child: Icon(Icons.storefront, size: 30, color: _primaryColor)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Studio Condeza', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(usuario?.email ?? 'Usuário não identificado', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text('INTELIGÊNCIA & FINANCEIRO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.psychology, color: Colors.purple),
                  title: const Text('Relatório Gerencial (IA)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Análises, Mapa de Calor e Dicas', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnaliseIaScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.redAccent),
                  title: const Text('Gestão de Despesas', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Custos Fixos, Parcelados e Regulares', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DespesasScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.green),
                  title: const Text('Resultados Financeiros', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Receitas, DRE, Caixa e Gráficos', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceiroScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
                  title: const Text('Estoque de Insumos', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Controle de Produtos, Compras e Alertas', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EstoqueScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined, color: Colors.pink),
                  title: const Text('Loja & Revenda', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Joias, Cosméticos e Vendas Avulsas', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProdutosScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text('SISTEMA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wechat, color: Colors.green),
                  title: const Text('Mensagens do WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Personalize textos automáticos', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsAppConfigScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.track_changes, color: Colors.blue),
                  title: const Text('Planejamento e Metas', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Configure suas metas de atendimentos', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MetasPlanejamentoScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.cloud_done_outlined, color: _primaryColor),
                  title: const Text('Status de Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sincronizado na Nuvem / Cópia JSON', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _mostrarStatusBackup(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                  title: const Text('Sobre o App', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Text('v1.1.3', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)), // atualiza a versão do app //
                  onTap: () {},
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          TextButton.icon(
            onPressed: () => _fazerLogout(context),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: const Text('Sair da Conta', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
