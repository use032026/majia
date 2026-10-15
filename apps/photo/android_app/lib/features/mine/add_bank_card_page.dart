import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/bank_card_model.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/st_keyboard_actions.dart';
import '../../shared/widgets/st_toast.dart';
import '../auth/auth_name_input_formatter.dart';

enum AddBankCardMediaPermission { granted, denied, restricted }

typedef AddBankCardMediaPermissionChecker =
    Future<AddBankCardMediaPermission> Function(ImageSource source);

typedef AddBankCardOpenAppSettings = Future<bool> Function();

class _AddBankCardText {
  const _AddBankCardText._();

  static const fallback = <String, String>{
    'add_bank_voucher': '添加账户证明',
    'bank_card_photo': '银行信息',
    'add_bank_card_tip_1': '请使用您本人名下的银行账户。平台不接受任何第三方入金。',
    'bank_belong_country': '银行所属国家/地区',
    'bank_name': '银行名称',
    'choose_bank': '选择银行',
    'search_bank_name': '搜索银行名称',
    'branch_name': '支行名称',
    'please_input_branch_name': '请输入支行名称',
    'bank_account_name': '银行账户姓名',
    'input_bank_holder_name': '请输入您的收款人姓名',
    'add_bank_card_tip_2': '请确保姓名与银行预留信息完全一致，否则将导致出金失败。',
    'bank_card_code': '银行账号',
    'please_input_bank_card_code': '请输入银行账号',
    'bank_currency': '银行账户币种',
    'choose_currency': '请选择币种',
    'add': '添加',
    'input_yes_name': '输入正确的姓名',
    'bank_card_length_error': '银行卡号长度应为 11-19 位',
    'bank_card_number_repeat': '该银行卡已被添加。',
    'bank_list_load_failed': '银行列表加载失败: %1\$s',
    'from_album': '从相册选择',
    'take_photo': '拍照',
    'cancel': '取消',
    'photo_permission_failed': '无法获取照片，请检查相册或相机权限',
    'enable_camera_permission': '请开启相机权限以进行拍照或录像。',
    'enable_album_permission': '请开启相册权限以选择照片或视频。',
    'later': '稍后',
    'setting': '设置',
    'open_settings_failed': '无法打开系统设置，请稍后重试',
    'bank_card_info_missing': '银行卡信息缺失，请重新填写',
    'submit_account_voucher': '提交账户证明',
    'add_bank_card_tip_3': '请提交一份包含以下信息的账户证明文件（如银行账单）：',
    'account_name': '账户名称',
    'account_number': '账户号码',
    'front_bank_card': '银行卡正面',
    'submit': '提交',
    'no_bank_found_add_prompt': '暂无此银行,是否添加此银行',
    'add_this_bank': '添加此银行',
    'add_bank_full_name_tip': '添加时请输入完整的银行名称,避免出现错误',
  };
}

