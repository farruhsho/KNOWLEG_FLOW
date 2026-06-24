import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// ORT Master KG design-system components.
///
/// A small, opinionated set of building blocks in the Anthropic editorial
/// style. All colors/spacing/radii come from [AppTokens] / the theme, so these
/// adapt automatically to light & dark.

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { regular, small }

/// Primary / secondary / ghost / danger button with optional leading icon and
/// inline loading state. Min height respects the 48dp touch target.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disabled = onPressed == null || isLoading;

    late final Color bg;
    late final Color fg;
    late final BorderSide side;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = t.accent;
        fg = Colors.white;
        side = BorderSide.none;
        break;
      case AppButtonVariant.danger:
        bg = t.danger;
        fg = Colors.white;
        side = BorderSide.none;
        break;
      case AppButtonVariant.secondary:
        bg = t.surface;
        fg = t.textPrimary;
        side = BorderSide(color: t.border);
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = t.textPrimary;
        side = BorderSide.none;
        break;
    }

    final double minHeight =
        size == AppButtonSize.small ? 40 : AppTokens.minTouchTarget;
    final EdgeInsets padding = size == AppButtonSize.small
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    final child = isLoading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: fg),
                ),
              ),
            ],
          );

    final button = Material(
      color: disabled ? bg.withValues(alpha: 0.45) : bg,
      borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return (variant == AppButtonVariant.primary ||
                    variant == AppButtonVariant.danger)
                ? Colors.black.withValues(alpha: 0.12)
                : t.accent.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.hovered)) {
            return (variant == AppButtonVariant.primary ||
                    variant == AppButtonVariant.danger)
                ? Colors.black.withValues(alpha: 0.06)
                : t.accent.withValues(alpha: 0.04);
          }
          return null;
        }),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
            border: side == BorderSide.none ? null : Border.fromBorderSide(side),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Bordered, flat surface card with consistent radius and optional tap.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space20),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(AppTokens.radiusCard);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? t.border),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

/// Pill chip / badge. Use [tone] to tint with an accent or status color.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.tone,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color? tone;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = tone ?? t.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.12) : t.section,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(
          color: filled ? c.withValues(alpha: 0.25) : t.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? c : t.textSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: filled ? c : t.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with optional trailing action (e.g. "See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (action != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

/// Centered empty state with icon, title, optional body and CTA.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.section,
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
              ),
              child: Icon(icon, size: 32, color: t.textTertiary),
            ),
            const SizedBox(height: AppTokens.space20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: AppTokens.space8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTokens.space24),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with retry.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Что-то пошло не так',
    this.message = 'Не удалось загрузить данные. Попробуйте ещё раз.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 32, color: t.danger),
            ),
            const SizedBox(height: AppTokens.space20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTokens.space24),
              AppButton(
                label: 'Повторить',
                icon: Icons.refresh,
                onPressed: onRetry,
                variant: AppButtonVariant.secondary,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quiet centered loader.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: t.accent),
          ),
          if (message != null) ...[
            const SizedBox(height: AppTokens.space16),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Shimmering skeleton block for loading placeholders.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final base = t.section;
        final highlight = Color.lerp(t.section, t.border, 0.9)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, _controller.value),
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A standard skeleton list-item card used by list screens during loading.
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AppSkeleton(width: 56, height: 56, radius: 12),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 140, height: 16),
                SizedBox(height: 10),
                AppSkeleton(height: 12),
                SizedBox(height: 8),
                AppSkeleton(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
