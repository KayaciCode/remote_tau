import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/desktop_dashboard_screen.dart';
import 'screens/mobile_controller_screen.dart';
import 'services/connection_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PCRemoteMasterApp());
  ConnectionService().loadSettings().catchError((_) {});
}

class PCRemoteMasterApp extends StatelessWidget {
  const PCRemoteMasterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'PC Remote Master PRO',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const PlatformAdaptiveRoot(),
        );
      },
    );
  }
}

class PlatformAdaptiveRoot extends StatefulWidget {
  const PlatformAdaptiveRoot({Key? key}) : super(key: key);

  @override
  State<PlatformAdaptiveRoot> createState() => _PlatformAdaptiveRootState();
}

class _PlatformAdaptiveRootState extends State<PlatformAdaptiveRoot> {
  bool? _forceMobileMode;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    final bool showDesktop = _forceMobileMode == null
        ? (isDesktopPlatform || (!kIsWeb && screenWidth > 850))
        : !_forceMobileMode!;

    return Scaffold(
      body: Stack(
        children: [
          showDesktop ? const DesktopDashboardScreen() : const MobileControllerScreen(),

          // Mode switcher FAB (for testing / demo purposes)
          Positioned(
            bottom: 12,
            left: 12,
            child: Opacity(
              opacity: 0.25,
              child: FloatingActionButton.small(
                backgroundColor: AppTheme.darkCardBg,
                child: Icon(
                  showDesktop ? Icons.phone_iphone : Icons.desktop_windows,
                  color: Colors.white,
                  size: 16,
                ),
                onPressed: () {
                  setState(() {
                    _forceMobileMode = showDesktop;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
