import 'package:flutter/cupertino.dart';

class HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double width = size.width;
    double height = size.height;
    Path path = Path();

    path.moveTo(width / 2, height / 5);

    // Upper left path
    path.cubicTo(5 * width / 14, 0, 0, height / 15, width / 28, 2 * height / 5);

    // Lower left path
    path.cubicTo(width / 14, 2 * height / 3, 3 * width / 7, 5 * height / 6, width / 2, height);

    // Lower right path
    path.cubicTo(4 * width / 7, 5 * height / 6, 13 * width / 14, 2 * height / 3, 27 * width / 28, 2 * height / 5);

    // Upper right path
    path.cubicTo(width, height / 15, 9 * width / 14, 0, width / 2, height / 5);

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}
