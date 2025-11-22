import 'package:flutter/material.dart';
import 'error_view.dart';

/// A widget that catches errors from its child and displays an error view
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stackTrace);
      }
      return ErrorView(
        message: 'Произошла ошибка',
        onRetry: () {
          setState(() {
            _error = null;
            _stackTrace = null;
          });
        },
      );
    }

    return ErrorWidget.builder = (FlutterErrorDetails details) {
      setState(() {
        _error = details.exception;
        _stackTrace = details.stack;
      });
      return const SizedBox.shrink();
    } as Widget;
  }
}

/// A wrapper that provides a safe context for widgets that might throw errors
class SafeWidget extends StatelessWidget {
  final Widget Function() builder;
  final Widget Function(Object error)? errorBuilder;

  const SafeWidget({
    super.key,
    required this.builder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return builder();
    } catch (error) {
      if (errorBuilder != null) {
        return errorBuilder!(error);
      }
      return ErrorView(
        message: 'Не удалось загрузить содержимое',
        onRetry: null,
      );
    }
  }
}
