import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const webLaunchImages = {
  'zh': 'assets/brand/web_launch_zh.png',
  'default': 'assets/brand/web_launch_default.png',
};

class WebLaunchSplash extends StatelessWidget {
  const WebLaunchSplash({super.key, required this.languageCode});
  final String languageCode;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: SizedBox.expand(
      child: Image.asset(
        webLaunchImages[languageCode.toLowerCase().startsWith('zh')
            ? 'zh'
            : 'default']!,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    ),
  );
}
