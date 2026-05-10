// MOVED FROM: lib/features/circles/screens/circle_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/circle_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/circle.dart';
import '../../../core/models/circle_member.dart';

import '../widgets/circle_member_tile.dart';
import '../widgets/add_members_sheet.dart';
import 'circle_map_page.dart';

class CirclePage extends StatefulWidget {
  const CirclePage({super.key});

  @override
  State<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends State<CirclePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  int? _deviceBattery;
  BatteryState? _batteryState;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDeviceBattery();
  }

  Future<void> _loadDeviceBattery() async {
    final battery = Battery();
    final level = await battery.batteryLevel;
    final state = await battery.batteryState;
    if (mounted) setState(() { _deviceBattery = level; _batteryState = state; });
  }

  Future<void> _loadData() async {
    context.read<CircleProvider>().loadCircles();
  }

  void _showShareCodeDialog(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Invite to Circle", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          QrImageView(data: code, size: 200.0, foregroundColor: Colors.black, backgroundColor: Colors.white),
          const SizedBox(height: 20),
          Text(code, style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Share.share("Join my SafePulse Circle! Code: $code"),
            child: const Text("SHARE CODE"),
          ),
        ]),
      ),
    );
  }

  void _showAddMembersSheet(String inviteCode) async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final withPhone = contacts.where((c) => c.phones.isNotEmpty).toList();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddMembersSheet(contacts: withPhone, inviteCode: inviteCode),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CircleProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Your Circles")),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.circles.isEmpty 
                ? _buildEmptyState() 
                : _buildCircleList(provider.circles),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text("No circles yet", style: TextStyle(color: Colors.white)));
  }

  Widget _buildCircleList(List<Circle> circles) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: circles.length,
      itemBuilder: (context, index) {
        final circle = circles[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCircleHeader(circle),
            const SizedBox(height: 20),
            ...circle.members.map((member) => CircleMemberTile(
              member: member,
              circleId: circle.id,
              circleName: circle.name,
              isSelf: member.id == context.read<AuthProvider>().userId,
              deviceBattery: _deviceBattery,
              batteryState: _batteryState,
            )),
          ],
        );
      },
    );
  }

  Widget _buildCircleHeader(Circle circle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.secondary, AppColors.primary]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Expanded(child: Text(circle.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
        IconButton(icon: const Icon(Icons.qr_code, color: Colors.white), onPressed: () => _showShareCodeDialog(circle.inviteCode)),
      ]),
    );
  }
}
