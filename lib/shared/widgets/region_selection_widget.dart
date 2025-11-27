import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/region_model.dart';

/// Reusable widget for hierarchical region selection
/// Displays cascading dropdowns: Oblast → District → Settlement
class RegionSelectionWidget extends StatefulWidget {
  final RegionModel? initialRegion;
  final ValueChanged<RegionModel?> onRegionChanged;
  final bool enabled;

  const RegionSelectionWidget({
    super.key,
    this.initialRegion,
    required this.onRegionChanged,
    this.enabled = true,
  });

  @override
  State<RegionSelectionWidget> createState() => _RegionSelectionWidgetState();
}

class _RegionSelectionWidgetState extends State<RegionSelectionWidget> {
  List<RegionData> _regions = [];
  String? _selectedOblast;
  String? _selectedDistrict;
  String? _selectedSettlement;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    if (widget.initialRegion != null) {
      _selectedOblast = widget.initialRegion!.oblast;
      _selectedDistrict = widget.initialRegion!.district;
      _selectedSettlement = widget.initialRegion!.settlement;
    }
  }

  Future<void> _loadRegions() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/kg_regions.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final regionsList = jsonData['regions'] as List<dynamic>;
      
      setState(() {
        _regions = regionsList
            .map((r) => RegionData.fromJson(r as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки регионов: $e')),
        );
      }
    }
  }

  List<DistrictData> _getDistricts() {
    if (_selectedOblast == null) return [];
    final region = _regions.firstWhere(
      (r) => r.oblast == _selectedOblast,
      orElse: () => const RegionData(oblast: '', districts: []),
    );
    return region.districts;
  }

  List<String> _getSettlements() {
    if (_selectedDistrict == null) return [];
    final districts = _getDistricts();
    final district = districts.firstWhere(
      (d) => d.name == _selectedDistrict,
      orElse: () => const DistrictData(name: '', settlements: []),
    );
    return district.settlements;
  }

  void _onOblastChanged(String? value) {
    setState(() {
      _selectedOblast = value;
      _selectedDistrict = null;
      _selectedSettlement = null;
    });
    _notifyChange();
  }

  void _onDistrictChanged(String? value) {
    setState(() {
      _selectedDistrict = value;
      _selectedSettlement = null;
    });
    _notifyChange();
  }

  void _onSettlementChanged(String? value) {
    setState(() {
      _selectedSettlement = value;
    });
    _notifyChange();
  }

  void _notifyChange() {
    if (_selectedOblast != null &&
        _selectedDistrict != null &&
        _selectedSettlement != null) {
      widget.onRegionChanged(
        RegionModel(
          oblast: _selectedOblast!,
          district: _selectedDistrict!,
          settlement: _selectedSettlement!,
        ),
      );
    } else {
      widget.onRegionChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Oblast dropdown
        DropdownButtonFormField<String>(
          value: _selectedOblast,
          decoration: const InputDecoration(
            labelText: 'Область',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_city),
          ),
          items: _regions.map((region) {
            return DropdownMenuItem(
              value: region.oblast,
              child: Text(region.oblast),
            );
          }).toList(),
          onChanged: widget.enabled ? _onOblastChanged : null,
        ),
        const SizedBox(height: 16),

        // District dropdown
        DropdownButtonFormField<String>(
          value: _selectedDistrict,
          decoration: const InputDecoration(
            labelText: 'Район',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.map),
          ),
          items: _getDistricts().map((district) {
            return DropdownMenuItem(
              value: district.name,
              child: Text(district.name),
            );
          }).toList(),
          onChanged: widget.enabled && _selectedOblast != null
              ? _onDistrictChanged
              : null,
        ),
        const SizedBox(height: 16),

        // Settlement dropdown
        DropdownButtonFormField<String>(
          value: _selectedSettlement,
          decoration: const InputDecoration(
            labelText: 'Населенный пункт',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home),
          ),
          items: _getSettlements().map((settlement) {
            return DropdownMenuItem(
              value: settlement,
              child: Text(settlement),
            );
          }).toList(),
          onChanged: widget.enabled && _selectedDistrict != null
              ? _onSettlementChanged
              : null,
        ),
      ],
    );
  }
}
