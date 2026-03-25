import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../auth/login_page.dart';
import 'admin_users_page.dart';
import 'admin_scans_page.dart';
import 'admin_reports_page.dart';
import 'admin_settings_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _totalUsers = 0;
  int _totalScans = 0;
  int _pendingReports = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final scansSnapshot = await FirebaseFirestore.instance.collection('scan_history').get();
      final reportsSnapshot = await FirebaseFirestore.instance.collection('reports').where('status', isEqualTo: 'Pending').get();

      if (mounted) {
        setState(() {
          _totalUsers = usersSnapshot.size;
          _totalScans = scansSnapshot.size;
          _pendingReports = reportsSnapshot.size;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              DatabaseService().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00695C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Users',
                          _totalUsers.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Total Scans',
                          _totalScans.toString(),
                          Icons.qr_code_scanner,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Pending Reports',
                          _pendingReports.toString(),
                          Icons.report_problem,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActionTile(
                    'Manage Users',
                    'View and manage system users',
                    Icons.manage_accounts,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminUsersPage()),
                    ),
                  ),
                  _buildActionTile(
                    'View All Scans',
                    'Monitor waste classification history',
                    Icons.history,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminScansPage()),
                    ),
                  ),
                  _buildActionTile(
                    'Review Reports',
                    'Handle user reported issues',
                    Icons.assignment,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminReportsPage()),
                    ),
                  ),
                  _buildActionTile(
                    'System Settings',
                    'Configure AI models and API keys',
                    Icons.settings,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminSettingsPage()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0F2F1),
          child: Icon(icon, color: const Color(0xFF00695C)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
