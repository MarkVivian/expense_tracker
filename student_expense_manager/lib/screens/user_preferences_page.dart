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
    try {
      await StorageUtil.createJsonIfNotExists();
      await _loadUserData();
    } catch (e) {
      _showErrorDialog('Failed to initialize data: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final data = await StorageUtil.loadData();
      setState(() {
        _userData = data;
      });
    } catch (e) {
      _showErrorDialog('Failed to load data: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
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
                children: _buildCategoryItems(category),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryItems(String category) {
    final items = _userData[category.toLowerCase()] as Map<String, dynamic>? ?? {};
    final List<Widget> widgets = [];

    widgets.add(
      SizedBox(
        height: 300,
        child: items.isEmpty
            ? Center(child: Text('No items added yet', style: Preferences.bodyStyle))
            : ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items.entries.elementAt(index);
            return _buildFoodItemCard(category, item.key, item.value);
          },
        ),
      ),
    );

    widgets.add(const SizedBox(height: 16));
    widgets.add(_buildAddButton(category));

    return widgets;
  }

  Widget _buildFoodItemCard(String category, String itemName, Map<String, dynamic> item) {
    return Dismissible(
      key: Key(itemName),
      background: Container(
        color: Colors.blue,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Icon(Icons.edit, color: Colors.white),
          ),
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await _showDeleteConfirmationDialog(category, itemName);
        } else {
          _showEditItemDialog(category, itemName, item);
          return false;
        }
      },
      child: Card(
        color: Colors.brown,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: category.toLowerCase() == 'extra expenses (e.g. fifa, drinking)' ? 'Item: ' : 'Food Name: ',
                            style: Preferences.bodyStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: category.toLowerCase() == 'extra expenses (e.g. fifa, drinking)'
                                ? item['itemName']?.toString() ?? 'N/A'
                                : item['foodName']?.toString() ?? 'N/A',
                            style: Preferences.majorTextStyle.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Price: ${item['price']?.toString() ?? 'N/A'} Ksh',
                style: Preferences.bodyStyle.copyWith(color: Colors.white),
              ),
              if (category.toLowerCase() != 'breakfast combos' &&
                  category.toLowerCase() != 'meal combos' &&
                  category.toLowerCase() != 'extra expenses (e.g. fifa, drinking)') ...[
                Text(
                  'Total Servings: ${item['totalServings']?.toString() ?? 'N/A'}',
                  style: Preferences.bodyStyle.copyWith(color: Colors.white),
                ),
                Text(
                  'Each Serving: ${item['eachServings']?.toString() ?? 'N/A'}',
                  style: Preferences.bodyStyle.copyWith(color: Colors.white),
                ),
              ],
              if (category.toLowerCase() == 'breakfast combos' ||
                  category.toLowerCase() == 'meal combos') ...[
                Text(
                  'Items: ${_truncateItems(item['items'] as List<dynamic>? ?? [])}',
                  style: Preferences.bodyStyle.copyWith(color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _truncateItems(List<dynamic> items) {
    const int maxLength = 50;
    String itemsString = items.map((item) => item['foodName']?.toString() ?? 'N/A').join(', ');
    if (itemsString.length <= maxLength) {
      return itemsString;
    }
    return '${itemsString.substring(0, maxLength)}...';
  }

  Widget _buildAddButton(String category) {
    return ElevatedButton(
      onPressed: () => _showAddItemDialog(category),
      style: ElevatedButton.styleFrom(
        backgroundColor: Preferences.accentColor,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
      ),
      child: const Icon(Icons.add),
    );
  }

  void _showAddItemDialog(String category) {
    _showItemDialog(category, null, null);
  }

  void _showEditItemDialog(String category, String itemName, Map<String, dynamic> item) {
    _showItemDialog(category, itemName, item);
  }

  void _showItemDialog(String category, String? oldItemName, Map<String, dynamic>? existingItem) {
    if (category.toLowerCase() == 'breakfast combos' || category.toLowerCase() == 'meal combos') {
      _showComboDialog(category, oldItemName, existingItem);
    } else if (category.toLowerCase() == 'extra expenses (e.g. fifa, drinking)') {
      _showExtraExpensesDialog(category, oldItemName, existingItem);
    } else {
      _showRegularItemDialog(category, oldItemName, existingItem);
    }
  }

  void _showRegularItemDialog(String category, String? oldItemName, Map<String, dynamic>? existingItem) {
    final formKey = GlobalKey<FormState>();
    String foodName = existingItem?['foodName']?.toString() ?? '';
    double price = existingItem?['price']?.toDouble() ?? 0;
    String totalServings = existingItem?['totalServings']?.toString() ?? Preferences.servingOptions.first;
    String eachServings = existingItem?['eachServings']?.toString() ?? Preferences.servingOptions.first;

    showDialog(
      context: context,
      barrierDismissible: false,
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
                        onSaved: (value) => price = double.tryParse(value!) ?? 0,
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
                            if (totalServings == 'NA' || totalServings == 'All') {
                              eachServings = totalServings;
                            }
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Each Serving'),
                        value: eachServings,
                        items: totalServings == 'NA' || totalServings == 'All'
                            ? [DropdownMenuItem<String>(value: totalServings, child: Text(totalServings))]
                            : Preferences.servingOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: totalServings == 'NA' || totalServings == 'All'
                            ? null
                            : (value) => setState(() => eachServings = value!),
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
                      _saveItem(category, oldItemName, newData);
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

  void _showComboDialog(String category, String? oldItemName, Map<String, dynamic>? existingItem) {
    List<Map<String, dynamic>> comboItems = [];
    if (existingItem != null && existingItem['items'] != null) {
      comboItems = List<Map<String, dynamic>>.from(existingItem['items']);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingItem == null ? 'Add $category' : 'Edit $category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...comboItems.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> item = entry.value;
                      return ListTile(
                        title: Text(item['foodName']?.toString() ?? 'N/A'),
                        subtitle: Text('${item['price']?.toString() ?? 'N/A'} Ksh'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              comboItems.removeAt(index);
                            });
                          },
                        ),
                      );
                    }).toList(),
                    ElevatedButton(
                      child: Text('Add Item'),
                      onPressed: () async {
                        final result = await _showAddComboItemDialog();
                        if (result != null) {
                          setState(() {
                            comboItems.add(result);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Done'),
                  onPressed: () {
                    if (comboItems.isNotEmpty) {
                      final totalPrice = comboItems.fold(0.0, (sum, item) => sum + (item['price'] as double? ?? 0));
                      final newData = {
                        'foodName': '${comboItems[0]['foodName']?.toString() ?? 'Combo'} Combo',
                        'price': totalPrice,
                        'items': comboItems,
                      };
                      _saveItem(category, oldItemName, newData);
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

  Future<Map<String, dynamic>?> _showAddComboItemDialog() async {
    final formKey = GlobalKey<FormState>();
    String foodName = '';
    double price = 0;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Combo Item'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Food Name'),
                  validator: (value) => value!.isEmpty ? 'Please enter a food name' : null,
                  onSaved: (value) => foodName = value!,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
                  onSaved: (value) => price = double.tryParse(value!) ?? 0,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.of(context).pop({'foodName': foodName, 'price': price});
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showExtraExpensesDialog(String category, String? oldItemName, Map<String, dynamic>? existingItem) {
    final formKey = GlobalKey<FormState>();
    String itemName = existingItem?['itemName']?.toString() ?? '';
    double price = existingItem?['price']?.toDouble() ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(existingItem == null ? 'Add Extra Expense' : 'Edit Extra Expense'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: itemName,
                  decoration: const InputDecoration(labelText: 'Item'),
                  validator: (value) => value!.isEmpty ? 'Please enter an item name' : null,
                  onSaved: (value) => itemName = value!,
                ),
                TextFormField(
                  initialValue: price.toString(),
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
                  onSaved: (value) => price = double.tryParse(value!) ?? 0,
                ),
              ],
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
                    'itemName': itemName,
                    'price': price,
                  };
                  _saveItem(category, oldItemName, newData);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _saveItem(String category, String? oldItemName, Map<String, dynamic> newData) {
    String key = newData['foodName']?.toString() ?? newData['itemName']?.toString() ?? '';
    if (key.isEmpty) {
      _showErrorDialog('Failed to save data: Item name is empty');
      return;
    }

    if (oldItemName != null && oldItemName != key) {
      StorageUtil.deleteItem(category, oldItemName).then((_) {
        StorageUtil.saveData(category, key, newData).then((_) {
          _loadUserData();
          Navigator.of(context).pop();
        }).catchError((error) {
          _showErrorDialog('Failed to save data: $error');
        });
      });
    } else {
      StorageUtil.saveData(category, key, newData).then((_) {
        _loadUserData();
        Navigator.of(context).pop();
      }).catchError((error) {
        _showErrorDialog('Failed to save data: $error');
      });
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String category, String itemName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete "$itemName"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                StorageUtil.deleteItem(category, itemName).then((_) {
                  _loadUserData().then((_) {
                    setState(() {}); // Trigger a rebuild
                    Navigator.of(context).pop(true);
                  });
                });
              },
            ),
          ],
        );
      },
    ) ?? false;
  }
}

