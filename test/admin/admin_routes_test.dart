import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/admin/admin_routes.dart';
import 'package:knowledge_flow/features/admin/domain/admin_nav.dart';

List<String> _paths(List<RouteBase> routes) => [
      for (final r in routes) ...[
        if (r is GoRoute) r.path,
        ..._paths(r.routes),
      ],
    ];

void main() {
  test('every admin route lives under /admin', () {
    final paths = _paths(adminRoutes);
    expect(paths, isNotEmpty);
    for (final p in paths) {
      expect(p == '/admin' || p.startsWith('/admin/'), isTrue, reason: p);
    }
  });

  test('login, dashboard and every CMS section are routed', () {
    final list = _paths(adminRoutes);
    final paths = list.toSet();
    expect(list.length, paths.length, reason: 'duplicate admin paths');
    expect(paths, containsAll([RoutePaths.adminLogin, RoutePaths.adminDashboard]));
    expect(paths, containsAll(AdminSection.values.map((s) => s.path)));
    expect(paths, containsAll([
      '/admin/lessons/:lessonId',
      '/admin/questions/:questionId',
      '/admin/exam-bank/:questionId',
      '/admin/variants/:variantId',
      '/admin/users/:uid',
    ]));
  });
}
