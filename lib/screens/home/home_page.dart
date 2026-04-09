import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';

class HomePage extends StatefulWidget {
  final Function(int) onNavigate;

  const HomePage({super.key, required this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isReporting = false;

  final Map<String, String> _categoryGuidelines = {
    'Organic Waste':
        'Compostable items like food scraps, vegetable peels, and garden waste. Ensure no plastic bags are mixed.',
    'Recyclable':
        'Clean and dry items like paper, cardboard, plastic bottles, and glass. Please flatten boxes.',
    'Non-Recyclable':
        'Items that cannot be recycled or composted, such as diapers, ceramics, and contaminated packaging. Use black/grey bins.',
    'E-Waste':
        'Electronic items like old phones, batteries, and wires. Do not throw in regular bins. Schedule a special pickup.',
  };

  Future<void> _reportWaste({String? manualType}) async {
    setState(() => _isReporting = true);
    try {
      // 1. Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          setState(() => _isReporting = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied, we cannot request permissions.',
              ),
            ),
          );
        }
        setState(() => _isReporting = false);
        return;
      }

      // 2. Get current position
      final position = await Geolocator.getCurrentPosition();

      // 3. Take Photo
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo == null) {
        setState(() => _isReporting = false);
        return;
      }

      // 4. Determine Waste Type (AI or Manual)
      String wasteTypeDescription = manualType ?? "Waste";

      if (manualType == null) {
        try {
          final imageBytes = await File(photo.path).readAsBytes();
          wasteTypeDescription = await AIService().getQuickReport(imageBytes);
        } catch (e) {
          debugPrint("AI Analysis failed in report: $e");
        }
      } else {
        // Appending user clarification if manually selected
        wasteTypeDescription = "$manualType (User Identified)";
      }

      final String googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      // 6. Save to Database for Admin Dashboard
      await DatabaseService().submitReport({
        'type': wasteTypeDescription,
        'description': 'Waste reported from Quick Actions near ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'location_url': googleMapsUrl,
        'imagePath': photo.path,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Report Submitted'),
              ],
            ),
            content: Text(
              'Thank you for reporting the $wasteTypeDescription!\n\nYour contribution has been recorded and reported to the authorities.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Great!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reporting waste: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isReporting = false);
      }
    }
  }

  void _showCategoryDetails(String category, String guidelines) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            Text(category),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Disposal Guidelines:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(guidelines),
            const SizedBox(height: 16),
            const Text(
              'Is this accumulated or dumped illegally?',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _reportWaste(manualType: category);
            },
            icon: const Icon(Icons.report_problem),
            label: const Text('Report Issue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      color: backgroundColor,
      child: StreamBuilder<Map<String, dynamic>>(
        stream: DatabaseService().getUserStatsStream(),
        builder: (context, snapshot) {
          final stats =
              snapshot.data ?? {'scans': 0, 'disposed': 0, 'co2': 0.0};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        Icons.camera_alt_outlined,
                        '${stats['scans']}',
                        'Items Scanned',
                        cardColor: cardColor,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        Icons.recycling,
                        '${stats['disposed']}',
                        'Properly Disposed',
                        cardColor: cardColor,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        Icons.eco_outlined,
                        '${(stats['co2'] as num).toStringAsFixed(1)}kg',
                        'CO₂ Saved',
                        cardColor: cardColor,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Report Waste Button
                GestureDetector(
                  onTap: _isReporting ? null : () => _reportWaste(),
                  child: _buildQuickActionCard(
                    context,
                    icon: Icons.report_problem_outlined,
                    title: _isReporting
                        ? 'Getting Location...'
                        : 'Report Waste',
                    subtitle: 'Send location to corporation',
                    color: const Color(0xFFD32F2F), // Red color for report
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () => widget.onNavigate(1), // Switch to Scan tab
                  child: _buildQuickActionCard(
                    context,
                    icon: Icons.camera_alt_outlined,
                    title: 'Scan Waste',
                    subtitle: 'Identify & classify waste instantly',
                    color: Theme.of(context).colorScheme.primary,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => widget.onNavigate(2), // Switch to Guide tab
                  child: _buildQuickActionCard(
                    context,
                    icon: Icons.menu_book_outlined,
                    title: 'Waste Guide',
                    subtitle: 'Learn about disposal methods',
                    color: Theme.of(context).colorScheme.secondary,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  icon: Icons.location_on_outlined,
                  title: 'Find Bins',
                  subtitle: 'Locate nearby recycling points',
                  color: const Color(0xFF006064),
                  cardColor: cardColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),

                const SizedBox(height: 24),

                // Waste Categories
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Waste Categories',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: () => widget.onNavigate(2),
                      icon: Text(
                        'View All',
                        style: TextStyle(color: const Color(0xFF2E7D32)),
                      ),
                      label: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildCategoryCard(
                      Icons.eco_outlined,
                      'Organic Waste',
                      cardColor: cardColor,
                      textColor: textColor,
                      iconColor: subtitleColor,
                      onTap: () => _showCategoryDetails(
                        'Organic Waste',
                        _categoryGuidelines['Organic Waste']!,
                      ),
                    ),
                    _buildCategoryCard(
                      Icons.recycling,
                      'Recyclable',
                      cardColor: cardColor,
                      textColor: textColor,
                      iconColor: subtitleColor,
                      onTap: () => _showCategoryDetails(
                        'Recyclable',
                        _categoryGuidelines['Recyclable']!,
                      ),
                    ),
                    _buildCategoryCard(
                      Icons.delete_outline,
                      'Non-Recyclable',
                      cardColor: cardColor,
                      textColor: textColor,
                      iconColor: subtitleColor,
                      onTap: () => _showCategoryDetails(
                        'Non-Recyclable',
                        _categoryGuidelines['Non-Recyclable']!,
                      ),
                    ),
                    _buildCategoryCard(
                      Icons.devices,
                      'E-Waste',
                      cardColor: cardColor,
                      textColor: textColor,
                      iconColor: subtitleColor,
                      onTap: () => _showCategoryDetails(
                        'E-Waste',
                        _categoryGuidelines['E-Waste']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label, {
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: subtitleColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: subtitleColor, size: 16),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    IconData icon,
    String title, {
    required Color cardColor,
    required Color textColor,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
