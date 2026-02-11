import 'package:flutter/material.dart';

class RevokeLogo extends StatelessWidget {
  const RevokeLogo({super.key, this.size = 40, this.fit = BoxFit.contain});

  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset('assets/branding/icon_source.png', fit: fit),
    );
  }
}
