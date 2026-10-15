import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/brand_config.dart';
import '../models/country_model.dart';
import '../models/ip_location_model.dart';
import '../models/user_state.dart';
import '../network/st_service.dart';
import '../services/country_preference_prefs.dart';

class CountryManagerState {
  const CountryManagerState({
    this.hotCountries = const [],
    this.countries = const [],
    this.guestSelectedCountry,
    this.defaultCountry,
    this.loggedInCountry,
    this.ipLocation,
    this.loaded = false,
    this.loading = false,
  });

  final List<CountryModel> hotCountries;
  final List<CountryModel> countries;

  /// 未登录时用户手动选择（对齐 iOS `_selectedCountry`）
  final CountryModel? guestSelectedCountry;

  /// 默认国家：Info.plist → IP 覆盖（对齐 iOS `defaultCountry`）
  final CountryModel? defaultCountry;

  /// 已登录用户国家（对齐 iOS `getUserCurrentCountryModel`）
  final CountryModel? loggedInCountry;
  final IpLocationModel? ipLocation;
  final bool loaded;
  final bool loading;

  List<CountryModel> get allCountries => [...hotCountries, ...countries];

  CountryManagerState copyWith({
    List<CountryModel>? hotCountries,
    List<CountryModel>? countries,
    CountryModel? guestSelectedCountry,
    CountryModel? defaultCountry,
    CountryModel? loggedInCountry,
    IpLocationModel? ipLocation,
    bool? loaded,
    bool? loading,
    bool clearGuestSelected = false,
    bool clearLoggedInCountry = false,
    bool clearIpLocation = false,
  }) {
    return CountryManagerState(
      hotCountries: hotCountries ?? this.hotCountries,
      countries: countries ?? this.countries,
      guestSelectedCountry: clearGuestSelected
          ? null
          : (guestSelectedCountry ?? this.guestSelectedCountry),
      defaultCountry: defaultCountry ?? this.defaultCountry,
      loggedInCountry: clearLoggedInCountry
          ? null
          : (loggedInCountry ?? this.loggedInCountry),
      ipLocation: clearIpLocation ? null : (ipLocation ?? this.ipLocation),
      loaded: loaded ?? this.loaded,
      loading: loading ?? this.loading,
    );
  }
}

class CountryManagerNotifier extends StateNotifier<CountryManagerState> {
  CountryManagerNotifier(this._ref) : super(const CountryManagerState());

  final Ref _ref;

