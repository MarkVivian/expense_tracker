import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/preferences.dart';
import '../utils/storage_util.dart';
import '../utils/AutoBackups.dart';
import '../utils/weekly_trainer.dart';
import '../utils/firebase_controller.dart';
import 'package:intl/intl.dart';

class UserPreferencesPage extends StatefulWidget {
  const UserPreferencesPage({Key? key}) : super(key: key);

  @override
  _UserPreferencesPageState createState() => _UserPreferencesPageState();
}

class _UserPreferencesPageState extends State<UserPreferencesPage> with WidgetsBindingObserver {
  int _expandedIndex = -1;
  Map<String, dynamic> _userData = {};
  final AutoBackups _autoBackups = AutoBackups();
  final FirebaseController _firebaseController = FirebaseController();
  bool _isCheckingBackups = false;
  bool _isProcessingBackup = false;
  Map<String, Map<String, dynamic>> _categoryRequirements = {};
  bool _isLoadingRequirements = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAndLoadData();
    _checkForFirstTimeBackup();
    _loadCategoryRequirements();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store a reference to the scaffold messenger
    ScaffoldMessenger.of(context);
  }

  Future<void> _loadCategoryRequirements() async {
    setState(() {
      _isLoadingRequirements = true;
    });

    try {
      final requirements = await WeeklyTrainer().getCategoryRequirementsStatus();
      setState(() {
        _categoryRequirements = requirements;
        _isLoadingRequirements = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading category requirements: $e');
      }
      setState(() {
        _isLoadingRequirements = false;
      });
    }
  }

  Future<void> _checkForFirstTimeBackup() async {
    if (await _autoBackups.hasFirstTimeBackup()) {
      // Show dialog to user about first-time backup
      if (mounted) {
        _showFirstTimeBackupDialog();
      }
    }
  }

  void _showFirstTimeBackupDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Existing Data Found'),
        content: Text(
            'We found existing data in your account backup, but you have fewer items on this device. '
                'Would you like to restore your data from the cloud?'
        ),
        actions: [
          TextButton(
            child: Text('No, Keep Current Data'),
            onPressed: () {
              _autoBackups.clearFirstTimeBackupFlag();
              _performBackup();
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Preferences.accentColor,
            ),
            child: Text('Yes, Restore My Data'),
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await _autoBackups.handleFirstTimeBackup();
              if (success && mounted) {
                _loadUserData();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Your data has been restored'))
                );
              } else if (mounted) {
                _showErrorDialog('Failed to restore data. Please try again later.');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _initializeAndLoadData() async {
    try {
      await StorageUtil.createJsonIfNotExists();
      await _loadUserData();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to initialize data: $e');
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final data = await StorageUtil.loadData();
      if (mounted) {
        setState(() {
          _userData = data;
        });
        // Refresh category requirements after loading user data
        _loadCategoryRequirements();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to load data: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildBackupButton(),
              ],
            ),
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

  Widget _buildBackupButton() {
    return ElevatedButton.icon(
      onPressed: (_isCheckingBackups || _isProcessingBackup) ? null : _showBackupOptions,
      style: ElevatedButton.styleFrom(
        backgroundColor: Preferences.accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      icon: Icon(_isCheckingBackups || _isProcessingBackup ? Icons.hourglass_empty : Icons.history),
      label: Text(_isCheckingBackups ? 'Loading...' : (_isProcessingBackup ? 'Processing...' : 'Backups')),
    );
  }

  Future<void> _performBackup() async {
    if (!mounted) return;

    setState(() {
      _isProcessingBackup = true;
    });

    try {
      final result = await _autoBackups.forceBackup();

      if (!mounted) return;

      setState(() {
        _isProcessingBackup = false;
      });

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Backup created successfully'))
          );
        }
      } else {
        _showErrorDialog('Backup failed: ${result['message']}');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessingBackup = false;
      });

      _showErrorDialog('Failed to create backup: $e');
    }
  }

  Future<void> _showBackupOptions() async {
    if (!mounted) return;

    setState(() {
      _isCheckingBackups = true;
    });

    try {
      final backupVersions = await _autoBackups.getBackupVersions();

      if (!mounted) return;

      setState(() {
        _isCheckingBackups = false;
      });

      if (backupVersions['current'] == null && backupVersions['previous'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No backups available yet'))
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: Preferences.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => _buildBackupOptionsSheet(backupVersions),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCheckingBackups = false;
      });

      _showErrorDialog('Failed to load backup options: $e');
    }
  }

  Widget _buildBackupOptionsSheet(Map<String, dynamic> backupVersions) {
    final lastBackupTime = backupVersions['lastBackupTime'] != null
        ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(backupVersions['lastBackupTime']))
        : 'Never';

    return StatefulBuilder(
      builder: (context, setState) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Backups',
                      style: Preferences.headlineStyle,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Last backup: $lastBackupTime',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white24),
              ListTile(
                leading: Icon(Icons.backup, color: Preferences.accentColor),
                title: Text('Backup Now', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Create a new backup of your current data',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _performBackup();
                },
              ),
              if (backupVersions['current'] != null)
                ListTile(
                  leading: Icon(Icons.restore, color: Preferences.accentColor),
                  title: Text('Restore Current Backup', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Restore from your most recent backup',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRestoreConfirmationDialog('current');
                  },
                ),
              if (backupVersions['previous'] != null)
                ListTile(
                  leading: Icon(Icons.settings_backup_restore, color: Preferences.accentColor),
                  title: Text('Restore Previous Backup', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Restore from your older backup',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRestoreConfirmationDialog('previous');
                  },
                ),
              if (backupVersions['current'] != null || backupVersions['previous'] != null)
                ListTile(
                  leading: Icon(Icons.compare_arrows, color: Preferences.accentColor),
                  title: Text('Compare Backups', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'View differences between backups',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showBackupComparisonDialog(backupVersions);
                  },
                ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showRestoreConfirmationDialog(String version) {
    if (!mounted) return;

    final versionName = version == 'current' ? 'most recent' : 'previous';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Preferences.backgroundColor,
        title: Text('Confirm Restore'),
        content: Text(
            'Are you sure you want to restore from your $versionName backup? '
                'This will replace your current data.'
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Preferences.accentColor,
            ),
            child: Text('Restore'),
            onPressed: () async {
              Navigator.of(context).pop();

              final success = await _autoBackups.rollbackTo(version);
              if (success && mounted) {
                await _loadUserData();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Data restored successfully'))
                );
              } else if (mounted) {
                _showErrorDialog('Failed to restore data. Check your internet connection.');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBackupComparisonDialog(Map<String, dynamic> backupVersions) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Preferences.backgroundColor,
        title: Text('Backup Comparison'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Backup:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
              _buildBackupSummary(backupVersions['current']),
              SizedBox(height: 16),
              Text('Previous Backup:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
              _buildBackupSummary(backupVersions['previous']),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSummary(Map<String, dynamic>? backupData) {
    if (backupData == null) {
      return Text('No backup available', style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic));
    }

    final summary = <String, int>{};

    backupData.forEach((category, items) {
      if (items is Map) {
        summary[category] = items.length;
      }
    });

    return Container(
      height: 150,
      child: ListView(
        shrinkWrap: true,
        children: summary.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key.capitalize(), style: TextStyle(color: Colors.white)),
                Text('${entry.value} items', style: TextStyle(color: Preferences.accentColor)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandableRectangle(int index) {
    final isExpanded = _expandedIndex == index;
    final category = Preferences.preferencesCategories[index];

    // Get requirement status for this category
    final requirementStatus = _categoryRequirements[category.toLowerCase()];
    final bool isMet = requirementStatus?['isMet'] ?? true;

    // Determine card color based on requirements
    final cardColor = (!_isLoadingRequirements && !isMet && category.toLowerCase() != 'extra expenses')
        ? Colors.red.shade900  // Red for categories that don't meet requirements
        : Preferences.secondaryColor;  // Default color otherwise

    return Card(
      color: cardColor,
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

    // Get requirement status for this category
    final requirementStatus = _categoryRequirements[category.toLowerCase()];
    final bool isMet = requirementStatus?['isMet'] ?? true;
    final int required = requirementStatus?['required'] ?? 0;
    final int current = requirementStatus?['current'] ?? 0;

    // Add warning message if requirements not met
    if (!_isLoadingRequirements && !isMet && category.toLowerCase() != 'extra expenses') {
      widgets.add(
        Container(
          padding: EdgeInsets.all(8),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please add at least $required items to this category (currently have $current)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              // Replace the RichText widget with a simpler Row layout
              Row(
                children: [
                  Text(
                    category.toLowerCase() == 'extra expenses (e.g. fifa, drinking)' ? 'Item: ' : 'Food Name: ',
                    style: Preferences.bodyStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      category.toLowerCase() == 'extra expenses (e.g. fifa, drinking)'
                          ? item['itemName']?.toString() ?? 'N/A'
                          : item['foodName']?.toString() ?? 'N/A',
                      style: Preferences.majorTextStyle.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
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
    if (!mounted) return;

    if (category.toLowerCase() == 'breakfast combos' || category.toLowerCase() == 'meal combos') {
      _showComboDialog(category, oldItemName, existingItem);
    } else if (category.toLowerCase() == 'extra expenses (e.g. fifa, drinking)') {
      _showExtraExpensesDialog(category, oldItemName, existingItem);
    } else {
      _showRegularItemDialog(category, oldItemName, existingItem);
    }
  }

  void _showRegularItemDialog(String category, String? oldItemName, Map<String, dynamic>? existingItem) {
    if (!mounted) return;

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
    if (!mounted) return;

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
    if (!mounted) return null;

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
    if (!mounted) return;

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
    if (!mounted) return;

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
          if (mounted) {
            _showErrorDialog('Failed to save data: $error');
          }
        });
      });
    } else {
      StorageUtil.saveData(category, key, newData).then((_) {
        _loadUserData();
        Navigator.of(context).pop();
      }).catchError((error) {
        if (mounted) {
          _showErrorDialog('Failed to save data: $error');
        }
      });
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String category, String itemName) async {
    if (!mounted) return false;

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

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

