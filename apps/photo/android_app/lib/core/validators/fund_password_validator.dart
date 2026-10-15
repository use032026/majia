/// 对齐 iOS `STCommonBussinessHandler.validateSixDigitCode:`
bool isSixDigitFundPasswordValid(String code) {
  if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) return false;
  return !_isStrictConsecutiveDigits(code);
}

/// 严格递增或递减步长为 1（如 123456、654321）
bool _isStrictConsecutiveDigits(String str) {
  final digits = str.codeUnits.map((u) => u - 48).toList();
  final firstDelta = digits[1] - digits[0];
  if (firstDelta.abs() != 1) return false;
  for (var i = 2; i < digits.length; i++) {
    if (digits[i] - digits[i - 1] != firstDelta) return false;
  }
  return true;
}
