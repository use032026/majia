/// Shared card item route extraction.
///
/// Mirrors iOS item models: `routerModel` wins, then `router + link`, then a
/// link-only fallback to `/web`, preserving `router_permission`.
({String path, Map<String, dynamic>? params}) extractCardItemRoute(
  Map<String, dynamic> item,
) {
  final link = item['link'] as String? ?? '';
  final permission =
      item['router_permission'] as String? ??
      item['routerPermission'] as String?;

  final routerModel = item['routerModel'];
  if (routerModel is Map<String, dynamic>) {
    final path = routerModel['router'] as String? ?? '';
    final rawParams = routerModel['params'];
    final params = rawParams is Map<String, dynamic>
        ? Map<String, dynamic>.from(rawParams)
        : <String, dynamic>{};
    params.putIfAbsent('link', () => link);
    if (permission != null && permission.isNotEmpty) {
      final current = params['permission'];
      if (current == null || (current is String && current.isEmpty)) {
        params['permission'] = permission;
      }
    }
    if (path.isNotEmpty) return (path: path, params: params);
  }

  final router = item['router'] as String? ?? '';
  if (router.isNotEmpty) {
    final params = <String, dynamic>{};
    if (link.isNotEmpty) params['link'] = link;
    if (permission != null && permission.isNotEmpty) {
      params['permission'] = permission;
    }
    return (path: router, params: params.isEmpty ? null : params);
  }

  if (link.isNotEmpty) {
    final params = <String, dynamic>{'link': link};
    if (permission != null && permission.isNotEmpty) {
      params['permission'] = permission;
    }
    return (path: '/web', params: params);
  }

  return (path: '', params: null);
}
