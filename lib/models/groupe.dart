class Groupe {
  final int? id;
  final String nom;
  final int filiereId;
  final int annee;
  final String anneeScolaire;
  final String? photoUrl;

  Groupe({
    this.id,
    required this.nom,
    required this.filiereId,
    required this.annee,
    this.anneeScolaire = '2023 - 2025',
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'filiere_id': filiereId,
      'annee': annee,
      'annee_scolaire': anneeScolaire,
      'photo_url': photoUrl,
    };
  }

  factory Groupe.fromMap(Map<String, dynamic> map) {
    return Groupe(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      filiereId: map['filiere_id'] as int,
      annee: map['annee'] as int,
      anneeScolaire: map['annee_scolaire'] as String? ?? '2023 - 2025',
      photoUrl: map['photo_url'] as String?,
    );
  }

  Groupe copyWith({
    int? id,
    String? nom,
    int? filiereId,
    int? annee,
    String? anneeScolaire,
    String? photoUrl,
  }) {
    return Groupe(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      filiereId: filiereId ?? this.filiereId,
      annee: annee ?? this.annee,
      anneeScolaire: anneeScolaire ?? this.anneeScolaire,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

