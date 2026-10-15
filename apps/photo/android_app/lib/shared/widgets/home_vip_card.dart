import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import 'base_card.dart';
import 'card_factory.dart';

/// VIP 卡片 `vip_1` / `vip_2` / `vip_3`
///
/// 行为对齐 iOS `Vip1CardView` / `Vip2CardView` / `Vip3CardView`：
/// - 卡片点击打开 `/action/popviewvipinfo`
/// - 「去升级」打开 `/web`，link 为 `vip_center_url`
/// - `pending_change_level_direction == DOWN` 时隐藏下一等级，进度按接口值展示
class HomeVipCard extends BaseCard {
  final CardNavigateCallback? onNavigate;
  final Map<String, dynamic>? dataCache;

  const HomeVipCard({
    super.key,
    required super.cardData,
    this.onNavigate,
    this.dataCache,
  });

  String _cacheKey() => '${cardData.cardStyle}_${cardData.cardId}';

  Map<String, dynamic> _vipPayload(WidgetRef ref) {
    final cached = dataCache?[_cacheKey()];
    if (cached is Map<String, dynamic> && cached.isNotEmpty) {
      return cached;
    }
    if (cached is Map && cached.isNotEmpty) {
      return Map<String, dynamic>.from(cached);
    }
    final detail = cardData.cardDetail;
    if (detail != null &&
        (detail.containsKey('current_level') ||
            detail.containsKey('progress'))) {
      return Map<String, dynamic>.from(detail);
    }
    return ref.watch(userStateProvider.select((s) => s.vipLevelPayload));
  }

  @override
  Widget build(BuildContext context) {
    if (!cardData.isShow) return const SizedBox.shrink();

    return Consumer(
      builder: (context, ref, _) {
        final isB = ref.watch(userStateProvider.select((s) => s.isB));
        if (isB) return const SizedBox.shrink();
        return super.build(context);
      },
    );
  }

  @override
  Widget buildCardContent(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(userStateProvider);
        final vipPayload = _vipPayload(ref);

        return _VipLocalizedScope(
          cardName: cardData.cardStyle,
          builder: (context, strings) {
            final vip = _VipCardData.fromPayload(vipPayload, user, strings);
            if (vip.isEmpty) return const SizedBox.shrink();

            void openLevelInfo() {
              onNavigate?.call('/action/popviewvipinfo', {
                'requirement': vip.upgradeRequirement,
                'progress': vip.progress,
              }, action: 'VIP升级条件');
            }

            void openUpgrade() {
              onNavigate?.call('/web', {
                'link': vip.vipCenterUrl,
              }, action: 'VIP会员中心');
            }

            switch (cardData.cardStyle) {
              case 'vip_1':
                return _Vip1Card(
                  data: vip,
                  upgradeText: strings.goUpgrade,
                  onCardTap: openLevelInfo,
                  onUpgrade: openUpgrade,
                );
              case 'vip_2':
                return _Vip2Card(
                  data: vip,
                  upgradeText: strings.goUpgrade,
                  onCardTap: openLevelInfo,
                  onUpgrade: openUpgrade,
                );
              case 'vip_3':
                return _Vip3Card(
                  data: vip,
                  upgradeText: strings.goUpgrade,
                  onCardTap: openLevelInfo,
                  onUpgrade: openUpgrade,
                );
              default:
                return _Vip3Card(
                  data: vip,
                  upgradeText: strings.goUpgrade,
                  onCardTap: openLevelInfo,
                  onUpgrade: openUpgrade,
                );
            }
          },
        );
      },
    );
  }
}

typedef _VipLocalizedBuilder =
    Widget Function(BuildContext context, _VipLocalizedStrings strings);

class _VipLocalizedScope extends ConsumerStatefulWidget {
  final String cardName;
  final _VipLocalizedBuilder builder;

  const _VipLocalizedScope({required this.cardName, required this.builder});

  @override
  ConsumerState<_VipLocalizedScope> createState() => _VipLocalizedScopeState();
}

class _VipLocalizedScopeState extends ConsumerState<_VipLocalizedScope> {
  static const Map<String, String> _globalFallbacks = {
    'to_enioy_more': '完成升级任务，尊享',
    'privilege': '特权',
    'looking_forward_to_higher': '完成保级任务，继续尊享',
    'ex_privileges': '专属特权。',
  };

  String? _loadKey;
  int _loadToken = 0;
  String _goUpgrade = '去升级';
  Map<String, String> _global = _globalFallbacks;

  @override
  Widget build(BuildContext context) {
    final localizations = ref.watch(stLocalizationsProvider);
    _ensureLocalized(localizations);
    return widget.builder(
      context,
      _VipLocalizedStrings(goUpgrade: _goUpgrade, global: _global),
    );
  }