mixin _AddBankCardLocalizedState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Map<String, String> _localized = _AddBankCardText.fallback;

  void _ensureLocalizedText() {
    final localizations = ref.watch(stLocalizationsProvider);
    localizations.textMap(_AddBankCardText.fallback).then((entries) {
      if (!mounted) return;
      if (identical(entries, _localized)) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _AddBankCardText.fallback[key] ?? key;
}

class AddBankCardPage extends ConsumerStatefulWidget {
  const AddBankCardPage({super.key, this.existingCards = const []});

  final List<BankCardModel> existingCards;

  @override
  ConsumerState<AddBankCardPage> createState() => _AddBankCardPageState();
}

class _AddBankCardPageState extends ConsumerState<AddBankCardPage>
    with _AddBankCardLocalizedState<AddBankCardPage> {
  static final RegExp _nonDigitReg = RegExp(r'[^0-9]');

  final _bankCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _cardNoCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _bankSearchCtrl = TextEditingController();
  final _bankFocus = FocusNode();
  final _branchFocus = FocusNode();
  final _holderFocus = FocusNode();
  final _cardNoFocus = FocusNode();
  final _bankSearchFocus = FocusNode();

  bool _loadingBanks = true;
  String? _bankLoadError;
  String _countryKey = '';
  String _countryName = '';
  String _swiftCode = '';
  List<_BankOption> _allBanks = [];
  List<_BankOption> _searchResult = [];
  bool _cleaningHolderName = false;

  bool get _hasBankList => _allBanks.isNotEmpty;

  bool get _canAdd {
    return _bankLoadError == null &&
        _countryName.trim().isNotEmpty &&
        _bankCtrl.text.trim().isNotEmpty &&
        _branchCtrl.text.trim().isNotEmpty &&
        _holderCtrl.text.trim().isNotEmpty &&
        _isValidCardLength(_cardNoCtrl.text) &&
        _currencyCtrl.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _bankCtrl.addListener(_refresh);
    _branchCtrl.addListener(_refresh);
    _holderCtrl.addListener(_onHolderChanged);
    _cardNoCtrl.addListener(_refresh);
    _currencyCtrl.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _branchCtrl.dispose();
    _holderCtrl.dispose();
    _cardNoCtrl.dispose();
    _currencyCtrl.dispose();
    _bankSearchCtrl.dispose();
    _bankFocus.dispose();
    _branchFocus.dispose();
    _holderFocus.dispose();
    _cardNoFocus.dispose();
    _bankSearchFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onHolderChanged() {
    if (!_cleaningHolderName) {
      _cleaningHolderName = true;
      AuthNameInputFormatter.cleanControllerText(
        _holderCtrl,
        countryKey: _countryKey,
      );
      _cleaningHolderName = false;
    }
    _refresh();
  }

  Future<void> _bootstrap() async {
    await ref.read(countryManagerProvider.notifier).ensureLoaded();
    if (!mounted) return;
    final country = ref.read(effectiveSelectedCountryProvider);
    _countryKey = country.key;
    _countryName = country.value;
    _currencyCtrl.text = country.currencyCode;

    final defaultHolder = await _loadDefaultHolderName();
    if (!mounted) return;
    if (mounted) {
      _holderCtrl.text = _countryKey == 'CN'
          ? AuthNameInputFormatter.filterChineseName(defaultHolder)
          : defaultHolder;
    }
    await _loadBanks();
  }

  Future<String> _loadDefaultHolderName() async {
    try {
      final raw = await ref.read(stServiceProvider).getUserProfile();
      final data = raw['data'];
      if (data is Map) {
        final name = data['name']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (e) {
      debugPrint('AddBankCard load holder name: $e');
    }
    return '';
  }

  Future<void> _loadBanks() async {
    setState(() {
      _loadingBanks = true;
      _bankLoadError = null;
    });
    try {
      final raw = await ref.read(stServiceProvider).getBankList();
      final options = <_BankOption>[];
      for (final item in raw.whereType<Map>()) {
        final parsed = _BankOption.fromDynamic(item);
        if (parsed.name.isNotEmpty) options.add(parsed);
      }
      if (!mounted) return;
      setState(() {
        _allBanks = options;
        _searchResult = options;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allBanks = const [];
        _searchResult = const [];
        _bankLoadError = _errorMessage(e);
      });
      _toast(_bankLoadError!);
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  static String _strip(String value) =>
      value.trim().replaceAll(_nonDigitReg, '');

  static String _removeInnerSpaces(String value) =>
      value.trim().replaceAll(' ', '');

  static bool _isValidCardLength(String raw) {
    final number = _strip(raw);
    return number.length >= 11 && number.length <= 19;
  }

  bool _isCardDuplicate(String rawCard) {
    final target = _strip(rawCard);
    return widget.existingCards.any(
      (card) => _strip(card.cardNumber) == target,
    );
  }

  Future<void> _nextAction() async {
    if (_holderCtrl.text.trim().length > 35) {
      _toast(_t('input_yes_name'));
      return;
    }
    if (!_isValidCardLength(_cardNoCtrl.text)) {
      _toast(_t('bank_card_length_error'));
      return;
    }
    if (_isCardDuplicate(_cardNoCtrl.text)) {
      _toast(_t('bank_card_number_repeat'));
      return;
    }

    final draft = <String, String>{
      'bank_name': _removeInnerSpaces(_bankCtrl.text),
      'branch_name': _removeInnerSpaces(_branchCtrl.text),
      'holder_name': _removeInnerSpaces(_holderCtrl.text),
      'card_number': _strip(_cardNoCtrl.text),
      'currency': _removeInnerSpaces(_currencyCtrl.text),
      'swift_code': _swiftCode,
    };

    final submitted = await context.push<bool>(
      '/mine/bankcard/add_voucher',
      extra: draft,
    );
    if (submitted == true && mounted) context.pop(true);
  }

  Future<void> _pickBank() async {
    if (_loadingBanks || !_hasBankList) return;
    _bankSearchCtrl.text = '';
    _searchResult = _allBanks;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: const Color(0x4D000000),
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setInnerState) {
            final bottomSafeArea = MediaQuery.of(ctx).viewPadding.bottom;
            return STKeyboardActions(
              isDialog: true,
              focusNodes: [_bankSearchFocus],
              child: SafeArea(
                top: false,
                bottom: false,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: ColoredBox(
                    color: ctx.adaptiveSurfacePrimary,
                    child: SizedBox(
                      height:
                          MediaQuery.of(ctx).size.height * 0.72 +
                          bottomSafeArea,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 15, 48, 10),
                            child: Text(
                              _t('choose_bank'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ctx.adaptiveTextPrimary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(21, 0, 11, 10),
                            child: SizedBox(
                              height: 41,
                              child: TextField(
                                controller: _bankSearchCtrl,
                                focusNode: _bankSearchFocus,
                                onChanged: (value) {
                                  final key = value.trim();
                                  setInnerState(() {
                                    _searchResult = key.isEmpty
                                        ? _allBanks
                                        : _allBanks
                                              .where(
                                                (item) =>
                                                    item.name.contains(key),
                                              )
                                              .toList(growable: false);
                                  });
                                },
                                style: TextStyle(
                                  fontSize: 16,
                                  color: ctx.adaptiveTextPrimary,
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                textAlign: TextAlign.left,
                                decoration: InputDecoration(
                                  hintText: _t('search_bank_name'),
                                  hintStyle: TextStyle(
                                    color: ctx.adaptiveTextHint,
                                    fontSize: 16,
                                  ),
                                  isDense: true,
                                  isCollapsed: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 11,
                                  ),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      15,
                                      10.5,
                                      13,
                                      10.5,
                                    ),
                                    child: Icon(
                                      Icons.search,
                                      size: 20,
                                      color: ctx.adaptiveTextSecondary,
                                    ),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 44,
                                  ),
                                  suffixIcon:
                                      _bankSearchCtrl.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _bankSearchCtrl.clear();
                                            setInnerState(() {
                                              _searchResult = _allBanks;
                                            });
                                          },
                                          icon: Icon(
                                            Icons.clear,
                                            color: ctx.adaptiveTextHint,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  filled: true,
                                  fillColor: ctx.adaptiveMutedBlock,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20.5),
                                    borderSide: BorderSide(
                                      width: 0.5,
                                      color: ctx.adaptiveDivider,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20.5),
                                    borderSide: BorderSide(
                                      width: 0.5,
                                      color: ctx.adaptiveDivider,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20.5),
                                    borderSide: BorderSide(
                                      width: 0.5,
                                      color: ctx.adaptiveDivider,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: bottomSafeArea),
                              child: _searchResult.isEmpty
                                  ? _BankNoRecordsView(
                                      emptyText: _t('no_bank_found_add_prompt'),
                                      addText: _t('add_this_bank'),
                                      fullNameTip: _t('add_bank_full_name_tip'),
                                      onAdd: () {
                                        final bankName = _bankSearchCtrl.text
                                            .trim();
                                        if (bankName.isEmpty) return;
                                        setState(() {
                                          _bankCtrl.text = bankName;
                                          _swiftCode = '';
                                        });
                                        Navigator.pop(sheetCtx);
                                      },
                                    )
                                  : ListView.separated(
                                      itemBuilder: (_, i) {
                                        final item = _searchResult[i];
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              _bankCtrl.text = item.name;
                                              _swiftCode = item.swiftCode;
                                            });
                                            Navigator.pop(sheetCtx);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 17,
                                              vertical: 0,
                                            ),
                                            child: SizedBox(
                                              height: 54,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  item.name,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color:
                                                        ctx.adaptiveTextPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: ctx.adaptiveDivider,
                                        indent: 17,
                                        endIndent: 17,
                                      ),
                                      itemCount: _searchResult.length,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    STToast.show(context, message);
  }

  String _errorMessage(Object error) {
    final message = stUserVisibleErrorMessage(error);
    return _t('bank_list_load_failed').replaceAll('%1\$s', message);
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    return STKeyboardActions(
      focusNodes: [_bankFocus, _branchFocus, _holderFocus, _cardNoFocus],
      child: Scaffold(
        backgroundColor: context.adaptivePageGrey,
        appBar: AppBar(
          title: Text(_t('add_bank_voucher')),
          backgroundColor: context.adaptiveSurfacePrimary,
          foregroundColor: context.adaptiveTextPrimary,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: context.adaptiveTextPrimary),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_bankLoadError != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _bankLoadError!,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(15, 25, 15, 0),
                        child: Text(
                          _t('bank_card_photo'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(15, 11, 15, 8),
                        child: Text(
                          _t('add_bank_card_tip_1'),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: context.adaptiveTextTertiary,
                          ),
                        ),
                      ),
                      _readonlyRow(_t('bank_belong_country'), _countryName),
                      _inputRow(
                        title: _t('bank_name'),
                        controller: _bankCtrl,
                        focusNode: _bankFocus,
                        placeholder: _t('choose_bank'),
                        readOnly: _hasBankList || _bankLoadError != null,
                        onTap: _bankLoadError == null ? _pickBank : null,
                        suffix: _loadingBanks
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                ),
                              )
                            : _bankLoadError != null
                            ? Icon(
                                Icons.error_outline,
                                size: 18,
                                color: context.adaptiveTextSecondary,
                              )
                            : _hasBankList
                            ? Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: context.adaptiveTextSecondary,
                              )
                            : null,
                      ),
                      if (_bankLoadError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
                          child: Text(
                            _bankLoadError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF95959),
                            ),
                          ),
                        ),
                      _inputRow(
                        title: _t('branch_name'),
                        controller: _branchCtrl,
                        focusNode: _branchFocus,
                        placeholder: _t('please_input_branch_name'),
                      ),
                      _inputRow(
                        title: _t('bank_account_name'),
                        controller: _holderCtrl,
                        focusNode: _holderFocus,
                        placeholder: _t('input_bank_holder_name'),
                        inputFormatters: _countryKey == 'CN'
                            ? const [AuthNameInputFormatter(countryKey: 'CN')]
                            : null,
                        helperText: _t('add_bank_card_tip_2'),
                      ),
                      _inputRow(
                        title: _t('bank_card_code'),
                        controller: _cardNoCtrl,
                        focusNode: _cardNoFocus,
                        placeholder: _t('please_input_bank_card_code'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      _inputRow(
                        title: _t('bank_currency'),
                        controller: _currencyCtrl,
                        placeholder: _t('choose_currency'),
                        readOnly: true,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 20),
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canAdd ? _nextAction : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B57A),
                        disabledBackgroundColor: const Color(
                          0xFF00B57A,
                        ).withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: Text(
                        _t('add'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _readonlyRow(String title, String value) {
    return _inputShell(
      title: title,
      child: Text(
        value.isNotEmpty ? value : '--',
        style: TextStyle(fontSize: 15, color: context.adaptiveTextPrimary),
      ),
    );
  }

  Widget _inputRow({
    required String title,
    required TextEditingController controller,
    required String placeholder,
    FocusNode? focusNode,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
    VoidCallback? onTap,
    String? helperText,
  }) {
    return _inputShell(
      title: title,
      helperText: helperText,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(fontSize: 15, color: context.adaptiveTextPrimary),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: context.adaptiveTextHint),
          isDense: true,
          border: InputBorder.none,
          suffixIcon: suffix == null
              ? null
              : Padding(padding: const EdgeInsets.only(left: 8), child: suffix),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _inputShell({
    required String title,
    required Widget child,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 13),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.adaptiveTextTertiary,
            ),
          ),
          SizedBox(
            height: 33,
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
          Divider(height: 1, color: context.adaptiveDivider),
          if (helperText != null) ...[
            const SizedBox(height: 9),
            Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.adaptiveTextTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AddBankCardVoucherPage extends ConsumerStatefulWidget {
  const AddBankCardVoucherPage({
    super.key,
    required this.draft,
    this.mediaPermissionChecker,
    this.openAppSettings,
  });

  final Map<String, String> draft;
  final AddBankCardMediaPermissionChecker? mediaPermissionChecker;
  final AddBankCardOpenAppSettings? openAppSettings;

  @override
  ConsumerState<AddBankCardVoucherPage> createState() =>
      _AddBankCardVoucherPageState();
}

class _AddBankCardVoucherPageState extends ConsumerState<AddBankCardVoucherPage>
    with _AddBankCardLocalizedState<AddBankCardVoucherPage> {
  final _picker = ImagePicker();
  bool _uploading = false;
  bool _submitting = false;
  String _frontUrl = '';
  Uint8List? _frontBytes;

  bool get _hasValidDraft {
    const requiredKeys = [
      'bank_name',
      'branch_name',
      'holder_name',
      'card_number',
      'currency',
    ];
    return requiredKeys.every(
      (key) => (widget.draft[key] ?? '').trim().isNotEmpty,
    );
  }

  bool get _canSubmit => _frontUrl.isNotEmpty && !_uploading && !_submitting;

  Future<void> _pickFrontPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Material(
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              color: ctx.adaptiveCard,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetItem(
                    _t('from_album'),
                    () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                  Divider(height: 1, color: ctx.adaptiveDivider),
                  _sheetItem(
                    _t('take_photo'),
                    () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                  Divider(height: 1, color: ctx.adaptiveDivider),
                  _sheetItem(_t('cancel'), () => Navigator.pop(ctx)),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (source == null) return;
    final granted = await _ensureMediaPermission(source);
    if (!granted) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;

      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final url = await ref
          .read(stServiceProvider)
          .uploadIdentityImage(
            bytes: bytes,
            filename: picked.name,
            mimeType: _mimeTypeFor(picked.name),
          );
      if (!mounted) return;
      setState(() {
        _frontBytes = bytes;
        _frontUrl = url;
      });
    } catch (e) {
      _toast(_t('photo_permission_failed'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<bool> _ensureMediaPermission(ImageSource source) async {
    final AddBankCardMediaPermission status;
    try {
      status = widget.mediaPermissionChecker == null
          ? await _checkSystemMediaPermission(source)
          : await widget.mediaPermissionChecker!(source);
    } catch (_) {
      return true;
    }
    if (status == AddBankCardMediaPermission.granted) return true;
    if (!mounted) return false;
    await _showMediaPermissionAlert(source);
    return false;
  }

  Future<AddBankCardMediaPermission> _checkSystemMediaPermission(
    ImageSource source,
  ) async {
    final permission = source == ImageSource.camera
        ? permissions.Permission.camera
        : permissions.Permission.photos;
    var status = await permission.status;
    if (_isPermissionGranted(status)) {
      return AddBankCardMediaPermission.granted;
    }
    if (status.isRestricted) {
      return AddBankCardMediaPermission.restricted;
    }
    if (!status.isPermanentlyDenied) {
      status = await permission.request();
      if (_isPermissionGranted(status)) {
        return AddBankCardMediaPermission.granted;
      }
      if (status.isRestricted) {
        return AddBankCardMediaPermission.restricted;
      }
    }
    return AddBankCardMediaPermission.denied;
  }

  bool _isPermissionGranted(permissions.PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  Future<void> _showMediaPermissionAlert(ImageSource source) async {
    await showIosCommonAlertDialog(
      context: context,
      title: source == ImageSource.camera
          ? _t('enable_camera_permission')
          : _t('enable_album_permission'),
      cancelText: _t('later'),
      confirmText: _t('setting'),
      onConfirm: () async {
        final opened = await _openSystemSettings();
        if (!opened && mounted) _toast(_t('open_settings_failed'));
      },
    );
  }

  Future<bool> _openSystemSettings() {
    final customOpen = widget.openAppSettings;
    if (customOpen != null) return customOpen();
    return launchUrl(
      Uri.parse('app-settings:'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _submit() async {
    if (_frontUrl.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final payload = Map<String, String>.from(widget.draft);
      payload['front_picture'] = _frontUrl;
      await ref.read(stServiceProvider).addBankCard(payload);
      if (!mounted) return;
      await context.push(
        '/mine/commit_success',
        extra: const {'kind': 'bank_card', 'fallbackPath': '/mine/bankcard'},
      );
      if (mounted) context.pop(true);
    } catch (e) {
      _toast(stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _mimeTypeFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  void _deletePhoto() {
    setState(() {
      _frontUrl = '';
      _frontBytes = null;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    STToast.show(context, message);
  }

  Widget _sheetItem(String title, VoidCallback onTap) {
    return Material(
      color: context.adaptiveCard,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    if (!_hasValidDraft) {
      return Scaffold(
        backgroundColor: context.adaptivePageGrey,
        appBar: AppBar(
          title: Text(_t('add_bank_voucher')),
          backgroundColor: context.adaptiveSurfacePrimary,
          foregroundColor: context.adaptiveTextPrimary,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: context.adaptiveTextPrimary),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: Text(
              _t('bank_card_info_missing'),
              style: const TextStyle(fontSize: 14, color: Color(0xFFF95959)),
            ),
          ),
        ),
      );
    }

    final holder = widget.draft['bank_name'] ?? '';
    final cardNo = widget.draft['card_number'] ?? '';

    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        title: Text(_t('add_bank_voucher')),
        backgroundColor: context.adaptiveSurfacePrimary,
        foregroundColor: context.adaptiveTextPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.adaptiveTextPrimary),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(15, 25, 15, 20),
                children: [
                  Text(
                    _t('submit_account_voucher'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_t('add_bank_card_tip_3')}\n\n* ${_t('account_name')}（$holder）\n* ${_t('account_number')}（$cardNo）',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: _pickFrontPhoto,
                        child: CustomPaint(
                          painter: _DashedRoundRectPainter(
                            context.adaptiveDivider,
                          ),
                          child: Container(
                            height: 171,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: _frontUrl.isEmpty
                                ? _uploading
                                      ? const CircularProgressIndicator()
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor:
                                                  context.adaptiveCard,
                                              child: Icon(
                                                Icons.photo_camera_outlined,
                                                color: context
                                                    .adaptiveTextSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            Text(
                                              _t('front_bank_card'),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: context
                                                    .adaptiveTextSecondary,
                                              ),
                                            ),
                                          ],
                                        )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _frontBytes == null
                                        ? Text(_frontUrl)
                                        : Image.memory(
                                            _frontBytes!,
                                            width: double.infinity,
                                            height: 171,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                          ),
                        ),
                      ),
                      if (_frontUrl.isNotEmpty)
                        Positioned(
                          top: -14,
                          right: -14,
                          child: IconButton(
                            onPressed: _deletePhoto,
                            icon: const Icon(Icons.cancel, color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 20),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B57A),
                    disabledBackgroundColor: const Color(
                      0xFF00B57A,
                    ).withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _t('submit'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankOption {
  _BankOption({required this.name, required this.swiftCode});

  final String name;
  final String swiftCode;

  factory _BankOption.fromDynamic(dynamic raw) {
    final map = raw is Map<String, dynamic>
        ? raw
        : (raw as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return _BankOption(
      name:
          map['bank_name']?.toString().trim() ??
          map['name']?.toString().trim() ??
          '',
      swiftCode:
          map['swift_code']?.toString().trim() ??
          map['swiftCode']?.toString().trim() ??
          '',
    );
  }
}

class _BankNoRecordsView extends StatelessWidget {
  const _BankNoRecordsView({
    required this.emptyText,
    required this.addText,
    required this.fullNameTip,
    required this.onAdd,
  });

  final String emptyText;
  final String addText;
  final String fullNameTip;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: context.adaptiveSurfacePrimary,
        child: Column(
          children: [
            const SizedBox(height: 59),
            Image.asset(
              'assets/images/st_mine_bank_add_empty.png',
              width: 108,
              height: 108,
              errorBuilder: (_, __, ___) =>
                  const SizedBox(width: 108, height: 108),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 140,
              height: 32,
              child: OutlinedButton(
                onPressed: onAdd,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00B57A),
                  side: const BorderSide(width: 0.5, color: Color(0xFF00B57A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text('+ $addText', style: const TextStyle(fontSize: 14)),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(68, 0, 15, 14),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '*',
                      style: TextStyle(color: Color(0xFFF95959)),
                    ),
                    TextSpan(text: fullNameTip),
                  ],
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRoundRectPainter extends CustomPainter {
  const _DashedRoundRectPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 2;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
