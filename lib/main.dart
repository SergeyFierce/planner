import 'package:flutter/material.dart';

import 'app_logic.dart';

void main() {
  runApp(const PlannerApp());
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111217),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: offsetAnimation,
                  child: child,
                ),
              );
            },
            child: _screens[_appState.currentIndex],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _BottomNavigationBar(
              currentIndex: _appState.currentIndex,
              onItemSelected: _appState.selectTab,
            ),
          ),
        );
      },
    );
  }
}

class _BottomNavigationBar extends StatelessWidget {
  const _BottomNavigationBar({
    required this.currentIndex,
    required this.onItemSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D24).withOpacity(0.95),
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: _CapsuleNavItem(
                tab: _tabs[i],
                selected: currentIndex == i,
                onTap: () => onItemSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _CapsuleNavItem extends StatelessWidget {
  const _CapsuleNavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _TabItem tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab.icon,
                  color: selected ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.horizontal,
                        child: child,
                      ),
                    );
                  },
                  child: selected
                      ? Text(
                          tab.label,
                          key: ValueKey(tab.label),
                          style: labelStyle,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _ScreenPlaceholder extends StatelessWidget {
  const _ScreenPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.index,
  }) : super(key: ValueKey<int>(index));

  final IconData icon;
  final String title;
  final String subtitle;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

const List<_TabItem> _tabs = <_TabItem>[
  _TabItem(icon: Icons.calendar_today_rounded, label: 'Календарь'),
  _TabItem(icon: Icons.bar_chart_rounded, label: 'Статистика'),
  _TabItem(icon: Icons.settings_rounded, label: 'Настройки'),
];

final List<Widget> _screens = <Widget>[
  const _ScreenPlaceholder(
    icon: Icons.calendar_today_rounded,
    title: 'Календарь',
    subtitle: 'Здесь появится ваш планировщик событий и встреч.',
    index: 0,
  ),
  const _ScreenPlaceholder(
    icon: Icons.bar_chart_rounded,
    title: 'Статистика',
    subtitle: 'Отчёты и аналитика по вашим задачам будут здесь.',
    index: 1,
  ),
  const _ScreenPlaceholder(
    icon: Icons.settings_rounded,
    title: 'Настройки',
    subtitle: 'Настройте приложение под себя в этом разделе.',
    index: 2,
  ),
];
