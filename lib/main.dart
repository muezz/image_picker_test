import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_test/pages.dart';

void main() {
  runApp(GoRouterTestApp());
}

class GoRouterTestApp extends StatelessWidget {
  GoRouterTestApp({super.key});

  final GoRouter _router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/1',
    routes: <GoRoute>[
      GoRoute(
        path: '/1',
        pageBuilder: (context, state) => const CupertinoPage(
          child: FirstPage(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Center(
      child: Text(
        state.error.toString(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
    );
  }
}

void testGoRouter(BuildContext context) {
  log(context.currentStack.toString());
}

extension Routing on BuildContext {
  /// Pops until the last remaining route
  void popAll() {
    while (canPop()) {
      pop();
    }
  }

  /// Pops until the first instance of [loc]
  void popUntil(String loc) {
    while (GoRouter.of(this).location != loc) {
      if (!canPop()) {
        throw Error.throwWithStackTrace(
          'Provided Location Not Found',
          StackTrace.current,
        );
      }
      pop();
    }
  }

  /// Removes all routes in stack and replaces them with the provided [loc]
  void replaceAll(String loc) {
    popAll();
    pushReplacement(loc);
  }

  /// Removes all routes in stack until [replaceUntil] and replaces them
  /// with the provided [replacement]
  void replaceAllUntil(String replaceUntil, String replacement) {
    popUntil(replaceUntil);
    pushReplacement(replacement);
  }

  /// Gets the current stack as list of locations (strings)
  List<String> get currentStack =>
      GoRouter.maybeOf(this)
          ?.routerDelegate
          .currentConfiguration
          .matches
          .map((e) => e.matchedLocation)
          .toList() ??
      [];
}