  void _ensureLocalized(STLocalizations localizations) {
    final cardName = _normalizedCardName(widget.cardName);
    final loadKey = '$cardName:${localizations.languageCode}';
    if (_loadKey == loadKey) return;
    _loadKey = loadKey;
    _goUpgrade = _fallbackGoUpgrade(cardName);
    _global = _globalFallbacks;

    final token = ++_loadToken;
    Future.wait([
      localizations.cardText(
        cardName,
        'go_upgrade',
        fallback: _fallbackGoUpgrade(cardName),
      ),
      ..._globalFallbacks.entries.map(
        (entry) => localizations.text(entry.key, fallback: entry.value),
      ),
    ]).then((values) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _goUpgrade = values.first;
        _global = {
          for (var i = 0; i < _globalFallbacks.length; i++)
            _globalFallbacks.keys.elementAt(i): values[i + 1],
        };
      });
    });
  }

  static String _normalizedCardName(String cardName) {
    final normalized = cardName.trim();
    return normalized.startsWith('vip_') ? normalized : 'vip_3';
  }

  static String _fallbackGoUpgrade(String cardName) {
    return cardName == 'vip_2' ? '去升级>' : '去升级';
  }
}

class _VipLocalizedStrings {
  final String goUpgrade;
  final Map<String, String> global;

  const _VipLocalizedStrings({required this.goUpgrade, required this.global});

  String t(String key) =>
      global[key] ?? _VipLocalizedScopeState._globalFallbacks[key] ?? key;
}

class _VipCardData {
  final bool isEmpty;
  final String currentName;
  final String nextName;
  final String upgradeBrief;
  final double progress;
  final bool pendingDowngrade;
  final Map<String, dynamic> upgradeRequirement;
  final String vipCenterUrl;

  const _VipCardData({
    required this.isEmpty,
    required this.currentName,
    required this.nextName,
    required this.upgradeBrief,
    required this.progress,
    required this.pendingDowngrade,
    required this.upgradeRequirement,
    required this.vipCenterUrl,
  });

  static Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static _VipCardData fromPayload(
    Map<String, dynamic> payload,
    UserState user,
    _VipLocalizedStrings strings,
  ) {
    if (payload.isEmpty) {
      return _VipCardData(
        isEmpty: false,
        currentName: '',
        nextName: '',
        upgradeBrief: '',
        progress: 0,
        pendingDowngrade: false,
        upgradeRequirement: const {},
        vipCenterUrl: user.h5AddressModel?.vipCenterUrl ?? '',
      );
    }

    final current = _map(payload['current_level']);
    final pending = _map(payload['pending_level']);
    final nextRaw = pending.isNotEmpty ? pending : _map(payload['next_level']);
    final direction =
        (payload['pending_change_level_direction'] ??
                payload['pendingChangeLevelDirection'] ??
                '')
            .toString()
            .toUpperCase();
    final pendingDown = direction == 'DOWN';
    final currentName = UserState.pickString(current, ['name'])?.trim() ?? '';
    final rawNextName = UserState.pickString(nextRaw, ['name'])?.trim() ?? '';
    final nextName = pendingDown ? '' : rawNextName;
    final rawProgress = payload['progress'];
    final progress = rawProgress is num
        ? rawProgress.toDouble().clamp(0.0, 1.0)
        : double.tryParse('$rawProgress')?.clamp(0.0, 1.0) ?? 0.0;

    final upgradeRequirement = _map(
      payload['upgrade_requirement'] ?? payload['upgradeRequirement'],
    );
    final brief = nextName.isNotEmpty
        ? '${strings.t('to_enioy_more')} $nextName ${strings.t('privilege')}'
        : '${strings.t('looking_forward_to_higher')} $currentName ${strings.t('ex_privileges')}';

    return _VipCardData(
      isEmpty: false,
      currentName: currentName,
      nextName: nextName,
      upgradeBrief: brief,
      progress: progress,
      pendingDowngrade: pendingDown,
      upgradeRequirement: upgradeRequirement,
      vipCenterUrl: user.h5AddressModel?.vipCenterUrl ?? '',
    );
  }
}

class _Vip1Card extends StatelessWidget {
  final _VipCardData data;
  final String upgradeText;
  final VoidCallback onCardTap;
  final VoidCallback onUpgrade;

