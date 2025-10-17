import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/services/background_service_manager.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/signalr_service.dart';
import '../../core/services/storage_service.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _initStatus = 'Initializing...';
  bool _isNavigating = false; // Tambahkan flag

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    try {
      // Minimum display time
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;
      
      setState(() {
        _initStatus = 'Checking authentication...';
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      
      final authState = ref.read(authProvider);
      print('🔐 Auth status: ${authState.isAuthenticated}');
      
      if (authState.isAuthenticated) {
        await _handleAuthenticatedUser();
      } else {
        await _handleUnauthenticatedUser();
      }
    } catch (e, stackTrace) {
      print('❌ Splash error: $e');
      print('Stack trace: $stackTrace');
      
      // Fallback to login on error
      if (mounted && !_isNavigating) {
        _navigateToLogin();
      }
    }
  }

  Future<void> _handleAuthenticatedUser() async {
    try {
      if (!mounted) return;

      setState(() {
        _initStatus = 'Connecting to chat service...';
      });

      // Try to connect SignalR with timeout
      try {
        await SignalRService.ensureConnection().timeout(
          const Duration(seconds: 10),
        );
        print('✅ SignalR connected');
      } catch (e) {
        print('⚠️ SignalR connection failed: $e');
        // Continue anyway - will reconnect later
      }

      if (!mounted) return;

      // Start background service (non-blocking)
      _startBackgroundServiceAsync();

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      _navigateToHome();
    } catch (e) {
      print('❌ Error in authenticated flow: $e');
      if (mounted && !_isNavigating) {
        _navigateToHome(); // Navigate anyway
      }
    }
  }

  Future<void> _handleUnauthenticatedUser() async {
    if (!mounted) return;
    
    // Check if we have saved credentials for auto login
    final authNotifier = ref.read(authProvider.notifier);
    final hasCredentials = await Future(() => StorageService.hasCredentials());
    
    if (hasCredentials) {
      setState(() {
        _initStatus = 'Auto login...';
      });
      
      print('🔄 Found saved credentials, attempting auto login...');
      
      final success = await authNotifier.tryAutoReLogin();
      
      if (!mounted) return;
      
      if (success) {
        print('✅ Auto login successful');
        await _handleAuthenticatedUser();
        return;
      } else {
        print('❌ Auto login failed');
      }
    }
    
    setState(() {
      _initStatus = 'Redirecting to login...';
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    _navigateToLogin();
  }

  void _startBackgroundServiceAsync() {
    // Run in background without blocking navigation
    Future.delayed(Duration.zero).then((_) async {
      try {
        await BackgroundServiceManager.startBackgroundService();
        print('✅ Background service started');
        
        final isExempted = await BackgroundServiceManager.isBatteryOptimizationDisabled();
        if (!isExempted) {
          await BackgroundServiceManager.requestBatteryOptimizationExemption();
        }
      } catch (e) {
        print('⚠️ Background service error: $e');
      }
    });
  }

  void _navigateToHome() {
    if (_isNavigating) {
      print('⚠️ Already navigating, skip');
      return;
    }
    
    _isNavigating = true;
    print('🏠 Navigating to home...');
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  void _navigateToLogin() {
    if (_isNavigating) {
      print('⚠️ Already navigating, skip');
      return;
    }
    
    _isNavigating = true;
    print('🔐 Navigating to login...');
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/nobox2.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Text(
                'NoBoxChat',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 12),
              const Text(
                'Professional Chat Management',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w400,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Loading dots
              SizedBox(
                width: 60,
                height: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDot(0),
                    const SizedBox(width: 8),
                    _buildDot(1),
                    const SizedBox(width: 8),
                    _buildDot(2),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Status text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _initStatus,
                  key: ValueKey(_initStatus),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        double animationValue = (_animationController.value + (index * 0.3)) % 1.0;
        double scale = 0.5 + (0.5 * (1 - (animationValue - 0.5).abs() * 2).clamp(0.0, 1.0));
        double opacity = 0.4 + (0.6 * (1 - (animationValue - 0.5).abs() * 2).clamp(0.0, 1.0));
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(opacity),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}