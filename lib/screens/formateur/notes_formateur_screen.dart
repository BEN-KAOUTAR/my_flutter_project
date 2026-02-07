import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../models/note.dart';
import '../../models/user.dart';
import '../../models/affectation.dart';
import '../../models/groupe.dart';
import '../../models/module.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class NotesFormateurScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const NotesFormateurScreen({super.key, this.onBack});

  @override
  State<NotesFormateurScreen> createState() => _NotesFormateurScreenState();
}

class _NotesFormateurScreenState extends State<NotesFormateurScreen> {
  List<Affectation> _affectations = [];
  List<Module> _modules = [];
  List<Groupe> _groupes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.id;

    if (userId != null) {
      final directorId = authService.currentUser?.directorId;
      final affectations = await DatabaseHelper.instance.getAffectationsByFormateur(userId);
      final modules = await DatabaseHelper.instance.getAllModules(directorId: directorId);
      final groupes = await DatabaseHelper.instance.getAllGroupes(directorId: directorId);

      if (mounted) {
        setState(() {
          _affectations = affectations;
          _modules = modules;
          _groupes = groupes;
          _isLoading = false;
        });
      }
    }
  }

  String _getModuleName(int id) {
    return _modules.where((m) => m.id == id).firstOrNull?.nom ?? 'N/A';
  }

  String _getGroupeName(int id) {
    return _groupes.where((g) => g.id == id).firstOrNull?.nom ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          color: AppTheme.background,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saisissez et validez les notes par module',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
              Expanded(
          child: _affectations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  itemCount: _affectations.length,
                  itemBuilder: (context, index) => _buildAffectationCard(_affectations[index]),
                ),
        ),
      ],
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.formateurColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.grade_outlined, size: 64, color: AppTheme.formateurColor.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun module affecté',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contactez l\'administration pour vos affectations',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAffectationCard(Affectation affectation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.formateurColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.grade_rounded, color: AppTheme.formateurColor, size: 24),
          ),
          title: Text(
            _getModuleName(affectation.moduleId),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.stagiaireColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getGroupeName(affectation.groupeId),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.stagiaireColor,
                  ),
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
          ),
          onTap: () => _showNotesForAffectation(affectation),
        ),
      ),
    );
  }

  void _showNotesForAffectation(Affectation affectation) async {
    final stagiaires = await DatabaseHelper.instance.getStagiairesByGroupe(affectation.groupeId);
    
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NotesDetailScreen(
          affectation: affectation,
          stagiaires: stagiaires,
          moduleName: _getModuleName(affectation.moduleId),
          groupeName: _getGroupeName(affectation.groupeId),
        ),
      ),
    );
  }
}

class _NotesDetailScreen extends StatefulWidget {
  final Affectation affectation;
  final List<User> stagiaires;
  final String moduleName;
  final String groupeName;

  const _NotesDetailScreen({
    required this.affectation,
    required this.stagiaires,
    required this.moduleName,
    required this.groupeName,
  });

  @override
  State<_NotesDetailScreen> createState() => _NotesDetailScreenState();
}

class _NotesDetailScreenState extends State<_NotesDetailScreen> {
  Map<int, List<Note>> _notesByStagiaire = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    
    Map<int, List<Note>> notes = {};
    for (var stagiaire in widget.stagiaires) {
      final stagiaireNotes = await DatabaseHelper.instance.getNotesByStagiaire(stagiaire.id!);
      notes[stagiaire.id!] = stagiaireNotes.where((n) => n.moduleId == widget.affectation.moduleId).toList();
    }

