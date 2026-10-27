import 'package:csv/csv.dart';

import 'data_project.dart';

class ExportBundle {
  const ExportBundle({required this.csv, required this.report});
  final String csv;
  final String report;
}

class ExportBuilder {
  const ExportBuilder();

  ExportBundle build(DataProject project, {required bool chinese}) {
    final table = <List<String>>[
      project.headers,
      ...project.records.map((row) => row.values),
    ];
    final csv = const ListToCsvConverter().convert(table);
    final report = chinese ? _chineseReport(project) : _englishReport(project);
    return ExportBundle(csv: csv, report: report);
  }

  String _chineseReport(DataProject project) =>
      '''
# ASTFX 数据质量报告

- 源文件：${project.fileName}
- 导入行数：${project.originalRecords.length}
- 导出行数：${project.records.length}
- 发现问题：${project.issues.length}
- 已修复：${project.fixedCount}
- 保留原样：${project.ignoredCount}
- 未处理：${project.openIssues.length}
- 质量分：${project.qualityScore}/100

## 变更记录

${_actions(project, chinese: true)}

本报告仅记录用户在本机确认的修改；原始 CSV 未被覆盖。报告不包含完整原始数据。
''';

  String _englishReport(DataProject project) =>
      '''
# ASTFX data quality report

- Source file: ${project.fileName}
- Imported rows: ${project.originalRecords.length}
- Exported rows: ${project.records.length}
- Issues found: ${project.issues.length}
- Fixed: ${project.fixedCount}
- Kept as-is: ${project.ignoredCount}
- Unresolved: ${project.openIssues.length}
- Quality score: ${project.qualityScore}/100

## Change log

${_actions(project, chinese: false)}

This report records only changes confirmed by the user on this device. The original CSV was not overwritten. Full source data is not embedded in this report.
''';

  String _actions(DataProject project, {required bool chinese}) {
    if (project.audit.isEmpty) {
      return chinese ? '尚无用户确认的修改。' : 'No user-confirmed changes yet.';
    }
    return project.audit
        .asMap()
        .entries
        .map((entry) {
          final action = entry.value;
          final label = switch (action.action) {
            'removedRow' => chinese ? '删除重复行' : 'Removed duplicate row',
            'ignored' => chinese ? '保留原样' : 'Kept as-is',
            _ => chinese ? '替换值' : 'Replaced value',
          };
          return '${entry.key + 1}. $label · ${action.rowId} · ${action.columnName}';
        })
        .join('\n');
  }
}
