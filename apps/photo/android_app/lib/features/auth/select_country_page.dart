import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import 'package:jufu/shared/widgets/st_network_image.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/country_model.dart';
import '../../core/providers/country_manager_provider.dart';

/// 居住国家/地区选择页（对齐 iOS `STSelectCountryViewController`）
class SelectCountryPage extends ConsumerStatefulWidget {
  const SelectCountryPage({super.key, this.selectedCountryKey});

  final String? selectedCountryKey;

  @override
  ConsumerState<SelectCountryPage> createState() => _SelectCountryPageState();
}

class _SelectCountryPageState extends ConsumerState<SelectCountryPage> {
  static const Map<String, String> _fallbackText = {
    'country_of_registration': '居住国家/地区',
    'search': '搜索',
    'no_data': '暂无数据',
    'hot_country': '热门国家/地区',
    'other_country': '其他国家/地区',
  };

  final _searchCtrl = TextEditingController();
  String? _languageCode;
  Map<String, String> _localized = const {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(countryManagerProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
  }

  void _loadLocalizedTextsIfNeeded() {
    final nextCode = stLanguageCodeOfContext(context);
    if (_languageCode == nextCode && _localized.isNotEmpty) return;
    _languageCode = nextCode;
    STLocalizations.ofContext(context).textMap(_fallbackText).then((entries) {
      if (!mounted) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  String? get _selectedKey =>
      widget.selectedCountryKey ??
      ref.read(effectiveSelectedCountryProvider).key;

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  void _onSelect(CountryModel model) {
    ref.read(countryManagerProvider.notifier).setSelectedCountry(model);
    Navigator.of(context).pop(model);
  }

  @override
  Widget build(BuildContext context) {
    final mgr = ref.watch(countryManagerProvider);
    final notifier = ref.read(countryManagerProvider.notifier);
    final query = _searchCtrl.text.trim();
    final sections = _isSearching
        ? [notifier.search(query)]
        : [mgr.hotCountries, mgr.countries];
    final showEmpty = sections.every((s) => s.isEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _t('country_of_registration'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: _t('search'),
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F7),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: mgr.loading && !mgr.loaded
                ? const Center(child: STLoadAnimationView())
                : showEmpty
                ? _emptyView()
                : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: _listItemCount(sections),
                    itemBuilder: (ctx, index) =>
                        _buildListItem(context, sections, index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Text(
        _t('no_data'),
        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
      ),
    );
  }

  int _listItemCount(List<List<CountryModel>> sections) {
    var count = 0;
    for (var i = 0; i < sections.length; i++) {
      if (!_isSearching && sections[i].isNotEmpty) count += 1; // header
      count += sections[i].length;
    }
    return count;
  }

  Widget _buildListItem(
    BuildContext context,
    List<List<CountryModel>> sections,
    int index,
  ) {
    var cursor = 0;
    for (var s = 0; s < sections.length; s++) {
      final rows = sections[s];
      if (!_isSearching && rows.isNotEmpty) {
        if (index == cursor) {
          return _sectionHeader(_headerTitle(s));
        }
        cursor += 1;
      }
      for (var r = 0; r < rows.length; r++) {
        if (index == cursor) {
          final model = rows[r];
          final selected = model.key == _selectedKey;
          return _countryCell(model, selected);
        }
        cursor += 1;
      }
    }
    return const SizedBox.shrink();
  }

  String _headerTitle(int section) {
    if (_isSearching) return '';
    return section == 0 ? _t('hot_country') : _t('other_country');
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
        ),
      ),
    );
  }

  Widget _countryCell(CountryModel model, bool selected) {
    return InkWell(
      onTap: () => _onSelect(model),
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _flagWidget(model),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  model.value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.check, color: Color(0xFF4DCB73), size: 20),
                ),
              Text(
                model.code,
                style: const TextStyle(fontSize: 15, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flagWidget(CountryModel model) {
    final url = model.flagUrl.trim();
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: STNetworkImage(
          imageUrl: url,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => _flagPlaceholder(model),
        ),
      );
    }
    return _flagPlaceholder(model);
  }

  Widget _flagPlaceholder(CountryModel model) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(model.flagEmoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

/// 打开居住国家/地区页并返回选中项（对齐 iOS push `STSelectCountryViewController`）
Future<CountryModel?> openSelectCountryPage(
  BuildContext context, {
  String? selectedCountryKey,
}) {
  return Navigator.of(context).push<CountryModel>(
    MaterialPageRoute(
      builder: (_) => SelectCountryPage(selectedCountryKey: selectedCountryKey),
    ),
  );
}
