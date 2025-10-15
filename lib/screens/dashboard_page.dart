import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'setup/setup_page.dart';
import 'service_order_page.dart';
import 'customer_management_page.dart';
import '../provider/auth_provider.dart';
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                Provider.of<AuthProvider>(context, listen: false).signOut();
              },
            ),
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

  // Handle technician tile click - check for existing orders and ask user
  Future<void> _handleTechnicianTileClick(Employee technician) async {
    // Find existing incomplete orders for this technician
    final existingOrders = _inProgressOrders.where((order) {
      // Check if technician is assigned to this order
      final technicianIds = _getOrderTechnicians(order);
      return technicianIds.contains(technician.id);
    }).toList();

    if (existingOrders.isEmpty) {
      // No existing orders, create new order
      _navigateToNewOrder(technician);
    } else if (existingOrders.length == 1) {
      // One existing order, ask user to choose
      _showOrderChoiceDialog(technician, existingOrders.first);
    } else {
      // Multiple existing orders, show list to choose from
      _showMultipleOrdersDialog(technician, existingOrders);
    }
  }

  void _navigateToNewOrder(Employee technician) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ServiceOrderPage(preSelectedTechnicianId: technician.id),
      ),
    ).then((_) => loadInProgressOrders());
  }

  void _navigateToExistingOrder(ServiceOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceOrderPage(existingOrder: order),
      ),
    ).then((_) => loadInProgressOrders());
  }

  Future<void> _showOrderChoiceDialog(
    Employee technician,
    ServiceOrder existingOrder,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade600,
              radius: 16,
              child: Text(
                technician.name.isNotEmpty
                    ? technician.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                technician.name,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This technician has an existing incomplete order:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${existingOrder.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${existingOrder.status.displayName}',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: \$${existingOrder.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (existingOrder.customerName != null &&
                      existingOrder.customerName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Customer: ${existingOrder.customerName}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What would you like to do?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('new'),
            icon: const Icon(Icons.add),
            label: const Text('Create New Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('existing'),
            icon: const Icon(Icons.edit),
            label: const Text('Open Existing Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (choice == 'new') {
      _navigateToNewOrder(technician);
    } else if (choice == 'existing') {
      _navigateToExistingOrder(existingOrder);
    }
    // If 'cancel' or null, do nothing
  }

  Future<void> _showMultipleOrdersDialog(
    Employee technician,
    List<ServiceOrder> orders,
  ) async {
    final choice = await showDialog<dynamic>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade600,
              radius: 16,
              child: Text(
                technician.name.isNotEmpty
                    ? technician.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                technician.name,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This technician has ${orders.length} incomplete orders:',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200, // Constrain height for scrolling
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.orange.shade200),
                        ),
                        tileColor: Colors.orange.shade50,
                        title: Text(
                          'Order #${order.orderNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${order.status.displayName}'),
                            Text('Total: \$${order.total.toStringAsFixed(2)}'),
                            if (order.customerName != null &&
                                order.customerName!.isNotEmpty)
                              Text('Customer: ${order.customerName}'),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.of(context).pop(order),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('new'),
            icon: const Icon(Icons.add),
            label: const Text('Create New Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (choice == 'new') {
      _navigateToNewOrder(technician);
    } else if (choice is ServiceOrder) {
      _navigateToExistingOrder(choice);
    }
    // If 'cancel' or null, do nothing
  }

  Widget _buildTechnicianTile(Employee technician) {
    return GestureDetector(
      onTap: () => _handleTechnicianTileClick(technician),
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

class _ReportsContent extends StatefulWidget {
  const _ReportsContent();

  @override
  State<_ReportsContent> createState() => _ReportsContentState();
}

class _ReportsContentState extends State<_ReportsContent> {
  int _selectedReportIndex = 0;

  final List<Map<String, dynamic>> _reportTypes = [
    {'title': 'Daily Summary', 'icon': Icons.today},
    {'title': 'Transaction Details', 'icon': Icons.receipt_long},
    {'title': 'Technician Performance', 'icon': Icons.person_outline},
    {'title': 'Service Analysis', 'icon': Icons.analytics},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Report types sidebar
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _reportTypes.length,
                    itemBuilder: (context, index) {
                      final report = _reportTypes[index];
                      final isSelected = index == _selectedReportIndex;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        elevation: isSelected ? 3 : 1,
                        color: isSelected ? Colors.blue.shade50 : null,
                        child: ListTile(
                          leading: Icon(
                            report['icon'],
                            color: isSelected
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                          ),
                          title: Text(
                            report['title'],
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? Colors.blue.shade700 : null,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedReportIndex = index;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Report content area
          Expanded(child: _buildReportContent()),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    switch (_selectedReportIndex) {
      case 0:
        return const _DailySummaryReport();
      case 1:
        return const _TransactionDetailsReport();
      case 2:
        return _buildComingSoonReport('Technician Performance');
      case 3:
        return _buildComingSoonReport('Service Analysis');
      default:
        return _buildComingSoonReport('Unknown Report');
    }
  }

  Widget _buildComingSoonReport(String reportName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            Text(
              reportName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon!',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailySummaryReport extends StatefulWidget {
  const _DailySummaryReport();

  @override
  State<_DailySummaryReport> createState() => _DailySummaryReportState();
}

class _DailySummaryReportState extends State<_DailySummaryReport> {
  DateTime _selectedDate = DateTime.now();
  List<ServiceOrder> _transactions = [];
  Map<String, List<ServiceOrderItem>> _transactionItems = {};
  bool _isLoading = false;
  String? _selectedTechnicianId;
  List<String> _availableTechnicians = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final startOfDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1));

      final transactions = await FirebaseService.getServiceOrdersByDateRange(
        startOfDay,
        endOfDay,
      );

      // Get all technicians from transactions
      final technicianIds = <String>{};
      for (final transaction in transactions) {
        technicianIds.addAll(transaction.technicianIds);
      }

      final filteredTransactions = transactions
          .where(
            (order) =>
                order.status == ServiceOrderStatus.completed ||
                order.status == ServiceOrderStatus.cancelled,
          )
          .toList();

      // Load service order items for each transaction
      final Map<String, List<ServiceOrderItem>> itemsMap = {};
      for (final transaction in filteredTransactions) {
        if (transaction.id != null) {
          final items = await FirebaseService.getServiceOrderItems(
            transaction.id!,
          );
          itemsMap[transaction.id!] = items;
        }
      }

      setState(() {
        _transactions = filteredTransactions;
        _transactionItems = itemsMap;
        _availableTechnicians = technicianIds.toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTechnicianId = null; // Reset technician filter
      });
      _loadTransactions();
    }
  }

  List<ServiceOrder> get _filteredTransactions {
    if (_selectedTechnicianId == null) {
      return _transactions;
    }
    return _transactions
        .where(
          (transaction) =>
              transaction.technicianIds.contains(_selectedTechnicianId),
        )
        .toList();
  }

  double get _totalAmount {
    return _filteredTransactions
        .where((t) => t.status != ServiceOrderStatus.cancelled)
        .fold<double>(0, (sum, t) => sum + t.total);
  }

  int get _voidedCount {
    return _filteredTransactions
        .where((t) => t.status == ServiceOrderStatus.cancelled)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.today, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Daily Summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Technician filter
                if (_availableTechnicians.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<String?>(
                      hint: const Text('All Technicians'),
                      value: _selectedTechnicianId,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Technicians'),
                        ),
                        ..._availableTechnicians.map((techId) {
                          return DropdownMenuItem<String?>(
                            value: techId,
                            child: Text('Technician $techId'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedTechnicianId = value;
                        });
                      },
                    ),
                  ),
                const SizedBox(width: 12),
                // Date selector
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadTransactions,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          // Summary cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt,
                            color: Colors.blue.shade600,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_filteredTransactions.where((t) => t.status != ServiceOrderStatus.cancelled).length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const Text('Transactions'),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.attach_money,
                            color: Colors.green.shade600,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${_totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const Text('Total Sales'),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_voidedCount > 0)
                  Expanded(
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.cancel,
                              color: Colors.red.shade600,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_voidedCount',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const Text('Voided'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try selecting a different date',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: MaterialStateColor.resolveWith(
                        (states) => Colors.grey.shade100,
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Order #',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Start - End Time',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Customer',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Services & Technicians',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Payment',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Actions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: _filteredTransactions.map((transaction) {
                        final items = _transactionItems[transaction.id] ?? [];

                        return DataRow(
                          cells: [
                            DataCell(Text(transaction.orderNumber)),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Start: ${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (transaction.completedAt != null)
                                    Text(
                                      'End: ${transaction.completedAt!.hour.toString().padLeft(2, '0')}:${transaction.completedAt!.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(transaction.customerName ?? 'Walk-in'),
                            ),
                            DataCell(
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 1,
                                      ),
                                      child: Text(
                                        '${item.serviceName} - ${item.technicianName}',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                transaction.paymentMethod?.toUpperCase() ??
                                    'N/A',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _getPaymentMethodColor(
                                    transaction.paymentMethod,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${transaction.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      transaction.status ==
                                          ServiceOrderStatus.cancelled
                                      ? Colors.red.shade300
                                      : Colors.green,
                                  decoration:
                                      transaction.status ==
                                          ServiceOrderStatus.cancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (transaction.status ==
                                      ServiceOrderStatus.cancelled)
                                    Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        transaction.status,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      transaction.status ==
                                              ServiceOrderStatus.cancelled
                                          ? 'VOIDED'
                                          : transaction.status.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              transaction.status != ServiceOrderStatus.cancelled
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'void') {
                                          _voidTransaction(transaction);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem<String>(
                                          value: 'void',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.cancel,
                                                color: Colors.red,
                                                size: 16,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Void Transaction'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ServiceOrderStatus status) {
    switch (status) {
      case ServiceOrderStatus.newOrder:
        return Colors.blue;
      case ServiceOrderStatus.inProgress:
        return Colors.orange;
      case ServiceOrderStatus.completed:
        return Colors.green;
      case ServiceOrderStatus.cancelled:
        return Colors.red;
    }
  }

  Color _getPaymentMethodColor(String? paymentMethod) {
    if (paymentMethod == null) return Colors.grey;

    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Colors.green.shade700;
      case 'credit':
        return Colors.blue.shade700;
      case 'debit':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Future<void> _voidTransaction(ServiceOrder transaction) async {
    final TextEditingController reasonController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Void Transaction'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction #${transaction.orderNumber}'),
            Text('Amount: \$${transaction.total.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text(
              'Please provide a reason for voiding this transaction:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Created by mistake, Customer requested refund',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Void Transaction'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        // Update the transaction with void status and reason
        final voidedTransaction = transaction.copyWith(
          status: ServiceOrderStatus.cancelled,
          notes:
              '${transaction.notes ?? ''}\n\nVOIDED: ${reasonController.text.trim()}\nVoided by: ${DateTime.now().toString()}',
        );

        await FirebaseService.updateServiceOrder(voidedTransaction);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction voided successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadTransactions(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error voiding transaction: $e')),
          );
        }
      }
    }
  }
}

class _TransactionDetailsReport extends StatefulWidget {
  const _TransactionDetailsReport();

  @override
  State<_TransactionDetailsReport> createState() =>
      _TransactionDetailsReportState();
}

class _TransactionDetailsReportState extends State<_TransactionDetailsReport> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<ServiceOrder> _transactions = [];
  Map<String, List<ServiceOrderItem>> _transactionItems = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await FirebaseService.getServiceOrdersByDateRange(
        _startDate,
        _endDate,
      );

      final filteredTransactions = transactions
          .where((order) => order.status == ServiceOrderStatus.completed)
          .toList();

      // Load service order items for each transaction
      final Map<String, List<ServiceOrderItem>> itemsMap = {};
      for (final transaction in filteredTransactions) {
        if (transaction.id != null) {
          final items = await FirebaseService.getServiceOrderItems(
            transaction.id!,
          );
          itemsMap[transaction.id!] = items;
        }
      }

      setState(() {
        _transactions = filteredTransactions;
        _transactionItems = itemsMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadTransactions();
    }
  }

  Future<void> _voidTransaction(ServiceOrder transaction) async {
    final TextEditingController reasonController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Void Transaction'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction #${transaction.orderNumber}'),
            Text('Amount: \$${transaction.total.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text(
              'Please provide a reason for voiding this transaction:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Created by mistake, Customer requested refund',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Void Transaction'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        // Update the transaction with void status and reason
        final voidedTransaction = transaction.copyWith(
          status: ServiceOrderStatus.cancelled,
          notes:
              '${transaction.notes ?? ''}\n\nVOIDED: ${reasonController.text.trim()}\nVoided by: ${DateTime.now().toString()}',
        );

        await FirebaseService.updateServiceOrder(voidedTransaction);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction voided successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadTransactions(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error voiding transaction: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Transaction Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Date range selector
                InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${_startDate.day}/${_startDate.month}/${_startDate.year} - ${_endDate.day}/${_endDate.month}/${_endDate.year}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadTransactions,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting the date range',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: MaterialStateColor.resolveWith(
                        (states) => Colors.grey.shade100,
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Order #',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Start - End Date',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Customer',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Services & Technicians',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Payment',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Actions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: _transactions.map((transaction) {
                        final items = _transactionItems[transaction.id] ?? [];

                        return DataRow(
                          cells: [
                            DataCell(Text(transaction.orderNumber)),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Start: ${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year} ${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (transaction.completedAt != null)
                                    Text(
                                      'End: ${transaction.completedAt!.day}/${transaction.completedAt!.month}/${transaction.completedAt!.year} ${transaction.completedAt!.hour.toString().padLeft(2, '0')}:${transaction.completedAt!.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(transaction.customerName ?? 'Walk-in'),
                            ),
                            DataCell(
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 1,
                                      ),
                                      child: Text(
                                        '${item.serviceName} - ${item.technicianName}',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                transaction.paymentMethod?.toUpperCase() ??
                                    'N/A',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _getPaymentMethodColor(
                                    transaction.paymentMethod,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${transaction.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      transaction.status ==
                                          ServiceOrderStatus.cancelled
                                      ? Colors.red.shade300
                                      : Colors.green,
                                  decoration:
                                      transaction.status ==
                                          ServiceOrderStatus.cancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (transaction.status ==
                                      ServiceOrderStatus.cancelled)
                                    Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        transaction.status,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      transaction.status ==
                                              ServiceOrderStatus.cancelled
                                          ? 'VOIDED'
                                          : transaction.status.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              transaction.status != ServiceOrderStatus.cancelled
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'void') {
                                          _voidTransaction(transaction);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem<String>(
                                          value: 'void',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.cancel,
                                                color: Colors.red,
                                                size: 16,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Void Transaction'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          // Footer with summary
          if (_transactions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Text(
                    'Total Transactions: ${_transactions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    'Total Amount: \$${_transactions.fold<double>(0, (sum, t) => sum + t.total).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(ServiceOrderStatus status) {
    switch (status) {
      case ServiceOrderStatus.newOrder:
        return Colors.blue;
      case ServiceOrderStatus.inProgress:
        return Colors.orange;
      case ServiceOrderStatus.completed:
        return Colors.green;
      case ServiceOrderStatus.cancelled:
        return Colors.red;
    }
  }

  Color _getPaymentMethodColor(String? paymentMethod) {
    if (paymentMethod == null) return Colors.grey;

    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Colors.green.shade700;
      case 'credit':
        return Colors.blue.shade700;
      case 'debit':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
