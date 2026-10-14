import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'strings.dart';

const _ink = Color(0xFF17312E);
const _teal = Color(0xFF0B6B63);
const _mint = Color(0xFFE9F2EF);
const _paper = Color(0xFFF8F7F2);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 58, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: light ? Colors.white : _teal,
      borderRadius: BorderRadius.circular(size * .28),
    ),
    child: CustomPaint(painter: _MarkPainter(light ? _teal : Colors.white)),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final route = Path()
      ..moveTo(size.width * .2, size.height * .72)
      ..lineTo(size.width * .42, size.height * .49)
      ..lineTo(size.width * .55, size.height * .61)
      ..lineTo(size.width * .8, size.height * .3);
    canvas.drawPath(route, line);
    canvas.drawCircle(
      Offset(size.width * .2, size.height * .72),
      size.width * .065,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(size.width * .8, size.height * .3),
      size.width * .065,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: const Scaffold(
      backgroundColor: _paper,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 82),
            SizedBox(height: 23),
            Text(
              'TRIP DELTA',
              style: TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish(L l) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.controller.completeOnboarding();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l('saveError'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L(Localizations.localeOf(context).languageCode == 'zh');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _paper,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 530),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const BrandMark(size: 38),
                        const SizedBox(width: 11),
                        const Text(
                          'TRIP DELTA',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          key: const Key('onboarding_skip'),
                          onPressed: _saving ? null : () => _finish(l),
                          child: Text(l('onboardingSkip')),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView.builder(
                        key: const Key('onboarding_pages'),
                        controller: _pages,
                        itemCount: 3,
                        onPageChanged: (index) => setState(() => _page = index),
                        itemBuilder: (context, index) => SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 30, bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '0${index + 1}  /  03',
                                  style: const TextStyle(
                                    color: _teal,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l('onboardingTitle${index + 1}'),
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 13),
                                Text(
                                  l('onboardingBody${index + 1}'),
                                  style: const TextStyle(
                                    color: Color(0xFF526460),
                                    fontSize: 16,
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 34),
                                _Illustration(index: index, l: l),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        3,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 230),
                          margin: const EdgeInsets.only(right: 7),
                          width: _page == index ? 30 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _page == index
                                ? _teal
                                : const Color(0xFFCCD9D4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        key: const Key('onboarding_next'),
                        onPressed: _saving
                            ? null
                            : () {
                                if (_page == 2) {
                                  _finish(l);
                                } else {
                                  _pages.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l(
                                  _page == 2
                                      ? 'onboardingStart'
                                      : 'onboardingNext',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l('onboardingPrivacy'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7C8B86),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.index, required this.l});

  final int index;
  final L l;

  @override
  Widget build(BuildContext context) {
    final icon = [
      Icons.route_outlined,
      Icons.receipt_long_outlined,
      Icons.insights_outlined,
    ][index];
    final label = [l('planned'), l('recorded'), l('difference')][index];
    return Container(
      height: 270,
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -75,
            right: -42,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD5E6E0), width: 25),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 40,
            bottom: 38,
            child: Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x190B6B63),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: _mint,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, color: _teal, size: 23),
                      ),
                      const Spacer(),
                      Text(
                        'TRIP  /  01',
                        style: TextStyle(
                          color: _teal.withValues(alpha: .7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF6E817B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ['¥ 10,000', '¥ 2,480', '¥ 7,520'][index],
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: [.72, .42, .65][index],
                      minHeight: 6,
                      backgroundColor: _mint,
                      valueColor: const AlwaysStoppedAnimation(_teal),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
