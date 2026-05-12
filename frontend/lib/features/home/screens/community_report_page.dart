// FUTURE_SCOPE: COMMUNITY REPORTING - fully implemented
/// Crowd-sourced hazard reporting screen.
///
/// Lets users submit an incident type (accident / hazard / roadblock),
/// capture GPS coordinates automatically, and add an optional description.
/// Submitted reports appear as colored map pins on the route suggestion map
/// and are wired into route_scoring.js as a density-based risk factor.
library;

import 'package:flutter/material.dart';
import '../../../core/services/community_report_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';

class CommunityReportPage extends StatefulWidget {
  const CommunityReportPage({super.key});

  @override
  State<CommunityReportPage> createState() => _CommunityReportPageState();
}

class _CommunityReportPageState extends State<CommunityReportPage> {
  HazardType _selectedType = HazardType.hazard;
  final TextEditingController _descController = TextEditingController();
  double? _lat;
  double? _lng;
  bool _locating = true;
  bool _submitting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _locating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_lat == null || _lng == null) {
      setState(() => _statusMessage = 'Location unavailable. Please try again.');
      return;
    }
    setState(() { _submitting = true; _statusMessage = null; });
    final ok = await CommunityReportService.instance.submitReport(
      latitude:    _lat!,
      longitude:   _lng!,
      hazardType:  _selectedType,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hazard reported — thank you for keeping roads safe!')),
      );
    } else {
      setState(() {
        _submitting = false;
        _statusMessage = 'Failed to submit report. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Report a Hazard', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Incident type', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            _HazardTypePicker(
              selected: _selectedType,
              onChanged: (t) => setState(() => _selectedType = t),
            ),
            const SizedBox(height: 24),
            const Text('Location', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            _locating
                ? const Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Detecting your location…', style: TextStyle(color: Colors.white60)),
                  ])
                : Text(
                    _lat != null
                        ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                        : 'Could not determine location',
                    style: TextStyle(color: _lat != null ? Colors.white : Colors.redAccent),
                  ),
            const SizedBox(height: 24),
            const Text('Description (optional)', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 500,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add details about the hazard…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(_statusMessage!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_submitting || _locating) ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Submitting…' : 'Submit Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HazardTypePicker extends StatelessWidget {
  final HazardType selected;
  final ValueChanged<HazardType> onChanged;

  const _HazardTypePicker({required this.selected, required this.onChanged});

  static const _items = [
    (HazardType.accident,  Icons.car_crash,     Colors.red,    'Accident'),
    (HazardType.hazard,    Icons.warning_amber,  Colors.orange, 'Hazard'),
    (HazardType.roadblock, Icons.do_not_disturb, Colors.purple, 'Road Block'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _items.map((item) {
        final (type, icon, color, label) = item;
        final isSelected = selected == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.15) : AppColors.cardBg,
                border: Border.all(color: isSelected ? color : Colors.white12, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(icon, color: isSelected ? color : Colors.white38, size: 24),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(color: isSelected ? color : Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
