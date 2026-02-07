enum SeanceStatus {
  enAttente,
  valide,
  rejetee,
}

extension SeanceStatusExtension on SeanceStatus {
  String get dbValue {
    switch (this) {
      case SeanceStatus.enAttente:
        return 'EN_ATTENTE';
      case SeanceStatus.valide:
        return 'VALIDE';
      case SeanceStatus.rejetee:
        return 'REJETEE';
    }
  }

  String get displayName {
    switch (this) {
      case SeanceStatus.enAttente:
        return 'En attente';
      case SeanceStatus.valide:
        return 'Validée';
      case SeanceStatus.rejetee:
        return 'Rejetée';
    }
  }

  static SeanceStatus fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'VALIDE':
        return SeanceStatus.valide;
      case 'REJETEE':
        return SeanceStatus.rejetee;
      default:
        return SeanceStatus.enAttente;
    }
  }
}

class Seance {
  final int? id;
  final int affectationId;
  final DateTime date;
  final String? heureDebut;
  final double duree;
  final String contenu;
  final SeanceStatus statut;

  Seance({
    this.id,
    required this.affectationId,
    required this.date,
    this.heureDebut,
    required this.duree,
    required this.contenu,
    this.statut = SeanceStatus.enAttente,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'affectation_id': affectationId,
      'date': date.toIso8601String(),
      'heure_debut': heureDebut,
      'duree': duree,
      'contenu': contenu,
      'statut': statut.dbValue,
    };
  }

  factory Seance.fromMap(Map<String, dynamic> map) {
    return Seance(
      id: map['id'] as int?,
      affectationId: map['affectation_id'] as int,
      date: DateTime.parse(map['date'] as String),
      heureDebut: map['heure_debut'] as String?,
      duree: (map['duree'] as num).toDouble(),
      contenu: map['contenu'] as String,
      statut: SeanceStatusExtension.fromDbValue(map['statut'] as String),
    );
  }

  Seance copyWith({
    int? id,
    int? affectationId,
    DateTime? date,
    String? heureDebut,
    double? duree,
    String? contenu,
    SeanceStatus? statut,
  }) {
    return Seance(
      id: id ?? this.id,
      affectationId: affectationId ?? this.affectationId,
      date: date ?? this.date,
      heureDebut: heureDebut ?? this.heureDebut,
      duree: duree ?? this.duree,
      contenu: contenu ?? this.contenu,
      statut: statut ?? this.statut,
    );
  }
}

