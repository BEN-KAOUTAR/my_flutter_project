import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/database_helper.dart';
import '../../models/affectation.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../models/affectation.dart';
import '../../models/user.dart';
import '../../models/module.dart';
import '../../models/groupe.dart';
import '../../theme/app_theme.dart';

class AffectationsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AffectationsScreen({super.key, this.onBack});

  @override
  State<AffectationsScreen> createState() => _AffectationsScreenState();
}

class _AffectationsScreenState extends State<AffectationsScreen> {
  List<Affectation> _affectations = [];
  List<User> _formateurs = [];
  List<Module> _modules = [];
  List<Groupe> _groupes = [];
  Map<int, double> _progressionMap = {};
  bool _isLoading = true;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedGroupeId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final directorId = user?.id;

    final affectations = await DatabaseHelper.instance.getAllAffectations(directorId: directorId);
    final formateurs = await DatabaseHelper.instance.getUsersByRole(UserRole.formateur, directorId: directorId);
    final modules = await DatabaseHelper.instance.getAllModules(directorId: directorId);
    final groupes = await DatabaseHelper.instance.getAllGroupes(directorId: directorId);
    
    Map<int, double> progressions = {};
    for (var aff in affectations) {
      final validatedHours = await DatabaseHelper.instance.getValidatedHoursByAffectation(aff.id!);
      final module = modules.where((m) => m.id == aff.moduleId).firstOrNull;
      if (module != null && module.masseHoraireTotale > 0) {
        progressions[aff.id!] = validatedHours / module.masseHoraireTotale;
      } else {
        progressions[aff.id!] = 0;
      }
    }

