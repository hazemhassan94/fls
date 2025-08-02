import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class DepartmentChatPage extends StatefulWidget {
  final String subject;
  const DepartmentChatPage({super.key, required this.subject});

  @override
  State<DepartmentChatPage> createState() => _DepartmentChatPageState();
}

class _DepartmentChatPageState extends State<DepartmentChatPage> {
  final _msgController = TextEditingController();
  final _scroll = ScrollController();
  late final String _uid;
  String _myName = '';
  bool _isAdmin = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _typingSub;
  List<DocumentSnapshot<Map<String, dynamic>>> _messages = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _pinned = [];
  final Set<String> _seenLocal = {};
  bool _loadingUser = true;

  static const Color primaryColor = Color(0xFF1E2B86);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    _uid = user.uid;
    _init();
  }

  Future<void> _init() async {
    await _loadProfile();
    _listenMessages();
    _listenTyping();
  }

  Future<void> _loadProfile() async {
    try {
      final teacherDoc = await FirebaseFirestore.instance.collection('teachers').doc(_uid).get();
      final meta = await FirebaseFirestore.instance
          .collection('department_chats')
          .doc(widget.subject)
          .get();

      setState(() {
        _myName = (teacherDoc.data()?['name'] as String?) ?? 'Teacher';
        final admins = (meta.data()?['admins'] ?? {}) as Map<String, dynamic>;
        _isAdmin = admins[_uid] == true;
        _loadingUser = false;
      });
    } catch (_) {
      setState(() {
        _myName = 'Teacher';
        _loadingUser = false;
      });
    }
  }

  void _listenMessages() {
    final col = FirebaseFirestore.instance
        .collection('department_chats')
        .doc(widget.subject)
        .collection('messages')
        .orderBy('createdAt', descending: true);

    _messagesSub = col.snapshots().listen((snap) {
      setState(() {
        _messages = snap.docs;
        _pinned = _messages.where((d) => (d.data()!['isPinned'] ?? false) == true).toList();
      });
      _markSeenForVisible();
    });
  }

  void _listenTyping() {
    final typingCol = FirebaseFirestore.instance
        .collection('department_chats')
        .doc(widget.subject)
        .collection('typing');

    _typingSub = typingCol.snapshots().listen((_) {
      setState(() {});
    });
  }

  void _notifyTyping() {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _setTypingFlag(true);
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _setTypingFlag(false);
    });
  }

  Future<void> _setTypingFlag(bool typing) async {
    final doc = FirebaseFirestore.instance
        .collection('department_chats')
        .doc(widget.subject)
        .collection('typing')
        .doc(_uid);
    await doc.set({
      'isTyping': typing,
      'lastUpdated': FieldValue.serverTimestamp(),
      'name': _myName,
    }, SetOptions(merge: true));
    setState(() {
      _isTyping = typing;
    });
  }

  void _markSeenForVisible() {
    for (var doc in _messages) {
      final msgId = doc.id;
      if (_seenLocal.contains(msgId)) continue;
      final data = doc.data();
      if (data == null) continue;
      final seenBy = (data['seenBy'] ?? {}) as Map<String, dynamic>;
      if (seenBy[_uid] == true) {
        _seenLocal.add(msgId);
        continue;
      }
      FirebaseFirestore.instance
          .collection('department_chats')
          .doc(widget.subject)
          .collection('messages')
          .doc(msgId)
          .set({
        'seenBy': {_uid: true}
      }, SetOptions(merge: true));
      _seenLocal.add(msgId);
    }
  }

  Future<void> _sendText() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    await FirebaseFirestore.instance
        .collection('department_chats')
        .doc(widget.subject)
        .collection('messages')
        .add({
      'senderUid': _uid,
      'senderName': _myName,
      'text': text,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': {_uid: true},
      'isPinned': false,
      'isDeleted': false,
    });
    await _updateMetadata();
  }

  Future<void> _sendAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null) return;
    final file = File(result.files.single.path!);
    final name = result.files.single.name;
    final ext = name.split('.').last;
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('department_chats')
        .child(widget.subject)
        .child('attachments')
        .child('${const Uuid().v4()}_$name');
    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('department_chats')
        .doc(widget.subject)
        .collection('messages')
        .add({
      'senderUid': _uid,
      'senderName': _myName,
      'text': name,
      'fileUrl': url,
      'fileName': name,
      'type': ext == 'png' || ext == 'jpg' || ext == 'jpeg' ? 'image' : 'file',
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': {_uid: true},
      'isPinned': false,
      'isDeleted': false,
    });
    await _updateMetadata();
  }

  Future<void> _updateMetadata() async {
    await FirebaseFirestore.instance
        .collection('department_chats')
        .doc(widget.subject)
        .set({
      'subject': widget.subject,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _togglePin(DocumentSnapshot<Map<String, dynamic>> msg) async {
    if (!_isAdmin) return;
    final current = (msg.data()?['isPinned'] ?? false) as bool;
    await msg.reference.set({'isPinned': !current}, SetOptions(merge: true));
  }

  Future<void> _deleteMessage(DocumentSnapshot<Map<String, dynamic>> msg) async {
    final data = msg.data()!;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isMe = data['senderUid'] == _uid;

    final canDelete = _isAdmin || (isMe && createdAt != null && DateTime.now().difference(createdAt) <= const Duration(minutes: 1));

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own messages within 1 minute.')),
      );
      return;
    }

    await msg.reference.set({
      'isDeleted': true,
      'deletedBy': _uid,
      'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('department_chats')
          .doc(widget.subject)
          .collection('typing')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final now = DateTime.now();
        final active = snap.data!.docs.where((d) {
          final isTyping = (d.data()['isTyping'] ?? false) as bool;
          final ts = d.data()['lastUpdated'] as Timestamp?;
          if (!isTyping || ts == null) return false;
          final age = now.difference(ts.toDate());
          return age < const Duration(seconds: 3) && d.id != _uid;
        }).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        final names = active.map((d) => d.data()['name'] ?? 'Someone').join(', ');
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.edit, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$names typing...',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final isMe = data['senderUid'] == _uid;
    final isDeleted = (data['isDeleted'] ?? false) as bool;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final seenBy = (data['seenBy'] ?? {}) as Map<String, dynamic>;
    final isPinned = (data['isPinned'] ?? false) as bool;

    Color bubbleColor = isMe ? primaryColor : Colors.grey.shade100;
    TextStyle textStyle = TextStyle(color: isMe ? Colors.white : Colors.black87);

    Widget content;
    if (isDeleted) {
      content = const Text('Message removed', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    } else {
      final type = data['type'] as String? ?? 'text';
      if (type == 'image' && data['fileUrl'] != null) {
        content = GestureDetector(
          onTap: () => _showFullImage(data['fileUrl']),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              data['fileUrl'],
              width: 180,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 60),
            ),
          ),
        );
      } else if (type == 'file' && data['fileUrl'] != null) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file),
            const SizedBox(width: 6),
            Expanded(child: Text(data['fileName'] ?? 'file', style: textStyle, overflow: TextOverflow.ellipsis)),
          ],
        );
      } else {
        content = Text(data['text'] ?? '', style: textStyle.copyWith(fontSize: 16));
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: isPinned ? Border.all(color: Colors.orange, width: 2) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && !isDeleted)
              Text(data['senderName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
            if (!isMe && !isDeleted) const SizedBox(height: 4),
            content,
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatTime(createdAt), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54)),
                const SizedBox(width: 6),
                if (isMe)
                  Icon(seenBy.length > 1 ? Icons.done_all : Icons.check,
                      size: 14,
                      color: seenBy.length > 1 ? Colors.lightBlueAccent : Colors.white70),
                if (isPinned) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.push_pin, size: 14, color: Colors.amber)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isAdmin)
                  TextButton(onPressed: () => _togglePin(doc), child: Text(isPinned ? 'Unpin' : 'Pin', style: const TextStyle(fontSize: 12))),
                TextButton(onPressed: () => _deleteMessage(doc), child: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.redAccent))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Image'), backgroundColor: primaryColor),
          backgroundColor: Colors.black,
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
    );
  }

  Widget _buildPinnedHeader() {
    if (_pinned.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pinned', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ..._pinned.map((doc) {
          final data = doc.data()!;
          final sender = data['senderName'] ?? '';
          final summary = data['type'] == 'text' ? (data['text'] ?? '') : (data['fileName'] ?? data['text'] ?? '');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.push_pin, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(child: Text('$sender: $summary', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
              ],
            ),
          );
        }).toList(),
      ]),
    );
  }

  @override
  void dispose() {
    _msgController.dispose();
    _messagesSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    FirebaseFirestore.instance
        .collection('department_chats')
        .doc(widget.subject)
        .collection('typing')
        .doc(_uid)
        .set({'isTyping': false}, SetOptions(merge: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectTitle = widget.subject;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Row(
          children: [
            const Icon(Icons.group, size: 22, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$subjectTitle Department',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (_loadingUser) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _buildPinnedHeader()),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  reverse: true,
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) {
                    final doc = _messages[idx];
                    return _buildMessageBubble(doc);
                  },
                ),
                Positioned(bottom: 0, left: 0, right: 0, child: _buildTypingIndicator()),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), offset: const Offset(0, -1), blurRadius: 6)]),
              child: Row(
                children: [
                  IconButton(onPressed: _sendAttachment, icon: const Icon(Icons.attach_file), color: primaryColor),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      onChanged: (_) => _notifyTyping(),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendText(),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendText,
                      padding: EdgeInsets.zero,
                      tooltip: 'Send',
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
