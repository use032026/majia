import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_state.dart';
import '../network/st_service.dart';
import 'st_router.dart';

/// iOS customer-service contract:
/// `STUserInfoManger.h5AddressModel.customer_support_url` -> `/web` + nav bar.
class CustomerServiceRoute {
  const CustomerServiceRoute._();

  static Map<String, dynamic>? paramsFromUser(
    UserState user, {
    Map<String, dynamic> extras = const {},
  }) {
    return paramsFromUrl(
      user.h5AddressModel?.customerSupportUrl,
      extras: extras,
    );
  }

  static Map<String, dynamic>? paramsFromUrl(
    String? url, {
    Map<String, dynamic> extras = const {},
  }) {
    final link = url?.trim() ?? '';
    if (link.isEmpty) return null;
    return <String, dynamic>{
      'link': link,
      'isNeedNavigationBar': true,
      ...extras,
    };
  }

  static String? locationFromUrl(
    String? url, {
    Map<String, dynamic> extras = const {},
  }) {
    final params = paramsFromUrl(url, extras: extras);
    return params == null ? null : locationFromParams(params);
  }

  static String locationFromParams(Map<String, dynamic> params) {
    return STRouteResolver.buildLocation('/web', params);
  }

  static Future<bool> open(
    BuildContext context,
    WidgetRef ref, {
    String action = '客服',
    Map<String, dynamic> extras = const {},
  }) async {
    var params = paramsFromUser(ref.read(userStateProvider), extras: extras);
    if (params == null) {
      try {
        final data = await ref.read(stServiceProvider).getH5Addresses();
        if (!context.mounted) return false;
        if (data.isNotEmpty) {
          ref.read(userStateProvider.notifier).updateH5Address(data);
          params = paramsFromUser(ref.read(userStateProvider), extras: extras);
        }
      } catch (_) {}
    }
    if (params == null) return false;
    await ref
        .read(stRouterProvider)
        .openPage(context, '/web', params: params, action: action);
    return true;
  }
}
