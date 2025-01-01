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
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      bool hasPermission = await StorageUtil.checkAndRequestPermission();
      if (!hasPermission) {
        throw Exception('Storage permission not granted');
      }

      await StorageUtil.createJsonIfNotExists();
      await _loadUserData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final data = await StorageUtil.loadData();
      setState(() {
        _userData = data;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: TextStyle(color: Colors.white)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeAndLoadData,
              child: Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Preferences.accentColor),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Preferences', style: Preferences.headlineStyle.copyWith(color: Colors.white)),
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
            title: Text(category, style: Preferences.majorTextStyle.copyWith(color: Colors.white)),
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
      title: Text(subcategory, style: Preferences.bodyStyle.copyWith(color: Colors.white)),
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
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Preferences.accentColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView(
            children: items.entries.map((entry) => _buildSwipeableItemRow(category, entry.key, entry.value)).toList(),
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
        children: [
          Expanded(flex: 2, child: Text('Food Item', style: Preferences.bodyStyle.copyWith(color: Colors.white), textAlign: TextAlign.center)),
          Expanded(child: Text('Cost', style: Preferences.bodyStyle.copyWith(color: Colors.white), textAlign: TextAlign.center)),
          Expanded(child: Text('Total Servings', style: Preferences.bodyStyle.copyWith(color: Colors.white), textAlign: TextAlign.center)),
          Expanded(child: Text('Each Serving', style: Preferences.bodyStyle.copyWith(color: Colors.white), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildSwipeableItemRow(String category, String itemName, Map<String, dynamic> item) {
    return Dismissible(
      key: Key(itemName),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 16),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.blue,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 16),
        child: Icon(Icons.edit, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          return await _showDeleteConfirmationDialog(category, itemName);
        } else {
          _showEditItemDialog(category, itemName, item);
          return false;
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Preferences.accentColor)),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(item['foodName'] as String, style: Preferences.bodyStyle.copyWith(color: Colors.white))),
            Expanded(child: Text(item['price'].toString(), style: Preferences.bodyStyle.copyWith(color: Colors.white))),
            Expanded(child: Text(item['totalServings'], style: Preferences.bodyStyle.copyWith(color: Colors.white))),
            Expanded(child: Text(item['eachServings'], style: Preferences.bodyStyle.copyWith(color: Colors.white))),
          ],
        ),
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
    String totalServings = existingItem?['totalServings'] ?? 'NA';
    String eachServings = existingItem?['eachServings'] ?? 'NA';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingItem == null ? 'Add $category Item' : 'Edit $category Item', style: TextStyle(color: Colors.white)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: foodName,
                        decoration: const InputDecoration(labelText: 'Food Name', labelStyle: TextStyle(color: Colors.white)),
                        style: TextStyle(color: Colors.white),
                        validator: (value) => value!.isEmpty ? 'Please enter a food name' : null,
                        onSaved: (value) => foodName = value!,
                      ),
                      TextFormField(
                        initialValue: price.toString(),
                        decoration: const InputDecoration(labelText: 'Price', labelStyle: TextStyle(color: Colors.white)),
                        style: TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
                        onSaved: (value) => price = double.parse(value!),
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Total Servings', labelStyle: TextStyle(color: Colors.white)),
                        value: totalServings,
                        items: Preferences.servingOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: TextStyle(color: Colors.white)),
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
                        dropdownColor: Preferences.primaryColor,
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Each Serving', labelStyle: TextStyle(color: Colors.white)),
                        value: eachServings,
                        items: Preferences.servingOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: totalServings == 'NA' || totalServings == 'All'
                            ? null
                            : (value) => setState(() => eachServings = value!),
                        dropdownColor: Preferences.primaryColor,
                      ),
                      if (totalServings == 'NA')
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
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
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
                        _loadUserData();
                        Navigator.of(context).pop();
                      }).catchError((error) {
                        _showErrorDialog('Failed to save data: $error');
                      });
                    }
                  },
                ),
              ],
              backgroundColor: Preferences.primaryColor,
            );
          },
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmationDialog(String category, String itemName) async {
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Item', style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to delete "$itemName"?', style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
              onPressed: () {
                StorageUtil.deleteItem(category, itemName).then((_) {
                  _loadUserData().then((_) {
                    setState(() {});
                    Navigator.of(context).pop(true);
                  });
                });
              },
            ),
          ],
          backgroundColor: Preferences.primaryColor,
        );
      },
    ) ?? false;
  }
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Preferences.primaryColor,
        actions: [
          TextButton(
            child: Text('OK', style: TextStyle(color: Preferences.accentColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Retry', style: TextStyle(color: Preferences.accentColor)),
            onPressed: () {
              Navigator.of(context).pop();
              _initializeAndLoadData();
            },
          ),
        ],
      ),
    );
  }
}

