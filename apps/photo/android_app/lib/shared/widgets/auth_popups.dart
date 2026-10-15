import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/network/st_error_messages.dart';

class WalletAccountSecurityItem {
  const WalletAccountSecurityItem({
    required this.step,
    required this.title,
    required this.completed,
    required this.completedText,
    required this.actionText,
    this.assetName,
    this.icon,
  });

  final String step;
  final String title;
  final bool completed;
  final String completedText;
  final String actionText;
  final String? assetName;
  final IconData? icon;
}

Future<bool?> showAuthGuideSheet({required BuildContext context}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (sheetContext) =>
        AuthGuideSheet(onConfirm: () => Navigator.of(sheetContext).pop(true)),
  );
}

Future<String?> showWalletAccountSecuritySheet({
  required BuildContext context,
  required List<WalletAccountSecurityItem> items,
  required String title,
  required String subtitle,
  required String cancelText,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (sheetContext) => WalletAccountSecuritySheet(
      items: items,
      title: title,
      subtitle: subtitle,
      cancelText: cancelText,
      onClose: () => Navigator.of(sheetContext).pop(),
      onSelect: (step) => Navigator.of(sheetContext).pop(step),
    ),
  );
}

Future<void> showAuthFailedDialog({
  required BuildContext context,
  required String title,
  required String reason,
  String buttonLabel = '确定',
  VoidCallback? onConfirm,
}) {
  final safeTitle = stSanitizeUserVisibleText(title);
  final safeReason = stSanitizeUserVisibleText(reason);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogContext) => AuthFailedDialog(
      title: safeTitle,
      reason: safeReason,
      buttonLabel: buttonLabel,
      onConfirm: () {
        Navigator.of(dialogContext).pop();
        onConfirm?.call();
      },
    ),
  );
}

Future<bool?> showAuthExampleDialog({required BuildContext context}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogContext) => AuthExampleDialog(
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
      onClose: () => Navigator.of(dialogContext).pop(false),
    ),
  );
}

class WalletAccountSecuritySheet extends StatelessWidget {
  const WalletAccountSecuritySheet({
    super.key,
    required this.items,
    required this.title,
    required this.subtitle,
    required this.cancelText,
    required this.onClose,
    required this.onSelect,
  });

