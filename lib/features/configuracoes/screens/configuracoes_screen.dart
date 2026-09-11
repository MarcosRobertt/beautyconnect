import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'analise_ia_screen.dart';
import '../../financeiro/screens/despesas_screen.dart';
import '../../financeiro/controllers/despesa_controller.dart';

class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  void _fazerLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryColor = Color(0xFF8A2463);
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0F4),
      appBar: AppBar(
        title: const Text('Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            tooltip: 'Sincronizar Dados',
            onPressed: () async {
              // Explicita a busca forcada no servidor para limpar o cache mobile
              await ref.read(despesaControllerProvider.notifier).carregarDespesasMes(
                DateTime.now(),
                forcarServidor: true,
              );
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dados sincronizados com o servidor! 🔄'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFF5E1EC),
                    child: const Icon(Icons.storefront, size: 30, color: primaryColor),
                  ),
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
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                  title: const Text('Gestão de Despesas', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Custos Fixos, Parcelados e Regulares', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DespesasScreen())),
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
                  leading: const Icon(Icons.cloud_download_outlined, color: Colors.blueGrey),
                  title: const Text('Backup de Dados'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo de backup em nuvem em desenvolvimento.')));
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                  title: const Text('Sobre o App'),
                  trailing: const Text('v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        ],
      ),
    );
  }
}
