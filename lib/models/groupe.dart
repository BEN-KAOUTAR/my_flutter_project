class Groupe {
  final int? id;
  final String nom;
  final int filiereId;
  final int annee;
  final String? photoUrl;

  Groupe({
    this.id,
    required this.nom,
    required this.filiereId,
    required this.annee,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'filiere_id': filiereId,
      'annee': annee,
      'photo_url': photoUrl,
    };
  }

  factory Groupe.fromMap(Map<String, dynamic> map) {
    return Groupe(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      filiereId: map['filiere_id'] as int,
      annee: map['annee'] as int,
      photoUrl: map['photo_url'] as String?,
    );
  }

  Groupe copyWith({
    int? id,
    String? nom,
    int? filiereId,
    int? annee,
    String? photoUrl,
  }) {
    return Groupe(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      filiereId: filiereId ?? this.filiereId,
      annee: annee ?? this.annee,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

