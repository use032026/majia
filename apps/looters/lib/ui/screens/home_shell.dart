import 'package:flutter/material.dart';

import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';
import 'pace_screen.dart';
import 'settings_screen.dart';
import 'timeline_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshForCurrentDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.route_outlined),
        selectedIcon: const Icon(Icons.route),
        label: text.get('pace'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history),
        label: text.get('timeline'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.tune_outlined),
        selectedIcon: const Icon(Icons.tune),
        label: text.get('settings'),
      ),
    ];
    final pages = <Widget>[
      PaceScreen(
        controller: widget.controller,
        openTimeline: () => setState(() => _index = 1),
      ),
      TimelineScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const AppMark(size: 32),
                const SizedBox(width: 10),
                Flexible(child: Text(text.get('appName'))),
              ],
            ),
            actions: <Widget>[
              if (!wide) AppBarControls(controller: widget.controller),
            ],
          ),
          body: Row(
            children: <Widget>[
              if (wide)
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppBarControls(controller: widget.controller),
                  ),
                  destinations: destinations
                      .map(
                        (item) => NavigationRailDestination(
                          icon: item.icon,
                          selectedIcon: item.selectedIcon,
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
              Expanded(
                child: IndexedStack(index: _index, children: pages),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: destinations,
                ),
        );
      },
    );
  }
}
