import 'package:flutter/material.dart';
import 'report_issue_page.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.grey[50];
    final Color titleColor = isDark ? Colors.white : const Color(0xFF00695C);
    final Color subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportIssuePage()),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.report_problem),
        label: const Text('Report an Issue'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporting Guidelines',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waste types to report to Tamil Nadu Corporation',
              style: TextStyle(fontSize: 16, color: subtitleColor),
            ),
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              icon: Icons.delete_sweep,
              title: 'Garbage Heaps',
              description:
                  'Report if public dustbins are overflowing or if there is uncollected garbage on the street.',
              priority: 'High Priority',
              color: Colors.orange,
            ),
            _buildInfoCard(
              context,
              icon: Icons.construction,
              title: 'Construction Waste',
              description:
                  'Illegal dumping of building debris, bricks, or cement on roadsides or public spaces.',
              priority: 'Medium Priority',
              color: Colors.blueGrey,
            ),
            _buildInfoCard(
              context,
              icon: Icons.local_fire_department,
              title: 'Open Burning',
              description:
                  'Burning of plastic, leaves, or mixed waste. Report immediately as it poses health risks.',
              priority: 'Critical Priority',
              color: Colors.red,
            ),
            _buildInfoCard(
              context,
              icon: Icons.pest_control,
              title: 'Dead Animals',
              description:
                  'Carcasses of stray animals on public roads require specialized sanitary handling.',
              priority: 'High Priority',
              color: Colors.brown,
            ),
            _buildInfoCard(
              context,
              icon: Icons.water_drop,
              title: 'Blocked Drains',
              description:
                  'Drains clogged by plastic or waste, leading to sewage overflow or water stagnation.',
              priority: 'High Priority',
              color: Colors.blue,
            ),
            _buildInfoCard(
              context,
              icon: Icons.battery_alert,
              title: 'E-Waste dumping',
              description:
                  'Illegal disposal of batteries, electronics, or medical waste in open areas.',
              priority: 'Critical Priority',
              color: Colors.purple,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.phone_in_talk,
                    size: 40,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Helpline Numbers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPhoneRow('Chennai Corporation', '1913'),
                  _buildPhoneRow(
                    'Tamil Nadu Pollution Control',
                    '044-22353134',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80), // Extra space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String priority,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          priority,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportIssuePage(initialType: title),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: const Text('Report This'),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneRow(String label, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SelectableText(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}
