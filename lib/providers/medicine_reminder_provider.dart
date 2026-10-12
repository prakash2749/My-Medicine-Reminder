import 'package:flutter/foundation.dart';

import '../core/components/views/medicine/models/medicine_reminder_model.dart';

enum MedicineFilter { all, pending, taken }

class MedicineReminderProvider extends ChangeNotifier {
  final List<MedicineReminder> _reminders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  MedicineFilter _filter = MedicineFilter.all;

  MedicineReminderProvider() {
    _loadInitialReminders();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  MedicineFilter get currentFilter => _filter;

  List<MedicineReminder> get allReminders => List.unmodifiable(_reminders);

  List<MedicineReminder> get filteredReminders {
    return _reminders.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.dosage.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = switch (_filter) {
        MedicineFilter.all => true,
        MedicineFilter.pending => !item.isTaken,
        MedicineFilter.taken => item.isTaken,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  int get totalCount => _reminders.length;
  int get pendingCount => _reminders.where((r) => !r.isTaken).length;
  int get takenCount => _reminders.where((r) => r.isTaken).length;
  double get adherenceRate =>
      _reminders.isEmpty ? 0.0 : (takenCount / totalCount);

  // Initial Sample Reminders for Immediate Preview & Testing
  void _loadInitialReminders() {
    _isLoading = true;
    notifyListeners();

    _reminders.addAll([
      MedicineReminder(
        id: '1',
        name: 'Amoxicillin',
        dosage: '500 mg',
        time: '08:00 AM',
        frequency: 'Twice daily',
        category: 'Capsule',
        notes: 'Take with food and full glass of water',
        isTaken: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      MedicineReminder(
        id: '2',
        name: 'Metformin',
        dosage: '850 mg',
        time: '01:00 PM',
        frequency: 'Daily with lunch',
        category: 'Pill',
        notes: 'Maintain low sugar diet',
        isTaken: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      MedicineReminder(
        id: '3',
        name: 'Vitamin D3 & Calcium',
        dosage: '1000 IU',
        time: '08:00 PM',
        frequency: 'Daily after dinner',
        category: 'Pill',
        notes: 'Take before sleeping',
        isTaken: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  // Mutations
  void addReminder(MedicineReminder reminder) {
    _reminders.insert(0, reminder);
    notifyListeners();
  }

  void updateReminder(MedicineReminder updated) {
    final index = _reminders.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _reminders[index] = updated;
      notifyListeners();
    }
  }

  void deleteReminder(String id) {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void toggleTaken(String id) {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final current = _reminders[index];
      _reminders[index] = current.copyWith(isTaken: !current.isTaken);
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(MedicineFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
