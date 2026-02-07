import 'dart:convert';

class Creneau {
  final String jour;
  final String heureDebut;
  final String heureFin;
  final int moduleId;
  final String moduleName;
  final int formateurId;
  final String formateurName;
  final String salle;

  Creneau({
    required this.jour,
    required this.heureDebut,
    required this.heureFin,
    required this.moduleId,
    required this.moduleName,
    required this.formateurId,
    required this.formateurName,
    required this.salle,
  });

  Map<String, dynamic> toMap() {
    return {
      'jour': jour,
      'heure_debut': heureDebut,
      'heure_fin': heureFin,
      'module_id': moduleId,
      'module_name': moduleName,
      'formateur_id': formateurId,
      'formateur_name': formateurName,
      'salle': salle,
    };
  }

  factory Creneau.fromMap(Map<String, dynamic> map) {
    return Creneau(
      jour: map['jour'] as String,
      heureDebut: map['heure_debut'] as String,
      heureFin: map['heure_fin'] as String,
      moduleId: map['module_id'] as int,
      moduleName: map['module_name'] as String,
      formateurId: map['formateur_id'] as int? ?? 0,
      formateurName: map['formateur_name'] as String? ?? 'N/A',
      salle: map['salle'] as String,
    );
  }

  Creneau copyWith({
    String? jour,
    String? heureDebut,
    String? heureFin,
    int? moduleId,
    String? moduleName,
    int? formateurId,
    String? formateurName,
    String? salle,
  }) {
    return Creneau(
      jour: jour ?? this.jour,
      heureDebut: heureDebut ?? this.heureDebut,
      heureFin: heureFin ?? this.heureFin,
      moduleId: moduleId ?? this.moduleId,
      moduleName: moduleName ?? this.moduleName,
      formateurId: formateurId ?? this.formateurId,
      formateurName: formateurName ?? this.formateurName,
      salle: salle ?? this.salle,
    );
  }
}

class Emploi {
  final int? id;
  final int semaineNum;
  final int groupeId;
  final int? formateurId;
  final List<Creneau> creneaux;
  final String? pdfUrl;

  Emploi({
    this.id,
    required this.semaineNum,
    required this.groupeId,
    this.formateurId,
    required this.creneaux,
    this.pdfUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'semaine_num': semaineNum,
      'groupe_id': groupeId,
      'formateur_id': formateurId,
      'donnees_json': jsonEncode(creneaux.map((c) => c.toMap()).toList()),
      'pdf_url': pdfUrl,
    };
  }

  factory Emploi.fromMap(Map<String, dynamic> map) {
    List<Creneau> creneaux = [];
    if (map['donnees_json'] != null) {
      final List<dynamic> decoded = jsonDecode(map['donnees_json'] as String);
      creneaux = decoded.map((c) => Creneau.fromMap(c as Map<String, dynamic>)).toList();
    }
    return Emploi(
      id: map['id'] as int?,
      semaineNum: map['semaine_num'] as int,
      groupeId: map['groupe_id'] as int,
      formateurId: map['formateur_id'] as int?,
      creneaux: creneaux,
      pdfUrl: map['pdf_url'] as String?,
    );
  }

  Emploi copyWith({
    int? id,
    int? semaineNum,
    int? groupeId,
    int? formateurId,
    List<Creneau>? creneaux,
    String? pdfUrl,
  }) {
    return Emploi(
      id: id ?? this.id,
      semaineNum: semaineNum ?? this.semaineNum,
      groupeId: groupeId ?? this.groupeId,
      formateurId: formateurId ?? this.formateurId,
      creneaux: creneaux ?? this.creneaux,
      pdfUrl: pdfUrl ?? this.pdfUrl,
    );
  }
}

