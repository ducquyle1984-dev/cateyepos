import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/service_catalog.dart';
import '../../provider/catalog_provider.dart';

class ServiceCatalogPage extends StatefulWidget {
  const ServiceCatalogPage({super.key});

  @override
  State<ServiceCatalogPage> createState() => _ServiceCatalogPageState();
}

class _ServiceCatalogPageState extends State<ServiceCatalogPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CatalogProvider>(context, listen: false).loadAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Catalog'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CatalogProvider>(
        builder: (context, catalogProvider, child) {
          if (catalogProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (catalogProvider.services.isEmpty) {
            return const Center(child: Text('No services available'));
          }

          return ListView.builder(
            itemCount: catalogProvider.services.length,
            itemBuilder: (context, index) {
              final service = catalogProvider.services[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(service.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (service.description.isNotEmpty)
                        Text(service.description),
                      Text(
                        '\$${service.price.toStringAsFixed(2)} • ${service.durationMinutes} min',
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
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
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showServiceDialog(service);
                      } else if (value == 'delete') {
                        _deleteService(catalogProvider, service);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(),
        backgroundColor: Colors.purple.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showServiceDialog([ServiceCatalog? service]) {
    final catalogProvider = Provider.of<CatalogProvider>(
      context,
      listen: false,
    );

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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                    content: Text('Service name is required'),
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
                categoryId: 'default',
                tags: [],
                isActive: true,
                requiresAppointment: false,
                createdAt: service?.createdAt ?? DateTime.now(),
                updatedAt: service != null ? DateTime.now() : null,
              );

              try {
                if (service == null) {
                  await catalogProvider.addService(newService);
                } else {
                  await catalogProvider.updateService(newService);
                }
                Navigator.pop(context);
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
    );
  }

  Future<void> _deleteService(
    CatalogProvider catalogProvider,
    ServiceCatalog service,
  ) async {
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
        await catalogProvider.deleteService(service.id);
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
}
