import 'package:flutter/material.dart';
import '../../models/waste_result.dart';

class ResultDetailsPage extends StatelessWidget {
  final WasteResult result;

  const ResultDetailsPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Details'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              _getIconForType(result.type),
                              size: 32,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.type,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        result.tag.toLowerCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "AI: Analysis complete. Verified scan history data.",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (result.confidence / 100).clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F9D58),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "${result.confidence}% match",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    if (result.detailedAnalysis.isNotEmpty) ...[
                      const Text(
                        "Detailed Analysis",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00695C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.detailedAnalysis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const Divider(height: 32),
                    ],

                    _buildSectionHeader(Icons.check_circle_outline, "Disposal Instructions", isPrimary: true),
                    ...result.disposalInstructions.map((instruction) => _buildInstructionItem(instruction)),
                    
                    const SizedBox(height: 16),
                    _buildExpansionTile(Icons.recycling, "Recycling Options", result.recyclingOptions),
                    _buildExpansionTile(Icons.info_outline, "Pro Tips", result.proTips),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: isPrimary ? const Color(0xFF0F9D58) : Colors.black87, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right_alt, color: Color(0xFF0F9D58), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[800]))),
        ],
      ),
    );
  }

  Widget _buildExpansionTile(IconData icon, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(left: 28.0, bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Text(item)),
          ],
        ),
      )).toList(),
    );
  }

  IconData _getIconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('plastic')) return Icons.local_drink;
    if (t.contains('paper') || t.contains('cardboard')) return Icons.description;
    if (t.contains('glass')) return Icons.wine_bar;
    if (t.contains('metal') || t.contains('can')) return Icons.view_comfy;
    if (t.contains('organic') || t.contains('food')) return Icons.compost;
    if (t.contains('e-waste') || t.contains('electronic')) return Icons.phone_android;
    return Icons.delete_outline;
  }
}
