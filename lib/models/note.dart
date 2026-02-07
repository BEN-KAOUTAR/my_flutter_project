enum NoteType {
  cc,
  efm,
}

extension NoteTypeExtension on NoteType {
  String get dbValue {
    switch (this) {
      case NoteType.cc:
        return 'CC';
      case NoteType.efm:
        return 'EFM';
    }
  }

  String get displayName {
    switch (this) {
      case NoteType.cc:
        return 'Contrôle Continu';
      case NoteType.efm:
        return 'Examen de Fin de Module';
    }
  }

  static NoteType fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'EFM':
        return NoteType.efm;
      default:
        return NoteType.cc;
    }
  }
}

enum NoteStatus {
  enAttente,
  validee,
  rejetee,
}

extension NoteStatusExtension on NoteStatus {
  String get dbValue {
    switch (this) {
      case NoteStatus.enAttente:
        return 'EN_ATTENTE';
      case NoteStatus.validee:
        return 'VALIDEE';
      case NoteStatus.rejetee:
        return 'REJETEE';
    }
  }

  static NoteStatus fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'VALIDEE':
      case 'VALIDE':
        return NoteStatus.validee;
      case 'REJETEE':
        return NoteStatus.rejetee;
      default:
        return NoteStatus.enAttente;
    }
  }
}

class Note {
  final int? id;
  final int stagiaireId;
  final int moduleId;
  final NoteType type;
  final double valeur;
  final DateTime dateExamen;
  final bool validee;
  final bool publiee;
  final NoteStatus statut;

  Note({
    this.id,
    required this.stagiaireId,
    required this.moduleId,
    required this.type,
    required this.valeur,
    required this.dateExamen,
    this.validee = false,
    this.publiee = false,
    this.statut = NoteStatus.enAttente,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stagiaire_id': stagiaireId,
      'module_id': moduleId,
      'type': type.dbValue,
      'valeur': valeur,
      'date_examen': dateExamen.toIso8601String(),
      'validee': validee ? 1 : 0,
      'publiee': publiee ? 1 : 0,
      'statut': statut.dbValue,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      stagiaireId: map['stagiaire_id'] as int,
      moduleId: map['module_id'] as int,
      type: NoteTypeExtension.fromDbValue(map['type'] as String),
      valeur: (map['valeur'] as num).toDouble(),
      dateExamen: DateTime.parse(map['date_examen'] as String),
      validee: (map['validee'] as int? ?? 0) == 1,
      publiee: (map['publiee'] as int? ?? 0) == 1,
      statut: NoteStatusExtension.fromDbValue(map['statut'] as String? ?? 'EN_ATTENTE'),
    );
  }

  Note copyWith({
    int? id,
    int? stagiaireId,
    int? moduleId,
    NoteType? type,
    double? valeur,
    DateTime? dateExamen,
    bool? validee,
    bool? publiee,
    NoteStatus? statut,
  }) {
    return Note(
      id: id ?? this.id,
      stagiaireId: stagiaireId ?? this.stagiaireId,
      moduleId: moduleId ?? this.moduleId,
      type: type ?? this.type,
      valeur: valeur ?? this.valeur,
      dateExamen: dateExamen ?? this.dateExamen,
      validee: validee ?? this.validee,
      publiee: publiee ?? this.publiee,
      statut: statut ?? this.statut,
    );
  }
}

