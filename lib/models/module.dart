class Module {
  final int? id;
  final String nom;
  final double masseHoraireTotale;
  final int filiereId;
  final int coefficient;
  final int annee;
  final int semestre;
  final String? photoUrl;

  Module({
    this.id,
    required this.nom,
    required this.masseHoraireTotale,
    required this.filiereId,
    this.coefficient = 1,
    this.annee = 1,
    this.semestre = 1,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'masse_horaire_totale': masseHoraireTotale,
      'filiere_id': filiereId,
      'coefficient': coefficient,
      'annee': annee,
      'semestre': semestre,
      'photo_url': photoUrl,
    };
  }

  factory Module.fromMap(Map<String, dynamic> map) {
    return Module(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      masseHoraireTotale: (map['masse_horaire_totale'] as num).toDouble(),
      filiereId: map['filiere_id'] as int,
      coefficient: map['coefficient'] as int? ?? 1,
      annee: map['annee'] as int? ?? 1,
      semestre: map['semestre'] as int? ?? 1,
      photoUrl: map['photo_url'] as String?,
    );
  }

  Module copyWith({
    int? id,
    String? nom,
    double? masseHoraireTotale,
    int? filiereId,
    int? coefficient,
    int? annee,
    int? semestre,
    String? photoUrl,
  }) {
    return Module(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      masseHoraireTotale: masseHoraireTotale ?? this.masseHoraireTotale,
      filiereId: filiereId ?? this.filiereId,
      coefficient: coefficient ?? this.coefficient,
      annee: annee ?? this.annee,
      semestre: semestre ?? this.semestre,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

