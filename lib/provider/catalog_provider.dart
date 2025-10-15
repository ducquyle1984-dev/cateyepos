import 'package:flutter/foundation.dart' hide Category;
import '../models/service_catalog.dart';
import '../models/category.dart';
import '../models/employee.dart';
import '../models/customer.dart';
import '../services/firebase_service.dart';

class CatalogProvider with ChangeNotifier {
  List<ServiceCatalog> _services = [];
  List<ServiceCatalog> _filteredServices = [];
  List<Category> _categories = [];
  List<Employee> _employees = [];
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _selectedCategoryId;
  String _searchQuery = '';

  // Getters
  List<ServiceCatalog> get services => _services;
  List<ServiceCatalog> get filteredServices => _filteredServices;
  List<Category> get categories => _categories;
  List<Employee> get employees => _employees;
  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;

  // Load all catalog data
  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final futures = await Future.wait([
        FirebaseService.getServices(),
        FirebaseService.getCategories(),
        FirebaseService.getEmployees(),
        FirebaseService.getCustomers(),
      ]);

      _services = futures[0] as List<ServiceCatalog>;
      _categories = futures[1] as List<Category>;
      _employees = futures[2] as List<Employee>;
      _customers = futures[3] as List<Customer>;

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading catalog data: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Service filtering
  void filterServicesByCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredServices = _services.where((service) {
      // Category filter
      bool matchesCategory =
          _selectedCategoryId == null ||
          service.categoryId == _selectedCategoryId;

      // Search filter
      bool matchesSearch =
          _searchQuery.isEmpty ||
          service.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (service.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ));

      return matchesCategory && matchesSearch && service.isActive;
    }).toList();
  }

  // Service management
  Future<void> addService(ServiceCatalog service) async {
    try {
      await FirebaseService.saveService(service);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error adding service: $e');
      rethrow;
    }
  }

  Future<void> updateService(ServiceCatalog service) async {
    try {
      await FirebaseService.saveService(service);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error updating service: $e');
      rethrow;
    }
  }

  Future<void> deleteService(String serviceId) async {
    try {
      await FirebaseService.deleteService(serviceId);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error deleting service: $e');
      rethrow;
    }
  }

  // Category management
  Future<void> addCategory(Category category) async {
    try {
      await FirebaseService.saveCategory(category);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error adding category: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await FirebaseService.saveCategory(category);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await FirebaseService.deleteCategory(categoryId);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  // Customer management
  Future<void> addCustomer(Customer customer) async {
    try {
      await FirebaseService.saveCustomer(customer);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error adding customer: $e');
      rethrow;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      await FirebaseService.saveCustomer(customer);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error updating customer: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    try {
      await FirebaseService.deleteCustomer(customerId);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      rethrow;
    }
  }

  // Employee management
  Future<void> addEmployee(Employee employee) async {
    try {
      await FirebaseService.saveEmployee(employee);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error adding employee: $e');
      rethrow;
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    try {
      await FirebaseService.saveEmployee(employee);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error updating employee: $e');
      rethrow;
    }
  }

  Future<void> deleteEmployee(String employeeId) async {
    try {
      await FirebaseService.deleteEmployee(employeeId);
      await loadAllData(); // Refresh data
    } catch (e) {
      debugPrint('Error deleting employee: $e');
      rethrow;
    }
  }

  // Helper methods
  ServiceCatalog? getServiceById(String serviceId) {
    try {
      return _services.firstWhere((service) => service.id == serviceId);
    } catch (e) {
      return null;
    }
  }

  Category? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((category) => category.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  Employee? getEmployeeById(String employeeId) {
    try {
      return _employees.firstWhere((employee) => employee.id == employeeId);
    } catch (e) {
      return null;
    }
  }

  Customer? getCustomerById(String customerId) {
    try {
      return _customers.firstWhere((customer) => customer.id == customerId);
    } catch (e) {
      return null;
    }
  }
}
