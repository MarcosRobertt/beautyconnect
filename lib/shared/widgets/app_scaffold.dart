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
    (icon: Icons.spa_outlined, selectedIcon: Icons.spa, label: 'Serviços'),
    (icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today, label: 'Agenda'),
    (icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Menu'),
  ];

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final ehTelaLarga = larguraTela >= 800;

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
                    const SizedBox(height: 6),
                    const Text('BeautyConnect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      'by studio condeza',
                      style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
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
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
            }
            return const TextStyle(fontSize: 10);
          }),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
          destinations: _destinos
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
