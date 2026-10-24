import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_controller.dart';
import 'core/theme.dart';
import 'features/conversion/prepare_screen.dart';
import 'features/conversion/progress_screen.dart';
import 'features/conversion/result_screen.dart';
import 'features/conversion/style_screen.dart';
import 'features/destinations/destination_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';

class GlyphicaApp extends ConsumerStatefulWidget {
  const GlyphicaApp({super.key});
  @override
  ConsumerState<GlyphicaApp> createState() => _GlyphicaAppState();
}

class _GlyphicaAppState extends ConsumerState<GlyphicaApp> {
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    Page<void> page(GoRouterState state, Widget child) =>
        CustomTransitionPage<void>(
          key: state.pageKey,
          child: child,
          transitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondary, child) =>
              app.reduceMotion || MediaQuery.disableAnimationsOf(context)
              ? child
              : FadeTransition(opacity: animation, child: child),
        );
    router = GoRouter(
      initialLocation: app.welcomed ? '/' : '/welcome',
      redirect: (context, state) {
        if (['/prepare', '/style', '/generate'].contains(state.uri.path) &&
            app.draft == null) {
          return '/';
        }
        if ((state.uri.path.startsWith('/result/') ||
                state.uri.path.startsWith('/destination/')) &&
            app.find(state.pathParameters['id'] ?? '') == null) {
          return '/history';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (_, state) => page(state, const HomeScreen()),
        ),
        GoRoute(
          path: '/welcome',
          pageBuilder: (_, state) => page(state, const WelcomeScreen()),
        ),
        GoRoute(
          path: '/prepare',
          pageBuilder: (_, state) => page(state, const PrepareScreen()),
        ),
        GoRoute(
          path: '/style',
          pageBuilder: (_, state) => page(state, const StyleScreen()),
        ),
        GoRoute(
          path: '/generate',
          pageBuilder: (_, state) => page(state, const ProgressScreen()),
        ),
        GoRoute(
          path: '/result/:id',
          pageBuilder: (_, state) =>
              page(state, ResultScreen(id: state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/destination/:id',
          pageBuilder: (_, state) =>
              page(state, DestinationScreen(id: state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (_, state) => page(state, const HistoryScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, state) => page(state, const SettingsScreen()),
        ),
      ],
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return MaterialApp.router(
      title: 'Glyphica',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: switch (app.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || app.reduceMotion,
          ),
          child: child!,
        );
      },
    );
  }
}
