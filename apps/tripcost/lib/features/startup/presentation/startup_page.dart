import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_cost/app/router/app_routes.dart';
import 'package:trip_cost/app/theme/app_theme.dart';
import 'package:trip_cost/features/startup/application/startup_controller.dart';

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
      context.go(
        destination == StartupDestination.home
            ? AppRoutes.home
            : AppRoutes.onboarding,
      );
    });
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
      semanticLabel: 'RoamSum',
    );
  }
}
