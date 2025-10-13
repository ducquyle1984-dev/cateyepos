import 'package:flutter/material.dart';
import '../../models/commission.dart';

class CommissionSetupPage extends StatefulWidget {
  const CommissionSetupPage({super.key});

  @override
  State<CommissionSetupPage> createState() => _CommissionSetupPageState();
}

class _CommissionSetupPageState extends State<CommissionSetupPage> {
  final List<Commission> _commissions = [];
  final TextEditingController _searchController = TextEditingController();
  List<Commission> _filteredCommissions = [];

  @override
  void initState() {
    super.initState();
    _filteredCommissions = _commissions;
    _searchController.addListener(_filterCommissions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCommissions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCommissions = _commissions.where((commission) {
        return commission.name.toLowerCase().contains(query) ||
            commission.description.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _addCommission() {
    _showCommissionDialog();
  }

  void _editCommission(Commission commission) {
    _showCommissionDialog(commission: commission);
  }

  void _deleteCommission(Commission commission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Commission'),
        content: Text('Are you sure you want to delete "${commission.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _commissions.remove(commission);
                _filterCommissions();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${commission.name} deleted successfully'),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCommissionDialog({Commission? commission}) {
    final nameController = TextEditingController(text: commission?.name ?? '');
    final descriptionController = TextEditingController(
      text: commission?.description ?? '',
    );
    final rateController = TextEditingController(
      text: commission?.rate.toString() ?? '0.0',
    );
    CommissionType selectedType = commission?.type ?? CommissionType.percentage;
    bool isActive = commission?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            commission == null ? 'Add Commission' : 'Edit Commission',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Commission Name',
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
                DropdownButtonFormField<CommissionType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Commission Type',
                    border: OutlineInputBorder(),
                  ),
                  items: CommissionType.values.map((type) {
                    String displayName;
                    switch (type) {
                      case CommissionType.percentage:
                        displayName = 'Percentage';
                        break;
                      case CommissionType.fixedAmount:
                        displayName = 'Fixed Amount';
                        break;
                      case CommissionType.tiered:
                        displayName = 'Tiered';
                        break;
                    }
                    return DropdownMenuItem(
                      value: type,
                      child: Text(displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: rateController,
                  decoration: InputDecoration(
                    labelText: selectedType == CommissionType.percentage
                        ? 'Rate (%)'
                        : 'Amount (\$)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Active Commission'),
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
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Commission name is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newCommission = Commission(
                  id:
                      commission?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  type: selectedType,
                  rate: double.tryParse(rateController.text) ?? 0.0,
                  isActive: isActive,
                  createdAt: commission?.createdAt ?? DateTime.now(),
                  updatedAt: commission != null ? DateTime.now() : null,
                );

                setState(() {
                  if (commission == null) {
                    _commissions.add(newCommission);
                  } else {
                    final index = _commissions.indexOf(commission);
                    _commissions[index] = newCommission;
                  }
                  _filterCommissions();
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${newCommission.name} ${commission == null ? 'added' : 'updated'} successfully',
                    ),
                  ),
                );
              },
              child: Text(commission == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  String _getCommissionTypeDisplay(CommissionType type) {
    switch (type) {
      case CommissionType.percentage:
        return 'Percentage';
      case CommissionType.fixedAmount:
        return 'Fixed Amount';
      case CommissionType.tiered:
        return 'Tiered';
    }
  }

  String _getCommissionRateDisplay(Commission commission) {
    switch (commission.type) {
      case CommissionType.percentage:
        return '${commission.rate}%';
      case CommissionType.fixedAmount:
        return '\$${commission.rate.toStringAsFixed(2)}';
      case CommissionType.tiered:
        return 'Tiered rates';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Setup'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _addCommission,
            icon: const Icon(Icons.add),
            tooltip: 'Add Commission',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search commissions...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredCommissions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.percent,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _commissions.isEmpty
                              ? 'No commission structures added yet'
                              : 'No commissions match your search',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_commissions.isEmpty)
                          ElevatedButton.icon(
                            onPressed: _addCommission,
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Commission'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCommissions.length,
                    itemBuilder: (context, index) {
                      final commission = _filteredCommissions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: commission.isActive
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.percent,
                              color: commission.isActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                          title: Text(
                            commission.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (commission.description.isNotEmpty)
                                Text(commission.description),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    _getCommissionTypeDisplay(commission.type),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getCommissionRateDisplay(commission),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!commission.isActive)
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
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editCommission(commission);
                                  } else if (value == 'delete') {
                                    _deleteCommission(commission);
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
        onPressed: _addCommission,
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
