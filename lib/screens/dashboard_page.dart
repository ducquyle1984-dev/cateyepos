import 'dart:async';
import 'package:flutter/material.dart';
import 'setup/setup_page.dart';
import 'service_order_page.dart';
import 'customer_management_page.dart';
import '../models/service_order.dart';
import '../models/service_order_item.dart';
import '../models/employee.dart';
import '../services/firebase_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final GlobalKey<_HomeContentState> _homeContentKey =
      GlobalKey<_HomeContentState>();

  // Define the pages for navigation
  late final List<Widget> _pages = [
    _HomeContent(key: _homeContentKey),
    _ServiceOrdersContent(
      onRefresh: () => _homeContentKey.currentState?.loadInProgressOrders(),
    ),
    const _CustomersContent(),
    const _AppointmentsContent(),
    const _ReportsContent(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CatEye POS'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.store, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'CatEye POS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Salon Management System',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.dashboard,
              title: 'Dashboard',
              index: 0,
            ),
            _buildDrawerItem(
              icon: Icons.receipt_long,
              title: 'Service Orders',
              index: 1,
            ),
            _buildDrawerItem(icon: Icons.people, title: 'Customers', index: 2),
            _buildDrawerItem(
              icon: Icons.calendar_today,
              title: 'Appointments',
              index: 3,
            ),
            _buildDrawerItem(icon: Icons.analytics, title: 'Reports', index: 4),
            const Divider(),
            _buildDrawerItem(icon: Icons.settings, title: 'Setup', index: 5),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.shade50,
      onTap: () {
        Navigator.pop(context); // Close drawer first

        switch (index) {
          case 1: // Service Orders
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ServiceOrderPage()),
            ).then((_) {
              // Refresh dashboard when returning from service order page
              _homeContentKey.currentState?.loadInProgressOrders();
            });
            break;
          case 2: // Customers
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomerManagementPage(),
              ),
            );
            break;
          case 5: // Setup
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SetupPage()),
            );
            break;
          default: // Dashboard content pages
            setState(() {
              _selectedIndex = index;
            });
        }
      },
    );
  }
}

// Content widgets for different sections
class _HomeContent extends StatefulWidget {
  const _HomeContent({super.key});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  List<ServiceOrder> _inProgressOrders = [];
  Map<String, List<ServiceOrderItem>> _orderItems =
      {}; // Service order ID -> items
  Map<String, Employee> _employees = {}; // Employee ID -> Employee
  Timer? _timer;
  DateTime _currentTime =
      DateTime.now(); // Track current time for timer updates

