import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key});

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  String teacherName = '';
  DateTime selectedDate = DateTime.now();
  List<DateTime> workingDays = [];
  Map<String, int> attendanceData = {}; // date -> degree (0,1,2)

  @override
  void initState() {
    super.initState();
    fetchTeacherData();
    generateWorkingDays();
    fetchAttendanceData();
  }

  Future<void> fetchTeacherData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('teacher').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          teacherName = data['name'] ?? 'Teacher';
        });
      }
    } catch (e) {
      print('Error fetching teacher data: $e');
    }
  }

  Future<void> fetchAttendanceData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Map<String, int> loadedData = {};

    try {
      // loop on all working days in selected month
      for (var day in workingDays) {
        final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

        final doc = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(dateKey)
            .collection('teachers')
            .doc(uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['degree'] != null) {
            loadedData[dateKey] = data['degree'] as int;
          }
        }
      }
    } catch (e) {
      print('Error fetching attendance: $e');
    }

    setState(() {
      attendanceData = loadedData;
    });
  }

  void generateWorkingDays() {
    workingDays.clear();
    final firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0);

    for (DateTime day = firstDay; day.isBefore(lastDay.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      if (day.weekday != 5 && day.weekday != 6) {
        workingDays.add(day);
      }
    }
  }

  void changeMonth(int direction) {
    setState(() {
      selectedDate = DateTime(selectedDate.year, selectedDate.month + direction, 1);
      generateWorkingDays();
    });
    fetchAttendanceData();
  }

  String getAttendanceStatus(DateTime date) {
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final degree = attendanceData[dateKey];

    if (degree == 2) return 'present';
    if (degree == 1) return 'late';
    if (degree == 0) return 'absent';
    return 'none';
  }

  Color getAttendanceColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.yellow;
      default:
        return Colors.grey.shade300;
    }
  }

  String getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Teacher Attendance'),
        backgroundColor: const Color(0xFF1E2B86),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E2B86),
            child: Column(
              children: [
                const Icon(Icons.person, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  teacherName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_left), color: const Color(0xFF1E2B86)),
                Text(
                  '${getMonthName(selectedDate.month)} ${selectedDate.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2B86)),
                ),
                IconButton(onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_right), color: const Color(0xFF1E2B86)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Present', Colors.green),
                _buildLegendItem('Absent', Colors.red),
                _buildLegendItem('Late', Colors.yellow),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E2B86),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: workingDays.length,
                      itemBuilder: (context, index) {
                        final day = workingDays[index];
                        final status = getAttendanceStatus(day);
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                          ),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(flex: 2, child: Text('${day.day} ${getMonthName(day.month)} ${day.year}', style: const TextStyle(fontWeight: FontWeight.w500))),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: getAttendanceColor(status),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.grey.shade300, width: 1),
                                      ),
                                    ),
                                  ),
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
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 1)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
