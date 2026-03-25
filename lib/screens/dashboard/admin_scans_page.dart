import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminScansPage extends StatelessWidget {
  const AdminScansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Scans'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('scan_history').get().asStream(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Export Scans',
                  onPressed: () => _exportToExcel(context, snapshot.data!.docs),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('scan_history').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No scans found.'));
          }

          final scans = snapshot.data!.docs;

          return ListView.builder(
            itemCount: scans.length,
            itemBuilder: (context, index) {
              final scanData = scans[index].data() as Map<String, dynamic>;
              final email = scanData['userEmail'] ?? 'Unknown User';
              final item = scanData['item'] as Map<String, dynamic>? ?? {};
              final classification = scanData['classification'] as Map<String, dynamic>? ?? {};
              final timestamp = (scanData['timestamp'] as Timestamp?)?.toDate();
              final itemName = item['type'] ?? 'Unknown';
              final tag = classification['tag'] ?? 'Unclassified';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00695C)),
                  ),
                  title: Text(itemName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('By: $email'),
                      Text('Tag: $tag', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      if (timestamp != null)
                        Text(
                          'Date: ${timestamp.toLocal().toString().substring(0, 19)}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () {
                    // Show full scan details
                    _showScanDetail(context, scanData);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _exportToExcel(BuildContext context, List<QueryDocumentSnapshot> scans) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating Scan History Export...')),
      );

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Scans'];
      excel.delete('Sheet1');

      // Add Headers
      sheetObject.appendRow([
        TextCellValue('Scan ID'),
        TextCellValue('User Email'),
        TextCellValue('Item Type'),
        TextCellValue('Description'),
        TextCellValue('Tag'),
        TextCellValue('Confidence'),
        TextCellValue('Date')
      ]);

      // Add Data
      for (var doc in scans) {
        final data = doc.data() as Map<String, dynamic>;
        final item = data['item'] as Map<String, dynamic>? ?? {};
        final classification = data['classification'] as Map<String, dynamic>? ?? {};
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        sheetObject.appendRow([
          TextCellValue(doc.id),
          TextCellValue(data['userEmail'] ?? ''),
          TextCellValue(item['type'] ?? ''),
          TextCellValue(item['description'] ?? ''),
          TextCellValue(classification['tag'] ?? ''),
          TextCellValue('${((classification['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
          TextCellValue(timestamp?.toLocal().toString().substring(0, 19) ?? 'N/A'),
        ]);
      }

      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/scans_export_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final fileBytes = excel.save();
      
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(filePath)], text: 'System Scans Export');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showScanDetail(BuildContext context, Map<String, dynamic> scanData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        final item = scanData['item'] as Map<String, dynamic>? ?? {};
        final classification = scanData['classification'] as Map<String, dynamic>? ?? {};
        final guidance = scanData['guidance'] as Map<String, dynamic>? ?? {};
        
        return Container(
          padding: const EdgeInsets.all(24.0),
          height: MediaQuery.of(context).size.height * 0.7,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scan Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _detailTile('Item Type', item['type']),
                _detailTile('Description', item['description']),
                _detailTile('Tag', classification['tag']),
                _detailTile('Confidence', '${((classification['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 16),
                const Text('Guidance:', style: TextStyle(fontWeight: FontWeight.bold)),
                _detailTile('Instructions', guidance['disposalInstructions']),
                _detailTile('Recycling', guidance['recyclingOptions']),
                _detailTile('Pro Tips', guidance['proTips']),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailTile(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value?.toString() ?? 'N/A', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
