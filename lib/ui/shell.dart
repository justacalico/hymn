import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'pages/apps_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/disks_page.dart';
import 'pages/settings_page.dart';
import 'pages/shares_page.dart';
import 'pages/snapshots_page.dart';
import 'pages/stats_page.dart';
import 'pages/storage_page.dart';
import 'pages/users_page.dart';
import 'theme.dart';

class NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const NavDestination(this.icon, this.selectedIcon, this.label, this.page);
}

const destinations = <NavDestination>[
  NavDestination(Icons.space_dashboard_outlined, Icons.space_dashboard,
      'Dashboard', DashboardPage()),
  NavDestination(
      Icons.dns_outlined, Icons.dns, 'Storage', StoragePage()),
  NavDestination(Icons.album_outlined, Icons.album, 'Disks', DisksPage()),
  NavDestination(Icons.folder_shared_outlined, Icons.folder_shared, 'Shares',
      SharesPage()),
  NavDestination(Icons.photo_camera_outlined, Icons.photo_camera, 'Snapshots',
      SnapshotsPage()),
  NavDestination(Icons.widgets_outlined, Icons.widgets, 'Apps', AppsPage()),
  NavDestination(Icons.group_outlined, Icons.group, 'Users', UsersPage()),
  NavDestination(Icons.query_stats_outlined, Icons.query_stats, 'Stats',
      StatsPage()),
  NavDestination(Icons.settings_outlined, Icons.settings, 'Settings',
      SettingsPage()),
];

/// Adaptive root scaffold. Wide windows get a navigation rail, compact
/// layouts get a bottom bar with a "More" sheet for the remaining sections.
/// Only the layout changes with size; state lives above in [AppState].
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final index = state.navIndex.clamp(0, destinations.length - 1);
    final page = IndexedStack(
      index: index,
      children: destinations.map((d) => d.page).toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: state.selectNav,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(bottom: 16, top: 8),
                    child: _RailLogo(),
                  ),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            ),
          );
        }
        return _CompactShell(index: index, body: page);
      },
    );
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [HymnTheme.accent, HymnTheme.accentAlt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storage, color: Colors.white, size: 24),
        ),
      ],
    );
  }
}

/// Compact shell: five primary destinations on the bottom bar, the rest in a
/// sheet. [AppState.navIndex] still indexes into the full [destinations] list.
class _CompactShell extends StatelessWidget {
  final int index;
  final Widget body;

  const _CompactShell({required this.index, required this.body});

  static const _primary = [0, 1, 3, 5]; // dashboard, storage, shares, apps

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final inPrimary = _primary.contains(index);
    final barIndex = inPrimary ? _primary.indexOf(index) : _primary.length;
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: barIndex,
        onDestinationSelected: (i) {
          if (i < _primary.length) {
            state.selectNav(_primary[i]);
          } else {
            _showMoreSheet(context);
          }
        },
        destinations: [
          for (final i in _primary)
            NavigationDestination(
              icon: Icon(destinations[i].icon),
              selectedIcon: Icon(destinations[i].selectedIcon),
              label: destinations[i].label,
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    final state = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < destinations.length; i++)
              if (!_primary.contains(i))
                ListTile(
                  leading: Icon(destinations[i].icon),
                  title: Text(destinations[i].label),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    state.selectNav(i);
                  },
                ),
          ],
        ),
      ),
    );
  }
}
