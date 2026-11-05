import 'package:go_router/go_router.dart';

import '../../core/routes/route_paths.dart';
import 'domain/tutor_models.dart';
import 'presentation/pages/tutor_page.dart';

/// Integration point for the AI tutor (owned by lib/features/tutor).
///
/// Navigate with `context.push(RoutePaths.tutor, extra: {'questionId': ...,
/// 'attemptId': ..., 'mode': 'explain_mistake', 'prefill': ...})`; every key
/// is optional.
List<RouteBase> get tutorRoutes => [
      GoRoute(
        path: RoutePaths.tutor,
        builder: (context, state) => TutorPage(args: TutorArgs.fromExtra(state.extra)),
      ),
    ];
