import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../models/waste_result.dart';
import '../auth/login_page.dart';
import '../auth/security_setup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _biometricsEnabled = false;
  bool _notificationsEnabled = true;
  bool _autoLoginEnabled = false;
  bool _darkModeEnabled = false;
  String _userName = '';
  String _userEmail = '';
  String _appVersion = '1.0.0';
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _autoLoginEnabled = prefs.getBool('auto_login_enabled') ?? false;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _userName = prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? '';
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      debugPrint('Error loading app version: $e');
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }


  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      try {
        final bool canCheckBiometrics = await _auth.canCheckBiometrics;
        final bool isDeviceSupported = await _auth.isDeviceSupported();
        final List<BiometricType> availableBiometrics = await _auth
            .getAvailableBiometrics();

        if (!canCheckBiometrics || !isDeviceSupported) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometrics not supported on this device'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Check if we have fingerprint or face
        final hasFingerprint = availableBiometrics.contains(
          BiometricType.fingerprint,
        );
        final hasFace = availableBiometrics.contains(BiometricType.face);

        if (!hasFingerprint && !hasFace) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Only fingerprint and face authentication are supported for login.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final authenticated = await _auth.authenticate(
          localizedReason: 'Authenticate to enable biometric login',
        );

        if (authenticated) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('biometrics_enabled', true);
          setState(() {
            _biometricsEnabled = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric login enabled'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication failed. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Biometric authentication error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Biometric setup failed: ${e.toString().split('.').first}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometrics_enabled', false);
      setState(() {
        _biometricsEnabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _toggleAutoLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login_enabled', value);
    setState(() {
      _autoLoginEnabled = value;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_enabled', value);
    setState(() {
      _darkModeEnabled = value;
    });
    // Update the app's theme immediately
    MyApp.updateTheme(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Dark mode enabled' : 'Light mode enabled'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _clearScanHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Scan History'),
        content: const Text(
          'Are you sure you want to clear all scan history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (DatabaseService().isConnected) {
          await DatabaseService().clearUserScanHistory(_userEmail);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Scan history cleared successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Database not connected. Cannot clear history.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _changeSecuritySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecuritySetupPage()),
    ).then((_) => _loadSettings());
  }

  Future<void> _exportData() async {
    try {
      if (!DatabaseService().isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database not connected. Cannot export data.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final scans = await DatabaseService().getScanHistory(_userEmail);

      if (scans.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No scan history to export.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create Excel file
      var excel = Excel.createExcel();
      
      // Rename default sheet if possible, or just use it
      String sheetName = 'Scan History';
      excel.rename('Sheet1', sheetName);
      Sheet sheetObject = excel[sheetName];

      // Add Headers
      List<String> headers = [
        'Date',
        'Waste Type',
        'Category',
        'Confidence',
        'Description',
        'Disposal Instructions',
        'Recycling Options',
        'Pro Tips',
      ];

      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Add Data
      for (var scan in scans) {
        // Use WasteResult model to parse nested data
        final result = WasteResult.fromMap(scan);

        // Format timestamp robustly
        String dateStr = 'Unknown Date';
        if (scan['timestamp'] != null) {
          if (scan['timestamp'] is Timestamp) {
            dateStr = (scan['timestamp'] as Timestamp).toDate().toLocal().toString();
          } else if (scan['timestamp'] is DateTime) {
            dateStr = (scan['timestamp'] as DateTime).toLocal().toString();
          } else {
            dateStr = scan['timestamp'].toString();
          }
        }

        List<CellValue> row = [
          TextCellValue(dateStr),
          TextCellValue(result.type),
          TextCellValue(result.tag),
          IntCellValue(result.confidence),
          TextCellValue(result.description),
          TextCellValue(result.disposalInstructions.join('; ')),
          TextCellValue(result.recyclingOptions.join('; ')),
          TextCellValue(result.proTips.join('; ')),
        ];

        sheetObject.appendRow(row);
      }

      // Save file
      var fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/scan_history_export.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes);

      // Share file
      if (mounted) {
        await Share.shareXFiles([XFile(path)], text: 'Waste Management Scan History');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpSection(
                'Getting Started',
                '1. Register or login to your account\n2. Scan waste items using the camera\n3. View disposal instructions\n4. Track your scan history',
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Contact Support',
                'Email: support@wastemanagement.app\nPhone: +1 (555) 123-4567\nHours: Mon-Fri 9AM-5PM',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ],
    );
  }

  void _showTermsPrivacy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpSection(
                'Terms of Service',
                'By using this app, you agree to:\n• Use the app responsibly\n• Provide accurate information\n• Follow waste disposal guidelines\n• Respect environmental regulations',
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Privacy Policy',
                'We respect your privacy:\n• Your data is stored securely\n• We do not share personal information\n• Scan history is stored locally\n• You can export or delete your data anytime',
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Data Usage',
                'The app uses:\n• Camera for waste scanning\n• Firebase for data storage\n• AI for waste classification\n• Location (optional) for finding bins',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _rateApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Our App'),
        content: const Text(
          'Thank you for using our app! Your feedback helps us improve.\n\nWould you like to rate us on the Play Store?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening Play Store...'),
                  backgroundColor: Colors.blue,
                ),
              );
              // In a real app, you would use url_launcher to open Play Store
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _showEditProfile() {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email (cannot be changed)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Update name in database (optional)
                try {
                  await DatabaseService().updateUserName(
                    _userEmail,
                    nameController.text.trim(),
                  );
                } catch (e) {
                  debugPrint('Failed to update name in database: $e');
                  // Continue anyway since SharedPreferences update is more important
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', nameController.text.trim());

                setState(() {
                  _userName = nameController.text.trim();
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account?\n\nThis will:\n• Delete all your data\n• Remove scan history\n• Cannot be undone',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final passwordController = TextEditingController();
      final bool? reauthSuccess = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verify Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please enter your password to confirm account deletion.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null && user.email != null) {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: passwordController.text,
                    );
                    await user.reauthenticateWithCredential(credential);
                    if (context.mounted) Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Confirm Deletion'),
            ),
          ],
        ),
      );

      if (reauthSuccess == true) {
        try {
          if (DatabaseService().isConnected) {
            await DatabaseService().deleteUserAccount();
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account and all data deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                );
                return;
              }
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: oldPasswordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);
                  
                  // Update password in database as well (if stored there)
                  await DatabaseService().updateUserPassword(user.email!, newPasswordController.text);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.setBool('auto_login_enabled', false);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.grey[100];
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ??
        const Color(0xFF2E7D32);
    final appBarForeground =
        Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: appBarColor,
        foregroundColor: appBarForeground,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // User Profile Section
          _buildSectionHeader('Profile'),
          _buildProfileCard(),
          const SizedBox(height: 16),

          // Security & Privacy
          _buildSectionHeader('Security & Privacy'),
          _buildSettingTile(
            icon: Icons.fingerprint,
            title: 'Biometric Login',
            subtitle: 'Use fingerprint or face ID to login',
            trailing: Switch(
              value: _biometricsEnabled,
              onChanged: _toggleBiometrics,
              activeThumbColor: const Color(0xFF2E7D32),
            ),
          ),
          _buildSettingTile(
            icon: Icons.login,
            title: 'Auto Login',
            subtitle: 'Automatically login on app start',
            trailing: Switch(
              value: _autoLoginEnabled,
              onChanged: _toggleAutoLogin,
              activeThumbColor: const Color(0xFF2E7D32),
            ),
          ),
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 16),


          // Security
          _buildSectionHeader('Security'),
          _buildSettingTile(
            icon: Icons.security,
            title: 'PIN & Biometrics',
            subtitle: 'Update your security PIN or fingerprint',
            onTap: _changeSecuritySettings,
          ),
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 16),

          // App Preferences
          _buildSectionHeader('App Preferences'),
          _buildSettingTile(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            subtitle: 'Switch between light and dark theme',
            trailing: Switch(
              value: _darkModeEnabled,
              onChanged: _toggleDarkMode,
              activeThumbColor: const Color(0xFF2E7D32),
            ),
          ),
          _buildSettingTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Enable or disable app notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeThumbColor: const Color(0xFF2E7D32),
            ),
          ),
          _buildSettingTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English (US)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Language selection coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Data Management
          _buildSectionHeader('Data Management'),
          _buildSettingTile(
            icon: Icons.delete_outline,
            title: 'Clear Scan History',
            subtitle: 'Delete all scanned waste records',
            onTap: _clearScanHistory,
            textColor: Colors.red,
          ),
          _buildSettingTile(
            icon: Icons.download,
            title: 'Export Data',
            subtitle: 'Download your data as Excel Format',
            onTap: _exportData,
          ),
          _buildSettingTile(
            icon: Icons.backup,
            title: 'Backup Settings',
            subtitle: 'Configure automatic backups',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup settings coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // About & Help
          _buildSectionHeader('About & Help'),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: 'Version $_appVersion',
            onTap: () {
              HapticFeedback.lightImpact();
            },
          ),
          _buildSettingTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: _showHelpSupport,
          ),
          _buildSettingTile(
            icon: Icons.description_outlined,
            title: 'Terms & Privacy',
            subtitle: 'View terms of service and privacy policy',
            onTap: _showTermsPrivacy,
          ),
          _buildSettingTile(
            icon: Icons.star_outline,
            title: 'Rate App',
            subtitle: 'Rate us on the Play Store',
            onTap: _rateApp,
          ),
          const SizedBox(height: 16),

          // Account Actions
          _buildSectionHeader('Account'),
          _buildSettingTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out from your account',
            onTap: _logout,
            textColor: Colors.red,
          ),
          _buildSettingTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            onTap: _deleteAccount,
            textColor: Colors.red,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: headerColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail.isNotEmpty ? _userEmail : 'No email',
                  style: TextStyle(fontSize: 14, color: subTextColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textColor),
            onPressed: _showEditProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? const Color(0xFF2E7D32)),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: subtitleColor),
              )
            : null,
        trailing:
            trailing ?? Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}
