import 'package:go_router/go_router.dart';

import '../../features/batch_converter/presentation/pages/batch_converter_page.dart';
import '../../features/batch_converter/presentation/pages/batch_results_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/id_photo/presentation/pages/id_photo_studio_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/batch',
      name: 'batch-converter',
      builder: (context, state) => const BatchConverterPage(),
    ),
    GoRoute(
      path: '/id-photo',
      name: 'id-photo-studio',
      builder: (context, state) => const IdPhotoStudioPage(),
    ),
    GoRoute(
      path: '/batch/results',
      name: 'batch-results',
      builder: (context, state) => const BatchResultsPage(),
    ),
  ],
);
