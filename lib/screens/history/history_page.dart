import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../models/waste_result.dart';
import '../scan/result_details_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? '';

    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ??
        const Color(0xFF2E7D32);
    final appBarForeground =
        Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: appBarColor,
        foregroundColor: appBarForeground,
      ),
      body: userEmail.isEmpty
          ? const Center(child: Text('Please log in to see history'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService().watchScanHistory(user?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final history = snapshot.data ?? [];

                if (history.isEmpty) {
                  return const Center(child: Text('No scan history found'));
                }

                return ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final data = history[index];
                    final itemObj = data['item'] as Map<String, dynamic>? ?? {};
                    final classification = data['classification'] as Map<String, dynamic>? ?? {};
                    final timestamp = data['timestamp'] as Timestamp?;
                    
                    final dateStr = timestamp != null
                        ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}"
                        : 'Recent';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        onTap: () {
                          final result = WasteResult.fromMap(data);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResultDetailsPage(result: result),
                            ),
                          );
                        },
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.history_edu, color: Color(0xFF2E7D32)),
                        ),
                        title: Text(
                          itemObj['type'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(itemObj['description'] ?? ''),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${classification['confidence'] ?? 0}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                                fontSize: 16,
                              ),
                            ),
                            const Text('match', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
