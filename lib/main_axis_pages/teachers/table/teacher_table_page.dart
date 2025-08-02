// features/teacher/presentation/teacher_table_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherTablePage extends StatefulWidget {
  final String? teacherUid; // if null, uses current authenticated user

  const TeacherTablePage({super.key, this.teacherUid});

  @override
  State<TeacherTablePage> createState() => _TeacherTablePageState();
}

class _TeacherTablePageState extends State<TeacherTablePage> {
  String teacherName = '';
  String subject = '';
  String role = '';
  String scheduleCount = '';
  String classNames = '';
  String tableImageUrl = '';
  bool isLoading = true;
  String? errorMessage;

  String? get _effectiveUid =>
      widget.teacherUid ?? FirebaseAuth.instance.currentUser?.uid;

  static const Color primaryColor = Color(0xFF1E2B86);

  @override
  void initState() {
    super.initState();
    fetchTeacherTableData();
  }

  Future<void> fetchTeacherTableData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final uid = _effectiveUid;
    if (uid == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Teacher not authenticated.';
      });
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('teacher').doc(uid).get();
      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          teacherName = data['name'] ?? 'Teacher';
          subject = data['subject'] ?? '';
          role = data['role'] ?? '';
          scheduleCount = data['schedule']?.toString() ?? '0';

          if (data['classes'] != null) {
            if (data['classes'] is List) {
              classNames = (data['classes'] as List<dynamic>).join(', ');
            } else {
              classNames = data['classes'].toString();
            }
          } else {
            classNames = 'No classes assigned';
          }

          tableImageUrl = (data['table'] as String?) ?? '';
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Teacher data not found.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load data: $e';
        isLoading = false;
      });
    }
  }

  void _openFullImage() {
    if (tableImageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: primaryColor,
            title: const Text('Table Image'),
            centerTitle: true,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                tableImageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 12),
                        const Text('Loading full image...'),
                      ],
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Text('Could not load full image.');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            GestureDetector(
              onTap: fetchTeacherTableData,
              child: const Icon(Icons.refresh, color: primaryColor),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Teacher Table'),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with name, subject, role, schedule, classes, and icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: const BoxDecoration(
                color: primaryColor,
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart, size: 36, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoading
                              ? 'Loading...'
                              : teacherName.isNotEmpty
                                  ? "$teacherName's Table"
                                  : "Teacher's Table",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (!isLoading && subject.isNotEmpty)
                              _infoChip(Icons.book, subject),
                            if (!isLoading && role.isNotEmpty)
                              _infoChip(Icons.badge, role),
                            if (!isLoading)
                              _infoChip(Icons.schedule, 'Schedule: $scheduleCount'),
                            if (!isLoading)
                              _infoChip(Icons.class_, classNames),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: fetchTeacherTableData,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Reload',
                  ),
                ],
              ),
            ),

            // Status banner
            _buildStatusBanner(),

            // Body content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildContentArea(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              'Loading table...',
              style: TextStyle(fontSize: 16, color: primaryColor),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 68, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: fetchTeacherTableData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          ],
        ),
      );
    }

    if (tableImageUrl.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.table_chart_outlined,
                  size: 64, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Table Available',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your schedule table has not been uploaded yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show the table image
    return GestureDetector(
      onTap: _openFullImage,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          children: [
            // Subtitle bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Class Schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Tap to expand',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    tableImageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            const Text('Loading table image...'),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image,
                                size: 60, color: Colors.red),
                            const SizedBox(height: 12),
                            const Text(
                              'Failed to load your table',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap retry below to try again.',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: fetchTeacherTableData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Retry'),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
