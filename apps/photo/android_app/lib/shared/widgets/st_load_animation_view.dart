import 'package:flutter/material.dart';

/// Flutter equivalent of iOS `STLoadAnimationView`.
///
/// Uses the native `st_web_loading` bitmap as a mask and runs the same
/// 1.5-second horizontal sweep used by the iOS gradient layer.
class STLoadAnimationView extends StatefulWidget {
  const STLoadAnimationView({super.key});

  static const double logoWidth = 112;
  static const double logoHeight = logoWidth * 48 / 156;

  @override
  State<STLoadAnimationView> createState() => _STLoadAnimationViewState();
}

class _STLoadAnimationViewState extends State<STLoadAnimationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/st_web_loading_dark.png'
        : 'assets/images/st_web_loading.png';

    return SizedBox(
      key: const ValueKey('st-load-animation-view'),
      width: STLoadAnimationView.logoWidth,
      height: STLoadAnimationView.logoHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.2,
            child: Image.asset(
              asset,
              key: const ValueKey('st-load-animation-logo'),
              fit: BoxFit.contain,
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = -1.25 + (_controller.value * 2.5);
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment(offset - 0.6, -1),
                    end: Alignment(offset + 0.7, 0.4),
                    colors: const [
                      Color(0xFFD8D8D8),
                      Color(0xFF8F8F8F),
                      Color(0xFF8F8F8F),
                      Color(0xFFD8D8D8),
                    ],
                    stops: const [0, 0.01, 0.16, 0.17],
                  ).createShader(bounds);
                },
                child: child,
              );
            },
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
