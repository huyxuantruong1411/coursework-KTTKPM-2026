class UserModel {
  final String userId;
  final String username;
  final String email;
  final String? displayName;
  final String? avatar;
  final String? bio;
  final String role;
  final bool isLocked;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    this.displayName,
    this.avatar,
    this.bio,
    this.role = 'user',
    this.isLocked = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['UserId']?.toString() ?? '',
      username: json['Username'] ?? '',
      email: json['Email'] ?? '',
      displayName: json['DisplayName'],
      avatar: json['Avatar'],
      bio: json['Bio'],
      role: json['Role'] ?? 'user',
      isLocked: json['IsLocked'] ?? false,
      createdAt: json['CreatedAt'] != null ? DateTime.tryParse(json['CreatedAt']) : null,
      updatedAt: json['UpdatedAt'] != null ? DateTime.tryParse(json['UpdatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'UserId': userId,
    'Username': username,
    'Email': email,
    'DisplayName': displayName,
    'Avatar': avatar,
    'Bio': bio,
    'Role': role,
    'IsLocked': isLocked,
  };
}
