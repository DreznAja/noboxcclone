import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/services/storage_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../home/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> 
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _loadingAnimationController;

  @override
  void initState() {
    super.initState();
    _loadingAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _loadLastUsername();
  }

  void _loadLastUsername() {
  final lastUsername = StorageService.getLastUsername();
  if (lastUsername != null && lastUsername.isNotEmpty) {
    _usernameController.text = lastUsername;
    print('📝 Loaded last username: $lastUsername');
  }
}

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  Widget _buildLoadingDot(int index) {
    return AnimatedBuilder(
      animation: _loadingAnimationController,
      builder: (context, child) {
        double animationValue = (_loadingAnimationController.value + (index * 0.3)) % 1.0;
        double scale = 0.5 + (0.5 * (1 - (animationValue - 0.5).abs() * 2).clamp(0.0, 1.0));
        double opacity = 0.4 + (0.6 * (1 - (animationValue - 0.5).abs() * 2).clamp(0.0, 1.0));
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Start loading animation
    _loadingAnimationController.repeat();

    print('Attempting login with username: ${_usernameController.text.trim()}');
    
    final success = await ref.read(authProvider.notifier).login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    // Stop loading animation
    _loadingAnimationController.stop();
    _loadingAnimationController.reset();

    if (success && mounted) {
      print('Login successful, navigating to home screen');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      print('Login failed');
    }
  }

// TIDAK ADA PERUBAHAN DI IMPORT - Tetap seperti original
// TIDAK PERLU import theme_provider karena login screen tidak pakai dark mode

@override
Widget build(BuildContext context) {
  final authState = ref.watch(authProvider);

  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.error!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      ref.read(authProvider.notifier).clearError();
    }
  });

  // WRAP DENGAN THEME UNTUK FORCE LIGHT MODE
  return Theme(
    data: ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.white,
      // Force input decoration theme to light
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: Colors.white,
        filled: false,
      ),
      // Force text theme to dark colors
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF1A1A1A)),
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/nobox2.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  const Text(
                    'NoBoxChat',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Sign in to your account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Username field - FIXED ROUNDED CORNERS
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      'Username',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
      ),
    ),
    const SizedBox(height: 8),
    TextFormField(
      controller: _usernameController,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        hintText: 'Enter your username',
        hintStyle: const TextStyle(
          color: Color(0xFF999999),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(
          Icons.person_outline_rounded,
          color: Color(0xFF666666),
          size: 22,
        ),
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF007AFF),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
      ),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Username is required';
        }
        return null;
      },
    ),
  ],
),

const SizedBox(height: 20),

// Password field - FIXED ROUNDED CORNERS
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      'Password',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
      ),
    ),
    const SizedBox(height: 8),
    TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        hintText: 'Enter your password',
        hintStyle: const TextStyle(
          color: Color(0xFF999999),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xFF666666),
          size: 22,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: const Color(0xFF666666),
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF007AFF),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
      ),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password is required';
        }
        return null;
      },
    ),
  ],
),
                  
                  const SizedBox(height: 32),
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                      child: authState.isLoading
                          ? SizedBox(
                              width: 40,
                              height: 20,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildLoadingDot(0),
                                  const SizedBox(width: 4),
                                  _buildLoadingDot(1),
                                  const SizedBox(width: 4),
                                  _buildLoadingDot(2),
                                ],
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Footer
                  const Text(
                    'Powered by Nobox',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
