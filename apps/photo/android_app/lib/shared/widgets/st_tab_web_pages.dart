import 'package:flutter/material.dart';

import 'st_mini_view.dart';
import 'st_unified_webview.dart';

class STTabWebH5Page extends StatelessWidget {
  final String url;
  final String? title;
  final bool visible;

  const STTabWebH5Page({
    super.key,
    required this.url,
    this.title,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    return STUnifiedWebView(
      visible: visible,
      config: STWebConfig.fromUrl(url, title: title, embedded: true),
    );
  }
}

class STTabWebMiniPage extends StatelessWidget {
  final String name;
  final String? title;
  final String? link;
  final String path;
  final bool visible;

  const STTabWebMiniPage({
    super.key,
    this.name = 'davmu',
    this.title,
    this.link,
    this.path = '',
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    return STMiniView(
      link: 'localMini://$name',
      path: path,
      title: title,
      routeParams: const {'isOnTabbar': '1'},
      embedded: true,
      visible: visible,
    );
  }
}
