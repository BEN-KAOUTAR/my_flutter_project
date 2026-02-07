class UserRequest {
  final int? id;
  final String nom;
  final String email;
  final String role;
  final String? phone;
  final String? groupe;
  final String? annee;
  final int directorId;
  final DateTime timestamp;
  final String status;

  UserRequest({
    this.id,
    required this.nom,
    required this.email,
    required this.role,
    this.phone,
    this.groupe,
    this.annee,
    required this.directorId,
    required this.timestamp,
    this.status = 'EN_ATTENTE',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'email': email,
      'phone': phone,
      'role': role,
      'groupe': groupe,
      'annee': annee,
      'director_id': directorId,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory UserRequest.fromMap(Map<String, dynamic> map) {
    return UserRequest(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String?,
      role: map['role'] as String,
      groupe: map['groupe'] as String?,
      annee: map['annee'] as String?,
      directorId: map['director_id'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
    );
  }
}

