import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/signalr_service.dart';
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

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(); // Make it repeat for dots animation
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    
    // Navigate after splash
    _navigateAfterSplash();
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

  Future<void> _navigateAfterSplash() async {
    // Simulate initialization steps with status updates
    setState(() {
      _initStatus = 'Checking authentication...';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    final authState = ref.read(authProvider);
    
    if (authState.isAuthenticated) {
      setState(() {
        _initStatus = 'Connecting to real-time service...';
      });
      
      // Ensure SignalR is connected for authenticated users
      try {
        await SignalRService.ensureConnection();
        print('✅ SignalR connected during splash for authenticated user');
      } catch (e) {
        print('❌ SignalR connection failed during splash: $e');
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _initStatus = 'Redirecting to login...';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
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
              // Logo/App Image - Enhanced version
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
                    'assets/nobox2.png', // Fallback to icon if image not available
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
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
              
              // App Name - Enhanced styling
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
              
              // Subtitle - Professional tagline
              const Text(
                'Professional Chat Management',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w400,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Enhanced Loading indicator with dots animation
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
              
              // Status text - Dynamic initialization status
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
}