    setState(() {
      _notesByStagiaire = notes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Center(
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.moduleName,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Groupe: ${widget.groupeName}',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: widget.stagiaires.length,
                    itemBuilder: (context, index) => _buildStagiaireCard(widget.stagiaires[index]),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNoteDialog(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Ajouter une note', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.formateurColor,
      ),
    );
  }

  Widget _buildStatsHeader() {
    int totalNotes = 0;
    double sum = 0;
    for (var list in _notesByStagiaire.values) {
      totalNotes += list.length;
      for (var n in list) {
        sum += n.valeur;
      }
    }
    double avg = totalNotes > 0 ? sum / totalNotes : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          _buildStatItem(
            label: 'Moyenne Groupe',
            value: totalNotes > 0 ? avg.toStringAsFixed(2) : '--',
            icon: Icons.analytics_rounded,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 16),
          _buildStatItem(
            label: 'Notes Saisies',
            value: totalNotes.toString(),
            icon: Icons.assignment_turned_in_rounded,
            color: AppTheme.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
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

  Widget _buildStagiaireCard(User stagiaire) {
    final notes = _notesByStagiaire[stagiaire.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.stagiaireColor.withValues(alpha: 0.1),
            child: Text(
              stagiaire.nom[0],
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.stagiaireColor,
              ),
            ),
          ),
          title: Text(
            stagiaire.nom,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            '${notes.length} note(s) enregistrée(s)',
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
          ),
          children: [
            const Divider(height: 1),
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Aucune note pour ce module',
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: notes.map((note) => _buildNoteItem(note)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    final statusColor = note.validee ? AppTheme.accentGreen : AppTheme.accentOrange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _getNoteColor(note.valeur).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              note.valeur.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _getNoteColor(note.valeur),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.type.displayName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('dd MMMM yyyy').format(note.dateExamen),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              note.validee ? 'VALIDÉE' : 'ATTENTE',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          if (!note.validee) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.formateurColor),
              onPressed: () => _showEditNoteDialog(note),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.accentRed),
              onPressed: () => _confirmDeleteNote(note),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette note ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );

    if (confirmed == true && note.id != null) {
      await DatabaseHelper.instance.deleteNote(note.id!);
      _loadNotes();
    }
  }

  Future<void> _showEditNoteDialog(Note note) async {
    final noteController = TextEditingController(text: note.valeur.toString());
    NoteType selectedType = note.type;
    DateTime selectedDate = note.dateExamen;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Modifier la note', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                DropdownButtonFormField<NoteType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Évaluation', prefixIcon: Icon(Icons.category_outlined)),
                  items: NoteType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
                  onChanged: (value) => setModalState(() => selectedType = value ?? note.type),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Note (/20)', prefixIcon: Icon(Icons.edit_note_rounded)),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setModalState(() => selectedDate = date);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today_rounded)),
                    child: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    final value = double.tryParse(noteController.text);
                    if (value == null || value < 0 || value > 20) return;
                    
                    final updatedNote = note.copyWith(
                      valeur: value,
                      type: selectedType,
                      dateExamen: selectedDate,
                    );
                    
                    await DatabaseHelper.instance.updateNote(updatedNote);
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadNotes();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.formateurColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getNoteColor(double note) {
    if (note >= 14) return AppTheme.accentGreen;
    if (note >= 10) return AppTheme.primaryBlue;
    if (note >= 8) return AppTheme.accentOrange;
    return AppTheme.accentRed;
  }

  Future<void> _showAddNoteDialog() async {
    int? selectedStagiaireId;
    NoteType selectedType = NoteType.cc;
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ajouter une note',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Stagiaire',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: widget.stagiaires.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.nom),
                  )).toList(),
                  onChanged: (value) => setModalState(() => selectedStagiaireId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<NoteType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Évaluation',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: NoteType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.displayName),
                  )).toList(),
                  onChanged: (value) => setModalState(() => selectedType = value ?? NoteType.cc),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Note (/20)',
                    hintText: 'Ex: 15.5',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setModalState(() => selectedDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date de l\'évaluation',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    child: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    final noteValue = double.tryParse(noteController.text);
                    if (selectedStagiaireId == null || noteValue == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Veuillez remplir tous les champs', style: GoogleFonts.poppins()),
                          backgroundColor: AppTheme.accentRed,
                        ),
                      );
                      return;
                    }

                    if (noteValue < 0 || noteValue > 20) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('La note doit être entre 0 et 20', style: GoogleFonts.poppins()),
                          backgroundColor: AppTheme.accentRed,
                        ),
                      );
                      return;
                    }

                    final note = Note(
                      stagiaireId: selectedStagiaireId!,
                      moduleId: widget.affectation.moduleId,
                      type: selectedType,
                      valeur: noteValue,
                      dateExamen: selectedDate,
                    );

                    await DatabaseHelper.instance.insertNote(note);

                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadNotes();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.formateurColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Enregistrer la note', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

