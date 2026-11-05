import 'package:go_router/go_router.dart';

import 'legal_documents.dart';
import 'presentation/legal_document_page.dart';

/// Integration point for the bundled legal texts (lib/features/legal).
List<RouteBase> get legalRoutes => [
      for (final doc in LegalDocument.values)
        GoRoute(
          path: doc.route,
          builder: (context, state) => LegalDocumentPage(document: doc),
        ),
    ];
