import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_cost/app/router/app_routes.dart';
import 'package:trip_cost/app/theme/app_theme.dart';
import 'package:trip_cost/features/startup/application/startup_controller.dart';
import 'package:trip_cost/features/startup/application/web_startup_controller.dart';
import 'package:trip_cost/l10n/app_localizations.dart';

class StartupPage extends ConsumerStatefulWidget {
  const StartupPage({super.key});

  @override
  ConsumerState<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends ConsumerState<StartupPage> {
  bool _navigationScheduled = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(startupDestinationProvider).whenData(_scheduleNavigation);

    return const CupertinoPageScaffold(
      backgroundColor: AppColors.launchBackground,
      child: Center(child: LaunchMark()),
    );
  }

  void _scheduleNavigation(StartupDestination destination) {
    if (_navigationScheduled) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openWebAndNavigate(destination));
    });
  }

  Future<void> _openWebAndNavigate(StartupDestination destination) async {
    final controller = ref.read(webStartupControllerProvider);
    final navigator = Navigator.of(context, rootNavigator: true);
    var presentationFailed = false;
    final enabled = await controller.isEnabled();
    if (!mounted) return;
    if (enabled) {
      try {
        // Keep the launch frame mounted until the native container is presented.
        // Its page-loading and Retry UI stay owned by mini_web.
        await controller.open();
      } on Object {
        presentationFailed = true;
      }
    }
    if (!mounted) return;
    context.go(
      destination == StartupDestination.home
          ? AppRoutes.home
          : AppRoutes.onboarding,
    );
    if (presentationFailed) {
      // The StartupPage will be disposed after routing. Keep only stable root
      // Navigator/controller references while offering a retry over native UI.
      await WidgetsBinding.instance.endOfFrame;
      await _showWebPresentationFailure(navigator, controller);
    }
  }

  static Future<void> _showWebPresentationFailure(
    NavigatorState navigator,
    WebStartupController controller,
  ) async {
    while (navigator.mounted) {
      final dialogContext = navigator.context;
      if (!dialogContext.mounted) return;
      final localizations = AppLocalizations.of(dialogContext);
      final retry = await showCupertinoDialog<bool>(
        context: dialogContext,
        builder: (context) => CupertinoAlertDialog(
          key: const Key('web-startup-error'),
          content: Text(localizations.webStartupPresentationFailed),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.commonDone),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(localizations.webStartupRetry),
            ),
          ],
        ),
      );
      if (retry != true || !navigator.mounted) return;
      try {
        await controller.open();
        return;
      } on Object {
        // Persistence succeeded earlier; presentation failure does not opt out.
      }
    }
  }
}

class LaunchMark extends StatelessWidget {
  const LaunchMark({this.size = 96, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/launch_mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      semanticLabel: 'RhinoSmart',
    );
  }
}
