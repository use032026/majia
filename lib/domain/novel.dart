class NovelChapter {
  const NovelChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int maxContentCharacters = 2000000;

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  NovelChapter copyWith({String? title, String? content, DateTime? updatedAt}) {
    return NovelChapter(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory NovelChapter.fromJson(Map<String, Object?> json) {
    final updatedAt = DateTime.parse(json['updatedAt'] as String);
    return NovelChapter(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? updatedAt,
      updatedAt: updatedAt,
    );
  }
}

class Novel {
  const Novel({
    required this.id,
    required this.title,
    required this.description,
    required this.chapters,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final List<NovelChapter> chapters;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get characterCount => chapters.fold(
    0,
    (total, chapter) => total + chapter.content.runes.length,
  );

  Novel copyWith({
    String? title,
    String? description,
    List<NovelChapter>? chapters,
    DateTime? updatedAt,
  }) {
    return Novel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      chapters: chapters ?? this.chapters,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Novel.fromJson(Map<String, Object?> json) {
    final rawChapters = json['chapters'] as List<Object?>? ?? const [];
    final updatedAt = DateTime.parse(json['updatedAt'] as String);
    return Novel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      chapters: rawChapters
          .map((value) => NovelChapter.fromJson(value! as Map<String, Object?>))
          .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? updatedAt,
      updatedAt: updatedAt,
    );
  }
}

class ImportedChapterDraft {
  const ImportedChapterDraft({required this.title, required this.content});

  final String title;
  final String content;
}

class NovelImportPlan {
  const NovelImportPlan({required this.title, required this.chapters});

  static const int maxImportCharacters = 2000000;
  static const int maxImportedChapters = 1000;

  final String title;
  final List<ImportedChapterDraft> chapters;
}

NovelImportPlan planNovelImport({
  required String fileName,
  required String content,
}) {
  final normalized = content
      .replaceFirst('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) {
    throw const FormatException('The selected text file is empty.');
  }
  if (normalized.length > NovelImportPlan.maxImportCharacters) {
    throw const FormatException('The selected text file is too large.');
  }

  final fallbackTitle = _fileStem(fileName);
  final lines = normalized.split('\n');
  final chapters = <ImportedChapterDraft>[];
  final preface = <String>[];
  String? activeTitle;
  final body = <String>[];

  void commitActive() {
    final title = activeTitle;
    if (title == null) return;
    chapters.add(
      ImportedChapterDraft(title: title, content: body.join('\n').trim()),
    );
    body.clear();
  }

  for (final line in lines) {
    final heading = _chapterHeading(line);
    if (heading != null) {
      if (activeTitle == null && preface.join('\n').trim().isNotEmpty) {
        chapters.add(
          ImportedChapterDraft(
            title: '前言 / Preface',
            content: preface.join('\n').trim(),
          ),
        );
      }
      commitActive();
      activeTitle = heading;
    } else if (activeTitle == null) {
      preface.add(line);
    } else {
      body.add(line);
    }
  }
  commitActive();

  if (chapters.isEmpty) {
    chapters.add(
      ImportedChapterDraft(title: '正文 / Main text', content: normalized),
    );
  }
  if (chapters.length > NovelImportPlan.maxImportedChapters) {
    throw const FormatException('The selected text has too many chapters.');
  }
  return NovelImportPlan(title: fallbackTitle, chapters: chapters);
}

String _fileStem(String source) {
  final normalized = source.replaceAll('\\', '/');
  final fileName = normalized.split('/').last.trim();
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  return stem.trim().isEmpty ? 'Untitled novel' : stem.trim();
}

String? _chapterHeading(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.length > 80) return null;
  final markdown = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(trimmed);
  if (markdown != null) return markdown.group(1)!.trim();
  final chinese = RegExp(
    r'^(第[0-9〇零一二三四五六七八九十百千万两]+[章节回卷篇部])(?:\s*[-—:：]\s*.{1,48}|\s+.{1,48})?$',
  ).firstMatch(trimmed);
  return chinese == null ? null : trimmed;
}
