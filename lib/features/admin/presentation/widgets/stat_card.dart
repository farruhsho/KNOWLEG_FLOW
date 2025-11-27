import 'package:flutter/material.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';

/// Animated statistics card for admin dashboard
class StatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final double? trendPercentage;
  final String? trendPeriod;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.trendPercentage,
    this.trendPeriod,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<int> _counterAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _counterAnimation = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(AdminSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? AdminColors.primary : AdminColors.border,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: _isHovered
                ? AdminSpacing.elevationMd
                : AdminSpacing.elevationSm,
          ),
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon and trend
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIcon(),
                    if (widget.trendPercentage != null) _buildTrend(),
                  ],
                ),
                const SizedBox(height: AdminSpacing.md),

                // Value with animation
                AnimatedBuilder(
                  animation: _counterAnimation,
                  builder: (context, child) {
                    return Text(
                      _formatNumber(_counterAnimation.value),
                      style: AdminTypography.h2.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AdminSpacing.xs),

                // Title
                Text(
                  widget.title,
                  style: AdminTypography.bodyMedium.copyWith(
                    color: AdminColors.textSecondary,
                  ),
                ),

                // Subtitle
                if (widget.subtitle != null) ...[
                  const SizedBox(height: AdminSpacing.xs),
                  Text(
                    widget.subtitle!,
                    style: AdminTypography.bodySmall.copyWith(
                      color: AdminColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (widget.iconColor ?? AdminColors.primary).withOpacity(0.1),
            (widget.iconColor ?? AdminColors.primary).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
      ),
      child: Icon(
        widget.icon,
        color: widget.iconColor ?? AdminColors.primary,
        size: 24,
      ),
    );
  }

  Widget _buildTrend() {
    final isPositive = (widget.trendPercentage ?? 0) > 0;
    final color = isPositive ? AdminColors.success : AdminColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: AdminSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.trendPercentage!.abs().toStringAsFixed(0)}%',
            style: AdminTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.trendPeriod != null) ...[
            const SizedBox(width: 4),
            Text(
              widget.trendPeriod!,
              style: AdminTypography.labelSmall.copyWith(
                color: AdminColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
