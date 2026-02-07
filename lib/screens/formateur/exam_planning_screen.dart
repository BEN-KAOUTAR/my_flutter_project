import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../models/exam.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ExamPlanningScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ExamPlanningScreen({super.key, this.onBack});

  @override
  State<ExamPlanningScreen> createState() => _ExamPlanningScreenState();
}

class _ExamPlanningScreenState extends State<ExamPlanningScreen> {
  List<Exam> _exams = [];
  List<Map<String, dynamic>> _affectations = [];
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
      final affectations = await DatabaseHelper.instance.getAffectationsWithProgress(userId);
      final examMaps = await DatabaseHelper.instance.getUpcomingExams(userId);
      
      if (mounted) {
        setState(() {
          _affectations = affectations;
          _exams = examMaps.map((m) => Exam.fromMap(m)).toList();
          _isLoading = false;
        });
      }
    }
  }

  String _getModuleName(int affectationId) {
    final affectation = _affectations.where((a) => a['id'] == affectationId).firstOrNull;
    return affectation?['module_name'] ?? 'N/A';
  }

  String _getGroupeName(int affectationId) {
    final affectation = _affectations.where((a) => a['id'] == affectationId).firstOrNull;
    return affectation?['groupe_name'] ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: AppTheme.background,
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                width: double.infinity,
                color: AppTheme.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Programmez vos CC et EFM par module',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: _exams.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
                          itemCount: _exams.length,
                          itemBuilder: (context, index) => _buildExamCard(_exams[index]),
                        ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              heroTag: 'exam_planning_fab',
              onPressed: () => _showAddExamDialog(),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Planifier un examen', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: AppTheme.formateurColor,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Aucun examen programmé',
            style: GoogleFonts.poppins(fontSize: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Exam exam) {
    final statusColor = exam.status == ExamStatus.planifie ? AppTheme.primaryBlue : AppTheme.accentGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.assignment_rounded, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${exam.type} - ${_getModuleName(exam.affectationId)}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Groupe: ${_getGroupeName(exam.affectationId)}',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(exam.date),
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('HH:mm').format(exam.date),
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed),
              onPressed: () => _confirmDeleteExam(exam),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddExamDialog() async {
    int? selectedAffectationId;
    String? selectedType = 'CC';
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 30);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Planifier un examen', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Module / Groupe'),
                    items: _affectations.map((a) => DropdownMenuItem(
                      value: a['id'] as int,
                      child: Text(
                        '${a['module_name']} (${a['groupe_name']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (value) => setModalState(() => selectedAffectationId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type d\'examen'),
                    items: ['CC', 'EFM', 'Quiz', 'TP'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (value) => setModalState(() => selectedType = value),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setModalState(() => selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date prévue'),
                      child: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) setModalState(() => selectedTime = time);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Heure de l\'examen'),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.poppins(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (optionnel)'),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedAffectationId == null) return;
                      
                      final examDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      
                      final exam = Exam(
                        affectationId: selectedAffectationId!,
                        date: examDateTime,
                        type: selectedType!,
                        description: descriptionController.text,
                      );
                      
                      await DatabaseHelper.instance.insertExam(exam.toMap());
                      if (mounted) {
                        Navigator.pop(context);
                        _loadData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.formateurColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Planifier', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteExam(Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment annuler cet examen ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui', style: TextStyle(color: AppTheme.accentRed))),
        ],
      ),
    );

    if (confirmed == true && exam.id != null) {
      await DatabaseHelper.instance.deleteExam(exam.id!);
      _loadData();
    }
  }
}