  const _Vip1Card({
    required this.data,
    required this.upgradeText,
    required this.onCardTap,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 343 / 77,
      child: GestureDetector(
        onTap: onCardTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _assetFill('assets/images/st_mine_vip_bg.png'),
            Positioned(
              left: 16,
              top: 15,
              child: Image.asset(
                'assets/images/st_mine_vip_icon.png',
                width: 18,
                height: 18,
              ),
            ),
            Positioned(
              left: 39,
              top: 15,
              child: Text(
                data.currentName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              top: 11,
              right: 17,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onUpgrade,
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4DCB73), Color(0xFF00B57A)],
                    ),
                  ),
                  child: Text(
                    upgradeText,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 17,
              top: 40,
              child: _Vip1Progress(data: data),
            ),
            Positioned(
              left: 16,
              right: 17,
              bottom: 10,
              child: _VipLevelFooter(
                currentName: data.nextName.isNotEmpty || data.pendingDowngrade
                    ? data.currentName
                    : '',
                nextName: data.nextName,
                brief: data.upgradeBrief,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vip1Progress extends StatelessWidget {
  final _VipCardData data;

  const _Vip1Progress({required this.data});

  @override
  Widget build(BuildContext context) {
    final value = data.nextName.isNotEmpty || data.pendingDowngrade
        ? data.progress
        : 1.0;
    final label = '${(value * 100).floor()}%';

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = _measure(label, 10) + 4;
        final trackWidth = constraints.maxWidth;
        final labelLeft = (trackWidth * value - labelWidth / 2).clamp(
          0.0,
          trackWidth - labelWidth,
        );
        return SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              Positioned(
                left: labelLeft,
                child: Container(
                  width: labelWidth,
                  height: 12,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF60656D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Vip2Card extends StatelessWidget {
  final _VipCardData data;
  final String upgradeText;
  final VoidCallback onCardTap;
  final VoidCallback onUpgrade;

  const _Vip2Card({
    required this.data,
    required this.upgradeText,
    required this.onCardTap,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final value = data.nextName.isNotEmpty || data.pendingDowngrade
        ? data.progress
        : 1.0;
    final digits = RegExp(
      r'\d+',
    ).allMatches(data.currentName).map((m) => m.group(0)).join();

    return AspectRatio(
      aspectRatio: 343 / 90,
      child: GestureDetector(
        onTap: onCardTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _assetFill(
              dark
                  ? 'assets/images/st_mine_vip_2_bg_dark.png'
                  : 'assets/images/st_mine_vip_2_bg.png',
            ),
            Positioned(
              left: 16,
              top: 11,
              child: Image.asset(
                'assets/images/st_mine_vip_icon.png',
                width: 24,
                height: 24,
              ),
            ),
            Positioned(
              left: 43,
              top: 17,
              child: Image.asset(
                'assets/images/vip_2_vip.png',
                width: 33,
                height: 12,
              ),
            ),
            Positioned(
              left: 78,
              top: 11,
              child: Text(
                digits,
                style: const TextStyle(
                  color: Color(0xFFC5A87B),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 10,
              height: 22,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onUpgrade,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    upgradeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 110,
              top: 49,
              height: 20,
              child: Text(
                data.upgradeBrief,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF60656D), fontSize: 10),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 70,
              child: _GoldProgressBar(value: value, height: 3),
            ),
            Positioned(
              left: 16,
              top: 77,
              child: Text(
                data.nextName.isNotEmpty || data.pendingDowngrade
                    ? data.currentName
                    : '',
                style: const TextStyle(
                  color: Color(0xFF60656D),
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 77,
              child: Text(
                data.nextName,
                style: const TextStyle(
                  color: Color(0xFF60656D),
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vip3Card extends StatelessWidget {
  final _VipCardData data;
  final String upgradeText;
  final VoidCallback onCardTap;
  final VoidCallback onUpgrade;

  const _Vip3Card({
    required this.data,
    required this.upgradeText,
    required this.onCardTap,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final showProgressValue = data.nextName.isNotEmpty || data.pendingDowngrade;
    final progress = showProgressValue ? data.progress : 1.0;
    final rowRight = data.pendingDowngrade ? 16.0 : 121.0;

    return AspectRatio(
      aspectRatio: 343 / 107,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 34,
            bottom: 0,
            child: GestureDetector(
              onTap: onCardTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _assetFill('assets/images/vip_3_bg.png'),
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 112,
                    child: Text(
                      data.upgradeBrief,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            child: Image.asset(
              'assets/images/vip_3_right_icon.png',
              width: 87,
              height: 68,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 12,
            right: rowRight,
            bottom: 18,
            child: Row(
              children: [
                Text(
                  data.currentName,
                  style: const TextStyle(
                    color: Color(0xFFFFDEC0),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFBA8A),
                      ),
                    ),
                  ),
                ),
                if (data.nextName.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    data.nextName,
                    style: const TextStyle(
                      color: Color(0xFFFFDEC0),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 25,
            bottom: 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onUpgrade,
              child: Container(
                width: 68,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7F0), Color(0xFFFFBA8A)],
                  ),
                ),
                child: Text(
                  upgradeText,
                  style: const TextStyle(
                    color: Color(0xFF111430),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipLevelFooter extends StatelessWidget {
  final String currentName;
  final String nextName;
  final String brief;
  final Color textColor;

  const _VipLevelFooter({
    required this.currentName,
    required this.nextName,
    required this.brief,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: currentName.isEmpty ? 0 : _measure(currentName, 12),
          child: Text(
            currentName,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            brief,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: nextName.isEmpty ? 0 : _measure(nextName, 12),
          child: Text(
            nextName,
            maxLines: 1,
            textAlign: TextAlign.right,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoldProgressBar extends StatelessWidget {
  final double value;
  final double height;

  const _GoldProgressBar({required this.value, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5E5),
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEFD7A7), Color(0xFFBC7200)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _assetFill(String path) {
  return Image.asset(
    path,
    fit: BoxFit.fill,
    errorBuilder: (_, __, ___) => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111430), Color(0xFF2A2D52)],
        ),
      ),
    ),
  );
}

double _measure(String text, double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width.ceilToDouble();
}
