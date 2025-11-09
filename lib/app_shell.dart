import 'dart:math' as math;

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final double availableWidth = constraints.maxWidth;

                          const double preferredCollapsedWidth = 64;
                          double collapsedWidth = preferredCollapsedWidth;

                          if (availableWidth <= 0) {
                            collapsedWidth = 0;
                          } else {
                            final double averageWidth = availableWidth / _items.length;
                            collapsedWidth = math.min(collapsedWidth, averageWidth);
                            if (averageWidth >= 48) {
                              collapsedWidth = math.max(collapsedWidth, 48);
                            }
                          }

                          final double calculatedExpandedWidth =
                              availableWidth - collapsedWidth * (_items.length - 1);
                          final double expandedWidth =
                              math.max(collapsedWidth, calculatedExpandedWidth);

                          return SizedBox(
                            height: 60,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                for (int index = 0; index < _items.length; index++)
                                  _NavigationPillItem(
                                    item: _items[index],
                                    selected: index == _selectedIndex,
                                    onTap: () => _onDestinationSelected(index),
                                    animationDuration: _navAnimationDuration,
                                    colorScheme: colorScheme,
                                    width: index == _selectedIndex
                                        ? expandedWidth
                                        : collapsedWidth,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
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
    required this.width,
  });

  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  final Duration animationDuration;
  final ColorScheme colorScheme;
  final double width;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final double labelMaxWidth = math.max(0, width - 62);

    final bool showLabel = selected && labelMaxWidth > 36;

    return SizedBox(
      width: width,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          splashColor: colorScheme.primary.withOpacity(0.12),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(item.icon, size: 22, color: iconColor),
                  AnimatedSwitcher(
                    duration: animationDuration,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axis: Axis.horizontal,
                          child: child,
                        ),
                      );
                    },
                    child: showLabel
                        ? Padding(
                            key: ValueKey<String>(item.label),
                            padding: const EdgeInsets.only(left: 8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: labelMaxWidth,
                              ),
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          )
                        : const SizedBox(key: ValueKey<String>('empty')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
