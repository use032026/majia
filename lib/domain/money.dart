const int maxMoneyCents = 999999999999;

int? parseMoneyToCents(String raw, {bool allowZero = false}) {
  final normalized = raw.trim().replaceAll(',', '');
  final match = RegExp(r'^(\d{1,10})(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final fractionRaw = match.group(2) ?? '';
  final fraction = fractionRaw.isEmpty
      ? 0
      : int.parse(fractionRaw.padRight(2, '0'));
  final cents = whole * 100 + fraction;
  if (cents > maxMoneyCents || (!allowZero && cents == 0)) return null;
  return cents;
}

String formatMoney(int cents, String currency) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${negative ? '−' : ''}$currency${buffer.toString()}.$fraction';
}
