
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PermissionRequestPage extends StatefulWidget {
  const PermissionRequestPage({super.key});

  @override
  State<PermissionRequestPage> createState() => _PermissionRequestPageState();
}

class _PermissionRequestPageState extends State<PermissionRequestPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid;

  String teacherName = '';
  bool isLoadingProfile = true;

  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool returned = false;
  bool isSubmitting = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static final _timeFormat = DateFormat('hh:mm a');
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('teacher').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          teacherName = data['name'] ?? '';
          isLoadingProfile = false;
        });
      } else {
        setState(() {
          teacherName = 'Unknown';
          isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        teacherName = 'Error';
        isLoadingProfile = false;
      });
    }
  }

  // Permission window must be between 7:00 and 14:30
  bool _validateTimes() {
    if (startTime == null || endTime == null || selectedDate == null) return false;
    final start = DateTime(
        selectedDate!.year, selectedDate!.month, selectedDate!.day, startTime!.hour, startTime!.minute);
    final end = DateTime(
        selectedDate!.year, selectedDate!.month, selectedDate!.day, endTime!.hour, endTime!.minute);
    final lowerBound = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, 7, 0);
    final upperBound = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, 14, 30);
    if (start.isBefore(lowerBound) || end.isAfter(upperBound)) return false;
    if (!end.isAfter(start)) return false;
    return true;
  }

  Future<void> _submitRequest() async {
    if (uid == null) return;
    if (!_validateTimes()) {
      _showSnackbar('Please choose a valid time between 7:00am and 2:30pm, with end after start.');
      return;
    }
    setState(() {
      isSubmitting = true;
    });

    final start = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day,
        startTime!.hour, startTime!.minute);
    final end = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day,
        endTime!.hour, endTime!.minute);

    try {
      // Optional: check overlap with existing current-month requests
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
      final existing = await _firestore
          .collection('permissions')
          .doc(uid)
          .collection('requests')
          .where('createdAt', isGreaterThanOrEqualTo: monthStart)
          .where('createdAt', isLessThanOrEqualTo: monthEnd)
          .get();

      bool overlaps = false;
      for (var doc in existing.docs) {
        final data = doc.data();
        final existingStart = (data['startTime'] as Timestamp).toDate();
        final existingEnd = (data['endTime'] as Timestamp).toDate();
        if (!(end.isBefore(existingStart) || start.isAfter(existingEnd))) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) {
        _showSnackbar('Time window overlaps with an existing request this month.');
        setState(() {
          isSubmitting = false;
        });
        return;
      }

      await _firestore
          .collection('permissions')
          .doc(uid)
          .collection('requests')
          .add({
        'teacherUid': uid,
        'teacherName': teacherName,
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
        'returned': returned,
        'createdAt': FieldValue.serverTimestamp(),
        'hrApproved': false,
        'deputyApproved': false,
        // You can have a computed 'status' client side: pending / approved / rejected
      });

      _showSnackbar('Permission request submitted.');
      setState(() {
        // reset selection
        selectedDate = null;
        startTime = null;
        endTime = null;
        returned = false;
      });
    } catch (e) {
      _showSnackbar('Failed to submit: $e');
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  String _computeStatus(Map<String, dynamic> data) {
    final hr = data['hrApproved'] as bool? ?? false;
    final dp = data['deputyApproved'] as bool? ?? false;
    if (hr && dp) return 'Approved';
    if (!hr && !dp) return 'Pending';
    return 'Waiting'; // one approved
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildRequestCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final start = (data['startTime'] as Timestamp).toDate();
    final end = (data['endTime'] as Timestamp).toDate();
    final returnedFlag = data['returned'] as bool? ?? false;
    final hr = data['hrApproved'] as bool? ?? false;
    final dp = data['deputyApproved'] as bool? ?? false;
    final status = _computeStatus(data);
    final created = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request on ${DateFormat.yMMMd().format(start)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Approved'
                        ? Colors.green.shade100
                        : status == 'Pending'
                            ? Colors.orange.shade100
                            : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: status == 'Approved'
                          ? Colors.green.shade800
                          : status == 'Pending'
                              ? Colors.orange.shade800
                              : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _infoRow(Icons.access_time, 'From: ${DateFormat.jm().format(start)}'),
                _infoRow(Icons.access_time_filled, 'To: ${DateFormat.jm().format(end)}'),
                _infoRow(Icons.redo, 'Returned: ${returnedFlag ? 'Yes' : 'No'}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _approvalChip('HR', hr),
                const SizedBox(width: 8),
                _approvalChip('Deputy', dp),
                const Spacer(),
                if (created != null)
                  Text(
                    'Requested ${timeAgo(created)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _approvalChip(String who, bool approved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: approved ? Colors.green.shade100 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: approved ? Colors.green : Colors.redAccent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approved ? Icons.check_circle : Icons.hourglass_top,
            size: 14,
            color: approved ? Colors.green.shade800 : Colors.redAccent,
          ),
          const SizedBox(width: 4),
          Text(
            '$who ${approved ? "Approved" : "Pending"}',
            style: TextStyle(
              fontSize: 12,
              color: approved ? Colors.green.shade800 : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  String timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _monthRequestsStream() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
    return _firestore
        .collection('permissions')
        .doc(uid)
        .collection('requests')
        .where('createdAt', isGreaterThanOrEqualTo: monthStart)
        .where('createdAt', isLessThanOrEqualTo: monthEnd)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year, now.month),
      lastDate: DateTime(now.year, now.month + 1, 0),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeWindowValid = _validateTimes();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Request'),
        backgroundColor: const Color(0xFF1E2B86),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // form
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoadingProfile)
                  const Center(child: CircularProgressIndicator())
                else
                  Text(
                    'Teacher: $teacherName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(selectedDate != null
                              ? _dateFormat.format(selectedDate!)
                              : 'Select date'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickStartTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(startTime != null
                              ? startTime!.format(context)
                              : '07:00 AM'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickEndTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(endTime != null
                              ? endTime!.format(context)
                              : '2:30 PM'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: returned,
                      onChanged: (v) => setState(() => returned = v ?? false),
                    ),
                    const SizedBox(width: 6),
                    const Text('Returned'),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: timeWindowValid && !isSubmitting ? _submitRequest : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2B86),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Permission'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (!timeWindowValid)
                  const Text(
                    'Time must be between 7:00 and 14:30 and end after start.',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),

          const Divider(),
          // existing month requests
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _monthRequestsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No permission requests this month.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _buildRequestCard(docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
