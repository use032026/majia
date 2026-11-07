import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:trip_cost/core/platform/online_web_bridge.dart';
import 'package:trip_cost/core/platform/online_web_config.dart';

void main() {
  const origin = 'https://h5.globalsmartchoose.com';
  late List<({Uri uri, String? title, bool showNavigationBar})> opens;
  late int closes;
  late List<String> reasons;
  late OnlineWebBridge bridge;

  setUp(() {
    opens = [];
    closes = 0;
    reasons = [];
    bridge = OnlineWebBridge(
      homeUri: Uri.parse(onlineWebHomeUrl),
      openPage: (uri, {title, required showNavigationBar}) async {
        opens.add((
          uri: uri,
          title: title,
          showNavigationBar: showNavigationBar,
        ));
      },
      closePage: () async {
        closes++;
      },
      notifySessionChanged: (reason) async {
        reasons.add(reason);
        return 2;
      },
    );
  });

  Future<Map<String, dynamic>> request(
    String method, {
    Map<String, dynamic> params = const {},
    String requestOrigin = origin,
  }) => bridge.handle(
    WebBridgeRequest(method: method, params: params, origin: requestOrigin),
  );

  test(
    'external /web opens a new HTTPS page with requested native chrome',
    () async {
      final result = await request(
        'open',
        params: {
          'router': '/web',
          'link': 'https://h5-x.761242.com/polymer/partner/',
          'title': '客服',
          'isNeedNavigationBar': '1',
        },
      );

      expect(result['code'], '1');
      expect(opens, hasLength(1));
      expect(
        opens.single.uri.toString(),
        'https://h5-x.761242.com/polymer/partner/',
      );
      expect(opens.single.title, '客服');
      expect(opens.single.showNavigationBar, isTrue);
    },
  );

  test('internal login creates a route child with a return hint', () async {
    final result = await request(
      'open',
      params: {
        'router': '/login',
        'redirect': '/polymer/partner/',
        'methodId': 'callback-1',
      },
    );

    expect(result['code'], '1');
    expect(opens, hasLength(1));
    final child = opens.single;
    expect(child.uri.origin, Uri.parse(onlineWebHomeUrl).origin);
    expect(child.showNavigationBar, isFalse);
    final fragment = Uri.parse('https://local.test${child.uri.fragment}');
    expect(fragment.queryParameters['__mini_child'], '1');
    expect(fragment.queryParameters['__mini_route_child'], '1');
    final encoded = fragment.queryParameters['__mini_open_route']!;
    final route =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(encoded))))
            as Map<String, dynamic>;
    expect(route, {
      'router': '/login',
      'redirect': '/polymer/partner/',
      'isBack': '1',
    });
  });

  test('invalid URLs, routes, and origins never open a page', () async {
    for (final params in [
      {'router': '/web', 'link': 'http://example.com'},
      {'router': '/web', 'link': '/relative'},
      {'router': '/web', 'link': 'https://user:pass@example.com'},
      {'router': '//example.com'},
      {'router': 'login'},
    ]) {
      expect((await request('open', params: params))['code'], '0');
    }
    expect(
      (await request(
        'open',
        params: {'router': '/login'},
        requestOrigin: 'http://h5.globalsmartchoose.com',
      ))['code'],
      '0',
    );
    expect(opens, isEmpty);
  });

  test('close and session change invoke host operations', () async {
    expect((await request('close'))['code'], '1');
    expect(closes, 1);
    final changed = await request(
      'web_notifySessionChanged',
      params: {'reason': 'login'},
    );
    expect(changed, {
      'code': '1',
      'data': {'notified': 2},
    });
    expect(reasons, ['login']);
    await request('web_notifySessionChanged');
    expect(reasons.last, 'sessionChanged');
  });

  test('diagnostics are acknowledged; unsupported calls fail', () async {
    expect((await request('applog'))['code'], '1');
    expect((await request('unknown'))['code'], '0');
  });
}
