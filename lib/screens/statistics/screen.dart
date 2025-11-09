import 'package:flutter/material.dart';

import 'controller.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key, required this.controller});

  final StatisticsController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.bar_chart_rounded, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            controller.headline,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              controller.description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
