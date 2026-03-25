import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard/dashboard_page.dart';

class PinAuthPage extends StatefulWidget {
  const PinAuthPage({super.key});

  @override
  State<PinAuthPage> createState() => _PinAuthPageState();
}

class _PinAuthPageState extends State<PinAuthPage> {
  final List<TextEditingController> _pinControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  int _pinLength = 4;
  String _savedPin = '';

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('user_pin') ?? '';
      _pinLength = prefs.getInt('pin_length') ?? 4;
    });
    if (_savedPin.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    }
  }

  void _verifyPin() async {
    String enteredPin = '';
    for (int i = 0; i < _pinLength; i++) {
      enteredPin += _pinControllers[i].text;
    }

    if (enteredPin == _savedPin) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        for (var c in _pinControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
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
                      const Icon(Icons.lock_person_rounded, size: 64, color: Color(0xFF2E7D32)),
                      const SizedBox(height: 16),
                      Text(
                        'Unlock App',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your $_pinLength-digit security PIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),

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
                                if (value.isNotEmpty) {
                                  if (index < _pinLength - 1) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else {
                                    _verifyPin();
                                  }
                                } else if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              },
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      TextButton(
                        onPressed: () {
                          // Handle forgot PIN (maybe logout and re-login)
                          Navigator.pop(context);
                        },
                        child: const Text('Logout and try again', style: TextStyle(color: Colors.grey)),
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
