import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../l10n/app_localizations.dart';

enum ReportLayout { concise, detailed }

class ReportOptions {
  const ReportOptions({
    this.layout = ReportLayout.concise,
    this.includePosition = false,
    this.includeStatus = false,
    this.includeSeverity = false,
    this.includeAssignee = false,
    this.includeDueDate = false,
    this.includeProjectDetails = false,
    this.includeNotes = false,
  });

  final ReportLayout layout;
  final bool includePosition;
  final bool includeStatus;
  final bool includeSeverity;
  final bool includeAssignee;
  final bool includeDueDate;
  final bool includeProjectDetails;
  final bool includeNotes;

  Map<String, Object> toMap() => {
    'layout': layout.name,
    'includePosition': includePosition,
    'includeStatus': includeStatus,
    'includeSeverity': includeSeverity,
    'includeAssignee': includeAssignee,
    'includeDueDate': includeDueDate,
    'includeProjectDetails': includeProjectDetails,
    'includeNotes': includeNotes,
  };
}

class ReportService {
  const ReportService();

  static const channel = MethodChannel('com.starburst.photo_report/report');

  Future<String> generateReport(
    ProjectRecord project,
    List<IssueRecord> issues,
    ReportOptions options, {
    String? languageCode,
  }) async {
    final reportLanguage =
        languageCode ?? AppLocalizations.activeLocale.languageCode;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final path = await channel.invokeMethod<String>('generateReport', {
      'languageCode': reportLanguage,
      'project': {
        'name': project.name,
        'address': project.address,
        'companyName': project.companyName,
        'inspectorName': project.inspectorName,
        'clientName': project.clientName,
        'inspectionDate': dateFormat.format(project.inspectionDate),
        'notes': project.notes,
      },
      'issues': issues
          .map(
            (issue) => {
              'code': issue.code,
              'room': issue.room,
              'location': issue.location,
              'category': issue.category,
              'severity': issue.severity.label,
              'status': issue.status.label,
              'description': issue.description,
              'assignee': issue.assignee,
              'dueDate': issue.dueDate == null
                  ? ''
                  : dateFormat.format(issue.dueDate!),
              'photos': issue.photos
                  .map(
                    (photo) => {
                      'path': photo.path,
                      'phase': photo.phase.label,
                      'annotations': photo.annotations
                          .map(
                            (annotation) => {
                              'kind': annotation.kind.name,
                              'x1': annotation.x1,
                              'y1': annotation.y1,
                              'x2': annotation.x2,
                              'y2': annotation.y2,
                              'text': annotation.text,
                              'color': annotation.colorValue,
                            },
                          )
                          .toList(),
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'options': options.toMap(),
    });
    if (path == null || path.isEmpty) {
      throw PlatformException(
        code: 'empty_path',
        message: tr('报告生成成功但未返回文件地址'),
      );
    }
    return path;
  }

  Future<void> preview(String path, {String? languageCode}) {
    return channel.invokeMethod<void>('previewReport', {
      'path': path,
      'languageCode':
          languageCode ?? AppLocalizations.activeLocale.languageCode,
    });
  }

  Future<void> share(String path, {String? languageCode}) {
    return channel.invokeMethod<void>('shareReport', {
      'path': path,
      'languageCode':
          languageCode ?? AppLocalizations.activeLocale.languageCode,
    });
  }

  Future<String?> pickBackup({String? languageCode}) {
    return channel.invokeMethod<String>('pickBackup', {
      'languageCode':
          languageCode ?? AppLocalizations.activeLocale.languageCode,
    });
  }
}
