import 'package:flutter/material.dart';

class TradeNoRecordsEmpty extends StatelessWidget {
  const TradeNoRecordsEmpty({
    super.key,
    required this.message,
    this.scrollable = false,
    this.height = 271,
  });

  final String message;
  final bool scrollable;
  final double height;

  static const String assetName = 'assets/images/trade_empty_state.png';

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            assetName,
            key: const ValueKey('trade-no-records-empty-art'),
            width: 94,
            height: 74,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF343434)),
          ),
        ],
      ),
    );

    if (!scrollable) return content;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [content],
    );
  }
}
