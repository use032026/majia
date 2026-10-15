import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/models/user_state.dart';
import '../../shared/widgets/st_toast.dart';

/// 价格预警设置页面
/// 对齐 iOS STAlarmSettingController
class AlertSettingPage extends ConsumerStatefulWidget {
  const AlertSettingPage({super.key});

  @override
  ConsumerState<AlertSettingPage> createState() => _AlertSettingPageState();
}

class _AlertSettingPageState extends ConsumerState<AlertSettingPage> {
  static const Map<String, String> _fallbackText = {
    'market_reminder': '价格预警',
    'please_login': '请登录',
    'login': '登录',
    'add': '新建预警',
    'no_record': '暂无价格预警',
    'product': '品种',
    'price_usd': '目标价格',
    'early_warning': '预警类型',
    'setting': '条件',
    'once': '单次提醒',
    'alarm_always': '重复提醒',
    'cancel': '取消',
    'delete': '删除',
    'delete_confirm': '删除预警',
    'confirm': '确定',
    'price_not_null': '请填写完整信息',
    'requestfail': '数据加载失败',
    'remove_success': '预警已删除',
    'the_price_has_risen_to': '目标',
    'price': '当前',
    'close': '已关闭',
  };

  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || !_hasLoadedOnce;
    if (shouldShowLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final service = ref.read(stServiceProvider);
      final rawAlerts = await service.getAlerts('');
      setState(() {
        _alerts = (rawAlerts['data'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _hasLoadedOnce = true;
      });
    } catch (e) {
      debugPrint('Failed to load alerts: $e');
      if (!shouldShowLoading && mounted) {
        STToast.show(
          context,
          stUserVisibleErrorMessage(e, fallback: _t('requestfail')),
        );
      }
    }
    if (mounted && shouldShowLoading) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAlert(String alertId, int index) async {
    try {
      final service = ref.read(stServiceProvider);
      await service.deleteAlert({'alert_id': alertId});
      setState(() => _alerts.removeAt(index));
      if (mounted) {
        STToast.show(context, _t('remove_success'));
      }
    } catch (e) {
      if (mounted) {
        STToast.show(
          context,
          stUserVisibleErrorMessage(e, fallback: _t('requestfail')),
        );
      }
    }
  }

  void _showCreateAlertDialog() {
    final symbolController = TextEditingController();
    final priceController = TextEditingController();
    String condition = '>=';
    String alertType = 'once';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${_t('add')} ${_t('market_reminder')}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: symbolController,
                      decoration: InputDecoration(
                        labelText: _t('product'),
                        hintText: 'EUR/USD',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: condition,
                            decoration: InputDecoration(
                              labelText: _t('setting'),
                              border: const OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: '>=', child: Text('>=')),
                              DropdownMenuItem(value: '<=', child: Text('<=')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => condition = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _t('price_usd'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: alertType,
                      decoration: InputDecoration(
                        labelText: _t('early_warning'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'once',
                          child: Text(_t('once')),
                        ),
                        DropdownMenuItem(
                          value: 'repeat',
                          child: Text(_t('alarm_always')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => alertType = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(_t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final symbol = symbolController.text.trim();
                    final price = double.tryParse(priceController.text.trim());
                    if (symbol.isEmpty || price == null) {
                      STToast.show(ctx, _t('price_not_null'));
                      return;
                    }
                    Navigator.of(ctx).pop();
                    await _createAlert({
                      'symbol': symbol,
                      'condition': condition,
                      'target_price': price,
                      'alert_type': alertType,
                    });
                  },
                  child: Text(_t('add')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createAlert(Map<String, dynamic> data) async {
    try {
      final service = ref.read(stServiceProvider);
      await service.createAlert(data);
      if (mounted) {
        STToast.show(context, _t('confirm'));
      }
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        STToast.show(
          context,
          stUserVisibleErrorMessage(e, fallback: _t('requestfail')),
        );
      }
    }
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _fallbackText;
    localizations.textMap(_fallbackText).then((value) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = value;
      });
    });
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    final userState = ref.watch(userStateProvider);
    if (!userState.isLogin) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('market_reminder'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_t('please_login')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: Text(_t('login')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('market_reminder')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateAlertDialog,
            tooltip: _t('add'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: STLoadAnimationView())
          : _alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('no_record'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showCreateAlertDialog,
                    icon: const Icon(Icons.add),
                    label: Text(_t('add')),
                  ),
                ],
              ),
            )
          : STPullRefresh(
              onRefresh: () => _loadAlerts(showLoading: false),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _alerts.length,
                itemBuilder: (context, index) {
                  return _buildAlertItem(index);
                },
              ),
            ),
    );
  }

  Widget _buildAlertItem(int index) {
    final alert = _alerts[index];
    final symbol = alert['symbol']?.toString() ?? '';
    final condition = alert['condition']?.toString() ?? '>=';
    final targetPrice = (alert['target_price'] as num?)?.toDouble() ?? 0;
    final currentPrice = (alert['current_price'] as num?)?.toDouble() ?? 0;
    final status = alert['status']?.toString() ?? 'active';
    final alertId =
        alert['alert_id']?.toString() ??
        alert['id']?.toString() ??
        index.toString();

    final isTriggered = status == 'triggered';
    final isActive = status == 'active';

    return Dismissible(
      key: ValueKey('alert_$alertId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(_t('delete_confirm')),
            content: Text('$symbol ${_t('delete_confirm')}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(_t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  _t('delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        return result ?? false;
      },
      onDismissed: (_) => _deleteAlert(alertId, index),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 状态图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isTriggered
                      ? Colors.orange.shade100
                      : isActive
                      ? Colors.blue.shade100
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isTriggered
                      ? Icons.notifications_active
                      : isActive
                      ? Icons.notifications
                      : Icons.notifications_off,
                  color: isTriggered
                      ? Colors.orange
                      : isActive
                      ? Colors.blue
                      : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // 品种和条件
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symbol,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${_t('the_price_has_risen_to')}: $condition $targetPrice',
                          style: TextStyle(
                            fontSize: 13,
                            color: isTriggered ? Colors.orange : Colors.grey,
                          ),
                        ),
                        if (currentPrice > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${_t('price')}: $currentPrice',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 状态标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isTriggered
                      ? Colors.orange.shade50
                      : isActive
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isTriggered
                      ? _t('early_warning')
                      : isActive
                      ? _t('alarm_always')
                      : _t('close'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isTriggered
                        ? Colors.orange
                        : isActive
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
