enum UserRole {
  dp,
  formateur,
  stagiaire,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.dp:
        return 'Directeur Pédagogique';
      case UserRole.formateur:
        return 'Formateur';
      case UserRole.stagiaire:
        return 'Stagiaire';
    }
  }

  String get description {
    switch (this) {
      case UserRole.dp:
        return 'Gestion globale et validation';
      case UserRole.formateur:
        return 'Saisie avancement et notes';
      case UserRole.stagiaire:
        return 'Consultation notes et emploi';
    }
  }

  String get dbValue {
    switch (this) {
      case UserRole.dp:
        return 'DP';
      case UserRole.formateur:
        return 'FORMATEUR';
      case UserRole.stagiaire:
        return 'STAGIAIRE';
    }
  }

  static UserRole fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'DP':
        return UserRole.dp;
      case 'FORMATEUR':
        return UserRole.formateur;
      case 'STAGIAIRE':
        return UserRole.stagiaire;
      default:
        return UserRole.stagiaire;
    }
  }
}

class User {
  final int? id;
  final String nom;
  final String email;
  final String password;
  final UserRole role;
  final double totalHeuresAffectees;
  final int? groupeId;
  final String? matricule;
  final String? specialite;
  final String invitationStatus;
  final String? phone;
  final String? birthDate;
  final String? photoUrl;
  final int? directorId;
  final bool isExpert;
  final int moduleCount;
  final String? anneeScolaire;

  User({
    this.id,
    required this.nom,
    required this.email,
    required this.password,
    required this.role,
    this.totalHeuresAffectees = 0.0,
    this.groupeId,
    this.matricule,
    this.specialite,
    this.invitationStatus = 'En attente',
    this.phone,
    this.birthDate,
    this.photoUrl,
    this.directorId,
    this.isExpert = false,
    this.moduleCount = 0,
    this.anneeScolaire,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'email': email,
      'password': password,
      'role': role.dbValue,
      'total_heures_affectees': totalHeuresAffectees,
      'groupe_id': groupeId,
      'matricule': matricule,
      'specialite': specialite,
      'invitation_status': invitationStatus,
      'phone': phone,
      'birth_date': birthDate,
      'photo_url': photoUrl,
      'director_id': directorId,
      'is_expert': isExpert ? 1 : 0,
      'annee_scolaire': anneeScolaire,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      role: UserRoleExtension.fromDbValue(map['role'] as String),
      totalHeuresAffectees: (map['total_heures_affectees'] as num?)?.toDouble() ?? 0.0,
      groupeId: map['groupe_id'] as int?,
      matricule: map['matricule'] as String?,
      specialite: map['specialite'] as String?,
      invitationStatus: (map['invitation_status'] as String?) ?? 'En attente',
      phone: map['phone'] as String?,
      birthDate: map['birth_date'] as String?,
      photoUrl: map['photo_url'] as String?,
      directorId: map['director_id'] as int?,
      isExpert: (map['is_expert'] as int?) == 1,
      moduleCount: map['module_count'] as int? ?? 0,
      anneeScolaire: map['annee_scolaire'] as String?,
    );
  }

  User copyWith({
    int? id,
    String? nom,
    String? email,
    String? password,
    UserRole? role,
    double? totalHeuresAffectees,
    int? groupeId,
    String? matricule,
    String? specialite,
    String? invitationStatus,
    String? phone,
    String? birthDate,
    String? photoUrl,
    int? directorId,
    bool? isExpert,
    int? moduleCount,
    String? anneeScolaire,
  }) {
    return User(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      totalHeuresAffectees: totalHeuresAffectees ?? this.totalHeuresAffectees,
      groupeId: groupeId ?? this.groupeId,
      matricule: matricule ?? this.matricule,
      specialite: specialite ?? this.specialite,
      invitationStatus: invitationStatus ?? this.invitationStatus,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      photoUrl: photoUrl ?? this.photoUrl,
      directorId: directorId ?? this.directorId,
      isExpert: isExpert ?? this.isExpert,
      moduleCount: moduleCount ?? this.moduleCount,
      anneeScolaire: anneeScolaire ?? this.anneeScolaire,
    );
  }
}
