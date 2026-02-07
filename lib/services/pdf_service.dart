import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/emploi.dart';
import '../models/note.dart';
import '../models/user.dart';
import '../models/module.dart';

class PdfService {
  static Future<void> generateEmploiPdf(Emploi emploi, {required String groupeName}) async {
    final pdf = pw.Document();
    
    final slots = ['08:30 - 11:00', '11:00 - 13:30', '13:30 - 16:00', '16:00 - 18:30'];
    final jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(groupeName, emploi.semaineNum),
              pw.SizedBox(height: 10),
              _buildGridTable(emploi.creneaux, jours, slots),
              pw.SizedBox(height: 20),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateFormateurEmploiPdf(List<Creneau> creneaux, {required String formateurName, required int semaineNum}) async {
    final pdf = pw.Document();
    
    final slots = ['08:30 - 11:00', '11:00 - 13:30', '13:30 - 16:00', '16:00 - 18:30'];
    final jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('$formateurName', semaineNum, title: 'EMPLOI DU TEMPS INDIVIDUEL'),
              pw.SizedBox(height: 10),
              _buildGridTable(creneaux, jours, slots, isFormateurView: true),
              pw.SizedBox(height: 20),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildHeader(String mainTitle, int semaineNum, {String title = 'EMPLOI DU TEMPS PAR GROUPE COURS DU JOUR'}) {
    return pw.Column(
      children: [
        pw.Text('ROYAUME DU MAROC', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('OFPPT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('CMC AGADIR', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Center(
            child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Groupe/Formateur: $title', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text('Semaine: $semaineNum', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Année de Formation: 2025/2026', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildGridTable(List<Creneau> creneaux, List<String> jours, List<String> slots, {bool isFormateurView = false}) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
          0: const pw.FixedColumnWidth(60),
        },
        children: [
          pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('JOUR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)))),
            ...slots.map((s) => pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))))),
          ],
        ),
        ...jours.map((jour) {
          return pw.TableRow(
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(jour, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ),
              ...slots.map((slot) {
                final times = slot.split(' - ');
                final start = times[0].trim();
                
                final creneau = creneaux.where((c) => 
                  c.jour == jour && 
                  (c.heureDebut.startsWith(start.substring(0, 2)) ||
                   c.heureDebut == start)
                ).firstOrNull;

                return pw.Container(
                  height: 50,
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(2),
                  child: creneau != null 
                    ? pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(creneau.moduleName, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          pw.SizedBox(height: 2),
                          pw.Text(isFormateurView ? creneau.formateurName : creneau.formateurName, style: pw.TextStyle(fontSize: 6)), 
                          pw.Text(creneau.salle, style: pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic)),
                        ],
                      )
                    : pw.Text(''),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Directeur Pédagogique', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text('Surveillant Général', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text('Formateur', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ],
    );
  }

    static Future<void> generateNoteReportPdf(User user, List<Note> notes, List<Module> modules) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('RELEVÉ DE NOTES', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Nom: ${user.nom}', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Email: ${user.email}', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Module', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Note', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...notes.map((n) {
                    final module = modules.firstWhere((m) => m.id == n.moduleId, orElse: () => Module(nom: 'N/A', masseHoraireTotale: 0, filiereId: 0));
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(module.nom)),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(n.type.toString().split('.').last.toUpperCase())),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${n.valeur}/20')),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Text('Observations:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 100,
                width: double.infinity,
                decoration: pw.BoxDecoration(border: pw.Border.all()),
              ),
              pw.Footer(
                margin: const pw.EdgeInsets.only(top: 20),
                leading: pw.Text('Généré par Academic Pro'),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateProgressReportPdf(List<Map<String, dynamic>> progressData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('RAPPORT DE PROGRESSION PÉDAGOGIQUE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Groupe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Module', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Formateur', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Heures Réalisées', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Masse Totale', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Progression', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    ],
                  ),
                  ...progressData.map((data) {
                    final done = data['hours_done'] as num? ?? 0;
                    final total = data['masse_horaire_totale'] as num? ?? 1;
                    final percent = (done / (total == 0 ? 1 : total) * 100).toStringAsFixed(1);
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['groupe_name'] ?? 'N/A')),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['module_name'] ?? 'N/A')),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['formateur_name'] ?? 'N/A')),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${done}h', textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${total}h', textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$percent%', textAlign: pw.TextAlign.center)),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Footer(
                margin: const pw.EdgeInsets.only(top: 20),
                leading: pw.Text('Direction Pédagogique - Academic Pro'),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
