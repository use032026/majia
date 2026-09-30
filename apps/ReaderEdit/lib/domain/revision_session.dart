import 'dart:convert';

enum ReaderSignal { unset, clear, dragging, lost }

class PassageRevision {
  const PassageRevision({
    required this.id,
    required this.original,
    required this.revised,
    this.signal = ReaderSignal.unset,
    this.note = '',
    this.isResolved = false,
  });

  final String id;
  final String original;
  final String revised;
  final ReaderSignal signal;
  final String note;
  final bool isResolved;

  bool get isFlagged =>
      signal == ReaderSignal.dragging || signal == ReaderSignal.lost;
  bool get wasChanged => original.trim() != revised.trim();

  PassageRevision copyWith({
    String? revised,
    ReaderSignal? signal,
    String? note,
    bool? isResolved,
  }) {
    return PassageRevision(
      id: id,
      original: original,
      revised: revised ?? this.revised,
      signal: signal ?? this.signal,
      note: note ?? this.note,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'original': original,
    'revised': revised,
    'signal': signal.name,
    'note': note,
    'isResolved': isResolved,
  };

  factory PassageRevision.fromJson(Map<String, Object?> json) {
    final signalName = json['signal'] as String? ?? ReaderSignal.unset.name;
    return PassageRevision(
      id: json['id'] as String,
      original: json['original'] as String,
      revised: json['revised'] as String? ?? json['original'] as String,
      signal: ReaderSignal.values.firstWhere(
        (value) => value.name == signalName,
        orElse: () => ReaderSignal.unset,
      ),
      note: json['note'] as String? ?? '',
      isResolved: json['isResolved'] as bool? ?? false,
    );
  }
}

class RevisionSession {
  const RevisionSession({
    required this.id,
    required this.title,
    required this.knowPromise,
    required this.feelPromise,
    required this.wonderPromise,
    required this.passages,
    required this.updatedAt,
    this.knowChecked = false,
    this.feelChecked = false,
    this.wonderChecked = false,
  });

  static const int maxDraftCharacters = 30000;
  static const int maxPassages = 80;

  final String id;
  final String title;
  final String knowPromise;
  final String feelPromise;
  final String wonderPromise;
  final List<PassageRevision> passages;
  final DateTime updatedAt;
  final bool knowChecked;
  final bool feelChecked;
  final bool wonderChecked;

  bool get allScanned =>
      passages.isNotEmpty &&
      passages.every((passage) => passage.signal != ReaderSignal.unset);
  int get flaggedCount => passages.where((passage) => passage.isFlagged).length;
  int get unresolvedCount => passages
      .where((passage) => passage.isFlagged && !passage.isResolved)
      .length;
  int get changedCount =>
      passages.where((passage) => passage.wasChanged).length;
  bool get promisesChecked => knowChecked && feelChecked && wonderChecked;
  bool get isComplete => allScanned && unresolvedCount == 0 && promisesChecked;

  String get revisedDraft =>
      passages.map((passage) => passage.revised.trim()).join('\n\n');

  String revisionLog({required bool chinese}) {
    final buffer = StringBuffer()
      ..writeln(chinese ? '《$title》修订记录' : 'Revision log — $title')
      ..writeln()
      ..writeln(
        chinese
            ? '读者承诺：知道「$knowPromise」；感受「$feelPromise」；好奇「$wonderPromise」。'
            : 'Reader promise: know "$knowPromise"; feel "$feelPromise"; wonder "$wonderPromise".',
      )
      ..writeln();

    final changed = passages.where((passage) => passage.wasChanged).toList();
    if (changed.isEmpty) {
      buffer.writeln(chinese ? '本次没有正文改动。' : 'No passage text was changed.');
    } else {
      for (var index = 0; index < changed.length; index++) {
        final passage = changed[index];
        buffer
          ..writeln(chinese ? '修改 ${index + 1}' : 'Change ${index + 1}')
          ..writeln(
            chinese ? '修改前：${passage.original}' : 'Before: ${passage.original}',
          )
          ..writeln(
            chinese ? '修改后：${passage.revised}' : 'After: ${passage.revised}',
          );
        if (passage.note.trim().isNotEmpty) {
          buffer.writeln(
            chinese ? '读者备注：${passage.note}' : 'Reader note: ${passage.note}',
          );
        }
        buffer.writeln();
      }
    }
    return buffer.toString().trimRight();
  }

  RevisionSession copyWith({
    List<PassageRevision>? passages,
    DateTime? updatedAt,
    bool? knowChecked,
    bool? feelChecked,
    bool? wonderChecked,
  }) {
    return RevisionSession(
      id: id,
      title: title,
      knowPromise: knowPromise,
      feelPromise: feelPromise,
      wonderPromise: wonderPromise,
      passages: passages ?? this.passages,
      updatedAt: updatedAt ?? this.updatedAt,
      knowChecked: knowChecked ?? this.knowChecked,
      feelChecked: feelChecked ?? this.feelChecked,
      wonderChecked: wonderChecked ?? this.wonderChecked,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'knowPromise': knowPromise,
    'feelPromise': feelPromise,
    'wonderPromise': wonderPromise,
    'passages': passages.map((passage) => passage.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
    'knowChecked': knowChecked,
    'feelChecked': feelChecked,
    'wonderChecked': wonderChecked,
  };

  String encode() => jsonEncode(toJson());

  factory RevisionSession.fromJson(Map<String, Object?> json) {
    final rawPassages = json['passages'] as List<Object?>? ?? const [];
    return RevisionSession(
      id: json['id'] as String,
      title: json['title'] as String,
      knowPromise: json['knowPromise'] as String,
      feelPromise: json['feelPromise'] as String,
      wonderPromise: json['wonderPromise'] as String,
      passages: rawPassages
          .map(
            (value) => PassageRevision.fromJson(value! as Map<String, Object?>),
          )
          .toList(growable: false),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      knowChecked: json['knowChecked'] as bool? ?? false,
      feelChecked: json['feelChecked'] as bool? ?? false,
      wonderChecked: json['wonderChecked'] as bool? ?? false,
    );
  }

  factory RevisionSession.decode(String source) =>
      RevisionSession.fromJson(jsonDecode(source) as Map<String, Object?>);
}

List<String> splitDraft(String source) {
  final normalized = source.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return const [];
  }
  return normalized
      .split(RegExp(r'\n\s*\n+'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .toList(growable: false);
}

int countCjkCharacters(String source) {
  return RegExp(
    r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]',
  ).allMatches(source).length;
}

int countLatinWords(String source) {
  return RegExp(
    r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*",
  ).allMatches(source).length;
}
