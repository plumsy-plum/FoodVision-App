import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeeklyStepsData {
  WeeklyStepsData({required this.date, required this.steps});
  final DateTime date;
  final int steps;
}

class StepTrackerProvider with ChangeNotifier {
  StepTrackerProvider();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<StepCount>? _stepSubscription;
  SharedPreferences? _prefs;
  Timer? _syncDebounce;

  String? _userId;
  int _dailySteps = 0;
  int? _baselineSteps;
  String _currentDayKey = _formatDate(DateTime.now());
  bool _permissionDenied = false;
  bool _isTracking = false;
  bool _isInitializing = false;

  Map<String, int> _weeklySteps = {};
  String? _lastCelebrationDayKey;
  bool _shouldCelebrate = false;

  static const int _defaultGoal = 10000;
  static const double _strideLengthMeters = 0.78;
  static const double _caloriesPerStep = 0.04;

  int get dailySteps => _dailySteps;
  int get dailyGoal => _defaultGoal;
  bool get permissionDenied => _permissionDenied;
  bool get isTracking => _isTracking;
  bool get shouldCelebrate => _shouldCelebrate;

  double get progress => (_dailySteps / _defaultGoal).clamp(0.0, 1.0);
  double get distanceKm => (_dailySteps * _strideLengthMeters) / 1000;
  double get caloriesBurned => _dailySteps * _caloriesPerStep;

  List<WeeklyStepsData> get weeklyStepsData {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      final key = _formatDate(day);
      final steps =
          key == _currentDayKey ? _dailySteps : (_weeklySteps[key] ?? 0);
      return WeeklyStepsData(date: day, steps: steps);
    });
  }

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void attachToUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    unawaited(_restartTracking());
    if (_userId != null && _userId!.isNotEmpty) {
      unawaited(_refreshWeeklySteps());
    }
  }

  void acknowledgeCelebration() {
    if (!_shouldCelebrate) return;
    _shouldCelebrate = false;
    _lastCelebrationDayKey = _currentDayKey;
    _prefs?.setString(_celebrationKey, _lastCelebrationDayKey!);
    notifyListeners();
  }

  Future<void> retryPermissionRequest() async {
    if (_userId == null) return;
    await _restartTracking(forcePermissionPrompt: true);
  }

  Future<void> _restartTracking({bool forcePermissionPrompt = false}) async {
    if (!_isMobilePlatform || _isInitializing) return;
    _isInitializing = true;
    await _stopTracking();

    if (_userId == null || _userId!.isEmpty) {
      _isInitializing = false;
      return;
    }

    await _loadPersistedState();
    final hasPermission =
        await _ensurePermissions(forcePrompt: forcePermissionPrompt);

    if (!hasPermission) {
      _permissionDenied = true;
      _isInitializing = false;
      notifyListeners();
      return;
    }

    _permissionDenied = false;
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _handleStepEvent,
        onError: _handleStepError,
        cancelOnError: false,
      );
      _isTracking = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to start pedometer stream: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _stopTracking() async {
    _syncDebounce?.cancel();
    await _stepSubscription?.cancel();
    _stepSubscription = null;
    _isTracking = false;
  }

  Future<bool> _ensurePermissions({bool forcePrompt = false}) async {
    if (!_isMobilePlatform) return false;

    final permission = Permission.activityRecognition;
    var status = await permission.status;

    if (status.isGranted) return true;

    if (status.isDenied || forcePrompt) {
      status = await permission.request();
      if (status.isGranted) return true;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }

  Future<void> _loadPersistedState() async {
    _prefs ??= await SharedPreferences.getInstance();
    _currentDayKey = _formatDate(DateTime.now());
    _dailySteps = _prefs?.getInt(_countKey) ?? 0;
    _baselineSteps = _prefs?.getInt(_baselineKey);
    _lastCelebrationDayKey = _prefs?.getString(_celebrationKey);
    _weeklySteps[_currentDayKey] = _dailySteps;
    notifyListeners();
  }

  Future<void> _persistState() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setInt(_countKey, _dailySteps);
    if (_baselineSteps != null) {
      await _prefs?.setInt(_baselineKey, _baselineSteps!);
    }
  }

  void _handleStepEvent(StepCount event) {
    final eventDayKey = _formatDate(event.timeStamp.toLocal());

    if (eventDayKey != _currentDayKey) {
      _currentDayKey = eventDayKey;
      _baselineSteps = null;
      _dailySteps = 0;
      _weeklySteps[_currentDayKey] = 0;
      unawaited(_refreshWeeklySteps());
    }

    _baselineSteps ??= event.steps;
    final computedSteps = event.steps - (_baselineSteps ?? event.steps);

    if (computedSteps >= 0) {
      _dailySteps = computedSteps;
    } else {
      _baselineSteps = event.steps;
      _dailySteps = 0;
    }

    _weeklySteps[_currentDayKey] = _dailySteps;
    _evaluateCelebration();
    _persistState();
    _queueFirestoreSync();
    notifyListeners();
  }

  void _evaluateCelebration() {
    if (_dailySteps >= _defaultGoal &&
        _lastCelebrationDayKey != _currentDayKey) {
      _shouldCelebrate = true;
    }
  }

  void _handleStepError(Object error) {
    debugPrint('Step stream error: $error');
    _isTracking = false;
    notifyListeners();
  }

  void _queueFirestoreSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 5), _syncToFirestore);
  }

  Future<void> _syncToFirestore() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('dailyActivity')
          .doc(_currentDayKey)
          .set(
        {
          'date': _currentDayKey,
          'steps': _dailySteps,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _weeklySteps[_currentDayKey] = _dailySteps;
      if (_weeklySteps.length < 7) {
        await _refreshWeeklySteps();
      }
    } catch (e) {
      debugPrint('Failed to sync steps to Firestore: $e');
    }
  }

  Future<void> _refreshWeeklySteps() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('dailyActivity')
          .orderBy('date', descending: true)
          .limit(14)
          .get();

      final map = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dateKey = data['date'] as String? ?? doc.id;
        final steps = (data['steps'] as num?)?.toInt() ?? 0;
        map[dateKey] = steps;
      }
      map[_currentDayKey] = _dailySteps;
      _weeklySteps = map;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh weekly steps: $e');
    }
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _stepSubscription?.cancel();
    super.dispose();
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String get _countKey => 'steps_${_currentDayKey}_count';
  String get _baselineKey => 'steps_${_currentDayKey}_baseline';
  String get _celebrationKey => 'steps_last_celebration_day';
}

