import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').get().asStream(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Export Users',
                  onPressed: () => _exportToExcel(context, snapshot.data!.docs),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final email = userData['email'] ?? 'No email';
              final displayName = userData['displayName'] ?? 'No name';
              final stats = userData['stats'] as Map<String, dynamic>? ?? {};
              final totalScans = stats['totalScans'] ?? 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF00695C),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(displayName),
                subtitle: Text(email),
                trailing: Chip(
                  label: Text('Scans: $totalScans'),
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  // Show user details
                  _showUserDetail(context, userData);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _exportToExcel(BuildContext context, List<QueryDocumentSnapshot> users) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating User Export...')),
      );

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Users'];
      excel.delete('Sheet1');

      // Add Headers
      sheetObject.appendRow([
        TextCellValue('UID'),
        TextCellValue('Name'),
        TextCellValue('Email'),
        TextCellValue('Aadhaar'),
        TextCellValue('PAN'),
        TextCellValue('Total Scans'),
        TextCellValue('Points'),
        TextCellValue('CO2 Saved (kg)'),
        TextCellValue('Created At')
      ]);

      // Add Data
      for (var doc in users) {
        final data = doc.data() as Map<String, dynamic>;
        final kyc = data['kyc'] as Map<String, dynamic>? ?? {};
        final stats = data['stats'] as Map<String, dynamic>? ?? {};
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final createdAt = (metadata['createdAt'] as Timestamp?)?.toDate();
        
        sheetObject.appendRow([
          TextCellValue(data['uid'] ?? doc.id),
          TextCellValue(data['displayName'] ?? ''),
          TextCellValue(data['email'] ?? ''),
          TextCellValue(kyc['aadhaar'] ?? ''),
          TextCellValue(kyc['pan'] ?? ''),
          TextCellValue((stats['totalScans'] ?? 0).toString()),
          TextCellValue((stats['points'] ?? 0).toString()),
          TextCellValue((stats['co2Saved'] ?? 0.0).toString()),
          TextCellValue(createdAt?.toLocal().toString().substring(0, 16) ?? 'N/A'),
        ]);
      }

      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/users_export_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final fileBytes = excel.save();
      
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(filePath)], text: 'System Users Export');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showUserDetail(BuildContext context, Map<String, dynamic> userData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        final kyc = userData['kyc'] as Map<String, dynamic>? ?? {};
        final stats = userData['stats'] as Map<String, dynamic>? ?? {};
        
        return Container(
          padding: const EdgeInsets.all(24.0),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userData['displayName'] ?? 'User Details',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(userData['email'] ?? 'N/A'),
              ),
              if (kyc.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('Aadhaar'),
                  subtitle: Text(kyc['aadhaar'] ?? 'N/A'),
                ),
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text('PAN'),
                  subtitle: Text(kyc['pan'] ?? 'N/A'),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Stats:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statItem('Scans', '${stats['totalScans'] ?? 0}')),
                  Expanded(child: _statItem('Points', '${stats['points'] ?? 0}')),
                  Expanded(child: _statItem('CO2 Saved', '${(stats['co2Saved'] ?? 0.0).toStringAsFixed(1)} kg')),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00695C))),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
