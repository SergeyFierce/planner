import 'package:flutter/material.dart';

import 'controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.settings_rounded, size: 64, color: colorScheme.primary),
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
