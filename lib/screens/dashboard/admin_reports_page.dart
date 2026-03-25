import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Reports'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('reports').get().asStream(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Export to Excel',
                  onPressed: () => _exportToExcel(context, snapshot.data!.docs),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No reports found.'));
          }

          final reports = snapshot.data!.docs;

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final reportData = reports[index].data() as Map<String, dynamic>;
              final email = reportData['userEmail'] ?? 'Unknown User';
              final type = reportData['type'] ?? 'General';
              final description = reportData['description'] ?? 'No description';
              final status = reportData['status'] ?? 'Pending';
              final timestamp = (reportData['timestamp'] as Timestamp?)?.toDate();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () {
                      final path = reportData['imagePath'];
                      if (path != null && File(path).existsSync()) {
                        _showFullImage(context, path);
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: reportData['imagePath'] != null && File(reportData['imagePath']).existsSync()
                              ? Image.file(File(reportData['imagePath']), fit: BoxFit.cover)
                              : Icon(Icons.image_not_supported, color: Colors.grey[400]),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: status == 'Pending' ? Colors.orange : Colors.green,
                            child: Icon(
                              status == 'Pending' ? Icons.pending : Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Text(type),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By: $email', 
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis
                      ),
                      Text(
                        'Info: $description', 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (timestamp != null)
                            Flexible(
                              flex: 2,
                              child: Text(
                                timestamp.toLocal().toString().substring(0, 16),
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const Spacer(),
                          if (reportData['location_url'] != null && reportData['location_url'] != 'Location not provided')
                            Flexible(
                              flex: 3,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final url = reportData['location_url'];
                                  final uri = Uri.parse(url);
                                  try {
                                    bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    if (!launched && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not open maps')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.location_on_outlined, size: 14, color: Colors.blue),
                                label: const Text(
                                  'View Maps', 
                                  style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(status.toUpperCase(), style: TextStyle(
                    color: status == 'Pending' ? Colors.orange[800] : Colors.green[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  )),
                  onTap: () {
                    // Update report status
                    _updateReportStatus(
                      context, 
                      reports[index].id, 
                      status,
                      reportData['userId'] ?? '',
                      type,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFullImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(path)),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel(BuildContext context, List<QueryDocumentSnapshot> reports) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating Excel file...')),
      );

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Reports'];
      excel.delete('Sheet1'); // Remove default sheet

      // Add Headers
      sheetObject.appendRow([
        TextCellValue('ID'),
        TextCellValue('User Email'),
        TextCellValue('Issue Type'),
        TextCellValue('Description'),
        TextCellValue('Status'),
        TextCellValue('Date'),
        TextCellValue('Location URL')
      ]);

      // Add Data
      for (var doc in reports) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        sheetObject.appendRow([
          TextCellValue(doc.id),
          TextCellValue(data['userEmail'] ?? ''),
          TextCellValue(data['type'] ?? ''),
          TextCellValue(data['description'] ?? ''),
          TextCellValue(data['status'] ?? ''),
          TextCellValue(timestamp?.toLocal().toString().substring(0, 16) ?? 'N/A'),
          TextCellValue(data['location_url'] ?? ''),
        ]);
      }

      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/waste_reports_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final fileBytes = excel.save();
      
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles([XFile(filePath)], text: 'Waste Management Reports Export');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _updateReportStatus(
    BuildContext context, 
    String reportId, 
    String currentStatus,
    String reporterId,
    String reportType,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Status'),
          content: Text('Mark this report as ${currentStatus == 'Pending' ? 'Resolved' : 'Pending'}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newStatus = currentStatus == 'Pending' ? 'Resolved' : 'Pending';
                
                try {
                  await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
                    'status': newStatus,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  // Send notification to the user
                  if (reporterId.isNotEmpty) {
                    await DatabaseService().createNotification(
                      userId: reporterId,
                      title: 'Report Update',
                      body: 'Your report regarding "$reportType" has been marked as $newStatus.',
                      type: 'report_update',
                      data: {
                        'reportId': reportId,
                        'status': newStatus,
                      },
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Report marked as $newStatus')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating report: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}
