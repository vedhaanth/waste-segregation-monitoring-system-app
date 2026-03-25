import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';
import '../../models/waste_result.dart';

import '../guide/report_issue_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ImagePicker _picker = ImagePicker();
  dynamic _image; // File for mobile, Uint8List for web
  bool _isAnalyzing = false;
  WasteResult? _analysisResult;

  @override
  void initState() {
    super.initState();
    _connectToDatabase();
  }

  Future<void> _connectToDatabase() async {
    try {
      await DatabaseService().connect();
    } catch (e) {
      debugPrint('Failed to connect to database: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Database connection failed. Some features may not work properly.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Image handling methods restored
  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (photo != null) {
        setState(() {
          if (kIsWeb) {
            // For web, read as bytes
            photo.readAsBytes().then((bytes) {
              setState(() {
                _image = bytes;
              });
            });
          } else {
            _image = File(photo.path);
          }
          _analysisResult = null; // Reset previous result
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capture image: $e')));
      }
    }
  }

  void _removeImage() {
    setState(() {
      _image = null;
      _analysisResult = null;
    });
  }

  // AI Analysis
  // API Key loaded from .env file

  Future<void> _identifyWaste() async {
    if (_image == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final imageBytes = kIsWeb
          ? _image as Uint8List
          : await (_image as File).readAsBytes();

      final data = await AIService().analyzeWaste(imageBytes);

      setState(() {
        _analysisResult = WasteResult(
          type: data['type'] ?? 'Unknown',
          description: data['description'] ?? 'No description available',
          detailedAnalysis:
              data['detailed_analysis'] ?? 'AI identification in progress...',
          tag: data['tag'] ?? 'waste',
          confidence: data['confidence'] ?? 0,
          disposalInstructions: List<String>.from(
            data['disposal_instructions'] ?? [],
          ),
          recyclingOptions: List<String>.from(data['recycling_options'] ?? []),
          proTips: List<String>.from(data['pro_tips'] ?? []),
        );
      });

      // Save to database
      if (_analysisResult != null) {
        _saveScanResult(_analysisResult!);
      }
    } catch (e) {
      debugPrint("AI Error: $e. Using Fallback Mock.");

      await Future.delayed(const Duration(seconds: 1));
      _parseResponse(_getMockResponse());

      if (mounted) {
        String msg = 'Using offline estimation.';
        if (e.toString().contains('Quota')) {
          msg = 'AI Limit Reached (Quota). Using offline fallback.';
        } else if (e.toString().contains('host') ||
            e.toString().contains('Socket')) {
          msg = 'No Internet connection. Using offline fallback.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  String _getMockResponse() {
    // Randomize slightly for variety if needed, but here's a standard fallback
    return """
{
  "type": "General Waste",
  "description": "Unidentified household waste item",
  "detailed_analysis": "The analysis indicates this is a general waste item that should be disposed of carefully.",
  "tag": "waste",
  "confidence": 85,
  "disposal_instructions": [
    "Check local guidelines if unsure",
    "Separate if recyclable material is visible",
    "Dispose in general waste bin if non-recyclable"
  ],
  "recycling_options": [
    "Community recycling center",
    "Curbside pickup"
  ],
  "pro_tips": [
    "Rinse containers before recycling",
    "Reduce waste by choosing reusable alternatives"
  ]
}
""";
  }

  void _parseResponse(String responseText) {
    try {
      // Robust JSON Extraction using Regex
      final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
      final match = jsonRegex.firstMatch(responseText);

      if (match == null) {
        throw FormatException("No valid JSON found in response");
      }

      String jsonString = match.group(0)!;
      final data = jsonDecode(jsonString);

      setState(() {
        _analysisResult = WasteResult(
          type: data['type'] ?? 'Unknown',
          description: data['description'] ?? 'No description available',
          detailedAnalysis:
              data['detailed_analysis'] ?? 'AI identification in progress...',
          tag: data['tag'] ?? 'waste',
          confidence: data['confidence'] ?? 0,
          disposalInstructions: List<String>.from(
            data['disposal_instructions'] ?? [],
          ),
          recyclingOptions: List<String>.from(data['recycling_options'] ?? []),
          proTips: List<String>.from(data['pro_tips'] ?? []),
        );
      });

      // Save to database
      _saveScanResult(_analysisResult!);
    } catch (e) {
      debugPrint("JSON Parse Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process AI results.')),
        );
      }
    }
  }

  Future<void> _saveScanResult(WasteResult result) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? '';

      if (userEmail.isEmpty) {
        debugPrint('No user logged in, cannot save scan result');
        return;
      }

      final dbService = DatabaseService();
      await dbService.saveScanResult({
        'userEmail': userEmail,
        'type': result.type,
        'description': result.description,
        'detailedAnalysis': result.detailedAnalysis,
        'tag': result.tag,
        'confidence': result.confidence,
        'disposalInstructions': result.disposalInstructions,
        'recyclingOptions': result.recyclingOptions,
        'proTips': result.proTips,
      });
    } catch (e) {
      debugPrint('DB Save Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save scan result to database. Please check your connection.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
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
                            _getIconForType(_analysisResult!.type),
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
                              _analysisResult!.type,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _analysisResult!.description,
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
                      _analysisResult!.tag.toLowerCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "AI: Analysis complete. Verify contents before disposal.",
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
                        widthFactor: (_analysisResult!.confidence / 100),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
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
                        "${_analysisResult!.confidence}% match",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                  if (_analysisResult!.detailedAnalysis.isNotEmpty) ...[
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
                      _analysisResult!.detailedAnalysis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const Divider(height: 32),
                  ],

                  // Disposal Instructions (Pre-expanded styled look)
                  _buildSectionHeader(
                    Icons.check_circle_outline,
                    "Disposal Instructions",
                    isPrimary: true,
                  ),
                  ..._analysisResult!.disposalInstructions.map(
                    (instruction) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.arrow_right_alt,
                            color: Color(0xFF0F9D58),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              instruction,
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildExpansionTile(
                    Icons.recycling,
                    "Recycling Options",
                    _analysisResult!.recyclingOptions,
                  ),
                  _buildExpansionTile(
                    Icons.info_outline,
                    "Pro Tips",
                    _analysisResult!.proTips,
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Locating nearby centers...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Find Nearby Bins & Centers'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportIssuePage(
                              initialType:
                                  _analysisResult!.type.contains('Plastic')
                                  ? 'Garbage Heaps'
                                  : 'Other',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Report This as an Issue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[100],
                        foregroundColor: Colors.orange[900],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.orange[300]!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _removeImage,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Another Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    IconData icon,
    String title, {
    bool isPrimary = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isPrimary ? const Color(0xFF0F9D58) : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          // Arrow icon removed as requested
        ],
      ),
    );
  }

  Widget _buildExpansionTile(IconData icon, String title, List<String> items) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 28.0, bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "• ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  IconData _getIconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('plastic')) {
      return Icons.local_drink;
    }
    if (t.contains('paper') || t.contains('cardboard')) {
      return Icons.description;
    }
    if (t.contains('glass')) {
      return Icons.wine_bar;
    }
    if (t.contains('metal') || t.contains('can')) {
      return Icons.view_comfy;
    }
    if (t.contains('organic') || t.contains('food')) {
      return Icons.compost;
    }
    if (t.contains('e-waste') || t.contains('electronic')) {
      return Icons.phone_android;
    }
    return Icons.delete_outline;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.grey[50];
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan Waste',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo to identify waste type and get disposal guidance',
                style: TextStyle(fontSize: 16, color: subtitleColor),
              ),
              const SizedBox(height: 24),

              if (_analysisResult != null) ...[
                Expanded(child: _buildResultView()),
              ] else ...[
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _image == null
                          ? (isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF0FDF4))
                          : Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _image == null
                            ? (isDark
                                  ? const Color(0xFF43A047)
                                  : const Color(0xFFA5D6A7))
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: _image != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  22,
                                ), // slightly less than container
                                child: kIsWeb
                                    ? Image.memory(
                                        _image as Uint8List,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        _image as File,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: GestureDetector(
                                  onTap: _removeImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 24,
                                left: 24,
                                right: 24,
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _isAnalyzing
                                        ? null
                                        : _identifyWaste,
                                    icon: _isAnalyzing
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome),
                                    label: Text(
                                      _isAnalyzing
                                          ? 'Analyzing...'
                                          : 'Identify Waste Type',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : CustomPaint(
                            painter: DashedBorderPainter(
                              color: const Color(0xFFA5D6A7),
                              strokeWidth: 2,
                              gap: 8,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE8F5E9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 48,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Scan Your Waste',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 40.0,
                                  ),
                                  child: Text(
                                    'Take a photo or upload an image to identify the waste type',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32.0,
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _getImage(ImageSource.camera),
                                          icon: const Icon(
                                            Icons.camera_alt_outlined,
                                          ),
                                          label: const Text('Camera'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _getImage(ImageSource.gallery),
                                          icon: const Icon(Icons.upload_file),
                                          label: const Text('Upload'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.black87,
                                            side: BorderSide(
                                              color: Colors.grey[300]!,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            backgroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Local WasteResult class removed in favor of models/waste_result.dart

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(24),
        ),
      );

    final PathMetrics pathMetrics = path.computeMetrics();
    for (PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + 10), // Dash length 10
          paint,
        );
        distance += 10 + gap;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
