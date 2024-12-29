import 'package:flutter/material.dart';
import '../utils/preferences.dart';
import '../utils/storage_util.dart';

class UserPreferencesPage extends StatefulWidget {
  const UserPreferencesPage({Key? key}) : super(key: key);

  @override
  _UserPreferencesPageState createState() => _UserPreferencesPageState();
}

class _UserPreferencesPageState extends State<UserPreferencesPage> {
  int _expandedIndex = -1;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    await StorageUtil.createJsonIfNotExists();
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await StorageUtil.loadData();
    setState(() {
      _userData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Preferences', style: Preferences.headlineStyle),
            const SizedBox(height: 16),
            ...List.generate(
              Preferences.preferencesCategories.length,
              (index) => _buildExpandableRectangle(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableRectangle(int index) {
    final isExpanded = _expandedIndex == index;
    final category = Preferences.preferencesCategories[index];

    return Card(
      color: Preferences.secondaryColor,
      child: Column(
        children: [
          ListTile(
            title: Text(category, style: Preferences.majorTextStyle),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
            ),
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (category == 'Breakfast')
                    ..._buildBreakfastSubcategories()
                  else
                    ..._buildCategoryItems(category),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildBreakfastSubcategories() {
    return [
      _buildSubcategory('Drink'),
      _buildSubcategory('Carb'),
    ];
  }

  Widget _buildSubcategory(String subcategory) {
    return ExpansionTile(
      title: Text(subcategory, style: Preferences.bodyStyle),
      children: [
        ..._buildCategoryItems('Breakfast - $subcategory'),
      ],
    );
  }

  List<Widget> _buildCategoryItems(String category) {
    final items = _userData[category.toLowerCase()] as Map<String, dynamic>? ?? {};
    final List<Widget> widgets = [];

    if (items.isEmpty) {
      widgets.add(_buildAddButton(category));
    } else {
      widgets.add(_buildTableHeader());
      widgets.add(
        Container(
          height: 200, // Set a fixed height for the scrollable area
          decoration: BoxDecoration(
            border: Border.all(color: Preferences.accentColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: items.entries.map((entry) => _buildItemRow(category, entry.key, entry.value)).toList(),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
      widgets.add(_buildAddButton(category));
    }

    return widgets;
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Preferences.primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: Text('Food Item', style: Preferences.bodyStyle, textAlign: TextAlign.center)),
          Expanded(child: Text('Cost', style: Preferences.bodyStyle, textAlign: TextAlign.center)),
          Expanded(child: Text('Servings', style: Preferences.bodyStyle, textAlign: TextAlign.center)),
          Expanded(child: Text('Each Serving', style: Preferences.bodyStyle, textAlign: TextAlign.center)),
          SizedBox(width: 80), // Space for action buttons
        ],
      ),
    );
  }

  Widget _buildItemRow(String category, String itemName, Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Preferences.accentColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: Text(item['foodName'] as String, style: Preferences.bodyStyle, textAlign: TextAlign.center)),
          Expanded(child: Text('${item['price']}', style: Preferences.bodyStyle, textAlign: TextAlign.center)),
          Expanded(child: Text('${item['totalServings']}', style: Preferences.bodyStyle, textAlign: TextAlign.center)),
          Expanded(child: Text('${item['eachServings']}', style: Preferences.bodyStyle, textAlign: TextAlign.center)),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Preferences.accentColor),
                onPressed: () => _showEditItemDialog(category, itemName, item),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Preferences.accentColor),
                onPressed: () => _showDeleteConfirmationDialog(category, itemName),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String category) {
    return ElevatedButton(
      child: const Icon(Icons.add),
      onPressed: () => _showAddItemDialog(category),
      style: ElevatedButton.styleFrom(
        backgroundColor: Preferences.accentColor,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
      ),
    );
  }

  void _showAddItemDialog(String category) {
    _showItemDialog(category, null, null);
  }

  void _showEditItemDialog(String category, String itemName, Map<String, dynamic> item) {
    _showItemDialog(category, itemName, item);
  }

  void _showItemDialog(String category, String? oldItemName, Map<String, dynamic>? existingItem) {
    final formKey = GlobalKey<FormState>();
    String foodName = existingItem?['foodName'] ?? '';
    double price = existingItem?['price'] ?? 0;
    String totalServings = existingItem?['totalServings'] ?? 'Unknown';
    String eachServings = existingItem?['eachServings'] ?? 'Unknown';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingItem == null ? 'Add $category Item' : 'Edit $category Item'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: foodName,
                        decoration: const InputDecoration(labelText: 'Food Name'),
                        validator: (value) => value!.isEmpty ? 'Please enter a food name' : null,
                        onSaved: (value) => foodName = value!,
                      ),
                      TextFormField(
                        initialValue: price.toString(),
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
                        onSaved: (value) => price = double.parse(value!),
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Total Servings'),
                        value: totalServings,
                        items: Preferences.servingOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            totalServings = value!;
                            if (totalServings == 'Unknown' || totalServings == 'All') {
                              eachServings = totalServings;
                            }
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Each Serving'),
                        value: eachServings,
                        items: Preferences.servingOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: totalServings == 'Unknown' || totalServings == 'All'
                            ? null
                            : (value) => setState(() => eachServings = value!),
                      ),
                      if (totalServings == 'Unknown')
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Please state when the item has ended.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      if (totalServings == 'All')
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'This means the food item will be finished in one serving.',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      final newData = {
                        'foodName': foodName,
                        'price': price,
                        'totalServings': totalServings,
                        'eachServings': eachServings,
                      };
                      StorageUtil.saveData(category, newData).then((_) {
                        _loadUserData().then((_) {
                          setState(() {}); // Trigger a rebuild
                          Navigator.of(context).pop();
                        });
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String category, String itemName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete "$itemName"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                StorageUtil.deleteItem(category, itemName).then((_) {
                  _loadUserData().then((_) {
                    setState(() {}); // Trigger a rebuild
                    Navigator.of(context).pop();
                  });
                });
              },
            ),
          ],
        );
      },
    );
  }
}

