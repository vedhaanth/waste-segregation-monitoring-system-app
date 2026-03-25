import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard/dashboard_page.dart';

class SecuritySetupPage extends StatefulWidget {
  const SecuritySetupPage({super.key});

  @override
  State<SecuritySetupPage> createState() => _SecuritySetupPageState();
}

class _SecuritySetupPageState extends State<SecuritySetupPage> {
  final LocalAuthentication auth = LocalAuthentication();
  final List<TextEditingController> _pinControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  int _pinLength = 4;
  bool _isBiometricsEnabled = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final bool canCheck = await auth.canCheckBiometrics;
      final bool isSupported = await auth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canCheck && isSupported;
      });
    } catch (e) {
      debugPrint('Biometric check error: $e');
    }
  }

  Future<void> _setupBiometrics() async {
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Verify your identity to enable fingerprint login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        setState(() {
          _isBiometricsEnabled = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint linked successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
    }
  }

  void _saveAndProceed() async {
    String pin = '';
    for (int i = 0; i < _pinLength; i++) {
      if (_pinControllers[i].text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a $_pinLength-digit PIN')),
        );
        return;
      }
      pin += _pinControllers[i].text;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', pin);
    await prefs.setBool('biometrics_enabled', _isBiometricsEnabled);
    await prefs.setInt('pin_length', _pinLength);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00695C), Color(0xFF2E7D32)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security_rounded, size: 64, color: Color(0xFF2E7D32)),
                      const SizedBox(height: 16),
                      Text(
                        'Secure Your Account',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set up a PIN or use your fingerprint for quicker access.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),
                      
                      // PIN Length Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLengthOption(4),
                          const SizedBox(width: 16),
                          _buildLengthOption(6),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // PIN Input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pinLength, (index) {
                          return Container(
                            width: 40,
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextField(
                              controller: _pinControllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 1,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                              decoration: InputDecoration(
                                counterText: "",
                                filled: true,
                                fillColor: const Color(0xFFF1F8E9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty && index < _pinLength - 1) {
                                  _focusNodes[index + 1].requestFocus();
                                } else if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              },
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      if (_canCheckBiometrics) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isBiometricsEnabled ? const Color(0xFFE8F5E9) : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.fingerprint,
                              color: _isBiometricsEnabled ? const Color(0xFF2E7D32) : Colors.grey,
                            ),
                          ),
                          title: const Text('Fingerprint Login', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(_isBiometricsEnabled ? 'Enabled' : 'Touch to set up'),
                          trailing: Switch(
                            value: _isBiometricsEnabled,
                            onChanged: (val) {
                              if (val) _setupBiometrics();
                              else setState(() => _isBiometricsEnabled = false);
                            },
                            activeColor: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _saveAndProceed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: const Text('COMPLETE SETUP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLengthOption(int length) {
    bool isSelected = _pinLength == length;
    return GestureDetector(
      onTap: () {
        setState(() {
          _pinLength = length;
          for (var c in _pinControllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E7D32)),
        ),
        child: Text(
          '$length Digits',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _pinControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}
