import 'package:flutter/material.dart';

import 'data/local_database.dart';
import 'screens/calendar/controller.dart';
import 'screens/calendar/screen.dart';
import 'screens/settings/controller.dart';
import 'screens/settings/screen.dart';
import 'screens/statistics/controller.dart';
import 'screens/statistics/screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.database});

  final LocalDatabase database;

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
  static const _navAnimationDuration = Duration(milliseconds: 350);

  late final CalendarController _calendarController;
  final StatisticsController _statisticsController = StatisticsController();
  final SettingsController _settingsController = SettingsController();

  late final PageController _pageController;
  late final List<_NavigationItem> _items;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController(database: widget.database)
      ..initialize();
    _pageController = PageController(initialPage: _selectedIndex);
    _items = const <_NavigationItem>[
      _NavigationItem(icon: Icons.calendar_month_rounded, label: 'Календарь'),
      _NavigationItem(icon: Icons.bar_chart_rounded, label: 'Статистика'),
      _NavigationItem(icon: Icons.settings_rounded, label: 'Настройки'),
    ];
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: _navAnimationDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
            // Оптимизированный Navigation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400, // Ограничиваем максимальную ширину
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12), // было 8 → стало 12
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List<Widget>.generate(
                        _items.length,
                            (int index) => _NavigationPillItem(
                          item: _items[index],
                          selected: index == _selectedIndex,
                          onTap: () => _onDestinationSelected(index),
                          animationDuration: _navAnimationDuration,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
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

class _NavigationPillItem extends StatefulWidget {
  const _NavigationPillItem({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.animationDuration,
    required this.colorScheme,
    required this.textTheme,
  });

  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  final Duration animationDuration;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  State<_NavigationPillItem> createState() => _NavigationPillItemState();
}

class _NavigationPillItemState extends State<_NavigationPillItem>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(duration: widget.animationDuration, vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController = AnimationController(duration: widget.animationDuration, vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    if (widget.selected) {
      _scaleController.forward();
      _fadeController.forward();
    }
  }

  @override
  void didUpdateWidget(_NavigationPillItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _scaleController.forward();
        _fadeController.forward();
      } else {
        _scaleController.reverse();
        _fadeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.selected
        ? widget.colorScheme.onPrimary
        : widget.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: widget.animationDuration,
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: 16,    // ↑ больше высота
          horizontal: widget.selected ? 24 : 20, // ↑ шире
        ),
        decoration: BoxDecoration(
          color: widget.selected ? widget.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(36), // ↑ крупнее скругление
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Крупная иконка
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.item.icon,
                size: 26, // ↑ крупнее
                color: iconColor,
              ),
            ),

            // Текст с fade + slide
            SizeTransition(
              sizeFactor: _fadeController,
              axis: Axis.horizontal,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10), // ↑ больше отступ
                  child: Text(
                    widget.item.label,
                    style: widget.textTheme.labelMedium?.copyWith(
                      color: widget.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14, // ↑ крупнее шрифт
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
