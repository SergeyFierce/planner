import 'package:flutter/material.dart';

import 'screens/calendar/screen.dart';
import 'screens/calendar/controller.dart';
import 'screens/settings/controller.dart';
import 'screens/settings/screen.dart';
import 'screens/statistics/controller.dart';
import 'screens/statistics/screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _NavigationItem {
  const _NavigationItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _AppShellState extends State<AppShell> {
  static const _navAnimationDuration = Duration(milliseconds: 300);

  final CalendarController _calendarController = CalendarController();
  final StatisticsController _statisticsController = StatisticsController();
  final SettingsController _settingsController = SettingsController();

  late final PageController _pageController;
  late final List<_NavigationItem> _items;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _items = const <_NavigationItem>[
      _NavigationItem(icon: Icons.calendar_month_rounded, label: 'Календарь'),
      _NavigationItem(icon: Icons.bar_chart_rounded, label: 'Статистика'),
      _NavigationItem(icon: Icons.settings_rounded, label: 'Настройки'),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  CalendarScreen(controller: _calendarController),
                  StatisticsScreen(controller: _statisticsController),
                  SettingsScreen(controller: _settingsController),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: Row(
                    children: List<Widget>.generate(
                      _items.length,
                      (int index) => Expanded(child: _NavigationPillItem(
                        item: _items[index],
                        selected: index == _selectedIndex,
                        onTap: () => _onDestinationSelected(index),
                        animationDuration: _navAnimationDuration,
                        colorScheme: colorScheme,
                      )),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationPillItem extends StatelessWidget {
  const _NavigationPillItem({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.animationDuration,
    required this.colorScheme,
  });

  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  final Duration animationDuration;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: selected ? 18 : 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(item.icon, size: 22, color: iconColor),
            AnimatedSwitcher(
              duration: animationDuration,
              transitionBuilder: (Widget child, Animation<double> animation) {
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
                  ? Padding(
                      key: ValueKey<String>(item.label),
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey<String>('empty'), width: 0),
            ),
          ],
        ),
      ),
    );
  }
}
