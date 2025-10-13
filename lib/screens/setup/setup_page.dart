import 'package:flutter/material.dart';
import 'employee_management_page.dart';
import 'commission_setup_page.dart';
import 'service_catalog_page.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Setup'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Configuration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure your POS system settings and manage your business data.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                      return _getSetupCard(context, index);
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

  Widget _getSetupCard(BuildContext context, int index) {
    final List<Map<String, dynamic>> cardData = [
      {
        'title': 'Employee Management',
        'subtitle': 'Add and manage employees',
        'icon': Icons.people,
        'color': Colors.blue,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EmployeeManagementPage(),
          ),
        ),
      },
      {
        'title': 'Commission Setup',
        'subtitle': 'Configure commission rates',
        'icon': Icons.percent,
        'color': Colors.green,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CommissionSetupPage()),
        ),
      },
      {
        'title': 'Service Catalog',
        'subtitle': 'Manage services and pricing',
        'icon': Icons.spa,
        'color': Colors.purple,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ServiceCatalogPage()),
        ),
      },
      {
        'title': 'System Settings',
        'subtitle': 'General system preferences',
        'icon': Icons.settings,
        'color': Colors.orange,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('System Settings - Coming Soon!')),
          );
        },
      },
    ];

    final card = cardData[index];
    return _buildSetupCard(
      context: context,
      title: card['title'],
      subtitle: card['subtitle'],
      icon: card['icon'],
      color: card['color'],
      onTap: card['onTap'],
    );
  }

  Widget _buildSetupCard({
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
