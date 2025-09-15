import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({
    super.key,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.15),
        color: Colors.white, // Simple white background
      ),
      padding: EdgeInsets.all(size * 0.05), // Minimal padding
      child: Image.asset(
        'assets/aqi_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.air,
            size: size * 0.7,
            color: Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }
}