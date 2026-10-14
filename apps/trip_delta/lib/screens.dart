import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'backup.dart';
import 'domain.dart';
import 'ios_overlays.dart';
import 'privacy_web_page.dart';
import 'review_share.dart';
import 'store.dart';
import 'strings.dart';

L loc(BuildContext context) =>
    L(Localizations.localeOf(context).languageCode == 'zh');

String amountInput(int minor, String currency) {
  if (currencyDigits(currency) == 0) return minor.toString();
  return (minor / 100).toStringAsFixed(2);
}

Widget pageWidth(Widget child) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: child,
  ),
);

void showSaveError(BuildContext context, L l) {
  showIosNotice(context, l('saveError'));
}

Future<bool> confirmDelete(BuildContext context, String question, L l) async {
  return await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => iosOverlayTheme(
          context,
          CupertinoAlertDialog(
            title: Text(question),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l('cancel')),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l('delete')),
              ),
            ],
          ),
        ),
      ) ??
      false;
}

class TripPaceCard extends StatelessWidget {
  const TripPaceCard({
    super.key,
    required this.trip,
    required this.l,
    this.showIdentity = true,
    this.showBreakdownFooter = true,
  });
  final Trip trip;
  final L l;
  final bool showIdentity;
  final bool showBreakdownFooter;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daily = trip.remainingMinor < 0
        ? null
        : trip.dailyAvailableMinor(now);
    final days = trip.daysRemaining(now);
    final over = trip.remainingMinor < 0;
    final planned = trip.plannedMinor;
    final spent = trip.spentMinor;
    final progress = planned == 0 ? 0.0 : (spent / planned).clamp(0.0, 1.0);
    final budgetedCount = BudgetCategory.values
        .where((category) => trip.plannedFor(category) > 0)
        .length;
    final largestOver = largestOverCategory(trip);
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showIdentity)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (trip.destination.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            trip.destination,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        l.stage(trip.stage),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: showIdentity ? 20 : 0),
            Text(
              over ? l('over') : l('remaining'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              moneyText(trip.remainingMinor.abs(), trip.baseCurrency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: over ? theme.colorScheme.error : null,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: over
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l('recorded')} ${moneyText(spent, trip.baseCurrency)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${l('planned')} ${moneyText(planned, trip.baseCurrency)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (daily != null) ...[
              const SizedBox(height: 12),
              Text(
                '${l('dailyAvailable')} ${moneyText(daily, trip.baseCurrency)}  ·  $days ${l('daysRemaining')}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (trip.estimatedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${l('includesEstimates')} ${trip.estimatedCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (showBreakdownFooter) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      largestOver == null
                          ? '$budgetedCount ${l('budgetCategoriesSet')}'
                          : '${l('largestDriver')}: ${l.category(largestOver)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: largestOver == null
                            ? null
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l('viewBreakdown'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.backupGateway,
  });
  final AppController controller;
  final BackupGateway backupGateway;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  final TextEditingController _historySearch = TextEditingController();

  AppController get controller => widget.controller;
  BackupGateway get backupGateway => widget.backupGateway;

  @override
  void dispose() {
    _historySearch.dispose();
    super.dispose();
  }

  Future<void> _language(String value) async {
    try {
      await controller.setLanguage(value);
    } catch (_) {
      if (mounted) showSaveError(context, loc(context));
    }
  }

  void _openTrip(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TripDetailPage(controller: controller, tripId: trip.id),
      ),
    );
  }

  void _newTrip() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PlanPage(controller: controller)),
    );
  }

  Widget _tripRow(Trip trip, L l) {
    final completed = trip.completedAt;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reviewed = trip.stage == TripStage.completed;
    final statusColor = trip.stage == TripStage.draft
        ? scheme.surfaceContainerHighest
        : scheme.primaryContainer;
    final statusTextColor = trip.stage == TripStage.draft
        ? scheme.onSurfaceVariant
        : scheme.onPrimaryContainer;
    final date = completed?.toLocal();
    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        key: Key('trip_${trip.id}'),
        onTap: () => _openTrip(trip),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        l.stage(trip.stage),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 20, color: scheme.outline),
                ],
              ),
              if (trip.destination.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        trip.destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (reviewed && date != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${l('completedOn')} ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _tripAmount(
                      l('planned'),
                      moneyText(trip.plannedMinor, trip.baseCurrency),
                      theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 38, color: scheme.outlineVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tripAmount(
                      l('recorded'),
                      moneyText(trip.spentMinor, trip.baseCurrency),
                      theme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripAmount(String label, String amount, ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          amount,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _currentPage(L l) {
    final current = controller.trips
        .where((trip) => trip.stage != TripStage.completed)
        .toList();
    final focus =
        current.where((trip) => trip.stage == TripStage.active).firstOrNull ??
        current.firstOrNull;
    final others = [
      ...current.where(
        (trip) => trip.stage == TripStage.active && trip.id != focus?.id,
      ),
      ...current.where(
        (trip) => trip.stage == TripStage.draft && trip.id != focus?.id,
      ),
    ];
    return pageWidth(
      CustomScrollView(
        key: const PageStorageKey('current_trips_scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l('currentTrips'),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        key: const Key('new_trip'),
                        onPressed: controller.busy ? null : _newTrip,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l('newTrip')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l('tagline'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (current.isEmpty) ...[
                    const SizedBox(height: 24),
                    Card.filled(
                      margin: EdgeInsets.zero,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.route_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              controller.trips.isEmpty
                                  ? l('noTrips')
                                  : l('noCurrentTrips'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              controller.trips.isEmpty
                                  ? l('noTripsHelp')
                                  : l('noCurrentTripsHelp'),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (focus != null) ...[
                    const SizedBox(height: 24),
                    InkWell(
                      key: const Key('focus_trip'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openTrip(focus),
                      child: TripPaceCard(trip: focus, l: l),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('home_quick_expense'),
                      onPressed: controller.busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ExpensePage(
                                  controller: controller,
                                  tripId: focus.id,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.add),
                      label: Text(l('addExpense')),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (others.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: others.length,
                itemBuilder: (context, index) {
                  final trip = others[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (index == 0 || others[index - 1].stage != trip.stage)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 4),
                          child: Text(
                            trip.stage == TripStage.active
                                ? l('recordingTrips')
                                : l('planningTrips'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      _tripRow(trip, l),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Text(
                l('localOnly'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyPage(L l) {
    final completed =
        controller.trips
            .where((trip) => trip.stage == TripStage.completed)
            .toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.createdAt).compareTo(
              a.completedAt ?? a.createdAt,
            ),
          );
    final query = _historySearch.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? completed
        : completed
              .where(
                (trip) =>
                    trip.title.toLowerCase().contains(query) ||
                    trip.destination.toLowerCase().contains(query),
              )
              .toList();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return pageWidth(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l('historyTrips'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        child: Text(
                          '${completed.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l('historyIntro'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  key: const Key('history_search'),
                  controller: _historySearch,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l('searchTrips'),
                    prefixIcon: Icon(
                      Icons.search,
                      color: scheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.primary, width: 1.5),
                    ),
                    suffixIcon: _historySearch.text.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('history_clear_search'),
                            tooltip: l('clearSearch'),
                            onPressed: () => setState(_historySearch.clear),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            completed.isEmpty
                                ? Icons.history_rounded
                                : Icons.search_off_rounded,
                            size: 36,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            completed.isEmpty
                                ? l('noHistoryTrips')
                                : l('noSearchResults'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const PageStorageKey('history_trips_scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: visible.length,
                    itemBuilder: (context, index) =>
                        _tripRow(visible[index], l),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final l = loc(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(l('app')),
            actions: [
              IconButton(
                key: const Key('backup_open'),
                tooltip: l('backupTitle'),
                onPressed: controller.loading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => BackupPage(
                            controller: controller,
                            gateway: backupGateway,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.folder_outlined),
              ),
              IconButton(
                tooltip: l('language'),
                icon: const Icon(Icons.translate),
                onPressed: () async {
                  const codes = ['auto', 'zh', 'en'];
                  final index = await showIosChoices<String>(
                    context,
                    title: l('language'),
                    cancelLabel: l('cancel'),
                    choices: [
                      for (final code in codes) IosChoice(code, l(code)),
                    ],
                    selected: controller.data.language,
                  );
                  if (index != null && context.mounted) {
                    await _language(codes[index]);
                  }
                },
              ),
              IconButton(
                tooltip: l('privacy'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => PrivacyScreen(l: l)),
                ),
                icon: const Icon(Icons.privacy_tip_outlined),
              ),
            ],
          ),
          body: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : controller.loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l('loadError'), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: controller.load,
                          child: Text(l('retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : _selectedTab == 0
              ? _currentPage(l)
              : _historyPage(l),
          bottomNavigationBar: CupertinoTabBar(
            currentIndex: _selectedTab,
            height: 62,
            iconSize: 24,
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveColor: Theme.of(context).colorScheme.onSurfaceVariant,
            backgroundColor: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            onTap: (index) => setState(() => _selectedTab = index),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(CupertinoIcons.location),
                activeIcon: _selectedTabIcon(CupertinoIcons.location_fill),
                label: l('currentTrips'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(CupertinoIcons.clock),
                activeIcon: _selectedTabIcon(CupertinoIcons.clock_fill),
                label: l('historyTrips'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _selectedTabIcon(IconData icon) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      child: Icon(icon, size: 20),
    ),
  );
}

enum _BackupImportMode { merge, replace }

class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    required this.controller,
    required this.gateway,
  });

  final AppController controller;
  final BackupGateway gateway;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _working = false;
  String? _status;

  Future<void> _export() async {
    final l = loc(context);
    setState(() {
      _working = true;
      _status = null;
    });
    try {
      final bytes = TripBackupCodec.encode(widget.controller.data);
      if (bytes.length > maxBackupBytes) {
        throw const FormatException('Backup is too large');
      }
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
      final saved = await widget.gateway.save('trip-delta-$stamp.json', bytes);
      if (mounted && saved) setState(() => _status = l('backupSaved'));
    } catch (_) {
      if (mounted) setState(() => _status = l('backupExportFailed'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _import() async {
    final l = loc(context);
    setState(() {
      _working = true;
      _status = null;
    });
    try {
      final bytes = await widget.gateway.pick();
      if (bytes == null || !mounted) return;
      final backup = TripBackupCodec.decode(bytes);
      final failedLoad = widget.controller.loadError != null;
      final mode = await showCupertinoDialog<_BackupImportMode>(
        context: context,
        builder: (dialogContext) => iosOverlayTheme(
          context,
          CupertinoAlertDialog(
            title: Text(l('backupImportPreview')),
            content: Text(
              '${l('backupFileTrips')} ${backup.trips.length}\n'
              '${l('backupCurrentTrips')} ${widget.controller.trips.length}\n\n'
              '${failedLoad ? l('backupRecoveryHelp') : l('backupMergeHelp')}',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l('cancel')),
              ),
              if (!failedLoad)
                CupertinoDialogAction(
                  key: const Key('backup_merge'),
                  onPressed: () =>
                      Navigator.pop(dialogContext, _BackupImportMode.merge),
                  child: Text(l('backupMerge')),
                ),
              CupertinoDialogAction(
                key: const Key('backup_replace'),
                isDestructiveAction: true,
                onPressed: () =>
                    Navigator.pop(dialogContext, _BackupImportMode.replace),
                child: Text(l('backupReplace')),
              ),
            ],
          ),
        ),
      );
      if (mode == null || !mounted) return;
      if (mode == _BackupImportMode.replace) {
        final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => iosOverlayTheme(
            context,
            CupertinoAlertDialog(
              title: Text(l('backupReplace')),
              content: Text(l('backupReplaceWarning')),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l('cancel')),
                ),
                CupertinoDialogAction(
                  key: const Key('backup_confirm_replace'),
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l('backupReplace')),
                ),
              ],
            ),
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      final result = await widget.controller.importBackup(
        backup,
        replace: mode == _BackupImportMode.replace,
      );
      if (mounted) {
        setState(
          () => _status =
              '${l('backupImported')} ${result.added} · ${l('backupSkipped')} ${result.skipped}',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _status = l('backupImportFailed'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = loc(context);
    return PopScope(
      canPop: !_working,
      child: Scaffold(
        appBar: AppBar(title: Text(l('backupTitle'))),
        body: pageWidth(
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(l('backupIntro')),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('backup_export'),
                onPressed:
                    _working ||
                        widget.controller.busy ||
                        widget.controller.loadError != null
                    ? null
                    : _export,
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(l('backupExport')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('backup_import'),
                onPressed: _working || widget.controller.busy ? null : _import,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(l('backupImport')),
              ),
              if (widget.controller.loadError != null) ...[
                const SizedBox(height: 12),
                Text(l('backupRecoveryHelp')),
              ],
              if (_status != null) ...[
                const SizedBox(height: 20),
                Text(_status!, key: const Key('backup_status')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PlanPage extends StatefulWidget {
  const PlanPage({
    super.key,
    required this.controller,
    this.existing,
    this.template,
  }) : assert(existing == null || template == null);
  final AppController controller;
  final Trip? existing;
  final Trip? template;

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _destination;
  late final Map<BudgetCategory, TextEditingController> _budgets;
  late String _currency;
  late String _localCurrency;
  late DateTimeRange _dates;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.existing ?? widget.template;
    _currency = initial?.baseCurrency ?? 'CNY';
    _localCurrency = initial?.entryCurrency ?? _currency;
    final today = DateUtils.dateOnly(DateTime.now());
    _dates = DateTimeRange(
      start: initial?.startDate ?? today,
      end: initial?.endDate ?? today.add(const Duration(days: 4)),
    );
    _name = TextEditingController(text: initial?.title ?? '');
    _destination = TextEditingController(text: initial?.destination ?? '');
    _budgets = {
      for (final category in BudgetCategory.values)
        category: TextEditingController(
          text: initial == null
              ? ''
              : amountInput(initial.plannedFor(category), _currency),
        ),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _destination.dispose();
    for (final controller in _budgets.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l = loc(context);
    final budgets = {
      for (final item in BudgetCategory.values)
        item: parseMinor(
          _budgets[item]!.text.trim().isEmpty ? '0' : _budgets[item]!.text,
          _currency,
        )!,
    };
    if (budgets.values.every((value) => value == 0)) {
      showIosNotice(context, l('positiveBudget'));
      return;
    }
    final now = DateTime.now().toUtc();
    final trip = widget.existing == null
        ? Trip(
            id: newId(),
            title: _name.text.trim(),
            destination: _destination.text.trim(),
            baseCurrency: _currency,
            localCurrency: _localCurrency,
            startDate: _dates.start,
            endDate: _dates.end,
            budgets: budgets,
            stage: TripStage.draft,
            createdAt: now,
            expenses: const [],
          )
        : widget.existing!.copyWith(
            title: _name.text.trim(),
            destination: _destination.text.trim(),
            localCurrency: _localCurrency,
            startDate: _dates.start,
            endDate: _dates.end,
            budgets: budgets,
          );
    setState(() => _saving = true);
    try {
      await widget.controller.upsertTrip(trip);
      if (mounted) {
        setState(() => _saving = false);
        if (widget.existing == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TripDetailPage(
                controller: widget.controller,
                tripId: trip.id,
              ),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) showSaveError(context, l);
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = loc(context);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? l('planTitle') : l('editPlan')),
          leading: IconButton(
            key: const Key('form_back'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _saving ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: pageWidth(
          Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                TextFormField(
                  key: const Key('trip_name'),
                  controller: _name,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l('tripName'),
                    hintText: l('tripHint'),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l('requiredName')
                      : null,
                ),
                TextFormField(
                  key: const Key('trip_destination'),
                  controller: _destination,
                  maxLength: 80,
                  decoration: InputDecoration(labelText: l('destination')),
                ),
                OutlinedButton.icon(
                  key: const Key('trip_dates'),
                  onPressed: () async {
                    final selected = await showIosDateRangePicker(
                      context: context,
                      title: l('travelDates'),
                      cancelLabel: l('cancel'),
                      doneLabel: l('done'),
                      startLabel: l('dateStart'),
                      endLabel: l('dateEnd'),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialRange: _dates,
                    );
                    if (selected != null && mounted) {
                      setState(() => _dates = selected);
                    }
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    '${l('travelDates')}: ${_dates.start.year}-${_dates.start.month}-${_dates.start.day} — ${_dates.end.year}-${_dates.end.month}-${_dates.end.day}',
                  ),
                ),
                const SizedBox(height: 16),
                IosChoiceField<String>(
                  key: const Key('base_currency'),
                  label: l('baseCurrency'),
                  value: _currency,
                  cancelLabel: l('cancel'),
                  choices: [
                    for (final currency in supportedCurrencies)
                      IosChoice(currency, currency),
                  ],
                  onSelected: widget.existing == null
                      ? (value) {
                          setState(() {
                            _currency = value;
                            _localCurrency = value;
                            for (final field in _budgets.values) {
                              field.clear();
                            }
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                IosChoiceField<String>(
                  key: ValueKey('local_currency_$_currency'),
                  label: l('localCurrency'),
                  value: _localCurrency,
                  cancelLabel: l('cancel'),
                  choices: [
                    for (final currency in supportedCurrencies)
                      IosChoice(currency, currency),
                  ],
                  onSelected: (value) => setState(() => _localCurrency = value),
                ),
                const SizedBox(height: 16),
                Text(
                  l('budgetByCat'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(l('budgetHelp')),
                const SizedBox(height: 12),
                for (final category in BudgetCategory.values) ...[
                  TextFormField(
                    key: Key('budget_${category.name}'),
                    controller: _budgets[category],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l.category(category),
                      prefixText: '$_currency ',
                    ),
                    validator: (value) =>
                        parseMinor(
                              value == null || value.trim().isEmpty
                                  ? '0'
                                  : value,
                              _currency,
                            ) ==
                            null
                        ? l('invalidMoney')
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('save_plan'),
                  onPressed: _saving ? null : _save,
                  child: Text(l('savePlan')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TripDetailPage extends StatelessWidget {
  const TripDetailPage({
    super.key,
    required this.controller,
    required this.tripId,
  });
  final AppController controller;
  final String tripId;

  Future<void> _deleteTrip(BuildContext context, Trip trip, L l) async {
    if (!await confirmDelete(context, l('deleteTripQuestion'), l)) return;
    try {
      await controller.deleteTrip(trip.id);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) showSaveError(context, l);
    }
  }

  Future<void> _setStage(
    BuildContext context,
    Trip trip,
    TripStage stage,
    L l,
  ) async {
    try {
      await controller.upsertTrip(
        trip.copyWith(
          stage: stage,
          startedAt: stage == TripStage.active && trip.startedAt == null
              ? DateTime.now().toUtc()
              : trip.startedAt,
        ),
      );
    } catch (_) {
      if (context.mounted) showSaveError(context, l);
    }
  }

  Future<void> _repeatPlan(BuildContext context, Trip trip, L l) async {
    final maxCategoryMinor =
        1000000 * (currencyDigits(trip.baseCurrency) == 0 ? 1 : 100);
    final actualFits = BudgetCategory.values.every(
      (item) => trip.spentFor(item) <= maxCategoryMinor,
    );
    final useActual = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => iosOverlayTheme(
        context,
        CupertinoAlertDialog(
          title: Text(l('repeatPlan')),
          content: Text(
            '${l('reuseBudgetHelp')}\n\n'
            '${l('planned')} ${moneyText(trip.plannedMinor, trip.baseCurrency)}\n'
            '${l('spent')} ${moneyText(trip.spentMinor, trip.baseCurrency)}'
            '${trip.estimatedCount > 0 ? '\n\n${l('reuseNeedsSettlement')}' : ''}'
            '${!actualFits ? '\n\n${l('reuseTooLarge')}' : ''}',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l('cancel')),
            ),
            CupertinoDialogAction(
              key: const Key('reuse_original'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l('reuseOriginal')),
            ),
            CupertinoDialogAction(
              key: const Key('reuse_actual'),
              isDefaultAction: true,
              onPressed: trip.estimatedCount > 0 || !actualFits
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(l('reuseActual')),
            ),
          ],
        ),
      ),
    );
    if (useActual == null || !context.mounted) return;
    final now = DateTime.now();
    final start = DateUtils.dateOnly(now);
    final duration = trip.startDate == null || trip.endDate == null
        ? 4
        : DateTime.utc(
                trip.endDate!.year,
                trip.endDate!.month,
                trip.endDate!.day,
              )
              .difference(
                DateTime.utc(
                  trip.startDate!.year,
                  trip.startDate!.month,
                  trip.startDate!.day,
                ),
              )
              .inDays;
    final draft = Trip(
      id: newId(),
      title: trip.title,
      destination: trip.destination,
      baseCurrency: trip.baseCurrency,
      localCurrency: trip.entryCurrency,
      startDate: start,
      endDate: start.add(Duration(days: duration)),
      budgets: useActual
          ? {
              for (final item in BudgetCategory.values)
                item: trip.spentFor(item),
            }
          : Map.of(trip.budgets),
      stage: TripStage.draft,
      createdAt: now.toUtc(),
      expenses: const [],
    );
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlanPage(controller: controller, template: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final trip = controller.tripById(tripId);
        final l = loc(context);
        if (trip == null) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(title: Text(trip.title)),
          body: pageWidth(
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                Text(
                  trip.destination.isEmpty
                      ? l.stage(trip.stage)
                      : '${trip.destination} · ${l.stage(trip.stage)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                TripPaceCard(
                  trip: trip,
                  l: l,
                  showIdentity: false,
                  showBreakdownFooter: false,
                ),
                const SizedBox(height: 16),
                if (trip.stage == TripStage.draft ||
                    trip.expenses.isEmpty &&
                        trip.stage == TripStage.active) ...[
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PlanPage(
                                controller: controller,
                                existing: trip,
                              ),
                            ),
                          ),
                    child: Text(l('editPlan')),
                  ),
                  const SizedBox(height: 12),
                ],
                if (trip.stage != TripStage.completed) ...[
                  if (trip.expenses.isNotEmpty) ...[
                    Text(
                      l('lockedHelp'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    key: const Key('add_expense'),
                    onPressed: controller.busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ExpensePage(
                                controller: controller,
                                tripId: trip.id,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.add),
                    label: Text(l('addExpense')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('finish_trip'),
                    onPressed: controller.busy || !trip.canComplete
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ReviewPage(
                                controller: controller,
                                tripId: trip.id,
                              ),
                            ),
                          ),
                    child: Text(l('finish')),
                  ),
                  if (trip.expenses.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(l('noExpenses')),
                  ],
                  if (trip.estimatedCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(l('settleBeforeReview')),
                    for (final expense in recentTripExpenses(
                      trip,
                    ).where((item) => item.isEstimate).take(1))
                      TextButton.icon(
                        key: Key('settle_${expense.id}'),
                        onPressed: controller.busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => ExpensePage(
                                    controller: controller,
                                    tripId: trip.id,
                                    existing: expense,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text(
                          expense.title.isEmpty
                              ? l.category(expense.category)
                              : expense.title,
                        ),
                      ),
                    if (trip.estimatedCount > 1)
                      TextButton.icon(
                        key: const Key('view_pending_expenses'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ExpenseListPage(
                              controller: controller,
                              tripId: trip.id,
                              estimatesOnly: true,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.list_alt_outlined),
                        label: Text(l('viewPendingExpenses')),
                      ),
                  ],
                ],
                if (trip.stage == TripStage.completed) ...[
                  if (reviewBandFor(trip) != null) ...[
                    ReviewVerdictCard(trip: trip, l: l),
                    const SizedBox(height: 20),
                  ],
                  if (trip.reflection.trim().isNotEmpty) ...[
                    Text(
                      l('reflection'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(trip.reflection),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    key: const Key('open_review_card'),
                    onPressed: () => showReviewCard(context, trip, l),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(l('reviewCard')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('repeat_plan'),
                    onPressed: controller.busy
                        ? null
                        : () => _repeatPlan(context, trip, l),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: Text(l('repeatPlan')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => _setStage(context, trip, TripStage.active, l),
                    child: Text(l('reopen')),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('open_budget_breakdown'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => BudgetBreakdownPage(
                        controller: controller,
                        tripId: trip.id,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.bar_chart_outlined),
                  label: Text(l('viewBudgetBreakdown')),
                ),
                if (trip.expenses.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    l('recentExpenses'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final expense in recentTripExpenses(trip).take(3)) ...[
                    ExpenseRecordTile(
                      key: Key('expense_${expense.id}'),
                      expense: expense,
                      trip: trip,
                      controller: controller,
                      compact: true,
                    ),
                    const Divider(height: 1),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('open_expenses'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ExpenseListPage(
                          controller: controller,
                          tripId: trip.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(
                      '${l('viewAllExpenses')} (${trip.expenses.length})',
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                TextButton(
                  onPressed: controller.busy
                      ? null
                      : () => _deleteTrip(context, trip, l),
                  child: Text(l('deleteTrip')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<Expense> recentTripExpenses(Trip trip) {
  final indexed = trip.expenses.reversed.toList().asMap().entries.toList()
    ..sort((a, b) {
      final byDate = b.value.recordedAt.compareTo(a.value.recordedAt);
      return byDate == 0 ? a.key.compareTo(b.key) : byDate;
    });
  return indexed.map((entry) => entry.value).toList();
}

String expenseDay(Expense expense) =>
    '${expense.recordedAt.year}-${expense.recordedAt.month.toString().padLeft(2, '0')}-${expense.recordedAt.day.toString().padLeft(2, '0')}';

class BudgetBreakdownPage extends StatelessWidget {
  const BudgetBreakdownPage({
    super.key,
    required this.controller,
    required this.tripId,
  });
  final AppController controller;
  final String tripId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final trip = controller.tripById(tripId);
      final l = loc(context);
      return Scaffold(
        appBar: AppBar(title: Text(l('viewBudgetBreakdown'))),
        body: trip == null
            ? const SizedBox.shrink()
            : pageWidth(
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                  children: [ComparisonSection(trip: trip, l: l)],
                ),
              ),
      );
    },
  );
}

class ExpenseListPage extends StatelessWidget {
  const ExpenseListPage({
    super.key,
    required this.controller,
    required this.tripId,
    this.estimatesOnly = false,
  });
  final AppController controller;
  final String tripId;
  final bool estimatesOnly;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final trip = controller.tripById(tripId);
      final l = loc(context);
      return Scaffold(
        appBar: AppBar(title: Text(l('expenseList'))),
        body: trip == null
            ? const SizedBox.shrink()
            : pageWidth(
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: ExpenseLedger(
                    trip: trip,
                    controller: controller,
                    estimatesOnly: estimatesOnly,
                  ),
                ),
              ),
      );
    },
  );
}

class ExpenseRecordTile extends StatelessWidget {
  const ExpenseRecordTile({
    super.key,
    required this.expense,
    required this.trip,
    required this.controller,
    this.compact = false,
  });
  final Expense expense;
  final Trip trip;
  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = loc(context);
    final theme = Theme.of(context);
    final title = expense.title.isEmpty
        ? l.category(expense.category)
        : expense.title;
    return InkWell(
      onTap: trip.stage == TripStage.completed
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ExpensePage(
                  controller: controller,
                  tripId: trip.id,
                  existing: expense,
                ),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        moneyText(expense.effectiveMinor, trip.baseCurrency),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l.category(expense.category)} · ${expenseDay(expense)} · ${expense.isEstimate ? l('estimate') : l('confirmed')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${moneyText(expense.effectiveMinor, trip.baseCurrency)} · ${expense.isEstimate ? l('estimate') : l('confirmed')}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l.category(expense.category)} · ${moneyText(expense.amountMinor, expense.currency)}${expense.currency == trip.baseCurrency ? '' : ' · 1 ${expense.currency} = ${expense.rate} ${trip.baseCurrency}'}',
                  ),
                  Text(expenseDay(expense)),
                  if (expense.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(expense.note),
                  ],
                ],
              ),
      ),
    );
  }
}

class ExpenseLedger extends StatefulWidget {
  const ExpenseLedger({
    super.key,
    required this.trip,
    required this.controller,
    this.estimatesOnly = false,
  });
  final Trip trip;
  final AppController controller;
  final bool estimatesOnly;

  @override
  State<ExpenseLedger> createState() => _ExpenseLedgerState();
}

class _ExpenseLedgerState extends State<ExpenseLedger> {
  BudgetCategory? _category;
  DateTimeRange? _range;
  late bool _estimatesOnly = widget.estimatesOnly;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final l = loc(context);
    final filtered = filterTripExpenses(
      trip,
      category: _category,
      startDate: _range?.start,
      endDate: _range?.end,
    );
    final matchingIds = filtered.map((expense) => expense.id).toSet();
    final visible = recentTripExpenses(trip)
        .where((expense) => matchingIds.contains(expense.id))
        .where((expense) => !_estimatesOnly || expense.isEstimate)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${l('entryCount')}: ${visible.length} / ${trip.expenses.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (trip.expenses.isNotEmpty) ...[
          IosChoiceField<BudgetCategory?>(
            key: ValueKey('ledger_category_${_category?.name ?? 'all'}'),
            label: l('filterCategory'),
            value: _category,
            cancelLabel: l('cancel'),
            choices: [
              IosChoice<BudgetCategory?>(null, l('allCategories')),
              for (final item in BudgetCategory.values)
                IosChoice<BudgetCategory?>(item, l.category(item)),
            ],
            onSelected: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('ledger_dates'),
            onPressed: () async {
              final selected = await showIosDateRangePicker(
                context: context,
                title: l('filterDates'),
                cancelLabel: l('cancel'),
                doneLabel: l('done'),
                startLabel: l('dateStart'),
                endLabel: l('dateEnd'),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialRange: _range,
              );
              if (selected != null && mounted) {
                setState(() => _range = selected);
              }
            },
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              _range == null
                  ? l('filterDates')
                  : '${_range!.start.year}-${_range!.start.month}-${_range!.start.day} — ${_range!.end.year}-${_range!.end.month}-${_range!.end.day}',
            ),
          ),
          if (trip.estimatedCount > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                key: const Key('ledger_estimates_only'),
                label: Text(l('estimatesOnly')),
                selected: _estimatesOnly,
                onSelected: (selected) =>
                    setState(() => _estimatesOnly = selected),
              ),
            ),
          if (_category != null || _range != null || _estimatesOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('ledger_clear'),
                onPressed: () => setState(() {
                  _category = null;
                  _range = null;
                  _estimatesOnly = false;
                }),
                child: Text(l('clearFilters')),
              ),
            ),
        ],
        const Divider(),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    trip.expenses.isEmpty
                        ? l('noExpenses')
                        : l('noMatchingExpenses'),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  key: const PageStorageKey('expense_ledger_scroll'),
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => ExpenseRecordTile(
                    key: Key('expense_${visible[index].id}'),
                    expense: visible[index],
                    trip: trip,
                    controller: widget.controller,
                  ),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                ),
        ),
      ],
    );
  }
}

BudgetCategory? largestOverCategory(Trip trip) {
  BudgetCategory? largest;
  for (final item in BudgetCategory.values) {
    if (trip.deltaFor(item) > 0 &&
        (largest == null || trip.deltaFor(item) > trip.deltaFor(largest))) {
      largest = item;
    }
  }
  return largest;
}

List<Expense> mainExpenses(Trip trip) {
  final largest = largestOverCategory(trip);
  final items = trip.expenses
      .where((item) => largest == null || item.category == largest)
      .toList();
  items.sort((a, b) => b.effectiveMinor.compareTo(a.effectiveMinor));
  return items.take(3).toList();
}

class ComparisonSection extends StatelessWidget {
  const ComparisonSection({super.key, required this.trip, required this.l});
  final Trip trip;
  final L l;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largest = largestOverCategory(trip);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trip.expenses.isEmpty ? l('budgetByCat') : l('difference'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (trip.expenses.isEmpty)
          Text('${l('incompleteSummary')} · ${l('noExpenses')}')
        else
          Text(
            trip.deltaMinor > 0
                ? '${l('over')}  ${moneyText(trip.deltaMinor, trip.baseCurrency)}'
                : '${l('remaining')}  ${moneyText(-trip.deltaMinor, trip.baseCurrency)}',
            style: theme.textTheme.titleMedium,
          ),
        const SizedBox(height: 8),
        Text('${l('entryCount')}: ${trip.expenses.length}'),
        if (trip.estimatedCount > 0)
          Text('${l('includesEstimates')} ${trip.estimatedCount}'),
        if (trip.expenses.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            largest == null
                ? l('noOverage')
                : '${l('largestDriver')}: ${l.category(largest)}',
          ),
        ],
        if (trip.expenses.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(l('mainExpenses'), style: theme.textTheme.titleMedium),
          for (final expense in mainExpenses(trip))
            Text(
              '${expense.title.isEmpty ? l.category(expense.category) : expense.title} · ${moneyText(expense.effectiveMinor, trip.baseCurrency)} · ${expense.isEstimate ? l('estimate') : l('confirmed')}',
            ),
        ],
        const SizedBox(height: 14),
        for (final item in BudgetCategory.values) ...[
          const Divider(height: 20),
          Text(l.category(item), style: theme.textTheme.titleMedium),
          const SizedBox(height: 5),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                '${l('planned')}  ${moneyText(trip.plannedFor(item), trip.baseCurrency)}',
              ),
              Text(
                '${l('spent')}  ${moneyText(trip.spentFor(item), trip.baseCurrency)}',
              ),
              if (trip.expenses.isNotEmpty)
                Text(
                  '${trip.deltaFor(item) > 0 ? l('over') : l('remaining')}  ${moneyText(trip.deltaFor(item).abs(), trip.baseCurrency)}',
                  style: TextStyle(
                    color: trip.deltaFor(item) > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class ReviewVerdictCard extends StatelessWidget {
  const ReviewVerdictCard({super.key, required this.trip, required this.l});
  final Trip trip;
  final L l;

  @override
  Widget build(BuildContext context) {
    final band = reviewBandFor(trip);
    if (band == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card.filled(
      key: const Key('review_verdict'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l('reviewAssessment'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l('review_${band.name}_title'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l('review_${band.name}_body')),
            const SizedBox(height: 12),
            Text(l('reviewBasis'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class ExpensePage extends StatefulWidget {
  const ExpensePage({
    super.key,
    required this.controller,
    required this.tripId,
    this.existing,
  });
  final AppController controller;
  final String tripId;
  final Expense? existing;

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _rate;
  late final TextEditingController _note;
  late final TextEditingController _settled;
  late String _currency;
  late BudgetCategory _category;
  late DateTime _expenseDate;
  DateTime? _rateObservedAt;
  bool _detailsExpanded = false;
  bool _saving = false;

  Expense? _lastRate(Trip trip, String currency) {
    for (final expense in trip.expenses.reversed) {
      if (expense.id != widget.existing?.id &&
          expense.currency == currency &&
          expense.currency != trip.baseCurrency) {
        return expense;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final trip = widget.controller.tripById(widget.tripId)!;
    final old = widget.existing;
    _currency = old?.currency ?? trip.entryCurrency;
    _category =
        old?.category ??
        (trip.expenses.isEmpty
            ? BudgetCategory.food
            : trip.expenses.last.category);
    _expenseDate = old?.recordedAt.toLocal() ?? DateTime.now();
    _rateObservedAt = old?.rateObservedAt ?? old?.recordedAt;
    _title = TextEditingController(text: old?.title ?? '');
    _amount = TextEditingController(
      text: old == null ? '' : amountInput(old.amountMinor, old.currency),
    );
    final previousRate = _lastRate(trip, _currency);
    _rate = TextEditingController(
      text:
          old?.rate.toString() ??
          previousRate?.rate.toString() ??
          (_currency == trip.baseCurrency ? '1' : ''),
    );
    _rateObservedAt ??=
        previousRate?.rateObservedAt ?? previousRate?.recordedAt;
    _note = TextEditingController(text: old?.note ?? '');
    _settled = TextEditingController(
      text: old?.settledMinor == null || old?.currency == trip.baseCurrency
          ? ''
          : amountInput(old!.settledMinor!, trip.baseCurrency),
    );
    _detailsExpanded =
        old != null &&
        (old.isEstimate ||
            old.title.isNotEmpty ||
            old.note.isNotEmpty ||
            old.settledMinor != null);
    _amount.addListener(_refresh);
    _rate.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amount.removeListener(_refresh);
    _rate.removeListener(_refresh);
    _title.dispose();
    _amount.dispose();
    _rate.dispose();
    _note.dispose();
    _settled.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final trip = widget.controller.tripById(widget.tripId)!;
    final l = loc(context);
    final amount = parseMinor(_amount.text, _currency)!;
    final rate = _currency == trip.baseCurrency ? 1.0 : parseRate(_rate.text)!;
    final booked = convertMinor(
      sourceMinor: amount,
      sourceCurrency: _currency,
      baseCurrency: trip.baseCurrency,
      rate: rate,
    );
    if (amount <= 0 || booked <= 0) {
      showIosNotice(context, l('invalidMoney'));
      return;
    }
    final posted = _settled.text.trim().isEmpty
        ? null
        : parseMinor(_settled.text, trip.baseCurrency);
    if (_settled.text.trim().isNotEmpty && (posted == null || posted <= 0)) {
      showIosNotice(context, l('invalidMoney'));
      return;
    }
    final expense = Expense(
      id: widget.existing?.id ?? newId(),
      title: _title.text.trim(),
      category: _category,
      amountMinor: amount,
      currency: _currency,
      rate: rate,
      bookedMinor: booked,
      recordedAt: DateTime.utc(
        _expenseDate.year,
        _expenseDate.month,
        _expenseDate.day,
      ),
      note: _note.text.trim(),
      settledMinor: _currency == trip.baseCurrency ? amount : posted,
      rateObservedAt: _currency == trip.baseCurrency
          ? null
          : (_rateObservedAt ?? DateTime.now().toUtc()),
    );
    final items = [...trip.expenses];
    final index = items.indexWhere((item) => item.id == expense.id);
    if (index < 0) {
      items.add(expense);
    } else {
      items[index] = expense;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.upsertTrip(
        trip.copyWith(
          expenses: items,
          stage: trip.stage == TripStage.draft ? TripStage.active : trip.stage,
          startedAt: trip.stage == TripStage.draft
              ? DateTime.now().toUtc()
              : trip.startedAt,
        ),
      );
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showSaveError(context, l);
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Trip trip, L l) async {
    if (!await confirmDelete(context, l('deleteExpenseQuestion'), l)) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final remaining = trip.expenses
          .where((item) => item.id != widget.existing!.id)
          .toList();
      await widget.controller.upsertTrip(
        trip.copyWith(
          expenses: remaining,
          stage: remaining.isEmpty ? TripStage.draft : trip.stage,
          clearStartedAt: remaining.isEmpty,
        ),
      );
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showSaveError(context, l);
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.controller.tripById(widget.tripId)!;
    final l = loc(context);
    final amount = parseMinor(_amount.text, _currency);
    final rate = _currency == trip.baseCurrency ? 1.0 : parseRate(_rate.text);
    final booked = amount == null || rate == null
        ? null
        : convertMinor(
            sourceMinor: amount,
            sourceCurrency: _currency,
            baseCurrency: trip.baseCurrency,
            rate: rate,
          );
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null ? l('addExpense') : l('editExpense'),
          ),
          leading: IconButton(
            key: const Key('form_back'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _saving ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        bottomNavigationBar: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: FilledButton(
                    key: const Key('save_expense'),
                    onPressed: _saving ? null : _save,
                    child: Text(l('saveExpense')),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: pageWidth(
          Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                Text(
                  trip.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (trip.destination.isNotEmpty) Text(trip.destination),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('expense_amount'),
                  controller: _amount,
                  autofocus: widget.existing == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l('amount'),
                    prefixText: '$_currency ',
                  ),
                  validator: (value) {
                    final parsed = parseMinor(value ?? '', _currency);
                    return parsed == null || parsed <= 0
                        ? l('invalidMoney')
                        : null;
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  l('category'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final item in BudgetCategory.values)
                      ChoiceChip(
                        key: Key('category_${item.name}'),
                        label: Text(l.category(item)),
                        selected: _category == item,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = item),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                IosChoiceField<String>(
                  key: const Key('expense_currency'),
                  label: l('currency'),
                  value: _currency,
                  cancelLabel: l('cancel'),
                  choices: [
                    for (final currency in supportedCurrencies)
                      IosChoice(currency, currency),
                  ],
                  onSelected: (value) {
                    final previous = _lastRate(trip, value);
                    setState(() {
                      _currency = value;
                      _rate.text = value == trip.baseCurrency
                          ? '1'
                          : (previous?.rate.toString() ?? '');
                      _rateObservedAt =
                          previous?.rateObservedAt ?? previous?.recordedAt;
                      _settled.clear();
                    });
                  },
                ),
                if (_currency != trip.baseCurrency) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('expense_rate'),
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l('rate'),
                      helperText: l('rateHint'),
                      helperMaxLines: 2,
                    ),
                    validator: (value) => parseRate(value ?? '') == null
                        ? l('invalidRate')
                        : null,
                    onChanged: (_) => _rateObservedAt = null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _rateObservedAt == null
                        ? l('rateExplain')
                        : '${l('reusedRate')} ${_rateObservedAt!.year}-${_rateObservedAt!.month.toString().padLeft(2, '0')}-${_rateObservedAt!.day.toString().padLeft(2, '0')} · ${l('rateExplain')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                if (booked != null)
                  Text(
                    '${_currency == trip.baseCurrency ? l('confirmed') : l('estimate')}: ${moneyText(booked, trip.baseCurrency)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                TextButton.icon(
                  key: const Key('expense_details_toggle'),
                  onPressed: () =>
                      setState(() => _detailsExpanded = !_detailsExpanded),
                  icon: Icon(
                    _detailsExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text(l('moreDetails')),
                ),
                if (_detailsExpanded) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('expense_title'),
                    controller: _title,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: l('expenseTitle'),
                      hintText: l('expenseHint'),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('expense_date'),
                    onPressed: () async {
                      final selected = await showIosDatePicker(
                        context: context,
                        title: l('expenseDate'),
                        cancelLabel: l('cancel'),
                        doneLabel: l('done'),
                        initialDate: _expenseDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null && mounted) {
                        setState(() => _expenseDate = selected);
                      }
                    },
                    icon: const Icon(Icons.today_outlined),
                    label: Text(
                      '${l('expenseDate')}: ${_expenseDate.year}-${_expenseDate.month}-${_expenseDate.day}',
                    ),
                  ),
                  if (_currency != trip.baseCurrency) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('expense_settled'),
                      controller: _settled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l('postedAmount'),
                        prefixText: '${trip.baseCurrency} ',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final parsed = parseMinor(value, trip.baseCurrency);
                        return parsed == null || parsed <= 0
                            ? l('invalidMoney')
                            : null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l('postedHelp'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (booked != null && booked > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('confirm_estimate'),
                          onPressed: () => setState(
                            () => _settled.text = amountInput(
                              booked,
                              trip.baseCurrency,
                            ),
                          ),
                          child: Text(l('confirmEstimate')),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('expense_note'),
                    controller: _note,
                    maxLength: 240,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l('note'),
                      counterText: '',
                    ),
                  ),
                ],
                if (widget.existing != null) ...[
                  const SizedBox(height: 20),
                  TextButton(
                    key: const Key('delete_expense'),
                    onPressed: _saving ? null : () => _delete(trip, l),
                    child: Text(l('deleteExpense')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.controller, required this.tripId});
  final AppController controller;
  final String tripId;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final TextEditingController _reflection;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reflection = TextEditingController(
      text: widget.controller.tripById(widget.tripId)?.reflection ?? '',
    );
  }

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _complete(Trip trip, L l) async {
    if (!trip.canComplete) return;
    setState(() => _saving = true);
    try {
      await widget.controller.upsertTrip(
        trip.copyWith(
          stage: TripStage.completed,
          completedAt: DateTime.now().toUtc(),
          reflection: _reflection.text.trim(),
        ),
      );
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showSaveError(context, l);
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.controller.tripById(widget.tripId)!;
    final l = loc(context);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l('reviewTitle')),
          leading: IconButton(
            key: const Key('form_back'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _saving ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: pageWidth(
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              Text(
                trip.expenses.isEmpty
                    ? l('incompleteSummary')
                    : trip.deltaMinor > 0
                    ? '${l('over')} ${moneyText(trip.deltaMinor, trip.baseCurrency)}'
                    : '${l('remaining')} ${moneyText(-trip.deltaMinor, trip.baseCurrency)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (reviewBandFor(trip) != null) ...[
                const SizedBox(height: 16),
                ReviewVerdictCard(trip: trip, l: l),
              ],
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('reflection'),
                controller: _reflection,
                maxLength: 500,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l('reflection'),
                  hintText: l('reflectionHint'),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save_review'),
                onPressed: _saving ? null : () => _complete(trip, l),
                child: Text(l('complete')),
              ),
              const SizedBox(height: 24),
              ComparisonSection(trip: trip, l: l),
            ],
          ),
        ),
      ),
    );
  }
}
