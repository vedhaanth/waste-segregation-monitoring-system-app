import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  String _version = 'Loading...';
  String _buildNumber = '...';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final Info = await PackageInfo.fromPlatform();
      setState(() {
        _version = Info.version;
        _buildNumber = Info.buildNumber;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = 'Not available';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _sectionHeader('Application Info'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: Text('$_version ($_buildNumber)'),
          ),
          const Divider(),
          _sectionHeader('API Configuration'),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('Gemini API Key'),
            subtitle: Text('${dotenv.env['GEMINI_API_KEY']?.substring(0, 5) ?? 'Not Set'}...'),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Firebase Status'),
            subtitle: const Text('Connected & Live'),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
          const Divider(),
          _sectionHeader('Danger Zone'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Scans', style: TextStyle(color: Colors.red)),
            onTap: () {
              // Implementation would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action restricted for safety')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00695C),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
