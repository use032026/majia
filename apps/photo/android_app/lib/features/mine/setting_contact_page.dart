import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/customer_service_route.dart';

/// 兜底设置页客服路由壳。
/// 实际客服内容仍走共享 `/web` + `CustomerServiceRoute` 合同。
class SettingContactPage extends ConsumerStatefulWidget {
  const SettingContactPage({super.key});

  @override
  ConsumerState<SettingContactPage> createState() => _SettingContactPageState();
}

class _SettingContactPageState extends ConsumerState<SettingContactPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCustomerService());
  }

  Future<void> _openCustomerService() async {
    final opened = await CustomerServiceRoute.open(
      context,
      ref,
      action: '设置联系客服',
    );
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('联系客服')),
      body: Center(
        child: _loading
            ? const SizedBox.shrink()
            : const Text(
                '暂无消息',
                style: TextStyle(fontSize: 14, color: Color(0xFF9A9DA2)),
              ),
      ),
    );
  }
}
