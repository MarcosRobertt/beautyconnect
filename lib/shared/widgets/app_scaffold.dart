import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Casco de navegação do app. Responsivo: barra lateral em telas largas
/// (desktop/tablet/notebook) e navegação inferior em telas estreitas.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinos = [
    (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Clientes'),
    (icon: Icons.miscellaneous_services_outlined, selectedIcon: Icons.miscellaneous_services, label: 'Serviços'),
    (icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today, label: 'Agenda'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Configurações'),
  ];

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final ehTelaLarga = larguraTela >= 800; // desktop/tablet/notebook

    if (ehTelaLarga) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.water_drop, color: Colors.white, size: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text('BeautyConnect', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              destinations: _destinos
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: _destinos
            .map((d) => NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label))
            .toList(),
      ),
    );
  }
}
