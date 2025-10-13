import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../models/service_catalog.dart';
import '../models/employee.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  static const String _categoriesCollection = 'categories';
  static const String _servicesCollection = 'services';
  static const String _employeesCollection = 'employees';

  // Categories CRUD operations
  static Future<List<Category>> getCategories() async {
    try {
      print('Fetching categories from Firebase...');
      final snapshot = await _firestore
          .collection(_categoriesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      print('Found ${snapshot.docs.length} categories in Firebase');
      final categories = snapshot.docs
          .map((doc) => Category.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      
      // Sort by name in code to avoid index requirements
      categories.sort((a, b) => a.name.compareTo(b.name));

      for (final category in categories) {
        print('Category: ${category.name} (ID: ${category.id})');
      }

      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  static Future<void> saveCategory(Category category) async {
    try {
      print('Saving category: ${category.name} with ID: ${category.id}');
      await _firestore
          .collection(_categoriesCollection)
          .doc(category.id)
          .set(category.toMap(), SetOptions(merge: true));
      print('Category saved successfully: ${category.name}');
    } catch (e) {
      print('Error saving category: $e');
      throw Exception('Failed to save category: $e');
    }
  }

  static Future<void> deleteCategory(String categoryId) async {
    try {
      // Check if category is being used by any services
      final servicesUsingCategory = await _firestore
          .collection(_servicesCollection)
          .where('categoryId', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true)
          .get();

      if (servicesUsingCategory.docs.isNotEmpty) {
        throw Exception(
          'Cannot delete category: It is being used by ${servicesUsingCategory.docs.length} service(s)',
        );
      }

      // Soft delete by setting isActive to false
      await _firestore.collection(_categoriesCollection).doc(categoryId).update(
        {'isActive': false, 'updatedAt': FieldValue.serverTimestamp()},
      );
    } catch (e) {
      print('Error deleting category: $e');
      throw Exception('Failed to delete category: $e');
    }
  }

  // Services CRUD operations
  static Future<List<ServiceCatalog>> getServices() async {
    try {
      print('Fetching services from Firebase...');
      final snapshot = await _firestore
          .collection(_servicesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      print('Found ${snapshot.docs.length} services in Firebase');
      final services = snapshot.docs
          .map((doc) => ServiceCatalog.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      
      // Sort by name in code to avoid index requirements
      services.sort((a, b) => a.name.compareTo(b.name));

      for (final service in services) {
        print('Service: ${service.name} (ID: ${service.id})');
      }

      return services;
    } catch (e) {
      print('Error fetching services: $e');
      return [];
    }
  }

  static Future<void> saveService(ServiceCatalog service) async {
    try {
      await _firestore
          .collection(_servicesCollection)
          .doc(service.id)
          .set(service.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('Error saving service: $e');
      throw Exception('Failed to save service: $e');
    }
  }

  static Future<void> deleteService(String serviceId) async {
    try {
      // Soft delete by setting isActive to false
      await _firestore.collection(_servicesCollection).doc(serviceId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deleting service: $e');
      throw Exception('Failed to delete service: $e');
    }
  }

  // Stream methods for real-time updates
  static Stream<List<Category>> getCategoriesStream() {
    return _firestore
        .collection(_categoriesCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Category.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  static Stream<List<ServiceCatalog>> getServicesStream() {
    return _firestore
        .collection(_servicesCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) {
            final services = snapshot.docs
                .map(
                  (doc) => ServiceCatalog.fromMap({...doc.data(), 'id': doc.id}),
                )
                .toList();
            
            // Sort by name in code to avoid index requirements
            services.sort((a, b) => a.name.compareTo(b.name));
            
            return services;
          },
        );
  }

  // Employees CRUD operations
  static Future<List<Employee>> getEmployees() async {
    try {
      print('Fetching employees from Firebase...');
      final snapshot = await _firestore
          .collection(_employeesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      print('Found ${snapshot.docs.length} employees in Firebase');
      final employees = snapshot.docs
          .map((doc) => Employee.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort by name in code to avoid index requirements
      employees.sort((a, b) => a.name.compareTo(b.name));

      for (final employee in employees) {
        print('Employee: ${employee.name} (ID: ${employee.id})');
      }

      return employees;
    } catch (e) {
      print('Error fetching employees: $e');
      return [];
    }
  }

  static Future<void> saveEmployee(Employee employee) async {
    try {
      print('Saving employee: ${employee.name} with ID: ${employee.id}');
      await _firestore
          .collection(_employeesCollection)
          .doc(employee.id)
          .set(employee.toMap(), SetOptions(merge: true));
      print('Employee saved successfully: ${employee.name}');
    } catch (e) {
      print('Error saving employee: $e');
      throw Exception('Failed to save employee: $e');
    }
  }

  static Future<void> deleteEmployee(String employeeId) async {
    try {
      // Soft delete by setting isActive to false
      await _firestore.collection(_employeesCollection).doc(employeeId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Employee soft deleted: $employeeId');
    } catch (e) {
      print('Error deleting employee: $e');
      throw Exception('Failed to delete employee: $e');
    }
  }
}
