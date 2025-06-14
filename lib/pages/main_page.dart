import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

// --- No changes in this class ---
class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDateTime,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminder_channel',
          'Class Reminders',
          channelDescription: 'Notifications for class end times',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  // --- No changes to properties ---
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  int selectedDayIndex = 0;

  Map<String, List<String>> classEndTimes = {
    'Mon': [],
    'Tue': [],
    'Wed': [],
    'Thu': [],
    'Fri': [],
  };

  Map<String, List<Map<String, dynamic>>> items = {
    'Mon': [],
    'Tue': [],
    'Wed': [],
    'Thu': [],
    'Fri': [],
  };

  final hourController = TextEditingController();
  final minuteController = TextEditingController();
  final itemController = TextEditingController();
  String amPm = 'AM';

  bool _isVibrating = false;
  Timer? _timer;
  DateTime? _vibrationEndTime;

  String _deviceTimeZone = 'Asia/Kolkata';
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData().then((_) {
      _initApp();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkClassEndTimesAndVibrate();
      setState(() {
        _autoSelectCurrentDay();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stopVibration();
    hourController.dispose();
    minuteController.dispose();
    itemController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    await _initTimeZoneAndNotifications();
    _autoSelectCurrentDay();
    _resetTodaysItemsIfNecessary();
    _rescheduleAllNotifications();
    _startPeriodicCheck();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String classEndTimesJson = json.encode(classEndTimes);
    final String itemsJson = json.encode(items);
    await prefs.setString('classEndTimes', classEndTimesJson);
    await prefs.setString('items', itemsJson);
    debugPrint("Data saved!");
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? classEndTimesJson = prefs.getString('classEndTimes');
    final String? itemsJson = prefs.getString('items');

    if (classEndTimesJson != null) {
      final decodedMap = json.decode(classEndTimesJson) as Map<String, dynamic>;
      classEndTimes = decodedMap.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    }
    if (itemsJson != null) {
      final decodedMap = json.decode(itemsJson) as Map<String, dynamic>;
      items = decodedMap.map((key, value) {
        final itemList =
            (value as List)
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
        return MapEntry(key, itemList);
      });
    }

    if (mounted) {
      setState(() {});
    }
    debugPrint("Data loaded!");
  }

  Future<void> _resetTodaysItemsIfNecessary() async {
    final prefs = await SharedPreferences.getInstance();
    final String todayString = DateTime.now().toIso8601String().substring(
      0,
      10,
    );
    final String? lastResetDay = prefs.getString('lastResetDay');

    if (lastResetDay != todayString) {
      final todayKey = days[DateTime.now().weekday - 1];
      if (items[todayKey] != null) {
        for (var item in items[todayKey]!) {
          item['checked'] = false;
        }
        debugPrint("Resetting items for $todayKey.");
        await _saveData();
        await prefs.setString('lastResetDay', todayString);
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  // --- Functions below are mostly unchanged, except for adding/handling items ---

  Future<void> _initTimeZoneAndNotifications() async {
    try {
      tz.initializeTimeZones();
      const String timeZoneName = 'Asia/Kolkata';
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      if (mounted) {
        setState(() {
          _deviceTimeZone = timeZoneName;
        });
      }

      await _notificationService.init();

      if (Platform.isAndroid) {
        await _notificationService.flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Could not get timezone or init notifications: $e');
    }
  }

  void _autoSelectCurrentDay() {
    final now = DateTime.now();
    int todayIndex = now.weekday - 1;
    if (todayIndex >= 0 && todayIndex < 5) {
      setState(() {
        selectedDayIndex = todayIndex;
      });
    }
  }

  (int, int) _parseTime(String timeStr) {
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final ampm = parts[1];

    if (ampm == 'PM' && hour != 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return (hour, minute);
  }

  void _scheduleNotificationFor(String day, String timeStr) {
    final dayIndex = days.indexOf(day);
    if (dayIndex == -1) return;

    final (hour, minute) = _parseTime(timeStr);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != dayIndex + 1 ||
        scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final notificationTime = scheduledDate.subtract(const Duration(minutes: 1));
    final notificationId = (day + timeStr).hashCode;

    _notificationService.scheduleNotification(
      id: notificationId,
      title: 'Class Ending Soon!',
      body: 'Your class on $day at $timeStr is about to end. Get your things!',
      scheduledDateTime: notificationTime,
    );
    debugPrint('Scheduled notification for $day at $timeStr');
  }

  void _rescheduleAllNotifications() {
    _notificationService.cancelAllNotifications();
    for (final day in classEndTimes.keys) {
      for (final timeStr in classEndTimes[day]!) {
        _scheduleNotificationFor(day, timeStr);
      }
    }
  }

  void _startVibration() async {
    if (await Vibration.hasVibrator()) {
      if (!_isVibrating) {
        Vibration.vibrate(pattern: [1000, 1000], repeat: 0);
        setState(() => _isVibrating = true);
      }
    }
  }

  void _stopVibration() {
    if (_isVibrating) {
      Vibration.cancel();
      setState(() {
        _isVibrating = false;
        _vibrationEndTime = null;
      });
    }
  }

  void _startPeriodicCheck() {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkClassEndTimesAndVibrate();
    });
  }

  void _checkClassEndTimesAndVibrate() {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    if (todayIndex < 0 || todayIndex >= days.length) {
      _stopVibration();
      return;
    }

    final selectedDay = days[todayIndex];

    DateTime? parseClassEndTime(String timeStr) {
      try {
        final (hour, minute) = _parseTime(timeStr);
        return DateTime(now.year, now.month, now.day, hour, minute);
      } catch (_) {
        return null;
      }
    }

    bool allItemsChecked() {
      final todayItems = items[selectedDay]!;
      if (todayItems.isEmpty) return true;
      return todayItems.every((item) => item['checked'] == true);
    }

    if (_vibrationEndTime != null && now.isBefore(_vibrationEndTime!)) {
      if (allItemsChecked()) {
        _stopVibration();
      } else if (!_isVibrating) {
        _startVibration();
      }
      return;
    }

    for (final endTimeStr in classEndTimes[selectedDay]!) {
      final classEndDateTime = parseClassEndTime(endTimeStr);
      if (classEndDateTime == null) continue;

      final vibrationWindowEnd = classEndDateTime.add(
        const Duration(minutes: 10),
      );

      if (now.isAfter(classEndDateTime) && now.isBefore(vibrationWindowEnd)) {
        if (!allItemsChecked()) {
          _vibrationEndTime = vibrationWindowEnd;
          _startVibration();
        } else {
          _stopVibration();
        }
        return;
      }
    }
    _stopVibration();
  }

  void _showManualTimeDialog() {
    hourController.clear();
    minuteController.clear();
    String dialogAmPm = 'AM';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Class End Time"),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: hourController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hour'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: minuteController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minute'),
                ),
              ),
              const SizedBox(width: 10),
              StatefulBuilder(
                builder: (context, setStateDrop) {
                  return DropdownButton<String>(
                    value: dialogAmPm,
                    items:
                        ['AM', 'PM']
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (val) => setStateDrop(() => dialogAmPm = val!),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final hour = int.tryParse(hourController.text);
                final minute = int.tryParse(minuteController.text);
                if (hour != null &&
                    hour >= 1 &&
                    hour <= 12 &&
                    minute != null &&
                    minute >= 0 &&
                    minute <= 59) {
                  final formattedTime =
                      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $dialogAmPm';
                  final currentDay = days[selectedDayIndex];
                  setState(() {
                    classEndTimes[currentDay]!.add(formattedTime);
                    _saveData();
                  });
                  _scheduleNotificationFor(currentDay, formattedTime);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Enter a valid 12-hour time (HH:MM)"),
                    ),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // --- UPDATED: This function now takes the context to pop the bottom sheet ---
  void _addItem(BuildContext sheetContext) {
    if (itemController.text.trim().isNotEmpty) {
      setState(() {
        final selectedDay = days[selectedDayIndex];
        items[selectedDay]!.add({
          'text': itemController.text.trim(),
          'checked': false,
        });
        _saveData();
      });
      itemController.clear();
      Navigator.pop(sheetContext); // Close the bottom sheet
      _checkClassEndTimesAndVibrate();
    }
  }

  // --- NEW: Function to display the modal bottom sheet for adding an item ---
  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      // This makes the sheet sit above the keyboard
      isScrollControlled: true,
      // For rounded corners
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (sheetContext) {
        return Padding(
          // This padding adjusts the sheet's content based on the keyboard's height
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add New Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: itemController,
                  // Automatically focuses the field and brings up the keyboard
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _addItem(sheetContext),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _addItem(sheetContext),
                  child: const Text(
                    'Add Item',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = days[selectedDayIndex];
    final times = classEndTimes[selectedDay]!;
    final todayItems = items[selectedDay]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📘 Class Reminder"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isVibrating ? Icons.vibration : Icons.notifications_active,
              color: const Color.fromARGB(255, 227, 226, 214),
            ),
            onPressed:
                () => _isVibrating ? _stopVibration() : _startVibration(),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            gradient: LinearGradient(
              colors: [Color(0xFF00BCD4), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Timezone: $_deviceTimeZone',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(days.length, (index) {
                  final isSelected = index == selectedDayIndex;
                  return GestureDetector(
                    onTap: () => setState(() => selectedDayIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.cyan[300]
                                : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: Colors.cyan[200]!,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                                : [],
                      ),
                      child: Text(
                        days[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Text(
                "Class End Times for $selectedDay",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              times.isEmpty
                  ? const Column(
                    children: [
                      Icon(Icons.access_time, size: 36, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("No end times added yet."),
                    ],
                  )
                  : Column(
                    children:
                        times
                            .map(
                              (time) => Card(
                                color: const Color(0xFFF0F8FF),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  title: Text(time),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        times.remove(time);
                                        final notificationId =
                                            (selectedDay + time).hashCode;
                                        _notificationService.cancelNotification(
                                          notificationId,
                                        );
                                        _saveData();
                                        debugPrint(
                                          'Cancelled notification for $selectedDay at $time',
                                        );
                                      });
                                    },
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
              const SizedBox(height: 20),
              // --- UPDATED: This section is now cleaner, just a title and a button ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Items to bring:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    onPressed: _showAddItemSheet,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Add Item"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.cyan[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              // --- End of updated section ---
              const SizedBox(height: 10),
              Expanded(
                child:
                    todayItems.isEmpty
                        ? const Center(
                          child: Text(
                            "No items for this day.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                        : ListView.builder(
                          itemCount: todayItems.length,
                          itemBuilder: (context, index) {
                            final item = todayItems[index];
                            return Material(
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: ListTile(
                                  tileColor: const Color(0xFFB3E5FC),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  leading: Checkbox(
                                    value: item['checked'],
                                    activeColor: Colors.cyan,
                                    onChanged: (val) {
                                      setState(() {
                                        item['checked'] = val!;
                                        if (todayItems.every(
                                              (i) => i['checked'] == true,
                                            ) &&
                                            _isVibrating) {
                                          _stopVibration();
                                        }
                                        _saveData();
                                      });
                                    },
                                  ),
                                  title: Text(
                                    item['text'],
                                    style: TextStyle(
                                      decoration:
                                          item['checked']
                                              ? TextDecoration.lineThrough
                                              : null,
                                      color: Colors.black,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        todayItems.removeAt(index);
                                        if (todayItems.isEmpty &&
                                            _isVibrating) {
                                          _stopVibration();
                                        }
                                        _saveData();
                                      });
                                    },
                                  ),
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.shade200,
              blurRadius: 7,
              spreadRadius: 1,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.cyan[400],
          onPressed: _showManualTimeDialog,
          child: const Icon(Icons.alarm_add, color: Colors.white),
        ),
      ),
    );
  }
}
