class Affectation {
  final int? id;
  final int formateurId;
  final int moduleId;
  final int groupeId;
  final String anneeScolaire;

  Affectation({
    this.id,
    required this.formateurId,
    required this.moduleId,
    required this.groupeId,
    required this.anneeScolaire,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'formateur_id': formateurId,
      'module_id': moduleId,
      'groupe_id': groupeId,
      'annee_scolaire': anneeScolaire,
    };
  }

  factory Affectation.fromMap(Map<String, dynamic> map) {
    return Affectation(
      id: map['id'] as int?,
      formateurId: map['formateur_id'] as int,
      moduleId: map['module_id'] as int,
      groupeId: map['groupe_id'] as int,
      anneeScolaire: map['annee_scolaire'] as String,
    );
  }

  Affectation copyWith({
    int? id,
    int? formateurId,
    int? moduleId,
    int? groupeId,
    String? anneeScolaire,
  }) {
    return Affectation(
      id: id ?? this.id,
      formateurId: formateurId ?? this.formateurId,
      moduleId: moduleId ?? this.moduleId,
      groupeId: groupeId ?? this.groupeId,
      anneeScolaire: anneeScolaire ?? this.anneeScolaire,
    );
  }
}