    setState(() {
      _affectations = affectations;
      _formateurs = formateurs;
      _modules = modules;
      _groupes = groupes;
      _progressionMap = progressions;
      _isLoading = false;
    });
  }

  List<Affectation> get _filteredAffectations {
    return _affectations.where((aff) {
      final matchesGroupe = _selectedGroupeId == null || aff.groupeId == _selectedGroupeId;
      
      final formateur = _getFormateur(aff.formateurId);
      final module = _getModule(aff.moduleId);
      final groupe = _getGroupe(aff.groupeId);
      
      final matchesSearch = _searchQuery.isEmpty || 
          (formateur?.nom.toLowerCase().startsWith(_searchQuery.toLowerCase()) ?? false) ||
          (module?.nom.toLowerCase().startsWith(_searchQuery.toLowerCase()) ?? false) ||
          (groupe?.nom.toLowerCase().startsWith(_searchQuery.toLowerCase()) ?? false);
          
      return matchesGroupe && matchesSearch;
    }).toList();
  }

  User? _getFormateur(int id) => _formateurs.where((f) => f.id == id).firstOrNull;
  Module? _getModule(int id) => _modules.where((m) => m.id == id).firstOrNull;
  Groupe? _getGroupe(int id) => _groupes.where((g) => g.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: _filteredAffectations.isEmpty
                  ? _buildEmptyState()
                  : _buildAffectationsTable(),
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
                      'Attribuez les modules aux formateurs',
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
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add_task_rounded, size: 20, color: Colors.white),
                label: Text(
                  isMobile ? 'Ajouter' : 'Nouvelle affectation',
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
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par formateur ou module...',
                      hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedGroupeId,
                    hint: Text('Tous les groupes', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                    icon: const Icon(Icons.filter_list_rounded, color: AppTheme.textSecondary, size: 20),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Tous les groupes', style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                      ..._groupes.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.nom, style: GoogleFonts.poppins(fontSize: 14)),
                      )),
                    ],
                    onChanged: (value) => setState(() => _selectedGroupeId = value),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAffectationsTable() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 180,
      ),
      itemCount: _filteredAffectations.length,
      itemBuilder: (context, index) {
        final affectation = _filteredAffectations[index];
        final module = _getModule(affectation.moduleId);
        final formateur = _getFormateur(affectation.formateurId);
        final groupe = _getGroupe(affectation.groupeId);
        final progression = _progressionMap[affectation.id!] ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
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
                          module?.nom ?? 'N/A',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          affectation.anneeScolaire,
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryBlue),
                        onPressed: () => _showAddEditDialog(affectation: affectation),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.accentRed),
                        onPressed: () => _confirmDelete(affectation),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              _buildInfoRow(Icons.person_outline, formateur?.nom ?? 'N/A'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.groups_outlined, groupe?.nom ?? 'N/A'),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progression,
                        backgroundColor: AppTheme.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(progression * 100).toInt()}%',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          Icon(Icons.assignment_outlined, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Aucune affectation',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({Affectation? affectation}) async {
    final isEdit = affectation != null;
    int? selectedFormateurId = affectation?.formateurId;
    int? selectedModuleId = affectation?.moduleId;
    int? selectedGroupeId = affectation?.groupeId;
    String anneeScolaire = affectation?.anneeScolaire ?? '${DateTime.now().year}-${DateTime.now().year + 1}';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Modifier l\'affectation' : 'Nouvelle affectation',
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      'Attribuez un module à un formateur pour un groupe spécifique',
                      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    
                    Text('Formateur *', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedFormateurId,
                      decoration: InputDecoration(
                        hintText: 'Sélectionner un formateur',
                        hintStyle: GoogleFonts.poppins(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      items: _formateurs.map((f) => DropdownMenuItem(
                        value: f.id,
                        child: Text('${f.nom} (${f.totalHeuresAffectees.toInt()}h / 910h)', style: GoogleFonts.poppins(fontSize: 14)),
                      )).toList(),
                      onChanged: (value) => setModalState(() => selectedFormateurId = value),
                    ),
                    
                    const SizedBox(height: 24),
                    Text('Module *', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedModuleId,
                      decoration: InputDecoration(
                        hintText: 'Sélectionner un module',
                        hintStyle: GoogleFonts.poppins(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      items: _modules.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text('${m.nom} (${m.masseHoraireTotale.toInt()}h)', style: GoogleFonts.poppins(fontSize: 14)),
                      )).toList(),
                      onChanged: (value) => setModalState(() => selectedModuleId = value),
                    ),
                    
                    const SizedBox(height: 24),
                    Text('Groupe *', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedGroupeId,
                      decoration: InputDecoration(
                        hintText: 'Sélectionner un groupe',
                        hintStyle: GoogleFonts.poppins(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      items: _groupes.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.nom, style: GoogleFonts.poppins(fontSize: 14)),
                      )).toList(),
                      onChanged: (value) => setModalState(() => selectedGroupeId = value),
                    ),
                    
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Heures prévues', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 8),
                               TextFormField(
                                  initialValue: '0',
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Année scolaire', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 8),
                               FormField(
                                  builder: (state) {
                                    return TextFormField(
                                      initialValue: anneeScolaire,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: 'Ex: 2023-2024',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      ),
                                      onChanged: (val) => anneeScolaire = val,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 48),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppTheme.border)),
                          ),
                          child: Text(
                            'Annuler',
                            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (selectedFormateurId == null || selectedModuleId == null || selectedGroupeId == null) return;
                            
                            final newAff = Affectation(
                              id: affectation?.id,
                              formateurId: selectedFormateurId!,
                              moduleId: selectedModuleId!,
                              groupeId: selectedGroupeId!,
                              anneeScolaire: anneeScolaire,
                            );
                            
                            try {
                              if (isEdit) {
                                await DatabaseHelper.instance.updateAffectation(newAff);
                              } else {
                                await DatabaseHelper.instance.insertAffectation(newAff);
                              }
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                _loadData();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')),
                                    backgroundColor: AppTheme.accentRed,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            isEdit ? 'Modifier' : 'Créer',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
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

  Future<void> _confirmDelete(Affectation affectation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Voulez-vous vraiment supprimer cette affectation ?', style: GoogleFonts.poppins()),
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
      await DatabaseHelper.instance.deleteAffectation(affectation.id!);
      _loadData();
    }
  }
}
