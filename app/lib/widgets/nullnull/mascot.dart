import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/mascot.svg',
      width: size,
      height: size,
    );
  }
}
