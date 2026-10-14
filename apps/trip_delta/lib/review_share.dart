import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'domain.dart';
import 'strings.dart';

typedef ReviewImageShare = Future<void> Function(Uint8List bytes, Rect origin);
typedef ReviewImageSave = Future<void> Function(Uint8List bytes);

Future<void> showReviewCard(BuildContext context, Trip trip, L l) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => ReviewCardSheet(trip: trip, l: l),
    );

class ReviewCardSheet extends StatefulWidget {
  const ReviewCardSheet({
    super.key,
    required this.trip,
    required this.l,
    this.shareImage,
    this.saveImage,
  });

  final Trip trip;
  final L l;
  final ReviewImageShare? shareImage;
  final ReviewImageSave? saveImage;

  @override
  State<ReviewCardSheet> createState() => _ReviewCardSheetState();
}

class _ReviewCardSheetState extends State<ReviewCardSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _working = false;
  String? _message;

  Future<Uint8List> _captureCard() async {
    final boundary = _cardKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Review card is not ready');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Review card image is empty');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  Future<void> _shareImage(Uint8List bytes, Rect origin) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/trip-delta-review-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _saveImage(Uint8List bytes) => Gal.putImageBytes(
    bytes,
    name: 'trip-delta-review-${DateTime.now().millisecondsSinceEpoch}',
  );

  Future<void> _export({required bool save, Rect? origin}) async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final bytes = await _captureCard();
      if (save) {
        await (widget.saveImage ?? _saveImage)(bytes);
        if (mounted) setState(() => _message = widget.l('cardSaved'));
      } else {
        await (widget.shareImage ?? _shareImage)(bytes, origin!);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _message = widget.l(save ? 'cardSaveFailed' : 'cardShareFailed'),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_working,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.l('reviewCard'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: widget.l('close'),
                    onPressed: _working ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: ReviewShareCard(trip: widget.trip, l: widget.l),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_message != null) ...[
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (buttonContext) => OutlinedButton.icon(
                              key: const Key('share_review_card'),
                              onPressed: _working
                                  ? null
                                  : () {
                                      final box =
                                          buttonContext.findRenderObject()
                                              as RenderBox;
                                      final origin =
                                          box.localToGlobal(Offset.zero) &
                                          box.size;
                                      _export(save: false, origin: origin);
                                    },
                              icon: const Icon(Icons.ios_share_outlined),
                              label: Text(widget.l('shareCard')),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('save_review_card'),
                            onPressed: _working
                                ? null
                                : () => _export(save: true),
                            icon: const Icon(Icons.download_outlined),
                            label: Text(widget.l('saveCard')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewShareCard extends StatelessWidget {
  const ReviewShareCard({super.key, required this.trip, required this.l});

  final Trip trip;
  final L l;

  static const _ink = Color(0xFF17312E);
  static const _muted = Color(0xFF5C6E6B);
  static const _teal = Color(0xFF0B6B63);
  static const _paper = Color(0xFFF4F7F6);
  static const _line = Color(0xFFD6E2DE);

  @override
  Widget build(BuildContext context) {
    final band = reviewBandFor(trip);
    final categoryRows = BudgetCategory.values.where(
      (item) => trip.plannedFor(item) != 0 || trip.spentFor(item) != 0,
    );
    final over = trip.deltaMinor > 0;
    final reviewed = trip.completedAt?.toLocal();
    return Container(
      key: const Key('review_card_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_outlined, color: _teal, size: 20),
              const SizedBox(width: 7),
              const Text(
                'TRIP DELTA',
                style: TextStyle(
                  color: _teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l('reviewCard'),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            trip.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          if (trip.destination.isNotEmpty || reviewed != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (trip.destination.isNotEmpty) trip.destination,
                if (reviewed != null)
                  '${l('completedOn')} ${reviewed.year}-${reviewed.month.toString().padLeft(2, '0')}-${reviewed.day.toString().padLeft(2, '0')}',
              ].join('  ·  '),
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            over ? l('over') : l('remaining'),
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              moneyText(trip.deltaMinor.abs(), trip.baseCurrency),
              style: TextStyle(
                color: over ? const Color(0xFFB44B3E) : _teal,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(child: _amount(l('planned'), trip.plannedMinor)),
                Container(width: 1, height: 42, color: _line),
                const SizedBox(width: 16),
                Expanded(child: _amount(l('recorded'), trip.spentMinor)),
              ],
            ),
          ),
          if (band != null) ...[
            const SizedBox(height: 26),
            const Divider(height: 1, color: _line),
            const SizedBox(height: 22),
            _sectionLabel(l('reviewAssessment')),
            const SizedBox(height: 8),
            Text(
              l('review_${band.name}_title'),
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l('review_${band.name}_body'),
              style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
            ),
          ],
          if (categoryRows.isNotEmpty) ...[
            const SizedBox(height: 26),
            const Divider(height: 1, color: _line),
            const SizedBox(height: 22),
            _sectionLabel(l('categoryComparison')),
            const SizedBox(height: 12),
            for (final category in categoryRows) ...[
              Row(
                children: [
                  Text(
                    l.category(category),
                    style: const TextStyle(color: _ink, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${moneyText(trip.spentFor(category), trip.baseCurrency)} / ${moneyText(trip.plannedFor(category), trip.baseCurrency)}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
            ],
            Text(
              '${l('recorded')} / ${l('planned')}',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
          if (trip.reflection.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: _line),
            const SizedBox(height: 22),
            _sectionLabel(l('nextTime')),
            const SizedBox(height: 8),
            Text(
              trip.reflection.trim(),
              style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l('reviewBasis'),
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _amount(String label, int minor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          moneyText(minor, trip.baseCurrency),
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: _teal,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );
}
