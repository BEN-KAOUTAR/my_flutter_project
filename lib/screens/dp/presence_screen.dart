import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../models/groupe.dart';
import '../../theme/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../widgets/responsive_layout.dart';
import '../common/dashboard_components.dart';

class PresenceScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const PresenceScreen({super.key, this.onBack});

  @override
  State<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends State<PresenceScreen> {
  List<Map<String, dynamic>> _allStats = [];
  List<Map<String, dynamic>> _filteredStats = [];
  List<Groupe> _groupes = [];
  int? _selectedGroupeId;
  String _searchQuery = '';
  bool _isLoading = true;
  Map<String, dynamic> _globalStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final directorId = user?.id;
    final stats = await DatabaseHelper.instance.getPresenceStatsForDP(directorId: directorId);
    final groupes = await DatabaseHelper.instance.getAllGroupes(directorId: directorId);
    final global = await DatabaseHelper.instance.getGlobalStats(directorId: directorId);

    setState(() {
      _allStats = stats;
      _filteredStats = stats;
      _groupes = groupes;
      _globalStats = global;
      _isLoading = false;
    });
  }

  void _filterStats() {
    setState(() {
      _filteredStats = _allStats.where((s) {
        final matchesSearch = s['nom'].toString().toLowerCase().startsWith(_searchQuery.toLowerCase()) ||
            s['matricule'].toString().toLowerCase().startsWith(_searchQuery.toLowerCase());
        final matchesGroupe = _selectedGroupeId == null || s['groupe_nom'] == _groupes.firstWhere((g) => g.id == _selectedGroupeId).nom;
        return matchesSearch && matchesGroupe;
      }).toList();
    });
  }
  Future<void> _exportData() async {
    final doc = pw.Document();
    final groupName = _selectedGroupeId != null 
        ? _groupes.firstWhere((g) => g.id == _selectedGroupeId).nom 
        : 'Tous les groupes';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Rapport de présence', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(groupName, style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Généré le: ${DateTime.now().toString().split('.')[0]}'),
              pw.Text('Groupe: $groupName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Stagiaire', 'Groupe', 'Présences', 'Absences', 'Taux'],
                  ..._filteredStats.map((item) {
                     final p = item['presences'] as int;
                     final a = item['absences'] as int;
                     final total = p + a;
                     final rate = total > 0 ? (p / total * 100).toStringAsFixed(1) : '0.0';
                     return [item['nom'], item['groupe_nom'] ?? '', p.toString(), a.toString(), '$rate%'];
                  }),
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                },
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'rapport_presence_${groupName.replaceAll(' ', '_')}.pdf');
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildSearchAndFilters(),
          const SizedBox(height: 24),
          _buildStatsRow(),
          const SizedBox(height: 32),
          _buildAttendanceTable(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consultez les taux de présence des stagiaires',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _exportData,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text('Exporter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textPrimary,
            side: BorderSide(color: AppTheme.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _filterStats();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un stagiaire...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedGroupeId,
                hint: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text('Tous les groupes', style: GoogleFonts.poppins(fontSize: 14)),
                  ],
                ),
                items: [
                  DropdownMenuItem<int>(
                    value: null,
                    child: Text('Tous les groupes', style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                  ..._groupes.map((g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.nom, style: GoogleFonts.poppins(fontSize: 14)),
                  )),
                ],
                onChanged: (value) {
                  setState(() => _selectedGroupeId = value);
                  _filterStats();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    int totalPresences = 0;
    int totalAbsences = 0;
    
    for (var s in _filteredStats) {
      totalPresences += (s['presences'] as int);
      totalAbsences += (s['absences'] as int);
    }
    
    double totalRate = 0;
    int ratedCount = 0;
    for (var s in _filteredStats) {
      final p = s['presences'] as int;
      final a = s['absences'] as int;
      if (p + a > 0) {
        totalRate += p / (p + a);
        ratedCount++;
      }
    }
    final avgRate = ratedCount > 0 ? (totalRate / ratedCount) : 0.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount;
        double aspectRatio;
        
        if (width > 800) {
          crossAxisCount = 4;
          aspectRatio = 2.4;
        } else if (width > 600) {
          crossAxisCount = 2;
          aspectRatio = 2.2;
        } else {
          crossAxisCount = 1;
          aspectRatio = 2.8;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: aspectRatio,
          children: [
            DashboardSummaryCard(
              label: 'Présences',
              value: totalPresences.toString(),
              icon: Icons.check_circle_outline_rounded,
              color: AppTheme.accentGreen,
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Absences',
              value: totalAbsences.toString(),
              icon: Icons.cancel_outlined,
              color: AppTheme.accentRed,
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Total Appels',
              value: (totalPresences + totalAbsences).toString(),
              icon: Icons.history_rounded,
              color: AppTheme.primaryBlue,
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Taux moyen',
              value: '${(avgRate * 100).toStringAsFixed(1)}%',
              icon: Icons.analytics_outlined,
              color: const Color(0xFF0EA5E9),
              width: double.infinity,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttendanceTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1000),
        child: Container(
          width: 1000,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              SizedBox(
                height: 500,
                child: _filteredStats.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('Aucun résultat trouvé', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: false,
                      itemCount: _filteredStats.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) => _buildTableRow(_filteredStats[index]),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Stagiaire', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Groupe', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Présences', style: _headerStyle, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Absences', style: _headerStyle, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('Taux de présence', style: _headerStyle)),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> stat) {
    final presences = stat['presences'] as int;
    final absences = stat['absences'] as int;
    final total = presences + absences;
    final rate = total > 0 ? (presences / total) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat['nom'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(stat['matricule'] ?? 'N/A', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.1)),
              ),
              child: Text(
                stat['groupe_nom'] ?? 'N/A',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(4)),
                child: Text(presences.toString(), style: GoogleFonts.poppins(color: const Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                child: Text(absences.toString(), style: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(rate * 100).toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(rate > 0.8 ? AppTheme.accentGreen : (rate > 0.5 ? AppTheme.accentOrange : AppTheme.accentRed)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      );
}