  @override
  void initState() {
    super.initState();
    loadInProgressOrders();
    // Start a timer to update the running time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _inProgressOrders.isNotEmpty) {
        setState(() {
          _currentTime = DateTime.now(); // Update current time
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> loadInProgressOrders() async {
    try {
      // Load orders
      final orders = await FirebaseService.getServiceOrders();
      final filteredOrders = orders
          .where(
            (order) =>
                order.status == ServiceOrderStatus.inProgress ||
                order.status == ServiceOrderStatus.newOrder,
          )
          .toList();

      // Load employees
      final employees = await FirebaseService.getEmployees();
      final employeeMap = <String, Employee>{};
      for (final employee in employees) {
        employeeMap[employee.id] = employee;
      }

      // Load service order items for each order
      final orderItemsMap = <String, List<ServiceOrderItem>>{};
      for (final order in filteredOrders) {
        if (order.id != null) {
          final items = await FirebaseService.getServiceOrderItems(order.id!);
          orderItemsMap[order.id!] = items;

          // Also collect technicians from service order items
          for (final item in items) {
            if (!employeeMap.containsKey(item.technicianId)) {
              // If we don't have this technician in our map yet, we can use the denormalized name
              employeeMap[item.technicianId] = Employee(
                id: item.technicianId,
                name: item.technicianName,
                email: '',
                phone: '',
                position: '',
                commissionRate: 0.0,
                createdAt: DateTime.now(),
              );
            }
          }
        }
      }

      setState(() {
        _inProgressOrders = filteredOrders;
        _employees = employeeMap;
        _orderItems = orderItemsMap;
      });
    } catch (e) {
      print('Error loading in-progress orders: $e');
    }
  }

  // Get all technicians for an order (from order level and service items)
  Set<String> _getOrderTechnicians(ServiceOrder order) {
    final technicians = <String>{};

    // Add technicians from order level
    technicians.addAll(order.technicianIds);

    // Add technicians from service order items
    if (order.id != null && _orderItems[order.id!] != null) {
      for (final item in _orderItems[order.id!]!) {
        technicians.add(item.technicianId);
      }
    }

    return technicians;
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ${duration.inMinutes % 60}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(ServiceOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Service Order'),
          content: Text(
            'Are you sure you want to delete Order #${order.orderNumber}?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteServiceOrder(order);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Delete service order
  Future<void> _deleteServiceOrder(ServiceOrder order) async {
    try {
      await FirebaseService.deleteServiceOrder(order.id!);

      // Remove from local list and refresh
      setState(() {
        _inProgressOrders.removeWhere((o) => o.id == order.id);
        if (order.id != null && _orderItems.containsKey(order.id!)) {
          _orderItems.remove(order.id!);
        }
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting service order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete service order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          const SizedBox(height: 16),

          // In-Progress Orders Banner
          if (_inProgressOrders.isNotEmpty) ...[
            _buildInProgressBanner(),
            const SizedBox(height: 16),
          ],

          // Active Technicians Section
          _buildActiveTechniciansSection(),
          const SizedBox(height: 16),

          // Grid view with fixed height to prevent overflow
          SizedBox(
            height: 400, // Fixed height for the grid
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.2, // Adjust aspect ratio to give more height
              physics:
                  const NeverScrollableScrollPhysics(), // Disable grid scrolling since parent scrolls
              children: [
                _buildQuickActionCard(
                  'Today\'s Sales',
                  '\$0.00',
                  Icons.attach_money,
                  Colors.green,
                ),
                _buildQuickActionCard(
                  'Appointments',
                  '0',
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildQuickActionCard(
                  'Total Customers',
                  '0',
                  Icons.people,
                  Colors.orange,
                ),
                _buildQuickActionCard(
                  'Active Services',
                  '${_inProgressOrders.length}',
                  Icons.content_cut,
                  Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade100, Colors.orange.shade50],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_actions,
                color: Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'In-Progress Service Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_inProgressOrders.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_inProgressOrders.isNotEmpty) ...[
            const Text(
              'Orders awaiting completion:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200, // Increased height to accommodate more content
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _inProgressOrders.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final order = _inProgressOrders[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ServiceOrderPage(existingOrder: order),
                        ),
                      ).then(
                        (_) => loadInProgressOrders(),
                      ); // Refresh when returning
                    },
                    child: Container(
                      width: 280, // Increased width for more content
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${order.orderNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13, // Slightly smaller font
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      order.status ==
                                          ServiceOrderStatus.newOrder
                                      ? Colors.blue.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  order.status == ServiceOrderStatus.newOrder
                                      ? 'New'
                                      : 'In Progress',
                                  style: TextStyle(
                                    fontSize: 9, // Smaller font
                                    color:
                                        order.status ==
                                            ServiceOrderStatus.newOrder
                                        ? Colors.blue.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _showDeleteConfirmation(order),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            (order.customerName?.isNotEmpty ?? false)
                                ? order.customerName!
                                : 'Walk-in Customer',
                            style: const TextStyle(
                              fontSize: 11, // Smaller font
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 6),
                          // Running Timer
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(
                                  _currentTime.difference(order.createdAt),
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Technicians (moved above services)
                          Builder(
                            builder: (context) {
                              final technicians = _getOrderTechnicians(order);
                              if (technicians.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Technicians:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    technicians
                                        .map(
                                          (techId) =>
                                              _employees[techId]?.name ??
                                              'Unknown',
                                        )
                                        .join(', '),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          // Service Items (moved below technicians)
                          if (order.id != null &&
                              _orderItems[order.id!]?.isNotEmpty == true)
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Services:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  // Use a constrained container for services list
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight:
                                          60, // Limit height for services
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ..._orderItems[order.id!]!
                                            .take(3) // Show max 3 services
                                            .map(
                                              (item) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 1,
                                                ),
                                                child: Text(
                                                  '• ${item.serviceName}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                        if (_orderItems[order.id!]!.length > 3)
                                          Text(
                                            '+ ${_orderItems[order.id!]!.length - 3} more',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveTechniciansSection() {
    // Get active technicians (employees)
    final activeTechnicians = _employees.values
        .where((employee) => employee.isActive)
        .toList();

    if (activeTechnicians.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade100, Colors.blue.shade50],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Active Technicians',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Grid of technician tiles
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 technicians per row
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5, // Adjust aspect ratio for better layout
            ),
            itemCount: activeTechnicians.length,
            itemBuilder: (context, index) {
              final technician = activeTechnicians[index];
              return _buildTechnicianTile(technician);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianTile(Employee technician) {
    return GestureDetector(
      onTap: () {
        // Navigate to ServiceOrderPage with pre-selected technician
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ServiceOrderPage(preSelectedTechnicianId: technician.id),
          ),
        ).then((_) => loadInProgressOrders());
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, color: Colors.blue.shade600, size: 20),
            const SizedBox(height: 4),
            Text(
              technician.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Reduced padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:
              MainAxisSize.min, // Important: minimize the column height
          children: [
            Icon(icon, size: 28, color: color), // Smaller icon
            const SizedBox(height: 6), // Reduced spacing
            FittedBox(
              // Ensures text fits within available space
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20, // Smaller font
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2), // Reduced spacing
            Text(
              title,
              style: const TextStyle(fontSize: 12), // Smaller font
              textAlign: TextAlign.center,
              maxLines: 2, // Allow wrapping
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOrdersContent extends StatelessWidget {
  final VoidCallback? onRefresh;
  const _ServiceOrdersContent({this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Orders',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  'New Order',
                  Icons.add_shopping_cart,
                  Colors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ServiceOrderPage(),
                    ),
                  ).then((_) => onRefresh?.call()),
                ),
                _buildActionCard(
                  context,
                  'View Orders',
                  Icons.receipt_long,
                  Colors.blue,
                  () {
                    // TODO: Navigate to order list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order list coming soon!')),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  'In Progress',
                  Icons.work,
                  Colors.orange,
                  () {
                    // TODO: Navigate to in-progress orders
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('In-progress orders coming soon!'),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  'Completed',
                  Icons.check_circle,
                  Colors.green,
                  () {
                    // TODO: Navigate to completed orders
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Completed orders coming soon!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomersContent extends StatelessWidget {
  const _CustomersContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  'Add Customer',
                  Icons.person_add,
                  Colors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerManagementPage(),
                    ),
                  ),
                ),
                _buildActionCard(
                  context,
                  'View All',
                  Icons.people,
                  Colors.blue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerManagementPage(),
                    ),
                  ),
                ),
                _buildActionCard(
                  context,
                  'Loyalty Points',
                  Icons.stars,
                  Colors.amber,
                  () {
                    // TODO: Navigate to loyalty points management
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Loyalty points management coming soon!'),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  'Customer Reports',
                  Icons.analytics,
                  Colors.purple,
                  () {
                    // TODO: Navigate to customer reports
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Customer reports coming soon!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentsContent extends StatelessWidget {
  const _AppointmentsContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Appointments',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Appointment management coming soon!',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ReportsContent extends StatelessWidget {
  const _ReportsContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Reports',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Analytics and reporting coming soon!',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
