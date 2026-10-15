import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_state.dart';
import '../network/st_service.dart';
import 'st_router.dart';

/// Shared agreement/privacy route helper.
///
/// When the current session has lost the H5 address model (for example after
/// logout or before startup data finishes hydrating), fetch the latest H5
/// addresses once before deciding whether the policy page is really missing.
class PolicyLinkRoute {
  const PolicyLinkRoute._();

  static String? urlFromUser(
    UserState user, {
    required bool privacy,
  }) {
    final link = privacy
        ? user.h5AddressModel?.privacyPolicyUrl
        : user.h5AddressModel?.userAgreementUrl;
    final trimmed = link?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, dynamic>? paramsFromUser(
    UserState user, {
    required bool privacy,
    required String title,
    Map<String, dynamic> extras = const {},
  }) {
    final link = urlFromUser(user, privacy: privacy);
    if (link == null) return null;
    return <String, dynamic>{'link': link, 'title': title, ...extras};
  }

  static Future<bool> open(
    BuildContext context,
    WidgetRef ref, {
    required bool privacy,
    required String title,
    Map<String, dynamic> extras = const {},
    String? action,
  }) async {
    var params = paramsFromUser(
      ref.read(userStateProvider),
      privacy: privacy,
      title: title,
      extras: extras,
    );
    if (params == null) {
      try {
        final data = await ref.read(stServiceProvider).getH5Addresses();
        if (!context.mounted) return false;
        if (data.isNotEmpty) {
          ref.read(userStateProvider.notifier).updateH5Address(data);
          params = paramsFromUser(
            ref.read(userStateProvider),
            privacy: privacy,
            title: title,
            extras: extras,
          );
        }
      } catch (_) {}
    }
    if (params == null) return false;
    await ref.read(stRouterProvider).openPage(
      context,
      '/web',
      params: params,
      action: action ?? title,
    );
    return true;
  }
}
