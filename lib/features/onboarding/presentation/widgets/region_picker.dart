import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/region_model.dart';
import '../../data/kg_regions_provider.dart';

/// Oblast → district picker backed by `assets/data/kg_regions.json`.
/// The district is optional.
class RegionPicker extends ConsumerWidget {
  const RegionPicker({
    super.key,
    required this.oblast,
    required this.district,
    required this.onChanged,
    this.enabled = true,
  });

  final String? oblast;
  final String? district;
  final void Function(String? oblast, String? district) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final regions = ref.watch(kgRegionsProvider);

    return regions.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      error: (_, __) => Row(
        children: [
          Expanded(
            child: Text(
              l.shellRegionLoadError,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.tokens.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(kgRegionsProvider),
            child: Text(l.shellRetry),
          ),
        ],
      ),
      data: (list) => _RegionFields(
        regions: list,
        oblast: oblast,
        district: district,
        onChanged: onChanged,
        enabled: enabled,
      ),
    );
  }
}

class _RegionFields extends StatelessWidget {
  const _RegionFields({
    required this.regions,
    required this.oblast,
    required this.district,
    required this.onChanged,
    required this.enabled,
  });

  final List<RegionData> regions;
  final String? oblast;
  final String? district;
  final void Function(String? oblast, String? district) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final oblasts = regions.map((r) => r.oblast).toList();
    final selectedOblast = oblasts.contains(oblast) ? oblast : null;
    final districts = selectedOblast == null
        ? const <String>[]
        : regions
            .firstWhere((r) => r.oblast == selectedOblast)
            .districts
            .map((d) => d.name)
            .toList();
    final selectedDistrict = districts.contains(district) ? district : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('oblast-$selectedOblast'),
          initialValue: selectedOblast,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.shellRegionOblast),
          items: [
            for (final name in oblasts)
              DropdownMenuItem(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled ? (value) => onChanged(value, null) : null,
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          key: ValueKey('district-$selectedOblast-$selectedDistrict'),
          initialValue: selectedDistrict,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l.shellRegionDistrict,
            helperText: l.shellOptional,
          ),
          items: [
            for (final name in districts)
              DropdownMenuItem(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled && districts.isNotEmpty
              ? (value) => onChanged(selectedOblast, value)
              : null,
        ),
      ],
    );
  }
}
