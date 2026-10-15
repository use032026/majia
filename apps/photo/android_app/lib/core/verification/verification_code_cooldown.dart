import 'package:flutter_riverpod/flutter_riverpod.dart';

class VerificationCodeCooldown {
  final DateTime? expiresAt;

  const VerificationCodeCooldown({this.expiresAt});

  int remainingSeconds([DateTime? now]) {
    final end = expiresAt;
    if (end == null) return 0;
    final diff = end.difference(now ?? DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isActive => remainingSeconds() > 0;
}

class VerificationCodeCooldownNotifier
    extends StateNotifier<VerificationCodeCooldown> {
  VerificationCodeCooldownNotifier() : super(const VerificationCodeCooldown());

  void start([int seconds = 60]) {
    state = VerificationCodeCooldown(
      expiresAt: DateTime.now().add(Duration(seconds: seconds)),
    );
  }

  void clear() {
    state = const VerificationCodeCooldown();
  }
}

final verificationCodeCooldownProvider =
    StateNotifierProvider<
      VerificationCodeCooldownNotifier,
      VerificationCodeCooldown
    >((ref) => VerificationCodeCooldownNotifier());
