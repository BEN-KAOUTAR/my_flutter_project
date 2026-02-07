import '../models/note.dart';
import '../models/module.dart';

class AnalysisService {
  static Map<String, dynamic> predictPerformance(List<Note> notes, List<Module> modules) {
    if (notes.isEmpty) {
      return {
        'prediction': 'Données insuffisantes',
        'score': 0.0,
        'recommendation': 'Commencez à passer des examens pour obtenir une analyse.',
        'status': 'neutral',
      };
    }

    final validatedNotes = notes.where((n) => n.validee).toList();
    if (validatedNotes.isEmpty) {
       return {
        'prediction': 'En attente de validation',
        'score': 0.1,
        'recommendation': 'Vos notes sont en cours de validation par l\'administration.',
        'status': 'neutral',
      };
    }

    final average = validatedNotes.map((n) => n.valeur).reduce((a, b) => a + b) / validatedNotes.length;
    
    bool isImproving = false;
    if (validatedNotes.length >= 2) {
      final sortedNotes = List<Note>.from(validatedNotes)..sort((a, b) => b.dateExamen.compareTo(a.dateExamen));
      if (sortedNotes[0].valeur >= sortedNotes[1].valeur) {
        isImproving = true;
      }
    }

    String prediction;
    double score;
    String recommendation;
    String status;

    if (average >= 16) {
      prediction = 'Excellente progression';
      score = 0.95;
      recommendation = isImproving 
          ? 'Performance exceptionnelle ! Vous maîtrisez parfaitement les concepts. Continuez sur cette lancée.'
          : 'Très haut niveau. Restez vigilant pour maintenir cette excellence.';
      status = 'success';
    } else if (average >= 13) {
      prediction = 'Bonne maîtrise';
      score = 0.8;
      recommendation = 'Solide compréhension des modules. Approfondissez les détails techniques pour atteindre l\'excellence.';
      status = 'success';
    } else if (average >= 10) {
      prediction = 'Niveau satisfaisant';
      score = 0.6;
      recommendation = 'Moyenne atteinte mais des lacunes persistent. Identifiez les modules faibles pour les renforcer.';
      status = 'warning';
    } else {
      prediction = 'Besoin de soutien';
      score = 0.3;
      recommendation = 'Difficultés détectées. Il est fortement conseillé de solliciter des séances de remédiation.';
      status = 'danger';
    }

    return {
      'prediction': prediction,
      'score': score,
      'recommendation': recommendation,
      'average': average,
      'status': status,
      'trend': isImproving ? 'up' : 'down',
    };
  }

  static Map<String, dynamic> analyzeGroupPerformance(List<Map<String, dynamic>> studentsData) {
    if (studentsData.isEmpty) return {'status': 'no_data'};

    double totalAverage = 0;
    int successCount = 0;
    int warningCount = 0;
    int dangerCount = 0;

    for (var student in studentsData) {
      final avg = (student['average'] as num).toDouble();
      totalAverage += avg;
      if (avg >= 12) successCount++;
      else if (avg >= 10) warningCount++;
      else dangerCount++;
    }

    final groupAverage = totalAverage / studentsData.length;
    
    return {
      'group_average': groupAverage,
      'success_rate': (successCount / studentsData.length) * 100,
      'warning_rate': (warningCount / studentsData.length) * 100,
      'danger_rate': (dangerCount / studentsData.length) * 100,
      'overall_status': groupAverage >= 14 ? 'Excellent' : (groupAverage >= 11 ? 'Satisfaisant' : 'À surveiller'),
    };
  }
}

