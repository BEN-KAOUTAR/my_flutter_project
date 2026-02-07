class Module {
  final int? id;
  final String nom;
  final double masseHoraireTotale;
  final int filiereId;
  final int coefficient;
  final String? photoUrl;

  Module({
    this.id,
    required this.nom,
    required this.masseHoraireTotale,
    required this.filiereId,
    this.coefficient = 1,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'masse_horaire_totale': masseHoraireTotale,
      'filiere_id': filiereId,
      'coefficient': coefficient,
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
      photoUrl: map['photo_url'] as String?,
    );
  }

  Module copyWith({
    int? id,
    String? nom,
    double? masseHoraireTotale,
    int? filiereId,
    int? coefficient,
    String? photoUrl,
  }) {
    return Module(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      masseHoraireTotale: masseHoraireTotale ?? this.masseHoraireTotale,
      filiereId: filiereId ?? this.filiereId,
      coefficient: coefficient ?? this.coefficient,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

