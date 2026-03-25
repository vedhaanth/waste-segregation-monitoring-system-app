import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard/dashboard_page.dart';
import 'security_setup_page.dart';
import 'package:flutter/services.dart';
import '../../services/database_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLoading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // registerUser will automatically connect if needed
        await DatabaseService().registerUser(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          aadhaar: _aadhaarController.text.trim(),
          pan: _panController.text.trim(),
        );

        // Save user session to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', _emailController.text.trim());
        await prefs.setString('user_name', _nameController.text.trim());

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful!'),
              backgroundColor: Colors.green,
            ),
          );
          // Small delay to show success message
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SecuritySetupPage()),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Registration failed';
          if (e.toString().contains('Database not connected')) {
            errorMessage =
                'Cannot connect to database. Please check your internet connection and Firebase configuration.';
          } else if (e.toString().contains('already exists') || e.toString().contains('already in use')) {
            errorMessage =
                'This email is already registered. Please use a different email.';
          } else {
            errorMessage = 'Error: ${e.toString()}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: 48),
                // Logo Section
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Register Card
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
                            'Create Account',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join the Smart Waste System',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Full Name
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(color: Color(0xFF1B5E20)),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2E7D32)),
                              filled: true,
                              fillColor: const Color(0xFFF1F8E9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Color(0xFF1B5E20)),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2E7D32)),
                              filled: true,
                              fillColor: const Color(0xFFF1F8E9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
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
                          const SizedBox(height: 16),
                          
                          // Aadhaar
                          TextFormField(
                            controller: _aadhaarController,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            style: const TextStyle(color: Color(0xFF1B5E20)),
                            decoration: InputDecoration(
                              labelText: 'Aadhaar Number',
                              prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF2E7D32)),
                              counterText: "",
                              filled: true,
                              fillColor: const Color(0xFFF1F8E9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Required';
                              if (value.length != 12) return 'Must be 12 digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Password
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
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Required';
                              if (value.length < 6) return 'Min 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          const SizedBox(height: 24),
                          
                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('REGISTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Login Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Old member?", style: TextStyle(color: Colors.grey[600])),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Login', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
