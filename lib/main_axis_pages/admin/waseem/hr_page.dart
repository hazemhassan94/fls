import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HrHomePage extends StatefulWidget {
  const HrHomePage({super.key});

  @override
  State<HrHomePage> createState() => _HrHomePageState();
}

class _HrHomePageState extends State<HrHomePage> {
  String hrName = '';
  String hrRole = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHrData();
  }

  Future<void> fetchHrData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('admin').doc(uid).get();
      if (doc.exists) {
        setState(() {
          hrName = doc['name'] ?? 'HR';
          hrRole = doc['role'] ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching HR data: $e');
      setState(() => isLoading = false);
    }
  }

  void navigateToPage(String page) {
    switch (page) {
      case 'Teachers Attendance':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HrAttendancePage()),
        );
        break;
      case 'Permissions':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HrPermissionPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'label': 'Teachers Attendance',
        'icon': Icons.fact_check,
        'color': Colors.blue
      },
      {
        'label': 'Permissions',
        'icon': Icons.verified_user,
        'color': Colors.orange
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: const Color(0xFF1E2B86),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isLoading
                        ? const Text(
                            'Loading...',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                hrName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hrRole,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                  ),
                  IconButton(
                    onPressed: fetchHrData,
                    icon:
                        const Icon(Icons.refresh, color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 1.1,
          children: items.map((item) {
            return GestureDetector(
              onTap: () => navigateToPage(item['label'] as String),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 40,
                      color: item['color'] as Color,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['label'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E2B86),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// صفحة تسجيل الحضور
class HrAttendancePage extends StatefulWidget {
  const HrAttendancePage({super.key});

  @override
  State<HrAttendancePage> createState() => _HrAttendancePageState();
}

class _HrAttendancePageState extends State<HrAttendancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, int> _attendanceValues = {};
  final String today =
      DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

  Future<void> _saveAttendance() async {
    try {
      final batch = _firestore.batch();

      _attendanceValues.forEach((teacherId, value) {
        final teacherRef = _firestore
            .collection('attendance')
            .doc(today) // اليوم الحالي
            .collection('teachers')
            .doc(teacherId);

        batch.set(teacherRef, {
          'degree': value,
          'date': today,
        }, SetOptions(merge: true));
      });

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الحضور بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل حضور المعلمين'),
        backgroundColor: const Color(0xFF1E2B86),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAttendance,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('teacher').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد معلمين.'));
          }

          final teachers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              final teacherId = teacher.id;
              final teacherName = teacher['name'] ?? 'بدون اسم';
              final teacherSubject = teacher['subject'] ?? 'بدون مادة';

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(teacherName),
                  subtitle: Text('المادة: $teacherSubject'),
                  trailing: DropdownButton<int>(
                    value: _attendanceValues[teacherId],
                    hint: const Text('اختر'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('غائب')),
                      DropdownMenuItem(value: 1, child: Text('تأخير')),
                      DropdownMenuItem(value: 2, child: Text('حاضر')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _attendanceValues[teacherId] = value!;
                      });
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Placeholder لصفحة Permissions
class HrPermissionPage extends StatelessWidget {
  const HrPermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأذونات'),
        backgroundColor: const Color(0xFF1E2B86),
      ),
      body: const Center(child: Text('هنا سيتم إدارة طلبات الأذونات')),
    );
  }
}
