import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../models/module.dart';
import '../../models/filiere.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../common/dashboard_components.dart';

class ModulesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ModulesScreen({super.key, this.onBack});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  List<Module> _modules = [];
  List<Filiere> _filieres = [];
  bool _isLoading = true;
  int? _selectedFiliereId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isLoading) {
        _loadData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final directorId = user?.id;

    final modules = await DatabaseHelper.instance.getAllModules(directorId: directorId);
    final filieres = await DatabaseHelper.instance.getAllFilieres(directorId: directorId);
    setState(() {
      _modules = modules;
      _filieres = filieres;
      _isLoading = false;
    });
  }

  List<Module> get _filteredModules {
    return _modules.where((m) {
      final matchesFiliere = _selectedFiliereId == null || m.filiereId == _selectedFiliereId;
      final matchesSearch = _searchQuery.isEmpty || 
          m.nom.toLowerCase().startsWith(_searchQuery.toLowerCase());
      return matchesFiliere && matchesSearch;
    }).toList();
  }

  String _getFiliereName(int filiereId) {
    final filiere = _filieres.where((f) => f.id == filiereId).firstOrNull;
    return filiere?.nom ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredModules.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _filteredModules.length,
                        itemBuilder: (context, index) => _buildModuleCard(_filteredModules[index]),
                      ),
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
                      'Gérez les unités de formation',
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
                icon: const Icon(Icons.add, size: 20, color: Colors.white),
                label: Text(
                  isMobile ? 'Nouveau' : 'Nouveau module',
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
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Rechercher un module...',
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
                    value: _selectedFiliereId,
                    hint: Text('Toutes les filières', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                    icon: const Icon(Icons.filter_list_rounded, color: AppTheme.textSecondary, size: 20),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Toutes les filières', style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                      ..._filieres.map((f) => DropdownMenuItem(
                        value: f.id,
                        child: Text(f.nom, style: GoogleFonts.poppins(fontSize: 14)),
                      )),
                    ],
                    onChanged: (value) => setState(() => _selectedFiliereId = value),
                  ),
                ),
              ),
            ],
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
          Icon(Icons.book_outlined, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Aucun module',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(Module module) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.book_rounded, color: AppTheme.accentOrange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            module.nom,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getFiliereName(module.filiereId),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Année ${module.annee} • Semestre ${module.semestre}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildInfoChip(Icons.access_time_rounded, '${module.masseHoraireTotale.toInt()}h', 'Volume h.'),
              const SizedBox(width: 24),
              _buildInfoChip(Icons.star_outline_rounded, 'Coeff ${module.coefficient}', 'Coefficient'),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showAddEditDialog(module: module),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('Modifier', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _confirmDelete(module),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                height: 1.2,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppTheme.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }


  void _showFilterSheet() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = button.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu<int?>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + button.size.width - 250,
        position.dy + button.size.height + 8,
        position.dx + button.size.width,
        position.dy + button.size.height,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 250, maxHeight: 400),
      items: [
        PopupMenuItem<int?>(
          value: null,
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              'Toutes les filières',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
          ),
        ),
        ..._filieres.map((filiere) => PopupMenuItem<int?>(
          value: filiere.id,
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5)),
            ),
            child: Text(
              filiere.nom,
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
        )),
      ],
    ).then((value) {
      if (value != null || value == null) {
        setState(() => _selectedFiliereId = value);
      }
    });
  }

  Future<void> _showAddEditDialog({Module? module}) async {
    final nomController = TextEditingController(text: module?.nom ?? '');
    final heuresController = TextEditingController(
      text: module?.masseHoraireTotale.toInt().toString() ?? '',
    );
    final coeffController = TextEditingController(
      text: module?.coefficient.toString() ?? '1',
    );
    int? selectedFiliereId = module?.filiereId ?? _filieres.firstOrNull?.id;
    int selectedAnnee = module?.annee ?? 1;
    int selectedSemestre = module?.semestre ?? 1;
    String? currentPhotoUrl = module?.photoUrl;
    final isEdit = module != null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
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
                        isEdit ? 'Modifier le module' : 'Nouveau module',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nom du module *',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nomController,
                    decoration: InputDecoration(
                      hintText: 'Ex: Programmation Web',
                      hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filière *',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: selectedFiliereId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                              items: _filieres.map((f) => DropdownMenuItem(
                                value: f.id,
                                child: Text(f.nom, style: GoogleFonts.poppins(fontSize: 14)),
                              )).toList(),
                              onChanged: (value) => selectedFiliereId = value,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Année *',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: selectedAnnee,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                              items: [
                                DropdownMenuItem(value: 1, child: Text('1ère année', style: GoogleFonts.poppins(fontSize: 14))),
                                DropdownMenuItem(value: 2, child: Text('2ème année', style: GoogleFonts.poppins(fontSize: 14))),
                                DropdownMenuItem(value: 3, child: Text('3ème année', style: GoogleFonts.poppins(fontSize: 14))),
                              ],
                              onChanged: (value) => selectedAnnee = value ?? 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Semestre *',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: selectedSemestre,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                              items: [1, 2, 3].map((s) => DropdownMenuItem(
                                value: s,
                                child: Text('Semestre $s', style: GoogleFonts.poppins(fontSize: 14)),
                              )).toList(),
                              onChanged: (value) => selectedSemestre = value ?? 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masse horaire *',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: heuresController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                hintText: 'Ex: 60',
                                suffixText: 'h',
                                hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coefficient *',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: coeffController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: 'Entre 1 et 5',
                          hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (nomController.text.trim().isEmpty || 
                              heuresController.text.trim().isEmpty ||
                              coeffController.text.trim().isEmpty ||
                              selectedFiliereId == null) {
                            return;
                          }

                          final heures = int.tryParse(heuresController.text) ?? 0;
                          if (heures == 0) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('La masse horaire doit être supérieure à 0', style: GoogleFonts.poppins()),
                                  backgroundColor: AppTheme.accentRed,
                                ),
                              );
                            }
                            return;
                          }

                          final coeff = int.tryParse(coeffController.text) ?? 1;
                          if (coeff < 1 || coeff > 5) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Le coefficient doit être compris entre 1 et 5', style: GoogleFonts.poppins()),
                                  backgroundColor: AppTheme.accentRed,
                                ),
                              );
                            }
                            return;
                          }
                          
                          final newModule = Module(
                            id: module?.id,
                            nom: nomController.text.trim(),
                            masseHoraireTotale: double.tryParse(heuresController.text) ?? 0,
                            filiereId: selectedFiliereId!,
                            coefficient: coeff,
                            annee: selectedAnnee,
                            semestre: selectedSemestre,
                            photoUrl: currentPhotoUrl,
                          );
                          
                          try {
                            if (isEdit) {
                              await DatabaseHelper.instance.updateModule(newModule);
                            } else {
                              await DatabaseHelper.instance.insertModule(newModule);
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
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Module module) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Voulez-vous vraiment supprimer ce module ?', style: GoogleFonts.poppins()),
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
      await DatabaseHelper.instance.deleteModule(module.id!);
      _loadData();
    }
  }
}

