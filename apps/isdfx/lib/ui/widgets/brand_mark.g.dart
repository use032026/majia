// Generated from branding/icon.svg by tool/generate_brand_assets.py.
// Draws synchronously so the mark is present on the first Flutter frame.
import 'dart:ui';

final List<(Path, Color)> _layers = [
  (
    Path()
      ..moveTo(38.4, 0)
      ..lineTo(121.6, 0)
      ..cubicTo(145, 0, 160, 15, 160, 38.4)
      ..lineTo(160, 121.6)
      ..cubicTo(160, 145, 145, 160, 121.6, 160)
      ..lineTo(38.4, 160)
      ..cubicTo(15, 160, 0, 145, 0, 121.6)
      ..lineTo(0, 38.4)
      ..cubicTo(0, 15, 15, 0, 38.4, 0)
      ..close(),
    const Color(0xff17191d),
  ),
  (
    Path()
      ..moveTo(28.8, 108.8)
      ..cubicTo(28.8, 63.8, 56.2, 28.8, 100.8, 28.8)
      ..lineTo(131.2, 28.8)
      ..lineTo(105.6, 54.4)
      ..lineTo(100.8, 54.4)
      ..cubicTo(70.7, 54.4, 54.4, 74.8, 54.4, 105.6)
      ..lineTo(54.4, 131.2)
      ..close(),
    const Color(0xffffffff),
  ),
  (
    Path()
      ..moveTo(67.2, 131.2)
      ..lineTo(67.2, 102.4)
      ..cubicTo(67.2, 81.9, 81.3, 67.2, 102.6, 67.2)
      ..lineTo(131.2, 67.2)
      ..lineTo(108.8, 92.8)
      ..lineTo(102, 92.8)
      ..cubicTo(96.6, 92.8, 92.8, 95.9, 92.8, 101.6)
      ..lineTo(92.8, 105.6)
      ..close(),
    const Color(0xffd92432),
  ),
];

void paintIsdfxMark(Canvas canvas, Size size) {
  canvas.save();
  canvas.scale(size.width / 160, size.height / 160);
  final paint = Paint();
  for (final (path, color) in _layers) {
    canvas.drawPath(path, paint..color = color);
  }
  canvas.restore();
}
