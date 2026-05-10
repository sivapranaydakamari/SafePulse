import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'circle_map_page.dart';
import 'member_detail_page.dart';

class CirclePage extends StatefulWidget {
  const CirclePage({super.key});

  @override
  State<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends State<CirclePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  List<dynamic> _circles = [];
  bool _isLoading = true;
  String? _userId;

  int? _deviceBattery;
  BatteryState? _batteryState;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDeviceBattery();
  }

  Future<void> _loadDeviceBattery() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      if (mounted)
        setState(() {
          _deviceBattery = level;
          _batteryState = state;
        });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    if (_userId != null) {
      try {
        final result = await ApiService.getUserCircles();
        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _circles = result['circles'] ?? [];
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        debugPrint('[CIRCLE] loadData error: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── SHARE INVITE CODE QR ──────────────────────────────────────────────────
  void _showShareCodeDialog(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 30),
          const Text("Invite to Circle",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Share this code with members you want to add",
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surface)),
            child: Column(children: [
              QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: Colors.black),
              const SizedBox(height: 20),
              Text(code,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8)),
            ]),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {
              Share.share(
                  "Join my SafePulse Circle!\nInvite code: $code\n\nDownload SafePulse for real-time family safety!");
            },
            icon: const Icon(Icons.share),
            label: const Text("SHARE CODE"),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56)),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── ADD MEMBERS — opens phone contacts → WhatsApp invite ──────────────────
  void _showAddMembersSheet(String inviteCode) async {
    // Ask for contacts permission
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please allow contacts access to invite members')));
      }
      return;
    }

    // Load contacts that have at least one phone number
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final withPhone = contacts.where((c) => c.phones.isNotEmpty).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    if (!mounted) return;
    Navigator.pop(context); // close loading dialog

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) =>
          _AddMembersSheet(contacts: withPhone, inviteCode: inviteCode),
    );
  }

  // ── JOIN ──────────────────────────────────────────────────────────────────
  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text("Join a Circle",
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: _codeController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: "Enter Invite Code",
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.surface)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final result = await ApiService.joinCircle(_codeController.text);
              if (!mounted) return;
              Navigator.pop(context);
              if (result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Joined Circle Successfully!")));
                _loadData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message'] ?? "Failed to join")));
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  // ── QR SCANNER ────────────────────────────────────────────────────────────
  void _showScanner() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("Camera permission is required. Enable it in settings.")));
      }
      return;
    }
    if (!status.isGranted) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 40),
          const Text("Scan Invite QR",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Align the QR code within the frame",
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 60),
          SizedBox(
            width: 250,
            height: 250,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: MobileScanner(
                controller: MobileScannerController(
                    detectionSpeed: DetectionSpeed.noDuplicates,
                    facing: CameraFacing.back),
                onDetect: (capture) async {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final code = barcodes.first.rawValue;
                    if (code != null) {
                      if (!mounted) return;
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      final result = await ApiService.joinCircle(code);
                      if (mounted) {
                        if (result['success']) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Joined Circle via QR!")));
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text(result['message'] ?? "Scan Failed")));
                        }
                      }
                    }
                  }
                },
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showJoinDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBg,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Enter Code Manually",
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel",
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── CREATE ────────────────────────────────────────────────────────────────
  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text("Create New Circle",
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: _nameController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: "Circle Name",
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.surface)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final result =
                  await ApiService.createCircle(_nameController.text);
              if (!mounted) return;
              Navigator.pop(context);
              if (result['success']) {
                final code = result['circle']['inviteCode'];
                _loadData();
                _showShareCodeDialog(code);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to create circle")));
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Your Circles"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            onPressed: _showScanner,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _circles.isEmpty
                ? _buildEmptyState()
                : _buildCircleList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.group_outlined,
              size: 100, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text("No Circles Yet",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            "Create a circle to start tracking your family and friends, or join an existing one using a code.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          _buildActionButtons(),
        ]),
      ),
    );
  }

  Widget _buildCircleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _circles.length,
      itemBuilder: (context, circleIndex) {
        final circle = _circles[circleIndex];
        final members = (circle['members'] as List? ?? []);
        final inviteCode = circle['inviteCode'] ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (circleIndex > 0) const SizedBox(height: 40),

            // Circle header card
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CircleMapPage(
                          circleId: circle['_id'] ?? '',
                          circleName: circle['name'] ?? ''))),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: circleIndex % 2 == 0
                          ? [AppColors.secondary, AppColors.primary]
                          : [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(circle['name'] ?? 'Unnamed Circle',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("${members.length} Members • Active",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.map_outlined,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text("Tap to view on map",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12)),
                        ]),
                      ])),
                  GestureDetector(
                    onTap: () => _showShareCodeDialog(inviteCode),
                    child: const Icon(Icons.qr_code,
                        color: Colors.white, size: 40),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 12),

            // View on Map
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CircleMapPage(
                            circleId: circle['_id'] ?? '',
                            circleName: circle['name'] ?? ''))),
                icon: const Icon(Icons.location_on, color: AppColors.primary),
                label: const Text("View Members on Map",
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ADD MEMBERS button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddMembersSheet(inviteCode),
                icon: const Icon(Icons.person_add_alt_1_rounded,
                    color: Colors.white),
                label: const Text("Add Members",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 20),
            _buildLiveStatsRow(members),
            const SizedBox(height: 20),

            const Text("Circle Members",
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            ...List.generate(members.length, (index) {
              final memberData = members[index];
              if (memberData is String) {
                return _buildMemberTile(context,
                    name: "Loading...",
                    status: "Updating...",
                    statusColor: Colors.grey,
                    battery: "--",
                    isDriving: false,
                    circleId: circle['_id'],
                    circleName: circle['name'],
                    isSelf: false);
              }

              final Map<String, dynamic> member =
                  Map<String, dynamic>.from(memberData);
              final isSelf = member['_id'] == _userId;
              final bool isDriving = member['isDriving'] == true;
              final int speed = (member['currentSpeed'] ?? 0).toInt();

              // Self → real device battery; others → server battery
              final String battery = isSelf && _deviceBattery != null
                  ? '$_deviceBattery%'
                  : member['batteryLevel']?.toString() ?? '--';
              final int batteryNum =
                  int.tryParse(battery.replaceAll('%', '').trim()) ?? 0;
              final Color batteryColor = batteryNum <= 20
                  ? Colors.red
                  : batteryNum <= 50
                      ? Colors.orange
                      : AppColors.safe;

              String statusText;
              Color statusColor;
              if (isDriving) {
                statusText = "Driving @ $speed km/h";
                statusColor = AppColors.primary;
              } else if (batteryNum <= 20) {
                statusText = "Low Battery";
                statusColor = Colors.orange;
              } else {
                statusText = isSelf ? "You • Active" : "Active";
                statusColor = AppColors.safe;
              }

              return _buildMemberTile(
                context,
                name: isSelf
                    ? "${member['name'] ?? 'You'} (You)"
                    : (member['name'] ?? 'Member'),
                status: statusText,
                statusColor: statusColor,
                battery: battery,
                batteryColor: batteryColor,
                isDriving: isDriving,
                currentSpeed: speed,
                profilePic: member['profilePic'],
                circleId: circle['_id'],
                circleName: circle['name'],
                memberData: member,
                isSelf: isSelf,
              );
            }),

            if (circleIndex == _circles.length - 1) ...[
              const SizedBox(height: 40),
              _buildActionButtons(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLiveStatsRow(List members) {
    int drivingCount = 0, lowBatteryCount = 0;
    for (var m in members) {
      if (m is String) continue;
      if (m['isDriving'] == true) drivingCount++;
      final battery =
          int.tryParse((m['batteryLevel'] ?? '100').replaceAll('%', '')) ?? 100;
      if (battery <= 20) lowBatteryCount++;
    }
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _buildStatChip(
          Icons.people, "${members.length} Members", AppColors.primary),
      if (drivingCount > 0)
        _buildStatChip(
            Icons.directions_car, "$drivingCount Driving", Colors.orange),
      if (lowBatteryCount > 0)
        _buildStatChip(
            Icons.battery_alert, "$lowBatteryCount Low Battery", Colors.red),
    ]);
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(
          child: GestureDetector(
        onTap: _showJoinDialog,
        child: _buildActionCard(
            icon: Icons.group_add,
            label: "Join Circle",
            color: AppColors.cardBg),
      )),
      const SizedBox(width: 16),
      Expanded(
          child: GestureDetector(
        onTap: _showCreateDialog,
        child: _buildActionCard(
            icon: Icons.create_new_folder,
            label: "Create New",
            color: AppColors.cardBg),
      )),
    ]);
  }

  Widget _buildMemberTile(
    BuildContext context, {
    required String name,
    required String status,
    required Color statusColor,
    required String battery,
    required bool isDriving,
    required bool isSelf,
    Color? batteryColor,
    int currentSpeed = 0,
    String? profilePic,
    String? circleId,
    String? circleName,
    Map<String, dynamic>? memberData,
  }) {
    final Color bColor = batteryColor ?? AppColors.safe;
    return GestureDetector(
      onTap: () {
        if (memberData != null && circleId != null && circleName != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberDetailPage(
                  memberData: memberData,
                  circleId: circleId,
                  circleName: circleName,
                  isSelf: isSelf,
                  deviceBattery: isSelf ? _deviceBattery : null,
                  deviceBatteryState: isSelf ? _batteryState : null,
                ),
              ));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surface, width: 1),
        ),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.surface,
              backgroundImage:
                  profilePic != null ? NetworkImage(profilePic) : null,
              child: profilePic == null
                  ? Text(name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20))
                  : null,
            ),
            Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBg, width: 2)),
                )),
          ]),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Row(children: [
                  if (isDriving)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.directions_car,
                          size: 13, color: AppColors.primary),
                    ),
                  Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ]),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Icon(_getBatteryIcon(battery), size: 14, color: bColor),
              const SizedBox(width: 2),
              Text(battery, style: TextStyle(color: bColor, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.textSecondary),
          ]),
        ]),
      ),
    );
  }

  IconData _getBatteryIcon(String battery) {
    final num = int.tryParse(battery.replaceAll('%', '').trim()) ?? 100;
    if (num <= 20) return Icons.battery_alert;
    if (num <= 50) return Icons.battery_3_bar;
    return Icons.battery_full;
  }

  Widget _buildActionCard(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surface)),
      child: Column(children: [
        Icon(icon, color: AppColors.primary, size: 30),
        const SizedBox(height: 12),
        Text(label,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADD MEMBERS SHEET — searchable contacts list with WhatsApp invite button
// ═══════════════════════════════════════════════════════════════════════════════
class _AddMembersSheet extends StatefulWidget {
  final List<Contact> contacts;
  final String inviteCode;
  const _AddMembersSheet({required this.contacts, required this.inviteCode});

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Contact> _filtered = [];
  // Track who has been invited in this session
  final Set<String> _invitedNumbers = {};

  @override
  void initState() {
    super.initState();
    _filtered = widget.contacts;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.contacts
            : widget.contacts
                .where((c) =>
                    c.displayName.toLowerCase().contains(q) ||
                    c.phones.any((p) => p.number.contains(q)))
                .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite(Contact contact) async {
    final phone = contact.phones.first.number;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final waNumber = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;

    final firstName = contact.displayName.split(' ').first;
    final message = Uri.encodeComponent(
      'Hey $firstName! 👋\n\n'
      'I\'m using SafePulse to stay connected with family & friends in real-time.\n\n'
      'Join my SafePulse circle using this invite code:\n'
      '🔑 *${widget.inviteCode}*\n\n'
      'Steps:\n'
      '1️⃣ Install SafePulse (APK link or Play Store)\n'
      '2️⃣ Sign up & go to Circles tab\n'
      '3️⃣ Tap "Join Circle" and enter the code above\n\n'
      "You'll appear on my map and I'll appear on yours! 🗺️",
    );

    final uri = Uri.parse('https://wa.me/$waNumber?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Mark as invited
      if (mounted) setState(() => _invitedNumbers.add(cleaned));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.87,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(children: [
        // Handle
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 20),

        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Add Members",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold)),
                    Text("Tap Invite → WhatsApp opens automatically",
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ]),
            ),
            // Code badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              child: Text(widget.inviteCode,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 2)),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or number...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: AppColors.cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.surface)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.surface)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Contact count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(children: [
            Text('${_filtered.length} contacts',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),

        const SizedBox(height: 6),

        // List
        Expanded(
          child: _filtered.isEmpty
              ? const Center(
                  child: Text('No contacts found',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final c = _filtered[i];
                    final phone = c.phones.first.number;
                    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
                    final isInvited = _invitedNumbers.contains(cleaned);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.surface,
                        backgroundImage: c.thumbnail != null
                            ? MemoryImage(c.thumbnail!)
                            : null,
                        child: c.thumbnail == null
                            ? Text(
                                c.displayName.isNotEmpty
                                    ? c.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15))
                            : null,
                      ),
                      title: Text(c.displayName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      subtitle: Text(phone,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      trailing: GestureDetector(
                        onTap: isInvited ? null : () => _invite(c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isInvited
                                ? AppColors.safe.withOpacity(0.1)
                                : const Color(0xFF25D366).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isInvited
                                  ? AppColors.safe.withOpacity(0.5)
                                  : const Color(0xFF25D366).withOpacity(0.6),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              isInvited
                                  ? Icons.check_circle_outline
                                  : Icons.send_rounded,
                              color: isInvited
                                  ? AppColors.safe
                                  : const Color(0xFF25D366),
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isInvited ? 'Sent' : 'Invite',
                              style: TextStyle(
                                color: isInvited
                                    ? AppColors.safe
                                    : const Color(0xFF25D366),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ]),
                        ),
                      ),
                      onTap: isInvited ? null : () => _invite(c),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
