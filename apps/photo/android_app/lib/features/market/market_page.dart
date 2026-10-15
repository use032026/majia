import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/network/st_service.dart';
import '../../core/network/market_websocket.dart';

/// 旧版行情三段 Tab UI（自选 / 全部 / 分类）。
///
/// **已弃用为主 Tab 入口**：产品侧行情首页已改为服务端卡片（见 [ConfiguredTabCardPage]、TabShell `/market`）。
/// 保留文件仅供对照或后续拆分组件复用，路由请勿再指向本页。
class MarketPage extends ConsumerStatefulWidget {
  const MarketPage({super.key});

  @override
  ConsumerState<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends ConsumerState<MarketPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late final MarketWebSocket _marketWebSocket;
  bool _isWebSocketConnected = false;
  bool _isLoading = false;
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  static final Map<String, String> _fallbackText = {
    'market': '市场',
    'optional': '自选',
    'all': '全部',
    'category': '类别',
    'price': '最新价',
    'foreign_exchange': '外汇',
    'goods': '商品',
    'stock': '股票',
    'index_number': '指数',
    'encryption': '加密货币',
  };

  static const List<String> _fallbackCategoryKeys = [
    'foreign_exchange',
    'goods',
    'stock',
    'index_number',
    'encryption',
  ];

  // 真实行情数据
  List<Map<String, dynamic>> _watchlistQuotes = [];
  List<Map<String, dynamic>> _allQuotes = [];
  List<Map<String, dynamic>> _categoryQuotes = [];

  // 模拟行情数据（作为fallback）
  final Map<String, Map<String, dynamic>> _mockMarketData = {
    'EUR/USD': {
      'price': '1.0856',
      'change': '+0.0023',
      'changePercent': '+0.21%',
      'isUp': true,
    },
    'GBP/USD': {
      'price': '1.2654',
      'change': '-0.0012',
      'changePercent': '-0.09%',
      'isUp': false,
    },
    'USD/JPY': {
      'price': '149.85',
      'change': '+0.35',
      'changePercent': '+0.23%',
      'isUp': true,
    },
    'AUD/USD': {
      'price': '0.6621',
      'change': '-0.0008',
      'changePercent': '-0.12%',
      'isUp': false,
    },
  };

