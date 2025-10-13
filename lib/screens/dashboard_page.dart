import 'package:flutter/material.dart';
import 'setup/setup_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CatEye POS Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SetupPage()),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Setup',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to CatEye POS!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your salon business efficiently',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate the number of columns based on available width
                  // Each card should be approximately 200-300 pixels wide
                  final double cardWidth = 250.0;
                  final int crossAxisCount = (constraints.maxWidth / cardWidth)
                      .floor()
                      .clamp(1, 6);

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return _getDashboardCard(context, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getDashboardCard(BuildContext context, int index) {
    final List<Map<String, dynamic>> cardData = [
      {
        'title': 'New Sale',
        'subtitle': 'Process a new transaction',
        'icon': Icons.shopping_cart,
        'color': Colors.green,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New Sale - Coming Soon!')),
          );
        },
      },
      {
        'title': 'Appointments',
        'subtitle': 'View and manage bookings',
        'icon': Icons.calendar_today,
        'color': Colors.blue,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointments - Coming Soon!')),
          );
        },
      },
      {
        'title': 'Reports',
        'subtitle': 'View sales and analytics',
        'icon': Icons.analytics,
        'color': Colors.orange,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reports - Coming Soon!')),
          );
        },
      },
      {
        'title': 'Setup',
        'subtitle': 'Configure POS settings',
        'icon': Icons.settings,
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SetupPage()),
          );
        },
      },
    ];

    final card = cardData[index];
    return _buildDashboardCard(
      context: context,
      title: card['title'],
      subtitle: card['subtitle'],
      icon: card['icon'],
      color: card['color'],
      onTap: card['onTap'],
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
