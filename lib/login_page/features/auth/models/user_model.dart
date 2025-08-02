// features/auth/models/user_model.dart

class AppUser {
  final String uid;
  final String email;
  final String phone;
  final String role;
  final String name;
  final String subject;

  AppUser({
    required this.uid,
    required this.email,
    required this.phone,
    required this.role,
    required this.name,
    required this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phone': phone,
      'role': role,
      'name': name,
      'subject': subject,
      'isProfileCompleted': true,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? '',
      name: map['name'] ?? '',
      subject: map['subject'] ?? '',
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? phone,
    String? role,
    String? name,
    String? subject,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      name: name ?? this.name,
      subject: subject ?? this.subject,
    );
  }

  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, phone: $phone, role: $role, name: $name, subject: $subject)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser &&
        other.uid == uid &&
        other.email == email &&
        other.phone == phone &&
        other.role == role &&
        other.name == name &&
        other.subject == subject;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        phone.hashCode ^
        role.hashCode ^
        name.hashCode ^
        subject.hashCode;
  }
}
