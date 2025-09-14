import 'package:flutter/material.dart';

class AppState extends InheritedWidget {
  final ValueNotifier<String> division = ValueNotifier("Dhaka");

  AppState({super.key, required super.child});

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppState>()!;
  }

  @override
  bool updateShouldNotify(AppState oldWidget) => true;
}
