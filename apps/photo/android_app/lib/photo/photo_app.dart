import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'launch_experience.dart';

class JufuApp extends StatelessWidget {
  const JufuApp({
    super.key,
    required this.settings,
    required this.preferences,
    required this.onOpenTrade,
  });

  final AppSettingsController settings;
  final SharedPreferences preferences;
  final Future<void> Function() onOpenTrade;

  @override
  Widget build(BuildContext context) => AppSettingsScope(
    controller: settings,
    child: AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        title: 'Jufu',
        debugShowCheckedModeBanner: false,
        locale: settings.locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppPalette.leaf,
            surface: AppPalette.paper,
          ),
          sliderTheme: const SliderThemeData(
            trackHeight: 3,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
        ),
        home: LaunchExperience(
          preferences: preferences,
          editorBuilder: (context) => PhotoEditorPage(onOpenTrade: onOpenTrade),
        ),
      ),
    ),
  );
}

class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({super.key, required this.onOpenTrade});

  final Future<void> Function() onOpenTrade;
  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  static const _photos = MethodChannel('jufu/photos');
  static const _watermarkColors = [
    Colors.white,
    Color(0xFFF4EEF8),
    Color(0xFF2B2232),
    Color(0xFF4A334F),
    Color(0xFF725286),
    Color(0xFFA470A5),
    Color(0xFFC3A2E2),
    Color(0xFF9B9BE5),
    Color(0xFF6270A6),
    Color(0xFF55728D),
    Color(0xFF4E7F7A),
    Color(0xFFA7A08D),
    Color(0xFF806F67),
    Color(0xFFB66F52),
    Color(0xFF9B4E67),
    Color(0xFFDE8DAA),
    Color(0xFFFFCFA0),
    Color(0xFFD8B36A),
  ];
  final _picker = ImagePicker();
  final _captureKey = GlobalKey();
  final _watermark = TextEditingController();
  final _toolPages = PageController(viewportFraction: .94);
  XFile? _photo;
  double _sourceRatio = 4 / 5;
  Offset _markPosition = const Offset(.5, .82);
  Offset _cropOffset = Offset.zero;
  double _markSize = 1;
  double _markOpacity = .92;
  double _cropZoom = 1;
  double _cropZoomAtGestureStart = 1;
  double _brightness = 0;
  double _effectIntensity = 1;
  Color _watermarkColor = Colors.white;
  PhotoEffect _effect = PhotoEffect.fresh;
  CropPreset _crop = CropPreset.original;
  int _toolPage = 0;
  bool _saving = false;
  bool _showOriginal = false;
  bool _hasPreparedWatermark = false;

  double get _ratio => _crop.ratio ?? _sourceRatio;
  double get _toolCardHeight => 270;

  @override
  void dispose() {
    _watermark.dispose();
    _toolPages.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPreparedWatermark) {
      _watermark.text = context.l('Shine in your own way');
      _hasPreparedWatermark = true;
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (file == null) return;
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (!mounted) return;
    setState(() {
      _photo = file;
      _sourceRatio = image.width / image.height;
    });
    image.dispose();
    codec.dispose();
  }

  void _reset() {
    _watermark.text = context.l('Shine in your own way');
    _markPosition = const Offset(.5, .82);
    _cropOffset = Offset.zero;
    _markSize = 1;
    _markOpacity = .92;
    _cropZoom = 1;
    _brightness = 0;
    _effectIntensity = 1;
    _watermarkColor = Colors.white;
    _effect = PhotoEffect.fresh;
    _crop = CropPreset.original;
  }

  Future<void> _save() async {
    final boundary = _captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    setState(() => _saving = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List();
      if (bytes == null) throw StateError('image capture failed');
      await _photos.invokeMethod<void>('saveImage', {'bytes': bytes});
      if (mounted) {
        _message(context.l('Saved to Photos'), Icons.check_circle_rounded);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        _message(
          e.message ??
              context.l('Couldn’t save. Check Photo Library permission.'),
          Icons.error_outline_rounded,
          error: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          context.l('Couldn’t save. Check Photo Library permission.'),
          Icons.error_outline_rounded,
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, IconData icon, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AppPalette.berry : AppPalette.ink,
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Text(text),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(child: _photo == null ? _emptyLayout() : _editorLayout()),
  );

  Widget _emptyLayout() => ListView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    children: [_header(), const SizedBox(height: 24), _empty()],
  );

  Widget _editorLayout() {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _header(),
        ),
        const SizedBox(height: 12),
        if (keyboardOpen)
          const SizedBox(height: 0)
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _preview(),
            ),
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _controls(),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _saveButton(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _header() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l('Jufu'),
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(width: 3),
                IconButton(
                  tooltip: context.l('Settings'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SettingsPage(onOpenTrade: widget.onOpenTrade),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  color: AppPalette.moss,
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              context.l('A refined finish for every photo'),
              style: const TextStyle(fontSize: 13, color: AppPalette.moss),
            ),
          ],
        ),
      ),
      if (_photo != null) ...[
        TextButton(
          onPressed: () => setState(_reset),
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.leaf,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: Text(context.l('Reset')),
        ),
        const SizedBox(width: 2),
      ],
      TextButton.icon(
        onPressed: _pickPhoto,
        icon: const Icon(Icons.photo_library_outlined, size: 19),
        label: Text(
          context.l(_photo == null ? 'Choose Photo' : 'Replace Photo'),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.ink,
          backgroundColor: AppPalette.mint,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  Widget _empty() => Container(
    margin: const EdgeInsets.only(top: 40),
    padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
    decoration: BoxDecoration(
      color: AppPalette.paper,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white),
    ),
    child: Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: const BoxDecoration(
            color: AppPalette.mint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_mosaic_rounded,
            color: AppPalette.leaf,
            size: 42,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.l('Make the moment yours'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppPalette.ink,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          context.l(
            'Add a personal watermark and a soft effect,\nthen save a version made for you.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            height: 1.55,
            fontSize: 14,
            color: AppPalette.moss,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(context.l('Choose from Photos')),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppPalette.leaf,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _preview() => LayoutBuilder(
    builder: (context, constraints) {
      final canvas = _previewCanvas();
      if (!constraints.hasBoundedHeight) {
        return AspectRatio(aspectRatio: _ratio, child: canvas);
      }
      return Center(
        child: AspectRatio(aspectRatio: _ratio, child: canvas),
      );
    },
  );

  Widget _previewCanvas() {
    final photo = _photo!;
    return RepaintBoundary(
      key: _captureKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: LayoutBuilder(
          builder: (context, box) {
            final markInset = box.maxWidth < 32 ? 0.0 : 8.0;
            final markWidth = (box.maxWidth - markInset * 2)
                .clamp(0.0, 300.0)
                .toDouble();
            final markLeft = (_markPosition.dx * box.maxWidth - markWidth / 2)
                .clamp(markInset, box.maxWidth - markWidth - markInset)
                .toDouble();
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _toolPage == 2
                  ? (_) => _cropZoomAtGestureStart = _cropZoom
                  : null,
              onScaleUpdate: _toolPage == 2
                  ? (event) => _updateCropGesture(event, box)
                  : null,
              onLongPressStart: _toolPage == 0
                  ? (_) => setState(() => _showOriginal = true)
                  : null,
              onLongPressEnd: _toolPage == 0
                  ? (_) => setState(() => _showOriginal = false)
                  : null,
              onLongPressCancel: _toolPage == 0
                  ? () => setState(() => _showOriginal = false)
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      _showOriginal
                          ? PhotoEffect.original.matrix
                          : _effect.matrixAt(_effectIntensity),
                    ),
                    child: Transform.translate(
                      offset: Offset(
                        _cropOffset.dx * box.maxWidth,
                        _cropOffset.dy * box.maxHeight,
                      ),
                      child: Transform.scale(
                        scale: _cropZoom,
                        child: Image.file(File(photo.path), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  if (_brightness != 0 && !_showOriginal)
                    ColoredBox(
                      color: (_brightness > 0 ? Colors.white : Colors.black)
                          .withValues(alpha: _brightness.abs() * .24),
                    ),
                  if (_effect.tint != null && !_showOriginal)
                    ColoredBox(
                      color: _effect.tint!.withValues(
                        alpha: (_effect.tint!.a / 255) * _effectIntensity,
                      ),
                    ),
                  if (_showOriginal)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _PreviewBadge(label: context.l('Original')),
                      ),
                    ),
                  if (_watermark.text.trim().isNotEmpty && !_showOriginal)
                    Positioned(
                      left: markLeft,
                      top: (_markPosition.dy * box.maxHeight - 28).clamp(
                        0.0,
                        (box.maxHeight - 56).clamp(0.0, double.infinity),
                      ),
                      width: markWidth,
                      child: GestureDetector(
                        onPanUpdate: (event) => setState(
                          () => _markPosition = Offset(
                            ((_markPosition.dx * box.maxWidth +
                                        event.delta.dx) /
                                    box.maxWidth)
                                .clamp(.08, .92),
                            ((_markPosition.dy * box.maxHeight +
                                        event.delta.dy) /
                                    box.maxHeight)
                                .clamp(.08, .92),
                          ),
                        ),
                        child: Text(
                          _watermark.text,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _watermarkColor.withValues(
                              alpha: _markOpacity,
                            ),
                            fontWeight: FontWeight.w800,
                            fontSize: 22 * _markSize,
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _updateCropGesture(ScaleUpdateDetails event, BoxConstraints box) {
    if (box.maxWidth <= 0 || box.maxHeight <= 0) return;
    setState(() {
      _cropZoom = (_cropZoomAtGestureStart * event.scale).clamp(1.0, 2.4);
      _cropOffset = Offset(
        (_cropOffset.dx + event.focalPointDelta.dx / box.maxWidth).clamp(
          -.35,
          .35,
        ),
        (_cropOffset.dy + event.focalPointDelta.dy / box.maxHeight).clamp(
          -.35,
          .35,
        ),
      );
    });
  }

  Widget _controls() => Column(
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: _toolCardHeight,
        child: PageView(
          controller: _toolPages,
          onPageChanged: (index) => setState(() => _toolPage = index),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SingleChildScrollView(child: _effectCard()),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SingleChildScrollView(child: _watermarkCard()),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SingleChildScrollView(child: _cropCard()),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 3; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _toolPage == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _toolPage == index
                    ? AppPalette.leaf
                    : AppPalette.sage.withValues(alpha: .38),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            context.l(switch (_toolPage) {
              0 => 'Swipe left to edit the watermark',
              1 => 'Swipe left to adjust the crop',
              _ => 'Swipe right to edit the watermark',
            }),
            style: const TextStyle(fontSize: 12, color: AppPalette.moss),
          ),
        ],
      ),
    ],
  );

  Widget _cropCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppPalette.paper,
      borderRadius: BorderRadius.circular(23),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.crop_rounded, size: 19, color: AppPalette.leaf),
            const SizedBox(width: 7),
            Text(
              context.l('Crop Photo'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _cropOffset = Offset.zero;
                _cropZoom = _crop == CropPreset.original ? 1 : 1.12;
              }),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.leaf,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                context.l('Reset Position'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          context.l('Crop Ratio'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CropPreset.values
              .map(
                (item) => ChoiceChip(
                  label: Text(item.label(context)),
                  selected: item == _crop,
                  onSelected: (_) => setState(() {
                    _crop = item;
                    _cropZoom = item == CropPreset.original ? 1 : 1.12;
                    _cropOffset = Offset.zero;
                  }),
                  selectedColor: AppPalette.mint,
                  backgroundColor: AppPalette.canvas,
                  side: BorderSide(
                    color: item == _crop
                        ? Colors.transparent
                        : AppPalette.sage.withValues(alpha: .45),
                  ),
                  labelStyle: TextStyle(
                    color: item == _crop ? AppPalette.ink : AppPalette.moss,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: const StadiumBorder(),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: _crop == CropPreset.original ? .42 : 1,
          child: IgnorePointer(
            ignoring: _crop == CropPreset.original,
            child: _slider(
              context.l('Zoom'),
              Icons.zoom_in_map_outlined,
              _cropZoom,
              1,
              2.4,
              (value) => setState(() => _cropZoom = value),
            ),
          ),
        ),
        Text(
          context.l('Drag to compose; pinch to zoom and sync the crop scale.'),
          style: const TextStyle(fontSize: 12, color: AppPalette.moss),
        ),
      ],
    ),
  );

  Widget _effectCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppPalette.paper,
      borderRadius: BorderRadius.circular(23),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.filter_vintage_outlined,
              size: 19,
              color: AppPalette.leaf,
            ),
            SizedBox(width: 7),
            Text(
              context.l('Photo Effects'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: PhotoEffect.values
                .where((item) => item != PhotoEffect.grayWhite)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: ChoiceChip(
                      label: Text(item.label(context)),
                      selected: item == _effect,
                      onSelected: (_) => setState(() => _effect = item),
                      selectedColor: AppPalette.mint,
                      backgroundColor: AppPalette.canvas,
                      side: BorderSide(
                        color: item == _effect
                            ? Colors.transparent
                            : AppPalette.sage.withValues(alpha: .45),
                      ),
                      labelStyle: TextStyle(
                        color: item == _effect
                            ? AppPalette.ink
                            : AppPalette.moss,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Opacity(
          opacity: _effect == PhotoEffect.original ? .42 : 1,
          child: IgnorePointer(
            ignoring: _effect == PhotoEffect.original,
            child: _slider(
              context.l('Effect Strength'),
              Icons.tune_rounded,
              _effectIntensity,
              0,
              1,
              (value) => setState(() => _effectIntensity = value),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: Color(0x336D5A80)),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l('Monochrome'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    context.l('Soft, low-saturation monochrome'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.moss,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _effect == PhotoEffect.grayWhite,
              activeTrackColor: AppPalette.leaf,
              onChanged: (enabled) => setState(
                () => _effect = enabled
                    ? PhotoEffect.grayWhite
                    : PhotoEffect.original,
              ),
            ),
          ],
        ),
        _slider(
          context.l('Brightness'),
          Icons.wb_sunny_outlined,
          _brightness,
          -1,
          1,
          (value) => setState(() => _brightness = value),
        ),
        const SizedBox(height: 2),
        Text(
          context.l('Press and hold the photo to compare.'),
          style: const TextStyle(fontSize: 12, color: AppPalette.moss),
        ),
      ],
    ),
  );

  Widget _watermarkCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppPalette.paper,
      borderRadius: BorderRadius.circular(23),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.text_fields_rounded, size: 19, color: AppPalette.leaf),
            SizedBox(width: 7),
            Text(
              context.l('Text Watermark'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.canvas,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _watermark,
            maxLength: 28,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              counterText: '',
              prefixIcon: Icon(
                Icons.text_fields_rounded,
                color: AppPalette.leaf,
              ),
              hintText: context.l('Enter a watermark'),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l('Text Color'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _watermarkColors
                  .map(
                    (color) => Padding(
                      padding: const EdgeInsets.only(right: 11),
                      child: GestureDetector(
                        onTap: () => setState(() => _watermarkColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == _watermarkColor
                                  ? AppPalette.leaf
                                  : AppPalette.sage.withValues(alpha: .55),
                              width: color == _watermarkColor ? 3 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x16000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _slider(
          context.l('Text Size'),
          Icons.format_size_rounded,
          _markSize,
          .65,
          1.7,
          (value) => setState(() => _markSize = value),
        ),
        _slider(
          context.l('Text Opacity'),
          Icons.opacity_rounded,
          _markOpacity,
          .35,
          1,
          (value) => setState(() => _markOpacity = value),
        ),
        const SizedBox(height: 4),
        Text(
          context.l('Long press and drag the watermark to position it.'),
          style: const TextStyle(fontSize: 12, color: AppPalette.moss),
        ),
      ],
    ),
  );

  Widget _slider(
    String name,
    IconData icon,
    double value,
    double min,
    double max,
    ValueChanged<double> callback,
  ) => Row(
    children: [
      Icon(icon, color: AppPalette.leaf, size: 19),
      const SizedBox(width: 8),
      Text(name, style: const TextStyle(fontSize: 14, color: AppPalette.ink)),
      const SizedBox(width: 10),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          activeColor: AppPalette.leaf,
          onChanged: callback,
        ),
      ),
    ],
  );

  Widget _saveButton() => FilledButton.icon(
    onPressed: _saving ? null : _save,
    icon: _saving
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.save_alt_rounded),
    label: Text(context.l(_saving ? 'Saving…' : 'Save to Photos')),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      backgroundColor: AppPalette.leaf,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppPalette.leaf.withValues(alpha: .6),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    ),
  );
}

enum PhotoEffect {
  original('Original', _identity, null),
  fresh('Lilac', _fresh, Color(0x1F9A82C4)),
  warm('Warm', _warm, Color(0x1FFFAC57)),
  film('Film', _film, Color(0x12DAB37B)),
  cinema('Cinema', _cinema, Color(0x171B7E8C)),
  dusk('Dusk', _dusk, Color(0x1A8266B8)),
  golden('Golden', _golden, Color(0x16E5A550)),
  noir('Noir', _noir, Color(0x166E4C36)),
  mist('Mist', _mist, Color(0x1F9F9AD3)),
  grayWhite('Mono', _mono, null);

  const PhotoEffect(this.localizationKey, this.matrix, this.tint);
  final String localizationKey;
  final List<double> matrix;
  final Color? tint;

  String label(BuildContext context) => context.l(localizationKey);

  List<double> matrixAt(double intensity) => List<double>.generate(
    matrix.length,
    (index) =>
        PhotoEffect._identity[index] +
        (matrix[index] - PhotoEffect._identity[index]) * intensity,
  );
  static const _identity = <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _fresh = <double>[
    1.04,
    0,
    0,
    0,
    0,
    0,
    1.05,
    0,
    0,
    5,
    0,
    0,
    .92,
    0,
    2,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _warm = <double>[
    1.10,
    0,
    0,
    0,
    10,
    0,
    1,
    0,
    0,
    3,
    0,
    0,
    .88,
    0,
    -4,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _film = <double>[
    .94,
    .04,
    .02,
    0,
    18,
    .02,
    .95,
    .03,
    0,
    13,
    .01,
    .03,
    .90,
    0,
    9,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _cinema = <double>[
    1.16,
    -.05,
    -.08,
    0,
    8,
    -.03,
    1.04,
    -.05,
    0,
    3,
    -.10,
    .02,
    .87,
    0,
    -4,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _dusk = <double>[
    .92,
    .01,
    .12,
    0,
    4,
    .01,
    .92,
    .08,
    0,
    1,
    .09,
    .02,
    1.10,
    0,
    10,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _golden = <double>[
    1.13,
    .02,
    -.05,
    0,
    12,
    .02,
    1.04,
    -.03,
    0,
    7,
    -.04,
    .01,
    .86,
    0,
    -2,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _noir = <double>[
    .42,
    .42,
    .16,
    0,
    2,
    .42,
    .42,
    .16,
    0,
    2,
    .42,
    .42,
    .16,
    0,
    2,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _mist = <double>[
    .92,
    0,
    0,
    0,
    9,
    0,
    .99,
    0,
    0,
    8,
    0,
    0,
    1.10,
    0,
    12,
    0,
    0,
    0,
    1,
    0,
  ];
  static const _mono = <double>[
    .5,
    .5,
    .5,
    0,
    5,
    .5,
    .5,
    .5,
    0,
    5,
    .5,
    .5,
    .5,
    0,
    5,
    0,
    0,
    0,
    1,
    0,
  ];
}

enum CropPreset {
  original('Original', null),
  square('1:1', 1),
  portrait('4:5', .8),
  story('9:16', .5625);

  const CropPreset(this.localizationKey, this.ratio);
  final String localizationKey;
  final double? ratio;

  String label(BuildContext context) => context.l(localizationKey);
}

abstract final class AppPalette {
  static const canvas = Color(0xFFF8F5FC);
  static const paper = Color(0xFFFFFDFF);
  static const mint = Color(0xFFE9E0F7);
  static const sage = Color(0xFFB9A8CF);
  static const leaf = Color(0xFF725286);
  static const moss = Color(0xFF66576F);
  static const ink = Color(0xFF2B2232);
  static const berry = Color(0xFFA84F72);
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xCC2B2232),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
