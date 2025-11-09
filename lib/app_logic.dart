import 'package:flutter/foundation.dart';

enum AppPage { calendar, statistics, settings }

String appPageTitle(AppPage page) {
  switch (page) {
    case AppPage.calendar:
      return 'Календарь';
    case AppPage.statistics:
      return 'Статистика';
    case AppPage.settings:
      return 'Настройки';
  }
}

class AppLogic {
  AppLogic();

  final ValueNotifier<AppPage> currentPage =
      ValueNotifier<AppPage>(AppPage.calendar);
  final ValueNotifier<bool> isFabOpen = ValueNotifier<bool>(false);

  void selectPage(AppPage page) {
    if (currentPage.value == page) {
      isFabOpen.value = false;
      return;
    }
    currentPage.value = page;
    isFabOpen.value = false;
  }

  void toggleFabPanel() {
    isFabOpen.value = !isFabOpen.value;
  }

  void dispose() {
    currentPage.dispose();
    isFabOpen.dispose();
  }
}