  /// 分类列表数据
  List<Map<String, dynamic>> _symbolGroups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _marketWebSocket = ref.read(marketWebSocketProvider);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _connectWebSocket();
    _loadWatchlistQuotes();
    _loadAllQuotes();
    _loadSymbolGroups();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
  }

  void _loadLocalizedTextsIfNeeded() {
    final localizations = ref.read(stLocalizationsProvider);
    if (_languageCode == localizations.languageCode && _localized.isNotEmpty) {
      return;
    }
    _languageCode = localizations.languageCode;

    final token = ++_languageLoadToken;
    localizations.textMap(_fallbackText).then((value) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _localized = value);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  String _fallbackCategoryLabel(int index) {
    final safeIndex = index.clamp(0, _fallbackCategoryKeys.length - 1);
    return _t(_fallbackCategoryKeys[safeIndex]);
  }

  String _resolveCategoryDisplayName(String rawName) {
    switch (rawName.trim().toLowerCase()) {
      case 'foreign_exchange':
      case 'forex':
      case '外汇':
        return _t('foreign_exchange');
      case 'goods':
      case 'commodity':
      case '商品':
      case '贵金属':
      case '原油':
        return _t('goods');
      case 'stock':
      case 'stocks':
      case '股票':
        return _t('stock');
      case 'index':
      case 'indices':
      case 'index_number':
      case '指数':
        return _t('index_number');
      case 'cryptocurrency':
      case 'crypto':
      case 'encryption':
      case '加密货币':
      case '虚拟货币':
        return _t('encryption');
      default:
        return rawName;
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final index = _tabController.index;
      if (index == 1 && _allQuotes.isEmpty) {
        _loadAllQuotes();
      } else if (index == 2 && _categoryQuotes.isEmpty) {
        _loadCategoryQuotes(_selectedCategory);
      }
    }
  }

  String _selectedCategory = _fallbackCategoryKeys.first;

  Future<void> _loadSymbolGroups() async {
    try {
      final service = ref.read(stServiceProvider);
      final groups = await service.getSymbolGroups();
      if (mounted) {
        setState(() {
          _symbolGroups = groups.map((g) => g as Map<String, dynamic>).toList();
          if (_symbolGroups.isNotEmpty) {
            _selectedCategory =
                _symbolGroups.first['name']?.toString() ??
                _fallbackCategoryKeys.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load symbol groups: $e');
      // fallback：使用默认分类
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _disconnectWebSocket(updateState: false);
    super.dispose();
  }

  /// 连接行情 WebSocket
  void _connectWebSocket() {
    _marketWebSocket.connect();
    _marketWebSocket.sendEnterMarketList(0);
    setState(() {
      _isWebSocketConnected = true;
    });
  }

  /// 断开 WebSocket
  void _disconnectWebSocket({bool updateState = true}) {
    _marketWebSocket.disconnect();
    if (!updateState || !mounted) {
      _isWebSocketConnected = false;
      return;
    }
    setState(() => _isWebSocketConnected = false);
  }

  /// 加载自选行情
  Future<void> _loadWatchlistQuotes({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || _watchlistQuotes.isEmpty;
    if (shouldShowLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final service = ref.read(stServiceProvider);
      final quotes = await service.getMarketQuotes();
      setState(() {
        _watchlistQuotes = quotes
            .map((q) => q as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      debugPrint('Failed to load watchlist quotes: $e');
      // 使用模拟数据作为fallback
    }
    if (mounted && shouldShowLoading) {
      setState(() => _isLoading = false);
    }
  }

  /// 加载全部行情
  Future<void> _loadAllQuotes({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || _allQuotes.isEmpty;
    if (shouldShowLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final service = ref.read(stServiceProvider);
      final quotes = await service.getMarketQuotes();
      setState(() {
        _allQuotes = quotes.map((q) => q as Map<String, dynamic>).toList();
      });
    } catch (e) {
      debugPrint('Failed to load all quotes: $e');
    }
    if (mounted && shouldShowLoading) {
      setState(() => _isLoading = false);
    }
  }

  /// 加载分类行情
  Future<void> _loadCategoryQuotes(
    String category, {
    bool showLoading = true,
  }) async {
    final shouldShowLoading = showLoading || _categoryQuotes.isEmpty;
    if (shouldShowLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final service = ref.read(stServiceProvider);
      final quotes = await service.getMarketQuotes();
      setState(() {
        _categoryQuotes = quotes.map((q) => q as Map<String, dynamic>).toList();
      });
    } catch (e) {
      debugPrint('Failed to load category quotes: $e');
    }
    if (mounted && shouldShowLoading) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _connectWebSocket();
      _loadWatchlistQuotes();
    } else if (state == AppLifecycleState.paused) {
      _disconnectWebSocket();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_t('market')),
            if (_isWebSocketConnected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.circle, color: Colors.green, size: 8),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              context.push('/market/alert');
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.push('/market/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/market/watchlist_edit');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: _t('optional')),
            Tab(text: _t('all')),
            Tab(text: _t('category')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 自选 Tab
          _buildWatchlistTab(),
          // 全部 Tab
          _buildAllMarketsTab(),
          // 分类 Tab
          _buildCategoryTab(),
        ],
      ),
    );
  }

  Widget _buildWatchlistTab() {
    if (_isLoading) {
      return const Center(child: STLoadAnimationView());
    }

    // 如果有真实数据，使用真实数据；否则使用模拟数据
    final quotes = _watchlistQuotes.isNotEmpty
        ? _watchlistQuotes
        : _mockMarketData.entries.map((e) {
            return {
              'symbol': e.key,
              'price': e.value['price'],
              'change': e.value['change'],
              'change_percent': e.value['changePercent'],
              'is_up': e.value['isUp'],
            };
          }).toList();

    return STPullRefresh(
      onRefresh: () => _loadWatchlistQuotes(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: quotes.map((quote) {
          return _buildMarketItemFromData(quote);
        }).toList(),
      ),
    );
  }

  Widget _buildAllMarketsTab() {
    final quotes = _allQuotes.isNotEmpty
        ? _allQuotes
        : _mockMarketData.entries.map((e) {
            return {
              'symbol': e.key,
              'price': e.value['price'],
              'change': e.value['change'],
              'change_percent': e.value['changePercent'],
              'is_up': e.value['isUp'],
            };
          }).toList();

    return STPullRefresh(
      onRefresh: () => _loadAllQuotes(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: quotes.map((quote) {
          return _buildMarketItemFromData(quote);
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryTab() {
    return Column(
      children: [
        // 分类选择器（横向滚动）
        Container(
          height: 44,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _symbolGroups.isNotEmpty ? _symbolGroups.length : 5,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) {
              final rawName = _symbolGroups.isNotEmpty
                  ? (_symbolGroups[index]['name']?.toString() ??
                        '${_t('category')}${index + 1}')
                  : _fallbackCategoryKeys[index];
              final name = _symbolGroups.isNotEmpty
                  ? _resolveCategoryDisplayName(rawName)
                  : _fallbackCategoryLabel(index);
              final isSelected = _selectedCategory == rawName;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = rawName);
                    _loadCategoryQuotes(rawName);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 分类行情列表
        Expanded(
          child: STPullRefresh(
            onRefresh: () =>
                _loadCategoryQuotes(_selectedCategory, showLoading: false),
            child: _categoryQuotes.isNotEmpty
                ? ListView(
                    padding: const EdgeInsets.all(8),
                    children: _categoryQuotes.map((quote) {
                      return _buildMarketItemFromData(quote);
                    }).toList(),
                  )
                : ListView(
                    children: _mockMarketData.entries.map((e) {
                      return _buildMarketItem(
                        e.key,
                        e.value['price']!,
                        e.value['change']!,
                        e.value['changePercent']!,
                        e.value['isUp'] as bool,
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarketItemFromData(Map<String, dynamic> data) {
    final symbol = data['symbol']?.toString() ?? '';
    final price = data['price']?.toString() ?? '0';
    final change = data['change']?.toString() ?? '0';
    final changePercent = data['change_percent']?.toString() ?? '0%';
    final isUp = data['is_up'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUp ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isUp ? Icons.trending_up : Icons.trending_down,
            color: isUp ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          symbol,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_t('price')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '$change ($changePercent)',
              style: TextStyle(
                fontSize: 12,
                color: isUp ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        onTap: () {
          context.push('/market/detail?symbol=${Uri.encodeComponent(symbol)}');
        },
      ),
    );
  }

  Widget _buildMarketItem(
    String symbol,
    String price,
    String change,
    String changePercent,
    bool isUp,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUp ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isUp ? Icons.trending_up : Icons.trending_down,
            color: isUp ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          symbol,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_t('price')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '$change ($changePercent)',
              style: TextStyle(
                fontSize: 12,
                color: isUp ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        onTap: () {
          context.push('/market/detail?symbol=${Uri.encodeComponent(symbol)}');
        },
      ),
    );
  }
}
