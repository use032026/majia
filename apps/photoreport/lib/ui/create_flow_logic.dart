import '../models.dart';

List<String> reusableIssueSuggestions(Iterable<String> source) {
  final suggestions = <String>{};
  for (final value in source) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    suggestions.add(trimmed);
    if (suggestions.length == 5) break;
  }
  return suggestions.toList();
}

String quickRecordTitle(String description) {
  final trimmed = description.trim();
  final lineEnd = trimmed.indexOf('\n');
  final firstLine = (lineEnd < 0 ? trimmed : trimmed.substring(0, lineEnd))
      .trim();
  if (firstLine.isEmpty) return '图文记录';
  final runes = firstLine.runes.take(25).toList(growable: false);
  if (runes.length <= 24) return firstLine;
  return '${String.fromCharCodes(runes.take(24))}…';
}

bool hasFormalCoreFields(IssueRecord issue) {
  return issue.room.trim().isNotEmpty &&
      issue.category.trim().isNotEmpty &&
      issue.description.trim().isNotEmpty &&
      issue.photos.isNotEmpty;
}

String issueLocationLabel(IssueRecord issue) {
  final room = issue.room.trim();
  final location = issue.location.trim();
  if (room.isEmpty && location.isEmpty) return '未分类';
  if (room.isEmpty) return location;
  if (location.isEmpty) return room;
  return '$room / $location';
}

List<String> formalReadinessWarnings(
  ProjectRecord project,
  List<IssueRecord> issues,
) {
  final warnings = <String>[];
  final optionalProjectFields = <String>[
    if (project.companyName.trim().isEmpty) '企业/团队',
    if (project.inspectorName.trim().isEmpty) '记录人',
    if (project.clientName.trim().isEmpty) '业主/客户',
  ];
  if (project.address.trim().isEmpty) warnings.add('项目地点尚未填写');
  if (optionalProjectFields.isNotEmpty) {
    warnings.add('项目资料可补充：${optionalProjectFields.join('、')}');
  }
  if (issues.isEmpty) warnings.add('项目还没有现场记录');
  for (final issue in issues) {
    final label = issue.code;
    if (issue.room.trim().isEmpty) warnings.add('$label 尚未填写区域');
    if (issue.category.trim().isEmpty) warnings.add('$label 尚未填写标题');
    if (issue.description.trim().isEmpty) warnings.add('$label 尚未填写说明');
    if (issue.photos.isEmpty) warnings.add('$label 尚未添加现场照片');
    final needsFollowUp =
        issue.status == IssueStatus.pending ||
        issue.status == IssueStatus.inProgress;
    if (needsFollowUp && issue.assignee.trim().isEmpty) {
      warnings.add('$label 待跟进但未填写负责人');
    }
    if (needsFollowUp && issue.dueDate == null) {
      warnings.add('$label 待跟进但未填写期限');
    }
  }
  return warnings;
}
