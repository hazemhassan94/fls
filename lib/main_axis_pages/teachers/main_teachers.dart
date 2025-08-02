// features/teacher/presentation/teacher_home_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:school_fls/main_axis_pages/teachers/department/departmen_chat.dart';
import 'package:school_fls/main_axis_pages/teachers/permissions/permission_page.dart';
import 'Attendance/teacher_attendance_page.dart';
import 'table/teacher_table_page.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  String teacherName = '';
  String subject = '';
  String role = '';
  String scheduleCount = '0';
  String classNames = '';
  String photoUrl = '';
  bool isLoading = true;
  String? errorMessage;

  final Map<String, String> itemIcons = {
    'Attendance': 'assets/teachers/attendance.png',
    'Table': 'assets/teachers/table.png',
    'Stage': 'assets/teachers/stage.png',
    'Permission': 'assets/teachers/permission.png',
    'Department': 'assets/teachers/department chat.png',
    'My Classes': 'assets/teachers/myclasses.png',
    'My Students': 'assets/teachers/break.png',
  };

  @override
  void initState() {
    super.initState();
    fetchTeacherData();
  }

  Future<void> fetchTeacherData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        errorMessage = 'Not authenticated';
        isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('teacher').doc(uid).get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        String classesString;
        final classesField = data['classes'];
        if (classesField != null) {
          if (classesField is List) {
            classesString = (classesField as List<dynamic>).join(', ');
          } else {
            classesString = classesField.toString();
          }
        } else {
          classesString = 'No classes assigned';
        }

        setState(() {
          teacherName = (data['name'] as String?)?.trim().isNotEmpty == true
              ? data['name']
              : 'Teacher';
          subject = data['subject'] ?? '';
          role = data['role'] ?? '';
          scheduleCount = data['schedule']?.toString() ?? '0';
          classNames = classesString;
          photoUrl = data['photoUrl'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() {
          teacherName = 'Teacher';
          subject = '';
          role = '';
          scheduleCount = '0';
          classNames = 'No classes assigned';
          photoUrl = '';
          isLoading = false;
          errorMessage = 'No profile found';
        });
      }
    } catch (e, st) {
      debugPrint('Error fetching teacher data: $e\n$st');
      if (!mounted) return;
      setState(() {
        teacherName = 'Teacher';
        subject = '';
        role = '';
        scheduleCount = '0';
        classNames = 'Error loading data';
        photoUrl = '';
        isLoading = false;
        errorMessage = 'Failed to load data';
      });
    }
  }

  void navigateToPage(String label) {
    switch (label) {
      case 'Attendance':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeacherAttendancePage()),
        );
        break;
      case 'Table':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeacherTablePage()),
        );
        break;
      case 'Permission':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PermissionRequestPage()),
        );
        break;
      case 'Department':
        _openDepartmentChatForCurrentTeacher();
        break;
      case 'Stage':
      case 'My Classes':
      case 'My Students':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label page coming soon!')),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown page: $label')),
        );
    }
  }

  Future<void> _openDepartmentChatForCurrentTeacher() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('teacher').doc(uid).get();
      if (!doc.exists) return;
      final subj = (doc.data()?['subject'] ?? '').toString();
      if (subj.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DepartmentChatPage(subject: subj)),
      );
    } catch (e) {
      debugPrint('Error opening department chat: $e');
    }
  }

  Widget _buildGridItem(String label, String iconPath) {
    return GestureDetector(
      onTap: () => navigateToPage(label),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              spreadRadius: 1,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconPath,
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _getIconForItem(label),
                  size: 40,
                  color: const Color(0xFF1E2B86),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              label,
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
  }

  IconData _getIconForItem(String label) {
    switch (label) {
      case 'Attendance':
        return Icons.people;
      case 'Table':
        return Icons.table_chart;
      case 'Stage':
        return Icons.school;
      case 'Permission':
        return Icons.security;
      case 'Department':
        return Icons.chat;
      case 'My Classes':
        return Icons.class_;
      case 'My Students':
        return Icons.people_outline;
      default:
        return Icons.dashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = itemIcons.entries
        .map((e) => {'label': e.key, 'icon': e.value})
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: const Color(0xFF1E2B86),
          elevation: 0,
          automaticallyImplyLeading: true,
          leadingWidth: 72,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Avatar
                  Padding(
                    padding: const EdgeInsets.only(left: 40, right: 12),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/teachers/logo.png') as ImageProvider,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLoading)
                          const Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            teacherName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildBadge(
                                icon: Icons.book,
                                label: subject.isNotEmpty ? subject : 'No subject'),
                            _buildBadge(
                                icon: Icons.badge,
                                label: role.isNotEmpty ? role : 'No role'),
                            _buildBadge(
                                icon: Icons.schedule,
                                label: 'Schedule: $scheduleCount'),
                            _buildBadge(
                              icon: Icons.class_,
                              label: classNames,
                              isTruncated: true,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: fetchTeacherData,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh Data',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      onPressed: fetchTeacherData,
                      icon: const Icon(Icons.refresh, color: Colors.red),
                    )
                  ],
                ),
              ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.1,
                children: items
                    .map(
                      (item) => _buildGridItem(item['label']!, item['icon']!),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
      {required IconData icon, required String label, bool isTruncated = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        if (isTruncated)
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    );
  }
}
