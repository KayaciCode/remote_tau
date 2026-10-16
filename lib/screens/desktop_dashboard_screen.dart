import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/radar_widget.dart';
import '../widgets/gauge_widget.dart';
import '../widgets/waveform_chart.dart';

class DesktopDashboardScreen extends StatefulWidget {
  const DesktopDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DesktopDashboardScreen> createState() => _DesktopDashboardScreenState();
}

class _DesktopDashboardScreenState extends State<DesktopDashboardScreen> {
  String deviceId = "849 210 492";
  String pinCode = "793 421";
  String localIp = "192.168.1.145";
  String macAddress = "B4:2E:99:A1:B2:C3";
  String globalTunnelUrl = "https://pc-remote-direct.trycloudflare.com";

  List<double> cpuHistory = List.generate(32, (i) => 12.0);
  List<double> ramHistory = List.generate(32, (i) => 64.0);
  List<double> gpuHistory = List.generate(32, (i) => 12.0);

  Timer? _telemetryTimer;
  int pinCountdown = 24;
  Timer? _pinTimer;

  int _selectedNavIndex = 0;

  final List<String> _logs = [
    "Starting PC Remote Master Core Host Engine v2.8 PRO...",
    "Direct WAN Cloudflare Tunnel established (active).",
    "Wake-on-LAN Subnet broadcast ready. MAC: B4:2E:99:A1:B2:C3",
    "Handshake verified with Mobile Client (iPhone 16 Pro) via TLS 1.3 ChaCha20.",
    "Audio pipeline synced @ 48kHz / 24-bit PCM stream.",
    "Input channel Touchpad & Keyboard mapped with 0.8ms latency.",
    "Tablet Remote (iPad Pro M4) connected as Virtual Trackpad.",
    "Zero frame drops in 34,200 incoming control telemetry frames.",
  ];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (!mounted) return;
      setState(() {
        cpuHistory.removeAt(0);
        cpuHistory.add((10 + rnd.nextDouble() * 5).clamp(8.0, 20.0));
        ramHistory.removeAt(0);
        ramHistory.add((62 + rnd.nextDouble() * 4).clamp(55.0, 70.0));
        gpuHistory.removeAt(0);
        gpuHistory.add((10 + rnd.nextDouble() * 4).clamp(8.0, 18.0));
      });
    });

    _pinTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        pinCountdown--;
        if (pinCountdown <= 0) {
          pinCountdown = 30;
          final d1 = 100 + rnd.nextInt(900);
          final d2 = 100 + rnd.nextInt(900);
          pinCode = "$d1 $d2";
          _logs.add("[${_formatTime(DateTime.now())}] Security: Auto-generated dynamic OTP PIN: $pinCode");
        }
      });
    });
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _pinTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Column(
        children: [
          // 1. TOP HEADER STATUS BAR (with Dark/Light Mode switch)
          _buildTopHeader(isDark, textPrimary, textSecondary, textMuted),

          // 2. MAIN WORKSPACE (Sidebar + Main Content)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Sidebar
                SizedBox(
                  width: 270,
                  child: _buildSidebar(isDark, textPrimary, textSecondary, textMuted),
                ),

                // Center and Right Workspace
                Expanded(
                  child: _buildMainWorkspace(isDark, textPrimary, textSecondary, textMuted),
                ),
              ],
            ),
          ),

          // 3. FLOATING ACTION DOCK
          _buildFloatingDock(isDark, textPrimary, textSecondary),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- 1. Top Header Bar ---
  Widget _buildTopHeader(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkHeaderBg : AppTheme.lightHeaderBg,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Status Badges
          Row(
            children: [
              // Glowing Active Indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGreen.withOpacity(0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "DIRECT TUNNEL ACTIVE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  letterSpacing: 0.5,
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 14),
              _buildTopDivider(isDark),
              const SizedBox(width: 14),
              Text(
                "IP: $localIp",
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSecondary),
              ),
              const SizedBox(width: 14),
              _buildTopDivider(isDark),
              const SizedBox(width: 14),
              Text(
                "Stream: 4K HDR @ 120 FPS",
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
              const SizedBox(width: 12),
              _buildTopDivider(isDark),
              const SizedBox(width: 12),
              Text(
                "TLS 1.3 ChaCha20",
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
              const SizedBox(width: 12),
              _buildTopDivider(isDark),
              const SizedBox(width: 12),
              Text(
                "Node: TR-Marmara-01",
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
            ],
          ),

          // Right Controls & Theme Toggle
          Row(
            children: [
              // Latency Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentCyan.withOpacity(0.35)),
                ),
                child: const Text(
                  "📶 1.0ms Ultra Low",
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Light / Dark Mode Toggle Button
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  AppTheme.toggleTheme();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0x10000000),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        size: 15,
                        color: isDark ? AppTheme.accentAmber : AppTheme.accentPurple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isDark ? "Light Mode" : "Dark Mode",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),
              // Host Profile Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accentRed.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, size: 12, color: AppTheme.accentRed),
                    SizedBox(width: 4),
                    Text(
                      "HOST-01",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopDivider(bool isDark) {
    return Container(
      width: 1,
      height: 14,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  // --- 2. Left Sidebar ---
  Widget _buildSidebar(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSidebarBg : AppTheme.lightSidebarBg,
        border: Border(
          right: BorderSide(
            color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand Logo & Pro Badge
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentRed, AppTheme.accentPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentRed.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "REMOTE MASTER",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.accentRed.withOpacity(0.6)),
                          ),
                          child: const Text(
                            "v2.8 PRO",
                            style: TextStyle(
                              color: AppTheme.accentRed,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "Core Host Engine Online",
                      style: TextStyle(fontSize: 9.5, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Crimson Desk ID Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFBE123C), Color(0xFF880A28)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentRed.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "WORKSPACE DESK ID",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: deviceId.replaceAll(" ", "")));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Desk ID panoya kopyalandı!"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.copy, size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Share this ID to connect mobile controller",
                    style: TextStyle(fontSize: 8.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        deviceId,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Copy",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield, size: 10, color: AppTheme.accentCyan),
                        SizedBox(width: 4),
                        Text(
                          "SECURE AES-256 GCM ENCRYPTION >",
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Dynamic OTP PIN Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDecoration(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "DYNAMIC OTP PIN",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: textSecondary,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 11, color: textMuted),
                          const SizedBox(width: 2),
                          Text(
                            "${pinCountdown}s",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      pinCode,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      "Auto-refreshes every 30 seconds",
                      style: TextStyle(fontSize: 8.5, color: textMuted),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Navigation Menu Pills
            _buildNavPill(0, "🏠 Dashboard (Host)", isDark, textPrimary, textSecondary),
            _buildNavPill(1, "📱 Paired Devices (2 Live)", isDark, textPrimary, textSecondary),
            _buildNavPill(2, "🌐 Connections & Tunnel", isDark, textPrimary, textSecondary),
            _buildNavPill(3, "📁 File Transfer Cache", isDark, textPrimary, textSecondary),
            _buildNavPill(4, "⚙ Host Settings", isDark, textPrimary, textSecondary),

            const SizedBox(height: 16),

            // Host Hardware Mini Progress Bars
            Container(
              padding: const EdgeInsets.all(10),
              decoration: AppTheme.cardDecoration(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "HOST HARDWARE TELEMETRY",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarProgress("DirectX 12 GPU", "12%", 0.12, AppTheme.accentPurple, textSecondary),
                  const SizedBox(height: 6),
                  _buildSidebarProgress("DDR5 Host RAM", "64%", 0.64, AppTheme.accentGreen, textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavPill(int index, String title, bool isDark, Color textPrimary, Color textSecondary) {
    final isSelected = _selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentRed.withOpacity(isDark ? 0.20 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppTheme.accentRed.withOpacity(0.7), width: 1)
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? (isDark ? Colors.white : AppTheme.accentRedDark) : textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarProgress(String label, String value, double percent, Color col, Color textSecondary) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, color: textSecondary)),
            Text(value, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: col)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: col.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(col),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  // --- 3. Main Workspace ---
  Widget _buildMainWorkspace(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Row 1: Top Dual Glowing Circular Gauges & Network Cards
          _buildTopMetricsRow(isDark, textPrimary, textSecondary, textMuted),
          const SizedBox(height: 12),

          // Row 2: Grid with Radar + Connected Clients (Left) & Hardware Graphs + Terminal (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Radar + Paired Clients
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    // Auto-Discovery Radar Card
                    _buildRadarCard(isDark, textPrimary, textSecondary, textMuted),
                    const SizedBox(height: 10),

                    // Paired Mobile Devices Cards (Client Monitors)
                    _buildConnectedClientsCard(isDark, textPrimary, textSecondary, textMuted),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right Column: Live 60FPS Hardware Graphs + Event Stream Terminal
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    // Live Hardware Splines Card
                    _buildHardwareMonitorCard(isDark, textPrimary, textSecondary, textMuted),
                    const SizedBox(height: 10),

                    // Live Event Stream Host Terminal
                    _buildTerminalCard(isDark, textPrimary, textSecondary, textMuted),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Top Metrics Row (Matching Reference UI top gauges) ---
  Widget _buildTopMetricsRow(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    return Row(
      children: [
        // Transfer Rate Gauge
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.cardDecoration(isDark: isDark),
            child: Row(
              children: [
                GlowGaugeWidget(
                  title: "TRANSFER RATE",
                  percent: 20,
                  valueText: "20 MB/S",
                  subtitle: "Up / Down Sync",
                  color: AppTheme.accentCyan,
                  isDark: isDark,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_upward, size: 12, color: AppTheme.accentCyan),
                          const SizedBox(width: 4),
                          Text("Upload: 12.4 MB/s", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.arrow_downward, size: 12, color: AppTheme.accentGreen),
                          const SizedBox(width: 4),
                          Text("Download: 7.6 MB/s", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text("Avg Throughput: 7.2 MB/s", style: TextStyle(fontSize: 9.5, color: textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Ultra Latency Gauge
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.cardDecoration(isDark: isDark),
            child: Row(
              children: [
                GlowGaugeWidget(
                  title: "ULTRA LATENCY",
                  percent: 98,
                  valueText: "1.0 MS",
                  subtitle: "P2P Kernel Level",
                  color: AppTheme.accentGreen,
                  isDark: isDark,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.speed, size: 12, color: AppTheme.accentGreen),
                          const SizedBox(width: 4),
                          Text("Roundtrip: 41.00 µs", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 12, color: AppTheme.accentCyan),
                          const SizedBox(width: 4),
                          Text("Packet Loss: 0.00%", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text("P2P Direct Buffer Lock", style: TextStyle(fontSize: 9.5, color: textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Auto-Discovery Radar Card ---
  Widget _buildRadarCard(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(isDark: isDark),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.radar, size: 15, color: AppTheme.accentGreen),
                  const SizedBox(width: 6),
                  Text(
                    "AUTO-DISCOVERY RADAR (5GHz)",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Targets in Range: 2",
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: RadarWidget(size: 140, isDark: isDark),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(isDark ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_tethering, size: 12, color: AppTheme.accentCyan),
                SizedBox(width: 6),
                Text(
                  "mDNS / ZeroConf Service Active • Beacon Broadcast ON",
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Paired Connected Clients Card ---
  Widget _buildConnectedClientsCard(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PAIRED MOBILE CLIENTS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: textPrimary,
                ),
              ),
              Text(
                "● 2 Active Monitors",
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Client 1: iPhone 16 Pro
          _buildClientItem(
            name: "iPhone 16 Pro",
            os: "iOS 18.2",
            ip: "192.168.1.56",
            battery: "78%",
            latency: "1.2ms",
            role: "Touchpad & Media Remote",
            icon: Icons.phone_iphone,
            color: AppTheme.accentCyan,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 8),

          // Client 2: iPad Pro M4
          _buildClientItem(
            name: "iPad Pro M4 (120Hz)",
            os: "iPadOS 18.2",
            ip: "192.168.1.88",
            battery: "84%",
            latency: "2.1ms",
            role: "Secondary Trackpad & Keypad",
            icon: Icons.tablet_mac,
            color: AppTheme.accentPurple,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildClientItem({
    required String name,
    required String os,
    required String ip,
    required String battery,
    required String latency,
    required String role,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B28) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text("● Connected", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
                        ),
                      ],
                    ),
                    Text(
                      "$os • IP: $ip • Mode: $role",
                      style: TextStyle(fontSize: 8.5, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text("🔋 $battery", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(width: 10),
                  Text("📶 $latency", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              Row(
                children: [
                  _buildMiniActionButton("Haptic Ping", isDark, () {
                    _logs.add("[${_formatTime(DateTime.now())}] Sent haptic feedback pulse to $name");
                    setState(() {});
                  }),
                  const SizedBox(width: 6),
                  _buildMiniActionButton("Audio Sync", isDark, () {
                    _logs.add("[${_formatTime(DateTime.now())}] Re-calibrated 48kHz audio buffer for $name");
                    setState(() {});
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniActionButton(String label, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0x15000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // --- Hardware Telemetry Card ---
  Widget _buildHardwareMonitorCard(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "LIVE 60FPS HARDWARE MONITOR",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: textPrimary,
                ),
              ),
              Text(
                "● Host Engine Ready",
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // CPU Waveform
          WaveformChartWidget(
            title: "HOST CPU (AMD Threadripper PRO 7995WX)",
            valueText: "12% @ 3.8 GHz",
            points: cpuHistory,
            color: AppTheme.accentCyan,
            maxValue: 30,
            isDark: isDark,
          ),

          // RAM Waveform
          WaveformChartWidget(
            title: "HOST RAM (DirectDMA Buffer Cache)",
            valueText: "64% (10.2 / 16.0 GB)",
            points: ramHistory,
            color: AppTheme.accentGreen,
            maxValue: 100,
            isDark: isDark,
          ),

          // GPU Waveform
          WaveformChartWidget(
            title: "DIRECTX 12 GPU (RTX 4090 D3D12 Encoder)",
            valueText: "12% Active",
            points: gpuHistory,
            color: AppTheme.accentPurple,
            maxValue: 30,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // --- Live Event Stream Terminal Card ---
  Widget _buildTerminalCard(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    return Container(
      height: 155,
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, size: 14, color: isDark ? AppTheme.accentGreen : AppTheme.accentBlue),
                  const SizedBox(width: 6),
                  Text(
                    "LIVE EVENT STREAM (HOST TERMINAL)",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const Text(
                "● Live Feed",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkTerminalBg : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.0),
                    child: Text(
                      "> ${_logs[i]}",
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 9.5,
                        color: Color(0xFF4ADE80),
                        height: 1.3,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Floating Action Dock ---
  Widget _buildFloatingDock(bool isDark, Color textPrimary, Color textSecondary) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF00E131F) : const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDockButton(
            icon: Icons.add_link,
            label: "Pair Mobile Device",
            color: AppTheme.accentCyan,
            isHighlight: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Mobil cihazınızdaki uygulamadan Desk ID ve PIN'i girerek bağlanın."),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildDockButton(
            icon: Icons.cloud_outlined,
            label: "Direct Tunnel Active",
            color: AppTheme.accentGreen,
            onTap: () {
              Clipboard.setData(ClipboardData(text: globalTunnelUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Tunnel URL kopyalandı: $globalTunnelUrl")),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildDockButton(
            icon: Icons.bolt,
            label: "WoL Broadcast",
            color: AppTheme.accentAmber,
            onTap: () {
              _logs.add("[${_formatTime(DateTime.now())}] WoL: Magic Packet sent to broadcast subnet ($macAddress)");
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
          _buildDockButton(
            icon: Icons.cleaning_services_outlined,
            label: "Clear Cache",
            color: textSecondary,
            onTap: () {
              _logs.add("[${_formatTime(DateTime.now())}] Cache flushed. 128 MB released.");
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
          _buildDockButton(
            icon: Icons.refresh,
            label: "Restart Server",
            color: AppTheme.accentRed,
            onTap: () {
              _logs.add("[${_formatTime(DateTime.now())}] Host Server Engine re-initialized.");
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required Color color,
    bool isHighlight = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isHighlight ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isHighlight ? Border.all(color: color.withOpacity(0.6)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? color : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

