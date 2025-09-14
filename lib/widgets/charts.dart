import 'package:flutter/material.dart';

class SimpleChart extends StatelessWidget {
  final List<int> values;
  const SimpleChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(child: Text("Chart with ${values.length} points")),
    );
  }
}
