import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Mirrors iOS `STLoginTextFieldTypeName` / bank-card username CN fields.
///
/// The implementation follows iOS' `shouldChangeCharactersInRange` branches
/// first, then applies the same no-marked-text cleanup used by `textChanged`.
class AuthNameInputFormatter extends TextInputFormatter {
  const AuthNameInputFormatter({required this.countryKey});

  final String countryKey;

  static final RegExp _whitespace = RegExp(r'\s');

  static String filterChineseName(String value) {
    return _filteredChineseNameTextFromString(value);
  }

  static bool cleanControllerText(
    TextEditingController controller, {
    required String countryKey,
  }) {
    if (countryKey.toUpperCase() != 'CN') return false;
    final value = controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) return false;
    final filtered = _filteredChineseNameTextFromString(value.text);
    if (filtered == value.text) return false;
    final cursor = _filteredChineseNameOffsetFor(
      value.text,
      value.selection.baseOffset,
    );
    controller.value = TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
    return true;
  }

  static bool _isDotRune(int rune) =>
      rune == 0x00B7 || rune == 0x30FB || rune == 0x2022;

  static bool _isAllowedCnNameRune(int rune) {
    if (rune == 0x00B7) return true;
    return (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF);
  }

  static bool _isComposingRune(int rune) =>
      (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);

  static bool _containsDotCharacter(String value) {
    return value.runes.any(_isDotRune);
  }

  static bool _canInputReplacementString(String value) {
    for (final rune in value.runes) {
      if (!_isAllowedCnNameRune(rune) &&
          !_isDotRune(rune) &&
          !_isComposingRune(rune)) {
        return false;
      }
    }
    return true;
  }

  static String _filteredChineseNameTextFromString(String value) {
    final buffer = StringBuffer();
    var previousWasDot = false;
    for (final rune in value.runes) {
      if (_isDotRune(rune)) {
        if (!previousWasDot) {
          buffer.write('·');
          previousWasDot = true;
        }
      } else if (_isAllowedCnNameRune(rune)) {
        buffer.write(String.fromCharCode(rune));
        previousWasDot = false;
      }
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final normalizedCountry = countryKey.toUpperCase();
    if (normalizedCountry != 'CN') {
      return newValue;
    }
    final edit = _inferEditDelta(oldValue, newValue);
    return _formatChineseNameLikeIos(oldValue, newValue, edit);
  }

  static TextEditingValue _formatChineseNameLikeIos(
    TextEditingValue oldValue,
    TextEditingValue newValue,
    _IosNameEditDelta edit,
  ) {
    final oldRunes = oldValue.text.runes.toList();
    final replacement = edit.replacement;

    if (replacement.contains(_whitespace)) {
      return _rejectEdit(oldValue, edit);
    }

    if (replacement.isNotEmpty && _containsDotCharacter(replacement)) {
      var filteredReplacement = _filteredChineseNameTextFromString(replacement);
      var replaceLocation = edit.location;
      var replaceLength = edit.length;
      if (filteredReplacement.isNotEmpty &&
          edit.length > 0 &&
          edit.location + edit.length == oldRunes.length) {
        replaceLocation = oldRunes.length;
        replaceLength = 0;
      }
      if (filteredReplacement.isNotEmpty &&
          filteredReplacement.runes.first == 0x00B7 &&
          replaceLocation > 0 &&
          oldRunes[replaceLocation - 1] == 0x00B7) {
        filteredReplacement = String.fromCharCodes(
          filteredReplacement.runes.skip(1),
        );
      }
      if (filteredReplacement.isNotEmpty &&
          filteredReplacement.runes.last == 0x00B7 &&
          replaceLocation + replaceLength < oldRunes.length &&
          oldRunes[replaceLocation + replaceLength] == 0x00B7) {
        final runes = filteredReplacement.runes.toList();
        filteredReplacement = String.fromCharCodes(
          runes.take(runes.length - 1),
        );
      }
      if (filteredReplacement.isEmpty) {
        return _rejectEdit(oldValue, edit);
      }
      final text = _replaceRunes(
        oldRunes,
        replaceLocation,
        replaceLength,
        filteredReplacement,
      );
      return _withCursor(
        _filteredChineseNameTextFromString(text),
        replaceLocation + filteredReplacement.runes.length,
      );
    }

    if (replacement.isNotEmpty && !_canInputReplacementString(replacement)) {
      final filteredReplacement = _filteredChineseNameTextFromString(
        replacement,
      );
      if (filteredReplacement.isEmpty) {
        if (edit.length == 0) {
          return newValue;
        }
        return _rejectEdit(oldValue, edit);
      }
      final text = _replaceRunes(
        oldRunes,
        edit.location,
        edit.length,
        filteredReplacement,
      );
      return _withCursor(
        _filteredChineseNameTextFromString(text),
        edit.location + filteredReplacement.runes.length,
      );
    }

    return _withFilteredChineseNameSelection(newValue);
  }

  static _IosNameEditDelta _inferEditDelta(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldRunes = oldValue.text.runes.toList();
    final newRunes = newValue.text.runes.toList();
    final selectedEdit = _inferSelectedEditDelta(
      oldValue.selection,
      oldRunes,
      newRunes,
    );
    if (selectedEdit != null) return selectedEdit;

    var prefixLength = 0;
    while (prefixLength < oldRunes.length &&
        prefixLength < newRunes.length &&
        oldRunes[prefixLength] == newRunes[prefixLength]) {
      prefixLength += 1;
    }
    var suffixLength = 0;
    while (suffixLength < oldRunes.length - prefixLength &&
        suffixLength < newRunes.length - prefixLength &&
        oldRunes[oldRunes.length - 1 - suffixLength] ==
            newRunes[newRunes.length - 1 - suffixLength]) {
      suffixLength += 1;
    }
    final replacementRunes = newRunes.sublist(
      prefixLength,
      newRunes.length - suffixLength,
    );
    return _IosNameEditDelta(
      location: prefixLength,
      length: oldRunes.length - prefixLength - suffixLength,
      replacement: String.fromCharCodes(replacementRunes),
    );
  }

  static _IosNameEditDelta? _inferSelectedEditDelta(
    TextSelection selection,
    List<int> oldRunes,
    List<int> newRunes,
  ) {
    if (!selection.isValid || selection.isCollapsed) return null;
    final start = selection.start;
    final end = selection.end;
    if (start < 0 || end < start || end > oldRunes.length) return null;
    final suffixLength = oldRunes.length - end;
    final replacementEnd = newRunes.length - suffixLength;
    if (replacementEnd < start) return null;
    for (var i = 0; i < start; i++) {
      if (oldRunes[i] != newRunes[i]) return null;
    }
    for (var i = 0; i < suffixLength; i++) {
      if (oldRunes[end + i] != newRunes[replacementEnd + i]) return null;
    }
    return _IosNameEditDelta(
      location: start,
      length: end - start,
      replacement: String.fromCharCodes(
        newRunes.sublist(start, replacementEnd),
      ),
    );
  }

  static String _replaceRunes(
    List<int> oldRunes,
    int location,
    int length,
    String replacement,
  ) {
    return String.fromCharCodes(<int>[
      ...oldRunes.take(location),
      ...replacement.runes,
      ...oldRunes.skip(location + length),
    ]);
  }

  static TextEditingValue _withCursor(String text, int offset) {
    final cursor = offset.clamp(0, text.runes.length).toInt();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue _rejectEdit(
    TextEditingValue oldValue,
    _IosNameEditDelta edit,
  ) {
    if (oldValue.selection.isValid) {
      return oldValue.copyWith(composing: TextRange.empty);
    }
    return _withCursor(oldValue.text, edit.location + edit.length);
  }

  static TextEditingValue _withFilteredChineseNameSelection(
    TextEditingValue value,
  ) {
    final filtered = _filteredChineseNameTextFromString(value.text);
    if (filtered == value.text) {
      return value.copyWith(composing: TextRange.empty);
    }
    return TextEditingValue(
      text: filtered,
      selection: _filteredChineseNameSelectionFor(value, filtered),
      composing: TextRange.empty,
    );
  }

  static TextSelection _filteredChineseNameSelectionFor(
    TextEditingValue value,
    String filtered,
  ) {
    final selection = value.selection;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: filtered.length);
    }
    return TextSelection(
      baseOffset: _filteredChineseNameOffsetFor(
        value.text,
        selection.baseOffset,
      ),
      extentOffset: _filteredChineseNameOffsetFor(
        value.text,
        selection.extentOffset,
      ),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  static int _filteredChineseNameOffsetFor(String text, int offset) {
    if (offset < 0) {
      return _filteredChineseNameTextFromString(text).length;
    }
    final clamped = offset.clamp(0, text.length).toInt();
    return _filteredChineseNameTextFromString(
      text.substring(0, clamped),
    ).length;
  }
}

class _IosNameEditDelta {
  const _IosNameEditDelta({
    required this.location,
    required this.length,
    required this.replacement,
  });

  final int location;
  final int length;
  final String replacement;
}
