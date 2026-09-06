import 'package:flutter/material.dart';

class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
