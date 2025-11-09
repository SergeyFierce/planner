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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _PlannerHome(),
    );
  }
}

class _PlannerHome extends StatefulWidget {
  const _PlannerHome();

  @override
  State<_PlannerHome> createState() => _PlannerHomeState();
}

class _PlannerHomeState extends State<_PlannerHome> {
  late final AppLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = AppLogic();
  }

  @override
  void dispose() {
    _logic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppPage>(
      valueListenable: _logic.currentPage,
      builder: (context, page, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(appPageTitle(page)),
            centerTitle: true,
          ),
          body: _AnimatedPageView(page: page),
          floatingActionButton: _FabNavigation(
            logic: _logic,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

class _AnimatedPageView extends StatelessWidget {
  const _AnimatedPageView({required this.page});

  final AppPage page;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        final offsetAnimation =
            Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: _PagePlaceholder(
        key: ValueKey<AppPage>(page),
        page: page,
      ),
    );
  }
}

class _PagePlaceholder extends StatelessWidget {
  const _PagePlaceholder({super.key, required this.page});

  final AppPage page;

  IconData get _icon {
    switch (page) {
      case AppPage.calendar:
        return Icons.calendar_month_outlined;
      case AppPage.statistics:
        return Icons.query_stats_outlined;
      case AppPage.settings:
        return Icons.settings_outlined;
    }
  }

  String get _message {
    switch (page) {
      case AppPage.calendar:
        return 'Экран календаря пока в разработке';
      case AppPage.statistics:
        return 'Экран статистики пока в разработке';
      case AppPage.settings:
        return 'Экран настроек пока в разработке';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: 96,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            _message,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FabNavigation extends StatelessWidget {
  const _FabNavigation({required this.logic});

  final AppLogic logic;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: logic.isFabOpen,
      builder: (context, isOpen, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: isOpen
                  ? _FabNavigationOptions(
                      key: const ValueKey('fab-options'),
                      onSelected: logic.selectPage,
                    )
                  : const SizedBox(key: ValueKey('fab-empty')),
            ),
            if (isOpen) const SizedBox(height: 12),
            FloatingActionButton(
              onPressed: logic.toggleFabPanel,
              child: Icon(isOpen ? Icons.close : Icons.menu),
            ),
          ],
        );
      },
    );
  }
}

class _FabNavigationOptions extends StatelessWidget {
  const _FabNavigationOptions({super.key, required this.onSelected});

  final ValueChanged<AppPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FabDestinationButton(
          icon: Icons.calendar_today,
          label: 'Календарь',
          page: AppPage.calendar,
          onSelected: onSelected,
        ),
        const SizedBox(height: 12),
        _FabDestinationButton(
          icon: Icons.stacked_line_chart,
          label: 'Статистика',
          page: AppPage.statistics,
          onSelected: onSelected,
        ),
        const SizedBox(height: 12),
        _FabDestinationButton(
          icon: Icons.settings,
          label: 'Настройки',
          page: AppPage.settings,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _FabDestinationButton extends StatelessWidget {
  const _FabDestinationButton({
    required this.icon,
    required this.label,
    required this.page,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final AppPage page;
  final ValueChanged<AppPage> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FloatingActionButton.extended(
      heroTag: page,
      onPressed: () => onSelected(page),
      icon: Icon(icon),
      label: Text(label),
      backgroundColor: theme.colorScheme.secondaryContainer,
      foregroundColor: theme.colorScheme.onSecondaryContainer,
    );
  }
}
