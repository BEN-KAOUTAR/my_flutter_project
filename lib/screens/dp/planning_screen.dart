import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math'; 
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../models/emploi.dart';
import '../../models/groupe.dart';
import '../../models/user.dart';
import '../../models/affectation.dart';
import '../../theme/app_theme.dart';
import '../../services/planning_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PlanningScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const PlanningScreen({super.key, this.onBack});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  List<Groupe> _groupes = [];
  int? _selectedGroupeId;
  List<Emploi> _emplois = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final directorId = user?.id;

    final groupes = await DatabaseHelper.instance.getAllGroupes(directorId: directorId);
    setState(() {
      _groupes = groupes;
      if (groupes.isNotEmpty && _selectedGroupeId == null) {
        _selectedGroupeId = groupes.first.id;
      }
    });
    if (_selectedGroupeId != null) {
      await _loadEmplois();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmplois() async {
    if (_selectedGroupeId == null) return;
    final emplois = await DatabaseHelper.instance.getEmploisByGroupe(_selectedGroupeId!);
    setState(() {
      _emplois = emplois;
      _isLoading = false;
    });
  }

  String _getGroupeName(int id) {
    return _groupes.where((g) => g.id == id).firstOrNull?.nom ?? 'N/A';
  }

  int _calculateWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
    final firstMonday = DateTime(date.year, 1, 1 + daysToFirstMonday);
    
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (normalizedDate.isBefore(firstMonday)) return 1;
    
    final daysSinceFirstMonday = normalizedDate.difference(firstMonday).inDays;
    return (daysSinceFirstMonday / 7).floor() + 1;
  }

  Map<String, dynamic> _getMonthlyWeekInfo(int yearlyWeekNum) {
    final year = DateTime.now().year;
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
    final firstMonday = DateTime(year, 1, 1 + daysToFirstMonday);
    
    final weekMonday = firstMonday.add(Duration(days: (yearlyWeekNum - 1) * 7));
    
    final firstDayOfMonth = DateTime(weekMonday.year, weekMonday.month, 1);
    int offsetToFirstMonday = (DateTime.monday - firstDayOfMonth.weekday + 7) % 7;
    final monthFirstMonday = firstDayOfMonth.add(Duration(days: offsetToFirstMonday));
    
    int weekIndex;
    if (weekMonday.isBefore(monthFirstMonday)) {
      weekIndex = 1; 
    } else {
      weekIndex = (weekMonday.difference(monthFirstMonday).inDays / 7).floor() + 1;
    }
    
    final months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    
    return {
      'month': months[weekMonday.month - 1],
      'weekIndex': weekIndex,
      'display': 'Semaine $weekIndex'
    };
  }

  String _getMonthlyWeekDisplay(int yearlyWeekNum) {
    final info = _getMonthlyWeekInfo(yearlyWeekNum);
    return info['display'] as String;
  }

  Future<void> _generateAndSharePdf(Emploi emploi) async {
    final doc = pw.Document();
    final groupeName = _getGroupeName(emploi.groupeId);
    
    final year = DateTime.now().year;
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
    final firstMonday = firstDayOfYear.add(Duration(days: daysToFirstMonday));
    final weekStart = firstMonday.add(Duration(days: (emploi.semaineNum - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 5));
    final dateFormat = DateFormat('dd/MM/yyyy');

    doc.addPage(
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
                    pw.Text('Emploi du Temps - $groupeName', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${_getMonthlyWeekDisplay(emploi.semaineNum)} (${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)})', style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              _buildPdfTable(emploi),
              pw.SizedBox(height: 20),
              pw.Text('Ecole: Digital Pole - Généré le ${dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'emploi_${groupeName}_S${emploi.semaineNum}.pdf');
  }

  pw.Widget _buildPdfTable(Emploi emploi) {
    const jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    const slots = ['08:30 - 10:30', '10:30 - 12:30', '14:00 - 16:00', '16:00 - 18:00'];

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Horaire', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ...jours.map((j) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(j, style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center))),
          ],
        ),
        ...slots.map((slot) {
          final times = slot.split(' - ');
          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(slot, style: const pw.TextStyle(fontSize: 10))),
              ...jours.map((jour) {
                final c = emploi.creneaux.where((cr) => cr.jour == jour && cr.heureDebut == times[0]).firstOrNull;
                return pw.Container(
                  height: 60,
                  padding: const pw.EdgeInsets.all(5),
                  child: c != null 
                    ? pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(c.moduleName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text(c.formateurName, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(c.salle, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ]
                      )
                    : pw.Container(),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadEmplois,
                child: _buildBody(),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Générez et gérez les plannings hebdomadaires',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 12 : 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(),
                icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                label: Text(
                  isMobile ? 'Nouveau' : 'Nouvel emploi',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedGroupeId,
                  isExpanded: true,
                  hint: Text('Choisir un groupe...', style: GoogleFonts.poppins(fontSize: 14)),
                  onChanged: (val) => setState(() {
                    _selectedGroupeId = val;
                    _isLoading = true;
                    _loadEmplois();
                  }),
                  items: _groupes.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.nom))).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGenerateAIDialog() async {
    int? dialogGroupId = _selectedGroupeId;
    int dialogSemaineNum = _calculateWeekNumber(DateTime.now());

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.formateurColor),
              const SizedBox(width: 8),
              Text('Génération IA', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'L\'IA va générer un emploi du temps équilibré pour ce groupe en fonction des modules affectés.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int?>(
                value: dialogGroupId,
                decoration: InputDecoration(
                  labelText: 'Groupe',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _groupes.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.nom))).toList(),
                onChanged: (val) => setModalState(() => dialogGroupId = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: dialogSemaineNum,
                decoration: InputDecoration(
                  labelText: 'Semaine',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: List.generate(52, (i) => i + 1).map((i) {
                  final info = _getMonthlyWeekInfo(i);
                  return DropdownMenuItem(value: i, child: Text('${info['display']} (${info['month']})'));
                }).toList(),
                onChanged: (val) => setModalState(() => dialogSemaineNum = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (dialogGroupId == null) return;
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final emploi = await PlanningService.generateSmartSchedule(dialogGroupId!, dialogSemaineNum);
                if (emploi != null) {
                  _loadEmplois();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Emploi du temps généré !'), backgroundColor: AppTheme.accentGreen),
                  );
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erreur lors de la génération'), backgroundColor: AppTheme.accentRed),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.formateurColor),
              child: Text('Générer', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedGroupeId == null) {
      return _buildNoGroupSelected();
    }
    
    if (_emplois.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _emplois.length,
      itemBuilder: (context, index) => _buildEmploiCard(_emplois[index]),
    );
  }

  Widget _buildNoGroupSelected() {
    return Center(
      child: Text(
        'Veuillez sélectionner un groupe',
        style: GoogleFonts.poppins(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun emploi du temps',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre premier emploi du temps',
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showCreateDialog(),
             style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Créer un emploi', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  Widget _buildEmploiCard(Emploi emploi) {
    final year = DateTime.now().year;
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
    final firstMonday = firstDayOfYear.add(Duration(days: daysToFirstMonday));
    final weekStart = firstMonday.add(Duration(days: (emploi.semaineNum - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 5));
    
    final dateFormat = DateFormat('yyyy-MM-dd');
    final totalHours = emploi.creneaux.fold<double>(0, (sum, c) => sum + 2.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getMonthlyWeekDisplay(emploi.semaineNum),
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Publié',
                                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _getGroupeName(emploi.groupeId),
                          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            Text(
                              '${totalHours.toInt()}h',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => _generateAndSharePdf(emploi),
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.primaryBlue, size: 18),
                    label: Text('Exporter', style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreateDialog(existingEmploi: emploi),
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.accentOrange, size: 18),
                    label: Text('Modifier', style: GoogleFonts.poppins(color: AppTheme.accentOrange, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(emploi),
                    icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed, size: 18),
                    label: Text('Supprimer', style: GoogleFonts.poppins(color: AppTheme.accentRed, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showCreateDialog({Emploi? existingEmploi}) async {
    int? dialogGroupId = existingEmploi?.groupeId ?? _selectedGroupeId;
    int dialogSemaineNum = existingEmploi?.semaineNum ?? _calculateWeekNumber(DateTime.now());
    List<Creneau> dialogCreneaux = existingEmploi != null ? List.from(existingEmploi.creneaux) : [];
    
    final List<String> jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    final List<String> slots = ['08:30 - 11:00', '11:00 - 13:00', '13:30 - 15:30', '15:30 - 18:30'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double totalHours = 0;
          for (var creneau in dialogCreneaux) {
            final start = creneau.heureDebut.split(':');
            final end = creneau.heureFin.split(':');
            final startMinutes = int.parse(start[0]) * 60 + int.parse(start[1]);
            final endMinutes = int.parse(end[0]) * 60 + int.parse(end[1]);
            totalHours += (endMinutes - startMinutes) / 60.0;
          }
          final year = DateTime.now().year;
          final firstDayOfYear = DateTime(year, 1, 1);
          final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
          final firstMonday = firstDayOfYear.add(Duration(days: daysToFirstMonday));
          final weekStart = firstMonday.add(Duration(days: (dialogSemaineNum - 1) * 7));
          final weekEnd = weekStart.add(const Duration(days: 5));
          final dateFormat = DateFormat('dd MMM');
          final dateRange = '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)} $year';

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 800),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existingEmploi != null ? 'Modifier l\'emploi du temps' : 'Créer un emploi du temps',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      'Configurez les créneaux ou utilisez l\'IA pour générer automatiquement',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 24,
                          runSpacing: 16,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Groupe *', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 8),
                                Container(
                                  width: constraints.maxWidth > 500 ? 320 : double.infinity,
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: dialogGroupId,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                      items: _groupes.map((g) => DropdownMenuItem(
                                        value: g.id,
                                        child: Text(g.nom, style: GoogleFonts.poppins(fontSize: 14)),
                                      )).toList(),
                                      onChanged: existingEmploi != null ? null : (value) => setModalState(() => dialogGroupId = value),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Semaine', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 8),
                                Container(
                                  width: constraints.maxWidth > 500 ? 360 : double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left, size: 20),
                                        onPressed: () => setModalState(() => dialogSemaineNum = dialogSemaineNum > 1 ? dialogSemaineNum - 1 : 1),
                                      ),
                                      Expanded(
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Text(
                                            dateRange,
                                            style: GoogleFonts.poppins(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right, size: 20),
                                        onPressed: () => setModalState(() => dialogSemaineNum++),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (dialogGroupId == null) return;
                        final generated = await PlanningService.generateSmartSchedule(dialogGroupId!, dialogSemaineNum);
                        if (generated != null) {
                          setModalState(() {
                            dialogCreneaux = generated.creneaux;
                          });
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.primaryBlue),
                      label: Text('Générer avec IA', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.primaryBlue,
                        elevation: 0,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 400,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1000),
                            child: Table(
                              border: TableBorder.all(color: AppTheme.border, width: 0.5),
                              columnWidths: const {
                                0: FixedColumnWidth(80),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade50),
                                  children: [
                                    _buildGridHeader('Horaire'),
                                    ...jours.map((j) => _buildGridHeader(j)),
                                  ],
                                ),
                                ...slots.map((slot) => TableRow(
                                  children: [
                                    _buildGridTimeCell(slot),
                                    ...jours.map((jour) => _buildGridSlot(jour, slot, dialogCreneaux, dialogSemaineNum, (c) {
                                      dialogCreneaux.removeWhere((x) => x.jour == c.jour && x.heureDebut == c.heureDebut);
                                      setModalState(() => dialogCreneaux.add(c));
                                    }, (c) {
                                      setModalState(() => dialogCreneaux.remove(c));
                                    })),
                                  ],
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 18, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Total: ${totalHours}h',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (dialogGroupId == null) return;
                            
                            final duplicate = await DatabaseHelper.instance.getEmploiBySemaineAndGroupe(dialogSemaineNum, dialogGroupId!);
                            
                            if (duplicate != null) {
                              if (existingEmploi == null || duplicate.id != existingEmploi.id) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Un emploi du temps existe déjà pour cette semaine et ce groupe.', style: GoogleFonts.poppins()), 
                                      backgroundColor: AppTheme.accentRed
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            final emploi = Emploi(
                              id: existingEmploi?.id,
                              semaineNum: dialogSemaineNum,
                              groupeId: dialogGroupId!,
                              creneaux: dialogCreneaux,
                            );
                            if (existingEmploi != null) {
                               await DatabaseHelper.instance.updateEmploi(emploi);
                            } else {
                               await DatabaseHelper.instance.insertEmploi(emploi);
                            }
                            if (context.mounted) {
                              setState(() {
                                _selectedGroupeId = dialogGroupId;
                              });
                              Navigator.pop(context);
                              _loadEmplois();
                            }
                          },
                          icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                          label: Text(
                            'Enregistrer et publier',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildGridTimeCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildGridSlot(String jour, String slot, List<Creneau> creneaux, int semaineNum, Function(Creneau) onAdd, Function(Creneau) onRemove) {
    final times = slot.split(' - ');
    final creneau = creneaux.where((c) => c.jour == jour && c.heureDebut == times[0]).firstOrNull;
    
    return Container(
      height: 90,
      padding: const EdgeInsets.all(8),
      child: creneau != null
        ? Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      creneau.moduleName,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      creneau.formateurName,
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF0D9488).withValues(alpha: 0.9)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 10, color: Color(0xFF0D9488)),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            creneau.salle,
                            style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF0D9488).withValues(alpha: 0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => onRemove(creneau),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: AppTheme.accentRed),
                  ),
                ),
              ),
            ],
          )
        : InkWell(
            onTap: () => _pickAffectationForSlot(jour, times[0], times[1], semaineNum, onAdd),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: DashedRectPainter(color: AppTheme.border),
                child: const Center(
                  child: Icon(Icons.add, size: 20, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
    );
  }

  void _pickAffectationForSlot(String jour, String debut, String fin, int semaineNum, Function(Creneau) onAdd) async {
    if (_selectedGroupeId == null) return;
    final affectations = await DatabaseHelper.instance.getAffectationsByGroupe(_selectedGroupeId!);
    final modules = await DatabaseHelper.instance.getAllModules();
    final formateurs = await DatabaseHelper.instance.getUsersByRole(UserRole.formateur);

    if (!mounted) return;

    final affectation = await showDialog<Affectation>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choisir une affectation', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(affectations.map((aff) async {
              final isAvailable = await DatabaseHelper.instance.checkFormateurAvailability(
                aff.formateurId, 
                semaineNum, 
                jour, 
                debut
              );
              return {'aff': aff, 'available': isAvailable};
            })),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final items = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final aff = item['aff'] as Affectation;
                  final isAvailable = item['available'] as bool;
                  
                  final mod = modules.where((m) => m.id == aff.moduleId).firstOrNull;
                  final form = formateurs.where((f) => f.id == aff.formateurId).firstOrNull;
                  
                  return ListTile(
                    enabled: isAvailable,
                    title: Text(mod?.nom ?? 'N/A', style: TextStyle(color: isAvailable ? Colors.black : Colors.grey)),
                    subtitle: Text(
                      isAvailable ? (form?.nom ?? 'N/A') : '${form?.nom ?? 'N/A'} (Occupé)', 
                      style: TextStyle(color: isAvailable ? Colors.grey[700] : Colors.red)
                    ),
                    onTap: isAvailable ? () => Navigator.pop(context, aff) : null,
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    if (affectation != null) {
      final mod = modules.where((m) => m.id == affectation.moduleId).firstOrNull;
      final form = formateurs.where((f) => f.id == affectation.formateurId).firstOrNull;
      
      onAdd(Creneau(
        jour: jour,
        heureDebut: debut,
        heureFin: fin,
        moduleId: affectation.moduleId,
        moduleName: mod?.nom ?? 'N/A',
        formateurId: affectation.formateurId,
        formateurName: form?.nom ?? 'N/A',
        salle: ['Salle 1', 'Salle A1', 'Salle B2', 'Amphi A', 'Labo 1', 'Labo 2'][Random().nextInt(6)],
      ));
    }
  }

  Future<void> _confirmDelete(Emploi emploi) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Voulez-vous vraiment supprimer cet emploi du temps ?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: Text('Supprimer', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteEmploi(emploi.id!);
      _loadEmplois();
    }
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    const dashWidth = 4;
    const dashSpace = 4;
    
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      canvas.drawLine(Offset(i, 0), Offset(i + dashWidth, 0), paint);
    }
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      canvas.drawLine(Offset(i, size.height), Offset(i + dashWidth, size.height), paint);
    }
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      canvas.drawLine(Offset(0, i), Offset(0, i + dashWidth), paint);
    }
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      canvas.drawLine(Offset(size.width, i), Offset(size.width, i + dashWidth), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