  List<CountryModel> _parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => CountryModel.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.key.isNotEmpty)
        .toList();
  }

  String _languageCode() {
    try {
      return _ref.read(stServiceProvider).dio.currentLanguage;
    } catch (_) {
      return 'zh-Hans';
    }
  }

  String _brandDefaultCountryCode() {
    return BrandConfig.jufu().defaultCountryCode;
  }

  CountryModel? _resolveFromAll(String? key, List<CountryModel> all) {
    if (key == null || key.isEmpty) return null;
    return CountryModel.fromKey(key, all);
  }

  CountryModel _resolveDefaultCountry(
    List<CountryModel> all, {
    String? isoCode,
  }) {
    if (isoCode != null && isoCode.isNotEmpty) {
      final byIp = _resolveFromAll(isoCode, all);
      if (byIp != null) return byIp;
    }
    final brandCode = _brandDefaultCountryCode();
    final byBrand = _resolveFromAll(brandCode, all);
    if (byBrand != null) return byBrand;
    return all.isNotEmpty ? all.first : CountryModel.china;
  }

  /// 对齐 iOS `selectedCountry` getter
  CountryModel effectiveSelectedCountry({required bool isLoggedIn}) {
    if (isLoggedIn && state.loggedInCountry != null) {
      return state.loggedInCountry!;
    }
    return state.guestSelectedCountry ??
        state.defaultCountry ??
        CountryModel.china;
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (state.loading) return;
    if (state.loaded && !force) return;
    state = state.copyWith(loading: true);
    try {
      await _requestCountry(force: force);
    } catch (_) {
      _applyFallbackLists();
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _requestCountry({required bool force}) async {
    final service = _ref.read(stServiceProvider);
    final payload = await service.getCountries(_languageCode());
    var hot = _parseList(payload['hot_countries']);
    var others = _parseList(payload['countries']);
    if (hot.isEmpty && others.isEmpty) {
      hot = CountryModel.fallbackDefaults;
      others = const [];
    }

    final all = [...hot, ...others];
    final previousGuest = state.guestSelectedCountry;
    final defaultCountry = _resolveDefaultCountry(
      all,
      isoCode: state.ipLocation?.isoCode,
    );
    final guestSelected = previousGuest != null
        ? _resolveFromAll(previousGuest.key, all) ?? previousGuest
        : null;
    final loggedIn = state.loggedInCountry != null
        ? _resolveFromAll(state.loggedInCountry!.key, all) ??
              state.loggedInCountry
        : null;

    state = state.copyWith(
      hotCountries: hot,
      countries: others,
      defaultCountry: defaultCountry,
      guestSelectedCountry: guestSelected,
      loggedInCountry: loggedIn,
      loaded: true,
    );

    await _requestLocation(all);
  }

  Future<void> _requestLocation(List<CountryModel> all) async {
    try {
      final service = _ref.read(stServiceProvider);
      final raw = await service.getIpLocation();
      final ip = IpLocationModel.fromJson(raw);
      final defaultCountry = _resolveDefaultCountry(all, isoCode: ip.isoCode);

      state = state.copyWith(ipLocation: ip, defaultCountry: defaultCountry);
    } catch (_) {}

    if (state.guestSelectedCountry == null && state.loggedInCountry == null) {
      state = state.copyWith(
        guestSelectedCountry: state.defaultCountry ?? CountryModel.china,
      );
    }
  }

  void _applyFallbackLists() {
    final fallback = CountryModel.fallbackDefaults;
    final defaultCountry = _resolveDefaultCountry(fallback);
    state = state.copyWith(
      hotCountries: fallback,
      countries: const [],
      defaultCountry: defaultCountry,
      guestSelectedCountry: state.guestSelectedCountry ?? defaultCountry,
      loaded: true,
    );
  }

  /// 对齐 iOS 选择页 `didSelectRow` → `selectedCountry = model`
  void setSelectedCountry(CountryModel model) {
    state = state.copyWith(guestSelectedCountry: model);
  }

  /// 对齐 iOS `getUserCurrentCountryModel`
  Future<void> syncLoggedInCountry({
    required String userId,
    String? countryKey,
  }) async {
    if (userId.isEmpty) return;

    CountryModel? model = await CountryPreferencePrefs.read(userId);
    if (model == null &&
        countryKey != null &&
        countryKey.isNotEmpty &&
        state.loaded) {
      model = countryByKey(countryKey);
      if (model != null) {
        await CountryPreferencePrefs.save(userId, model);
      }
    }

    if (model != null) {
      state = state.copyWith(loggedInCountry: model);
      return;
    }

    if (countryKey != null && countryKey.isNotEmpty && !state.loaded) {
      await ensureLoaded();
      model = countryByKey(countryKey);
      if (model != null) {
        await CountryPreferencePrefs.save(userId, model);
        state = state.copyWith(loggedInCountry: model);
      }
    }
  }

  Future<void> clearLoggedInCountry({String? userId}) async {
    if (userId != null && userId.isNotEmpty) {
      await CountryPreferencePrefs.clear(userId);
    }
    state = state.copyWith(clearLoggedInCountry: true);
  }

  CountryModel? countryByKey(String? key) {
    if (key == null || key.isEmpty) return null;
    return CountryModel.fromKey(key, state.allCountries);
  }

  List<CountryModel> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    return state.allCountries.where((c) => c.matchesQuery(q)).toList();
  }
}

final countryManagerProvider =
    StateNotifierProvider<CountryManagerNotifier, CountryManagerState>((ref) {
      return CountryManagerNotifier(ref);
    });

/// 对齐 iOS `[STCountryManager shareInstance].selectedCountry`
final effectiveSelectedCountryProvider = Provider<CountryModel>((ref) {
  final user = ref.watch(userStateProvider);
  return ref
      .read(countryManagerProvider.notifier)
      .effectiveSelectedCountry(isLoggedIn: user.isExplicitlyLoggedIn);
});

/// 登录 / 拉 profile 后同步用户国家缓存
Future<void> syncCountryManagerFromProfile(
  CountryManagerNotifier notifier, {
  required String userId,
  String? countryKey,
}) async {
  await notifier.ensureLoaded();
  await notifier.syncLoggedInCountry(userId: userId, countryKey: countryKey);
}

/// 监听登录态，登出时清缓存（对齐 iOS 未登录回退 guest selected）
final countrySessionBindingProvider = Provider<void>((ref) {
  ref.listen<UserState>(userStateProvider, (prev, next) {
    if (prev?.isExplicitlyLoggedIn == true && !next.isExplicitlyLoggedIn) {
      ref
          .read(countryManagerProvider.notifier)
          .clearLoggedInCountry(userId: prev?.userId);
    }
  });
});