  final List<WalletAccountSecurityItem> items;
  final String title;
  final String subtitle;
  final String cancelText;
  final VoidCallback onClose;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellColor = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF7F7F7);
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF111111);
    final secondaryText = isDark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF9A9DA2);
    final dividerColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFEAEAEA);
    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        child: Container(
          key: const ValueKey('wallet_account_security_sheet'),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(15, 42, 15, 22 + bottomInset),
          decoration: BoxDecoration(
            color: shellColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    _walletSecurityAssetPath('st_mine_info_perfect', isDark),
                    key: const ValueKey('wallet_account_security_top_icon'),
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: ColoredBox(
                      color: cardColor,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            _WalletAccountSecurityRow(
                              item: items[i],
                              onSelect: onSelect,
                              isDark: isDark,
                              primaryText: primaryText,
                            ),
                            if (i != items.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 17,
                                ),
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: dividerColor,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    key: const ValueKey('wallet_account_security_cancel'),
                    width: double.infinity,
                    height: 57,
                    child: TextButton(
                      onPressed: onClose,
                      style: TextButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: primaryText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(cancelText),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  key: const ValueKey('wallet_account_security_close'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 30),
                  color: secondaryText,
                  tooltip: cancelText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletAccountSecurityRow extends StatelessWidget {
  const _WalletAccountSecurityRow({
    required this.item,
    required this.onSelect,
    required this.isDark,
    required this.primaryText,
  });

  final WalletAccountSecurityItem item;
  final ValueChanged<String> onSelect;
  final bool isDark;
  final Color primaryText;

  @override
  Widget build(BuildContext context) {
    final action = item.completed ? null : () => onSelect(item.step);
    return SizedBox(
      key: ValueKey('wallet_account_security_${item.step}'),
      height: 54,
      child: InkWell(
        onTap: action,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Row(
            children: [
              _WalletAccountSecurityIcon(item: item, isDark: isDark),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (item.completed)
                Text(
                  item.completedText,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                SizedBox(
                  height: 30,
                  child: TextButton(
                    key: ValueKey(
                      'wallet_account_security_action_${item.step}',
                    ),
                    onPressed: action,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      backgroundColor: const Color(0xFF00B57A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(item.actionText),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletAccountSecurityIcon extends StatelessWidget {
  const _WalletAccountSecurityIcon({required this.item, required this.isDark});

  final WalletAccountSecurityItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final assetName = item.assetName;
    if (assetName != null) {
      return Image.asset(
        _walletSecurityAssetPath(assetName, isDark),
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      );
    }
    return Icon(
      item.icon ?? Icons.verified_user_outlined,
      size: 24,
      color: const Color(0xFF2B2D33),
    );
  }
}

String _walletSecurityAssetPath(String assetName, bool isDark) {
  const darkAssets = {
    'st_mine_info_perfect',
    'st_mine_real_auth',
    'st_mine_bank_card',
    'st_mine_phone',
    'st_mine_wallet_black',
    'st_mine_pwd',
    'st_mine_email',
  };
  final suffix = isDark && darkAssets.contains(assetName) ? '_cmsdark' : '';
  return 'assets/images/$assetName$suffix.png';
}

class AuthGuideSheet extends StatelessWidget {
  const AuthGuideSheet({super.key, this.onConfirm});

  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('auth_guide_sheet_shell'),
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, 47, 24, 26 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/st_mine_auth_guide.png',
              key: const ValueKey('auth_guide_image'),
              width: 123,
              height: 75,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 15),
            const Text(
              '信息待完善',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请先完成身份认证以使用相关服务',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 42),
            SizedBox(
              key: const ValueKey('auth_guide_primary_button'),
              width: 193,
              height: 48,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF00B57A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('前往设置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthFailedDialog extends StatelessWidget {
  const AuthFailedDialog({
    super.key,
    required this.title,
    required this.reason,
    required this.onConfirm,
    this.buttonLabel = '确定',
  });

  final String title;
  final String reason;
  final String buttonLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.max(260.0, screenWidth - 100);
    return Center(
      child: Container(
        key: const ValueKey('auth_failed_dialog_shell'),
        width: width,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 21),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/st_common_warn.png',
              key: const ValueKey('auth_failed_warn_image'),
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 11),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              reason,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9A9DA2),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              key: const ValueKey('auth_failed_primary_button'),
              width: 125,
              height: 42,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF00B57A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthExampleDialog extends StatelessWidget {
  const AuthExampleDialog({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.onClose,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback? onClose;

  static const List<String> _exampleLabels = ['图片模糊', '角度倾斜', '图片反光', '标准示例'];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.max(280.0, screenWidth - 80);
    return Center(
      child: Material(
        key: const ValueKey('auth_example_dialog_shell'),
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 24),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '示例',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onClose ?? onCancel,
                      behavior: HitTestBehavior.opaque,
                      child: Image.asset(
                        'assets/images/st_mine_close_gary.png',
                        key: const ValueKey('auth_example_close'),
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Image.asset(
                'assets/images/st_mine_auth_example.png',
                key: const ValueKey('auth_example_first_image'),
                width: 136,
                height: 86,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                '示例参考',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 11),
              Image.asset(
                'assets/images/st_mine_auth_example_sec.png',
                key: const ValueKey('auth_example_second_image'),
                width: 252,
                height: 36,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 252,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _exampleLabels
                      .map(
                        (label) => SizedBox(
                          width: 54,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9A9DA2),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 15),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFE5E7EB),
              ),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: _AuthExampleAction(
                        label: '取消',
                        color: const Color(0xFF9A9DA2),
                        onTap: onCancel,
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 0.5,
                      color: Color(0xFFE5E7EB),
                    ),
                    Expanded(
                      child: _AuthExampleAction(
                        label: '确定',
                        color: const Color(0xFF4DCB73),
                        onTap: onConfirm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthExampleAction extends StatelessWidget {
  const _AuthExampleAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
