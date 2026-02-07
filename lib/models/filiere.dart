class Filiere {
  final int? id;
  final String nom;
  final String description;
  final int? directorId;

  Filiere({
    this.id,
    required this.nom,
    this.description = '',
    this.directorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'director_id': directorId,
    };
  }

  factory Filiere.fromMap(Map<String, dynamic> map) {
    return Filiere(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      description: map['description'] as String? ?? '',
      directorId: map['director_id'] as int?,
    );
  }

  Filiere copyWith({
    int? id,
    String? nom,
    String? description,
    int? directorId,
  }) {
    return Filiere(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      directorId: directorId ?? this.directorId,
    );
  }
}

