import 'package:flutter/material.dart';

class AppState extends InheritedWidget {
  final ValueNotifier<String> division;

  AppState({super.key, required super.child, ValueNotifier<String>? division})
      : division = division ?? ValueNotifier("Dhaka");

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppState>()!;
  }

  @override
  bool updateShouldNotify(AppState oldWidget) => division != oldWidget.division;
}
