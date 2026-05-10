import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:animate_do/animate_do.dart';

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
    try {
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      if (mounted) setState(() { _deviceBattery = level; _batteryState = state; });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    context.read<CircleProvider>().loadCircles();
  }

  void _showCreateCircleDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Create New Circle", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Circle Name",
            labelStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surface)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                final success = await context.read<CircleProvider>().createCircle(name);
                if (mounted) {
                  Navigator.pop(context);
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to create circle")));
                  }
                }
              }
            },
            child: const Text("CREATE"),
          ),
        ],
      ),
    );
  }

  void _showJoinCircleDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Join a Circle", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _codeController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Invite Code",
            labelStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surface)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final code = _codeController.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                final success = await context.read<CircleProvider>().joinCircle(code);
                if (mounted) {
                  Navigator.pop(context);
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid code or already joined")));
                  }
                }
              }
            },
            child: const Text("JOIN"),
          ),
        ],
      ),
    );
  }

  void _showShareCodeDialog(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text("Invite to Circle", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(data: code, size: 180.0, foregroundColor: Colors.black),
          ),
          const SizedBox(height: 24),
          Text(code, style: const TextStyle(color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Share.share("Join my SafePulse Circle! Code: $code"),
            icon: const Icon(Icons.share),
            label: const Text("SHARE INVITE CODE"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CircleProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Your Circles", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: provider.isLoading && provider.circles.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : provider.circles.isEmpty 
                ? _buildEmptyState() 
                : _buildCircleList(provider.circles),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _showJoinCircleDialog,
            heroTag: 'join',
            icon: const Icon(Icons.group_add),
            label: const Text("JOIN"),
            backgroundColor: AppColors.secondary,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _showCreateCircleDialog,
            heroTag: 'create',
            icon: const Icon(Icons.add),
            label: const Text("CREATE"),
            backgroundColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_outlined, size: 80, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              child: const Text(
                "Keep your family safe",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: const Text(
                "Create a circle to track your loved ones or join an existing one using a code.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _showJoinCircleDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.secondary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("JOIN CIRCLE", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showCreateCircleDialog,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("CREATE NEW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleList(List<Circle> circles) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: circles.length,
      itemBuilder: (context, index) {
        final circle = circles[index];
        return FadeInUp(
          delay: Duration(milliseconds: index * 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCircleHeader(circle),
              const SizedBox(height: 12),
              ...circle.members.map((member) => CircleMemberTile(
                member: member,
                circleId: circle.id,
                circleName: circle.name,
                isSelf: member.id == context.read<AuthProvider>().userId,
                deviceBattery: _deviceBattery,
                batteryState: _batteryState,
              )),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircleHeader(Circle circle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary.withOpacity(0.8), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(circle.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("${circle.members.length} Members", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_2, color: Colors.white, size: 28), 
          onPressed: () => _showShareCodeDialog(circle.inviteCode)
        ),
      ]),
    );
  }
}
