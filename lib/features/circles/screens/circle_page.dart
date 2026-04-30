import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/screens/monitoring_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId != null) {
      final result = await ApiService.getUserCircles();
      if (result['success']) {
        setState(() {
          _circles = result['circles'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showShareCodeDialog(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            const Text("Invite to Circle", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Share this code with members you want to add", style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.surface)),
              child: Column(
                children: [
                  QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: Colors.black,
                  ),
                  const SizedBox(height: 20),
                  Text(code, style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Share.share("Join my SafePulse Circle! Use my invite code: $code\n\nDownload SafePulse today for real-time family safety!");
              },
              icon: const Icon(Icons.share),
              label: const Text("SHARE CODE"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text("Join a Circle", style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: _codeController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: "Enter Invite Code",
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surface)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getString('userId');
              if (userId == null) return;
              
              final result = await ApiService.joinCircle(_codeController.text);
              if (!mounted) return;
              Navigator.pop(context);
              
              if (result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined Circle Successfully!")));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? "Failed to join")));
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  void _showScanner() async {
    // 1. Check/Request Camera Permission first
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission is required. Enable it in settings.")),
        );
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
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 40),
            const Text("Scan Invite QR", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Align the QR code within the frame", style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 60),
            
            // Real Scanner View
            SizedBox(
              width: 250,
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  controller: MobileScannerController(
                    detectionSpeed: DetectionSpeed.noDuplicates,
                    facing: CameraFacing.back,
                  ),
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final code = barcodes.first.rawValue;
                      if (code != null) {
                        debugPrint('QR_DEBUG: Scanned code: $code');
                        
                        // Prevent multiple scans
                        if (!mounted) return;
                        
                        // Immediate feedback
                        HapticFeedback.mediumImpact();
                        
                        Navigator.pop(context); // Close scanner
                        
                        // Attempt to join
                        final prefs = await SharedPreferences.getInstance();
                        final userId = prefs.getString('userId');
                        if (userId != null) {
                          final result = await ApiService.joinCircle(code);
                          if (mounted) {
                            if (result['success']) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined Circle via QR!")));
                              _loadData();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? "Scan Failed")));
                            }
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
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showJoinDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardBg,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Enter Code Manually", style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text("Create New Circle", style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: _nameController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: "Circle Name",
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surface)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getString('userId');
              if (userId == null) return;

              final result = await ApiService.createCircle(_nameController.text);
              if (!mounted) return;
              Navigator.pop(context);

              if (result['success']) {
                final code = result['circle']['inviteCode'];
                _loadData();
                _showShareCodeDialog(code);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to create circle")));
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 100, color: AppColors.primary.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text("No Circles Yet", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              "Create a circle to start tracking your family and friends, or join an existing one using a code.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleList() {
    // For now, we'll show the first circle details
    final circle = _circles[0];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.secondary, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(circle['name'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("${circle['members'].length} Members • Active", style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showShareCodeDialog(circle['inviteCode']),
                  child: const Icon(Icons.qr_code, color: Colors.white, size: 40),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text("Circle Members", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Real members from backend
          ...List.generate(circle['members'].length, (index) {
            final memberData = circle['members'][index];
            
            // Defensive check: if backend didn't populate, memberData might be a String (ID)
            if (memberData is String) {
              return _buildMemberTile(
                context,
                name: "Loading member...",
                status: "Updating...",
                statusColor: Colors.grey,
                battery: "--",
                image: "assets/images/john_doe_avatar.png",
              );
            }

            final Map<String, dynamic> member = Map<String, dynamic>.from(memberData);
            final isSelf = member['_id'] == _userId;
            final bool isDriving = member['isDriving'] == true;

            return _buildMemberTile(
              context,
              name: isSelf ? "${member['name'] ?? 'You'} (You)" : (member['name'] ?? 'Member'),
              status: isDriving ? "Driving @ ${member['currentSpeed'] ?? 0} km/h" : "At Home",
              statusColor: isDriving ? AppColors.primary : AppColors.safe,
              battery: member['batteryLevel'] ?? "100%",
              image: "assets/images/john_doe_avatar.png",
              isDriving: isDriving,
            );
          }),
          const SizedBox(height: 40),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showJoinDialog,
            child: _buildActionCard(icon: Icons.group_add, label: "Join Circle", color: AppColors.cardBg),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _showCreateDialog,
            child: _buildActionCard(icon: Icons.create_new_folder, label: "Create New", color: AppColors.cardBg),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(
    BuildContext context, {
    required String name,
    required String status,
    required Color statusColor,
    required String battery,
    required String image,
    bool isDriving = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MonitoringPage()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surface, width: 1),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: AssetImage(image),
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
                      border: Border.all(color: AppColors.cardBg, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.battery_3_bar, size: 14, color: AppColors.textSecondary),
                    Text(
                      battery,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                if (isDriving)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.directions_car, size: 16, color: AppColors.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
