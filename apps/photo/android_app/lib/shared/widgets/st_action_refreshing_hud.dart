import 'package:flutter/material.dart';

/// Shared in-page blocking HUD used by iOS-aligned action refresh flows.
class STActionRefreshingHud extends StatelessWidget {
  const STActionRefreshingHud({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xCC17171A),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: const SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFFE6E6EA),
                    backgroundColor: Color(0xFF3A3A40),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
