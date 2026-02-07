import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/database_helper.dart';
import '../../models/seance.dart';
import '../../models/note.dart';
import '../../models/user.dart';
import '../../models/groupe.dart';
import '../../models/affectation.dart';
import '../../services/notification_service.dart';

import '../../theme/app_theme.dart';
import '../../providers/notification_provider.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';


class ValidationScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ValidationScreen({super.key, this.onBack});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Seance> _seancesEnAttente = [];
  List<Note> _notesEnAttente = [];
  List<Note> _notesAPublier = [];
  List<Map<String, dynamic>> _presencesEnAttente = [];
  List<Map<String, dynamic>> _examsAPublier = [];
  Map<int, String> _moduleNames = {};
  Map<int, String> _stagiaireNames = {};
  Map<int, User> _stagiairesMap = {};
  List<Affectation> _affectations = [];
  Map<int, String> _formateurNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final directorId = user?.id;

      final seances = await DatabaseHelper.instance.getSeancesEnAttente(directorId: directorId);
      final notesAttente = await DatabaseHelper.instance.getNotesEnAttente(directorId: directorId);
      final notesPublier = await DatabaseHelper.instance.getNotesAPublier(directorId: directorId);
      final presencesAttente = await DatabaseHelper.instance.getPresencesEnAttente(directorId: directorId);
      final examsAPublier = await DatabaseHelper.instance.getExamsAPublier(directorId: directorId);
      
      final modules = await DatabaseHelper.instance.getAllModules(directorId: directorId);
      final stagiaires = await DatabaseHelper.instance.getUsersByRole(UserRole.stagiaire, directorId: directorId);
      final formateurs = await DatabaseHelper.instance.getUsersByRole(UserRole.formateur, directorId: directorId);
      final affectations = await DatabaseHelper.instance.getAllAffectations(directorId: directorId);
      
      Map<int, String> modNames = {for (var m in modules) m.id!: m.nom};
      Map<int, String> stagNames = {for (var s in stagiaires) s.id!: s.nom};
      Map<int, User> stagMap = {for (var s in stagiaires) s.id!: s};
      Map<int, String> formNames = {for (var f in formateurs) f.id!: f.nom};

      if (mounted) {
        setState(() {
          _seancesEnAttente = seances;
          _notesEnAttente = notesAttente;
          _notesAPublier = notesPublier;
          _presencesEnAttente = presencesAttente;
          _examsAPublier = examsAPublier;
          _moduleNames = modNames;
          _stagiaireNames = stagNames;
          _stagiairesMap = stagMap;
          _affectations = affectations;
          _formateurNames = formNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading validation data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  String _getFormateurNameForSeance(Seance seance) {
    final aff = _affectations.where((a) => a.id == seance.affectationId).firstOrNull;
    if (aff != null) {
      return _formateurNames[aff.formateurId] ?? 'Inconnu';
    }
    return 'Inconnu';
  }

  String _getFormateurNameForNote(Note note) {
    final stagiaire = _stagiairesMap[note.stagiaireId];
    if (stagiaire != null && stagiaire.groupeId != null) {
      final aff = _affectations.where((a) => 
        a.groupeId == stagiaire.groupeId && a.moduleId == note.moduleId
      ).firstOrNull;
      if (aff != null) {
        return _formateurNames[aff.formateurId] ?? 'Inconnu';
      }
    }
    return 'Inconnu';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        _buildStatsRow(),
        const SizedBox(height: 24),
        _buildTabBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotesAttenteTab(),
                    _buildNotesAPublierTab(),
                    _buildExamsAPublierList(),
                    _buildSeancesTab(),
                    _buildPresencesTab(),
                  ],
                ),
        ),
      ],
    );
  }


  Widget _buildExamsAPublierList() {
    if (_examsAPublier.isEmpty) {
      return _buildEmptyState('Aucun examen à publier', 'Les examens validés apparaîtront ici', Icons.assignment_turned_in_outlined);
    }

    final isMobile = MediaQuery.of(context).size.width < 950;

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 280,
      ),
      itemCount: _examsAPublier.length,
      itemBuilder: (context, index) {
        final exam = _examsAPublier[index];
        return _buildExamAPublierCard(exam);
      },
    );
  }

  Widget _buildExamAPublierCard(Map<String, dynamic> exam) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.formateurColor.withValues(alpha: 0.03),
                border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.formateurColor.withValues(alpha: 0.1),
                    radius: 20,
                    child: const Icon(Icons.assignment_turned_in_outlined, color: AppTheme.formateurColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam['module_name'] ?? 'Module',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          exam['type'] ?? 'EXAM',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.parse(exam['date'])),
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text('Groupe: ${exam['groupe_name']}', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text('Formateur: ${exam['formateur_name']}', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                  if (exam['description'] != null && exam['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        exam['description'],
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _handleRejeterExam(exam['id']),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accentRed,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Rejeter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handlePublierExam(exam['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Publier', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePublierExam(int id) async {
    try {
      await DatabaseHelper.instance.updateExamStatus(id, 'PUBLIE');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Examen publié avec succès'), backgroundColor: AppTheme.accentGreen),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
      );
    }
  }

  Future<void> _handleRejeterExam(int id) async {
    try {
      await DatabaseHelper.instance.updateExamStatus(id, 'REJETE');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Examen rejeté'), backgroundColor: AppTheme.accentRed),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
      );
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validez les séances et notes des formateurs',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1100) {
            return SizedBox(
              height: constraints.maxWidth < 600 ? 500 : 440,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth < 600 ? 1.6 : 2.5,
                children: [
                _buildStatCard(
                  'Notes à valider',
                  '${_notesEnAttente.length}',
                  Icons.schedule_rounded,
                  AppTheme.accentOrange,
                ),
                _buildStatCard(
                  'Notes à publier',
                  '${_notesAPublier.length}',
                  Icons.check_circle_outline_rounded,
                  AppTheme.primaryBlue,
                ),
                _buildStatCard(
                  'Séances à valider',
                  '${_seancesEnAttente.length}',
                  Icons.psychology_alt_rounded,
                  AppTheme.formateurColor,
                ),
                _buildStatCard(
                  'Présents',
                  '${_presencesEnAttente.length}',
                  Icons.how_to_reg_rounded,
                  AppTheme.accentGreen,
                ),
                _buildStatCard(
                  'Examens',
                  '${_examsAPublier.length}',
                  Icons.assignment_turned_in_outlined,
                  AppTheme.formateurColor,
                ),
              ],
            ),
            );
          }
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Notes à valider',
                  '${_notesEnAttente.length}',
                  Icons.schedule_rounded,
                  AppTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Notes à publier',
                  '${_notesAPublier.length}',
                  Icons.check_circle_outline_rounded,
                  AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Séances à valider',
                  '${_seancesEnAttente.length}',
                  Icons.psychology_alt_rounded,
                  AppTheme.formateurColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Présents',
                  '${_presencesEnAttente.length}',
                  Icons.how_to_reg_rounded,
                  AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Examens',
                  '${_examsAPublier.length}',
                  Icons.assignment_turned_in_outlined,
                  AppTheme.formateurColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                icon,
                size: 100,
                color: color.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color,
                          color.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppTheme.textPrimary,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'Notes à valider (${_notesEnAttente.length})'),
          Tab(text: 'Notes à publier (${_notesAPublier.length})'),
          Tab(text: 'Examens (${_examsAPublier.length})'),
          Tab(text: 'Séances (${_seancesEnAttente.length})'),
          Tab(text: 'Présences (${_presencesEnAttente.length})'),
        ],
      ),
    );
  }

  Widget _buildNotesAttenteTab() {
    if (_notesEnAttente.isEmpty) {
      return _buildEmptyState('Tout est validé', 'Aucune note en attente de validation', Icons.check_circle_outline_rounded);
    }
    
    final isMobile = MediaQuery.of(context).size.width < 950;

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 220,
      ),
      itemCount: _notesEnAttente.length,
      itemBuilder: (context, index) => _buildNoteCard(_notesEnAttente[index], isAttente: true),
    );
  }

  Widget _buildNotesAPublierTab() {
    if (_notesAPublier.isEmpty) {
      return _buildEmptyState('Aucune note à publier', 'Les notes validées apparaîtront ici', Icons.bookmark_added_outlined);
    }

    final isMobile = MediaQuery.of(context).size.width < 950;

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 220,
      ),
      itemCount: _notesAPublier.length,
      itemBuilder: (context, index) => _buildNoteCard(_notesAPublier[index], isAttente: false),
    );
  }

  Widget _buildSeancesTab() {
    if (_seancesEnAttente.isEmpty) {
      return _buildEmptyState('Tout est validé', 'Aucune séance en attente de validation', Icons.task_alt_rounded);
    }

    final isMobile = MediaQuery.of(context).size.width < 950;

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 260,
      ),
      itemCount: _seancesEnAttente.length,
      itemBuilder: (context, index) => _buildSeanceCard(_seancesEnAttente[index]),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.2)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note, {required bool isAttente}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.03),
                border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    radius: 20,
                    child: const Icon(Icons.grade_rounded, color: AppTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stagiaireNames[note.stagiaireId] ?? 'Stagiaire',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          _moduleNames[note.moduleId] ?? 'Module',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${note.valeur.toStringAsFixed(1)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.category_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(note.type.displayName, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                      const Spacer(),
                      Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        _getFormateurNameForNote(note),
                        style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (isAttente) ...[
                        Expanded(
                          child: TextButton(
                            onPressed: () => _handleRejeterNote(note),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accentRed,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Rejeter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleValiderNote(note),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Valider', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handlePublierNote(note),
                            icon: const Icon(Icons.publish_rounded, size: 18),
                            label: Text('Publier la note', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeanceCard(Seance seance) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.03),
                border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.1),
                    radius: 20,
                    child: const Icon(Icons.event_note_rounded, color: AppTheme.accentOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(seance.date),
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Par ${_getFormateurNameForSeance(seance)}',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${seance.duree.toInt()}h',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentOrange),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contenu de la séance:',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  seance.contenu,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary, height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _handleRejeterSeance(seance),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accentRed,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Rejeter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleValiderSeance(seance),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Valider', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresencesTab() {
    if (_presencesEnAttente.isEmpty) {
      return _buildEmptyState('Aucune présence à valider', 'Toutes les fiches de présence sont à jour', Icons.how_to_reg_rounded);
    }

    final isMobile = MediaQuery.of(context).size.width < 950;

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 220,
      ),
      itemCount: _presencesEnAttente.length,
      itemBuilder: (context, index) => _buildPresenceCard(_presencesEnAttente[index]),
    );
  }

  Widget _buildPresenceCard(Map<String, dynamic> sheet) {
    final dateStr = sheet['date'] as String;
    final groupeId = sheet['groupe_id'] as int;
    final groupeNom = sheet['groupe_nom'] as String;
    final count = sheet['student_count'] as int;
    final heure = sheet['heure'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.03),
              border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.1),
                  radius: 20,
                  child: const Icon(Icons.calendar_today_rounded, color: AppTheme.accentGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupeNom,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Date: $dateStr${heure != null ? " • $heure" : ""}',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accentGreen),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPresenceDetails(dateStr, groupeId, groupeNom, heure: heure),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text('Détails', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleValiderPresence(dateStr, groupeId, heure: heure),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Valider', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPresenceDetails(String date, int groupeId, String groupeNom, {String? heure}) async {
    final details = await DatabaseHelper.instance.getPresenceDetails(date, groupeId, heure: heure);
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails Présence - $groupeNom${heure != null ? " ($heure)" : ""}', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: details.length,
            itemBuilder: (context, index) {
              final d = details[index];
              final status = d['statut'] as String;
              Color color;
              switch (status) {
                case 'PRESENT': color = AppTheme.accentGreen; break;
                case 'ABSENT': color = AppTheme.accentRed; break;
                default: color = AppTheme.accentOrange;
              }

              return ListTile(
                dense: true,
                title: Text(d['stagiaire_nom'], style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleValiderPresence(String date, int groupeId, {String? heure}) async {
    await DatabaseHelper.instance.validerPresenceDP(groupeId, date, heure: heure);
    
    if (mounted) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fiche de présence validée avec succès'), backgroundColor: AppTheme.accentGreen),
      );
    }
    _loadData();
  }

  Future<void> _handleValiderNote(Note note) async {
    await DatabaseHelper.instance.validerNote(note.id!);
    if (mounted) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
    }
    _loadData();
  }

  Future<void> _handleRejeterNote(Note note) async {
    await DatabaseHelper.instance.rejeterNote(note.id!);
    
    final stagiaire = _stagiairesMap[note.stagiaireId];
    if (stagiaire != null && stagiaire.groupeId != null) {
      final aff = _affectations.where((a) => 
        a.groupeId == stagiaire.groupeId && a.moduleId == note.moduleId
      ).firstOrNull;
      
      if (aff != null) {
        await NotificationService().notifyUser(
          userId: aff.formateurId,
          title: 'Note rejetée',
          message: 'La note de ${_stagiaireNames[note.stagiaireId]} pour le module ${_moduleNames[note.moduleId]} a été rejetée.',
          type: 'WARNING'
        );
      }
    }
    
    _loadData();
    if (mounted) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note rejetée'), backgroundColor: AppTheme.accentRed),
      );
    }
  }

  Future<void> _handlePublierNote(Note note) async {
    await DatabaseHelper.instance.publierNote(note.id!);
    
    await NotificationService().notifyUser(
      userId: note.stagiaireId,
      title: 'Nouvelle note publiée',
      message: 'Une note a été publiée pour le module ${_moduleNames[note.moduleId]}',
      type: 'INFO'
    );
    
    _loadData();
  }

  Future<void> _handleValiderSeance(Seance seance) async {
    await DatabaseHelper.instance.validerSeance(seance.id!);
    if (mounted) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
    }
    _loadData();
  }

  Future<void> _handleRejeterSeance(Seance seance) async {
    await DatabaseHelper.instance.rejeterSeance(seance.id!);
    
    final aff = _affectations.where((a) => a.id == seance.affectationId).firstOrNull;
    if (aff != null) {
      await NotificationService().notifyUser(
        userId: aff.formateurId,
        title: 'Séance rejetée',
        message: 'Votre séance du ${seance.date.day}/${seance.date.month}/${seance.date.year} a été rejetée.',
        type: 'WARNING'
      );
    }
    
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Séance rejetée'), backgroundColor: AppTheme.accentRed),
      );
    }
  }
}

