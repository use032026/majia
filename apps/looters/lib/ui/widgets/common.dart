import 'package:flutter/material.dart';

import '../../app.dart';
import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';

class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PaceJar',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        padding: EdgeInsets.all(size * 0.2),
        child: CustomPaint(painter: _TrackMarkPainter()),
      ),
    );
  }
}

class _TrackMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = AppPalette.checkpoint;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.34),
      Offset(size.width * 0.92, size.height * 0.34),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.68),
      Offset(size.width * 0.72, size.height * 0.68),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.68),
      size.width * 0.12,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 16),
          const SizedBox(width: 7),
          Flexible(child: Text(AppText.of(context).get('offlineBadge'))),
        ],
      ),
    );
  }
}

class AppBarControls extends StatelessWidget {
  const AppBarControls({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextButton(
          onPressed: () => controller.setLocaleCode(
            controller.localeCode == 'zh' ? 'en' : 'zh',
          ),
          child: Text(controller.localeCode == 'zh' ? 'EN' : '中'),
        ),
        IconButton(
          tooltip: text.get('darkMode'),
          onPressed: () => controller.setDarkMode(!controller.darkMode),
          icon: Icon(controller.darkMode ? Icons.light_mode : Icons.dark_mode),
        ),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(AppText.of(context).get('retry')),
              ),
          ],
        ),
      ),
    );
  }
}
