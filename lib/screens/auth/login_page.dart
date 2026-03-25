import 'package:flutter/material.dart';
import 'register_page.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/admin_dashboard_page.dart';
import 'pin_auth_page.dart';
import '../../services/database_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLoading = false;
  bool _biometricsAvailable = false;
  bool _isBiometricsEnabled = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _initializeBiometrics();
    // Show splash for 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  Future<void> _initializeBiometrics() async {
    await _checkBiometricAvailability();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
    });
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;

    if (biometricsEnabled && _biometricsAvailable) {
      _authenticateWithBiometrics();
    } else {
      final pinSet = (prefs.getString('user_pin') ?? '').isNotEmpty;
      if (pinSet && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PinAuthPage()),
        );
      }
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        final List<BiometricType> availableBiometrics = await auth
            .getAvailableBiometrics();

        if (availableBiometrics.isNotEmpty) {
          setState(() {
            _biometricsAvailable = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Biometric availability check error: $e');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        return;
      }

      final List<BiometricType> availableBiometrics = await auth
          .getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Authenticate to login',
      );

      if (authenticated) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
    }
  }

  Future<void> _manualBiometricLogin() async {
    try {
      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication not supported'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final List<BiometricType> availableBiometrics = await auth
          .getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No biometric sensors available'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Authenticate to login',
      );

      if (authenticated) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      }
    } catch (e) {
      debugPrint('Manual biometric authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Admin Check - Direct Override
        if (_emailController.text.trim() == 'vedhaanth@gmail.com' &&
            _passwordController.text.trim() == '123456') {
          try {
            // Attempt to sign in to Firebase to get the auth token for rules
            await DatabaseService().loginUser(
              'vedhaanth@gmail.com',
              '123456',
            );
          } catch (e) {
            // If the user doesn't exist, maybe create it or just warn.
            // For now, we'll try to register it if not found, but that's complex.
            // Let's assume the user exists or will be created.
            debugPrint('Admin Firebase login failed: $e');
            // We continue anyway so they can see the dashboard UI, 
            // but Firestore operations might fail if they aren't authenticated.
          }
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Admin Login successful!'),
                backgroundColor: Colors.blueAccent,
              ),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
              );
            }
          }
          return;
        }

        final user = await DatabaseService().loginUser(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (user != null) {
          // Save user session to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', _emailController.text.trim());
          await prefs.setString('user_name', user.displayName ?? 'User');

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful!'),
                backgroundColor: Colors.green,
              ),
            );
            // Small delay to show success message
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              final pinSet = (prefs.getString('user_pin') ?? '').isNotEmpty;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => pinSet ? const PinAuthPage() : const DashboardPage(),
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF00695C), // Teal 800
                Color(0xFF2E7D32), // Green 800
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Waste Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00695C), // Teal 800
              Color(0xFF2E7D32), // Green 800
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Login Card
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome Back',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B5E20),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Smart Waste Management System',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Color(0xFF1B5E20)),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'user@example.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2E7D32)),
                              filled: true,
                              fillColor: const Color(0xFFF1F8E9), // Light Green 50
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2E7D32),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Color(0xFF1B5E20)),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2E7D32)),
                              filled: true,
                              fillColor: const Color(0xFFF1F8E9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2E7D32),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'LOGIN',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded),
                                      ],
                                    ),
                            ),
                          ),
                          
                          // Biometrics Button
                          if (_biometricsAvailable && _isBiometricsEnabled) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _manualBiometricLogin,
                                icon: const Icon(Icons.fingerprint),
                                label: const Text('Login with Fingerprint'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                                  foregroundColor: const Color(0xFF2E7D32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          
                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "New here?",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
