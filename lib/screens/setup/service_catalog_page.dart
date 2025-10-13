import 'package:flutter/material.dart';
import '../../models/service_catalog.dart';
import '../../models/category.dart';
import '../../services/firebase_service.dart';

class ServiceCatalogPage extends StatefulWidget {
  const ServiceCatalogPage({super.key});

  @override
  State<ServiceCatalogPage> createState() => _ServiceCatalogPageState();
}

class _ServiceCatalogPageState extends State<ServiceCatalogPage> {
  final List<ServiceCatalog> _services = [];
  final List<Category> _categories = [];
  final TextEditingController _searchController = TextEditingController();
  List<ServiceCatalog> _filteredServices = [];
  Category? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _filteredServices = _services;
    _searchController.addListener(_filterServices);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await FirebaseService.getCategories();
      final services = await FirebaseService.getServices();
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
        _services.clear();
        _services.addAll(services);
        _filterServices();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _filterServices() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredServices = _services.where((service) {
        final matchesSearch =
            service.name.toLowerCase().contains(query) ||
            service.description.toLowerCase().contains(query) ||
            service.tags.any((tag) => tag.toLowerCase().contains(query));

        final matchesCategory =
            _selectedCategory == null ||
            service.categoryId == _selectedCategory!.id;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _addService() {
    _showServiceDialog();
  }

  void _editService(ServiceCatalog service) {
    _showServiceDialog(service: service);
  }

  Future<void> _deleteService(ServiceCatalog service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "${service.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService.deleteService(service.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${service.name} deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting service: $e')));
        }
      }
    }
  }

  void _showServiceDialog({ServiceCatalog? service}) {
    // Check if we're still loading data
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading data, please wait...'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Check if categories exist before showing the dialog
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please create at least one category before adding services',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      _showCategoryDialog(
        onCategoryCreated: () {
          // After creating a category, show the service dialog
          Future.delayed(const Duration(milliseconds: 500), () {
            _showServiceDialog(service: service);
          });
        },
      ); // Prompt to create a category
      return;
    }

    final nameController = TextEditingController(text: service?.name ?? '');
    final descriptionController = TextEditingController(
      text: service?.description ?? '',
    );
    final priceController = TextEditingController(
      text: service?.price.toString() ?? '0.00',
    );
    final durationController = TextEditingController(
      text: service?.durationMinutes.toString() ?? '30',
    );

    Category? selectedCategory;
    if (service != null) {
      try {
        selectedCategory = _categories.firstWhere(
          (cat) => cat.id == service.categoryId,
        );
      } catch (e) {
        selectedCategory = _categories.first;
      }
    } else {
      selectedCategory = _categories.first;
    }

    bool isActive = service?.isActive ?? true;
    bool requiresAppointment = service?.requiresAppointment ?? false;
    List<String> tags = List.from(service?.tags ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(service == null ? 'Add Service' : 'Edit Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Service Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price (\$)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Category>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _showCategoryDialog(),
                      tooltip: 'Add Category',
                    ),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(category.icon, size: 20, color: category.color),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Active Service'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value ?? true;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Requires Appointment'),
                  value: requiresAppointment,
                  onChanged: (value) {
                    setDialogState(() {
                      requiresAppointment = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service name and category are required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newService = ServiceCatalog(
                  id:
                      service?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  price: double.tryParse(priceController.text) ?? 0.0,
                  durationMinutes: int.tryParse(durationController.text) ?? 30,
                  categoryId: selectedCategory!.id,
                  tags: tags,
                  isActive: isActive,
                  requiresAppointment: requiresAppointment,
                  createdAt: service?.createdAt ?? DateTime.now(),
                  updatedAt: service != null ? DateTime.now() : null,
                );

                try {
                  await FirebaseService.saveService(newService);
                  Navigator.pop(context);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${newService.name} ${service == null ? 'added' : 'updated'} successfully',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving service: $e')),
                  );
                }
              },
              child: Text(service == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog({
    Category? category,
    VoidCallback? onCategoryCreated,
  }) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController = TextEditingController(
      text: category?.description ?? '',
    );
    IconData selectedIcon = category?.icon ?? Icons.miscellaneous_services;
    Color selectedColor = category?.color ?? Colors.blue;
    bool isActive = category?.isActive ?? true;

    final List<IconData> availableIcons = [
      Icons.content_cut,
      Icons.palette,
      Icons.style,
      Icons.healing,
      Icons.back_hand,
      Icons.face,
      Icons.spa,
      Icons.miscellaneous_services,
      Icons.build,
      Icons.home,
      Icons.person,
      Icons.favorite,
    ];

    final List<Color> availableColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.cyan,
      Colors.indigo,
      Colors.amber,
      Colors.brown,
      Colors.grey,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Icon:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: availableIcons.map((icon) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedIcon == icon
                                ? selectedColor
                                : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: selectedIcon == icon
                              ? selectedColor
                              : Colors.grey,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: availableColors.map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color
                                ? Colors.black
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Active Category'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value ?? true;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category name is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newCategory = Category(
                  id:
                      category?.id ??
                      'cat_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  icon: selectedIcon,
                  color: selectedColor,
                  isActive: isActive,
                  createdAt: category?.createdAt ?? DateTime.now(),
                  updatedAt: category != null ? DateTime.now() : null,
                );

                try {
                  await FirebaseService.saveCategory(newCategory);
                  Navigator.pop(context);

                  // Add the category to local state immediately
                  setState(() {
                    if (category == null) {
                      _categories.add(newCategory);
                    } else {
                      final index = _categories.indexWhere(
                        (c) => c.id == category.id,
                      );
                      if (index != -1) {
                        _categories[index] = newCategory;
                      }
                    }
                  });

                  // Also reload from Firebase to ensure consistency
                  await _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${newCategory.name} ${category == null ? 'added' : 'updated'} successfully',
                        ),
                      ),
                    );
                  }

                  // Call the callback if it's a new category creation
                  if (category == null && onCategoryCreated != null) {
                    onCategoryCreated();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving category: $e')),
                  );
                }
              },
              child: Text(category == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryManagementScreen() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manage Categories',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _showCategoryDialog(),
                        icon: const Icon(Icons.add),
                        tooltip: 'Add Category',
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _categories.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No categories found'),
                            Text('Add a category to get started'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return Card(
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: category.color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  category.icon,
                                  color: category.color,
                                ),
                              ),
                              title: Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(category.description),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!category.isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Inactive',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        _showCategoryDialog(category: category);
                                      } else if (value == 'delete') {
                                        await _deleteCategory(category);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService.deleteCategory(category.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${category.name} deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e')),
          );
        }
      }
    }
  }

  Category? _getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Catalog'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.category),
            tooltip: 'Category Options',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_category',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20),
                    SizedBox(width: 8),
                    Text('Add Category'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'manage_categories',
                child: Row(
                  children: [
                    Icon(Icons.list, size: 20),
                    SizedBox(width: 8),
                    Text('Manage Categories'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'add_category') {
                _showCategoryDialog();
              } else if (value == 'manage_categories') {
                _showCategoryManagementScreen();
              }
            },
          ),
          IconButton(
            onPressed: _addService,
            icon: const Icon(Icons.add),
            tooltip: 'Add Service',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search services...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter by Category:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Long press to edit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: _selectedCategory == null,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = null;
                                  _filterServices();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            ..._categories.map((category) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onLongPress: () {
                                    // Show context menu for category edit/delete
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          'Category: ${category.name}',
                                        ),
                                        content: const Text(
                                          'What would you like to do with this category?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _showCategoryDialog(
                                                category: category,
                                              );
                                            },
                                            child: const Text('Edit'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await _deleteCategory(category);
                                            },
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: FilterChip(
                                    avatar: Icon(
                                      category.icon,
                                      size: 16,
                                      color: category.color,
                                    ),
                                    label: Text(category.name),
                                    selected:
                                        _selectedCategory?.id == category.id,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedCategory = selected
                                            ? category
                                            : null;
                                        _filterServices();
                                      });
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredServices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.spa,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _services.isEmpty
                                    ? 'No services added yet'
                                    : 'No services match your criteria',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_services.isEmpty)
                                ElevatedButton.icon(
                                  onPressed: _addService,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Service'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredServices.length,
                          itemBuilder: (context, index) {
                            final service = _filteredServices[index];
                            final category = _getCategoryById(
                              service.categoryId,
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: service.isActive
                                        ? (category?.color ?? Colors.purple)
                                              .withOpacity(0.1)
                                        : Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    category?.icon ??
                                        Icons.miscellaneous_services,
                                    color: service.isActive
                                        ? (category?.color ?? Colors.purple)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                title: Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (service.description.isNotEmpty)
                                      Text(service.description),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          service.formattedPrice,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          service.formattedDuration,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          category?.name ?? 'Unknown',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                category?.color ?? Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (service.requiresAppointment)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 12,
                                              color: Colors.orange,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Requires Appointment',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!service.isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'Inactive',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton(
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editService(service);
                                        } else if (value == 'delete') {
                                          _deleteService(service);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addService,
        backgroundColor: Colors.purple.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
