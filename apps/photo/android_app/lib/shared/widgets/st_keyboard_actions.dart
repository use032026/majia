import 'package:flutter/material.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/router/route_observer.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// Shared keyboard manager aligned with iOS IQKeyboardManager defaults.
///
/// iOS reference:
/// `AppDelegate+ConfigSDK.launchConfigIQKeyboardManager`
/// - auto toolbar enabled
/// - toolbar order follows subview order
/// - tap outside dismisses keyboard
/// - distance from text field is 10pt
class STKeyboardActions extends StatelessWidget {
  const STKeyboardActions({
    super.key,
    required this.focusNodes,
    required this.child,
    this.enabled = true,
    this.autoScroll = true,
    this.disableScroll = true,
    this.isDialog = false,
  });

  final List<FocusNode> focusNodes;
  final Widget child;
  final bool enabled;
  final bool autoScroll;
  final bool disableScroll;
  final bool isDialog;

  @override
  Widget build(BuildContext context) {
    final nodes = focusNodes.where((node) => node.canRequestFocus).toList();
    if (nodes.isEmpty) return child;

    return KeyboardActions(
      config: KeyboardActionsConfig(
        keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
        keyboardBarColor: context.adaptiveMutedBlock,
        keyboardSeparatorColor: context.adaptiveHairline,
        defaultDoneWidget: const _STKeyboardDoneLabel(),
        nextFocus: true,
        actions: [
          for (final node in nodes)
            KeyboardActionsItem(
              focusNode: node,
              displayArrows: nodes.length > 1,
              displayDoneButton: true,
            ),
        ],
      ),
      enable: enabled,
      autoScroll: autoScroll,
      isDialog: isDialog,
      overscroll: 10,
      disableScroll: disableScroll,
      tapOutsideBehavior: TapOutsideBehavior.none,
      keepFocusOnTappingNode: true,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) =>
            dismissCurrentKeyboardFocus(pointerGlobalPosition: event.position),
        child: child,
      ),
    );
  }
}

class _STKeyboardDoneLabel extends StatelessWidget {
  const _STKeyboardDoneLabel();

  @override
  Widget build(BuildContext context) {
    final localizations = STLocalizations.ofContext(context);
    return FutureBuilder<String>(
      future: localizations.text('complete', fallback: '完成'),
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? _fallbackDoneLabelFor(context),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        );
      },
    );
  }

  String _fallbackDoneLabelFor(BuildContext context) {
    final languageCode = stLanguageCodeOfContext(context);
    if (languageCode.startsWith('en')) {
      return 'Complete';
    }
    return '完成';
  }
}
