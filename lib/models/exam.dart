enum ExamStatus {
  planifie,
  publie,
  realise,
  annule,
  rejete;

  String get displayName {
    switch (this) {
      case ExamStatus.planifie: return 'PlanifiÃ©';
      case ExamStatus.publie: return 'PubliÃ©';
      case ExamStatus.realise: return 'RÃ©alisÃ©';
      case ExamStatus.annule: return 'AnnulÃ©';
      case ExamStatus.rejete: return 'RejetÃ©';
    }
  }
}

class Exam {
  final int? id;
  final int affectationId;
  final DateTime date;
  final String type;
  final String description;
  final ExamStatus status;

  Exam({
    this.id,
    required this.affectationId,
    required this.date,
    required this.type,
    required this.description,
    this.status = ExamStatus.planifie,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'affectation_id': affectationId,
      'date': date.toIso8601String(),
      'type': type,
      'description': description,
      'status': status.name.toUpperCase(),
    };
  }

  factory Exam.fromMap(Map<String, dynamic> map) {
    return Exam(
      id: map['id'],
      affectationId: map['affectation_id'],
      date: DateTime.parse(map['date']),
      type: map['type'],
      description: map['description'] ?? '',
      status: ExamStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == map['status'],
        orElse: () => ExamStatus.planifie,
      ),
    );
  }
}

