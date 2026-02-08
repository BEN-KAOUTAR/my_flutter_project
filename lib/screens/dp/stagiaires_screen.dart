import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../models/user.dart';
import '../../models/groupe.dart';
import '../../theme/app_theme.dart';

class StagiairesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const StagiairesScreen({super.key, this.onBack});

  @override
  State<StagiairesScreen> createState() => _StagiairesScreenState();
}

class _StagiairesScreenState extends State<StagiairesScreen> {
  List<User> _stagiaires = [];
  List<Groupe> _groupes = [];
  bool _isLoading = true;
  int? _selectedGroupeId;
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

    final stagiaires = await DatabaseHelper.instance.getUsersByRole(UserRole.stagiaire, directorId: directorId);
    final groupes = await DatabaseHelper.instance.getAllGroupes(directorId: directorId);
    setState(() {
      _stagiaires = stagiaires;
      _groupes = groupes;
      _isLoading = false;
    });
  }

  List<User> get _filteredStagiaires {
    return _stagiaires.where((s) {
      final matchesGroup = _selectedGroupeId == null || s.groupeId == _selectedGroupeId;
      final matchesSearch = _searchQuery.isEmpty || 
          s.nom.toLowerCase().startsWith(_searchQuery.toLowerCase());
      return matchesGroup && matchesSearch;
    }).toList();
  }

  String _getGroupeName(int? groupeId) {
    if (groupeId == null) return 'Non affecté';
    final groupe = _groupes.where((g) => g.id == groupeId).firstOrNull;
    return groupe?.nom ?? 'N/A';
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
                : _filteredStagiaires.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _filteredStagiaires.length,
                        itemBuilder: (context, index) => _buildStagiaireCard(_filteredStagiaires[index]),
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
                      'Suivez le parcours de vos apprenants',
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
                icon: const Icon(Icons.person_add_rounded, size: 20, color: Colors.white),
                label: Text(
                  isMobile ? 'Nouvelle' : 'Nouvelle inscription',
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
                      hintText: 'Rechercher par nom ou matricule...',
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Aucun stagiaire',
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

  Widget _buildStagiaireCard(User stagiaire) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.stagiaireColor.withValues(alpha: 0.1),
                child: Text(
                  stagiaire.nom.isNotEmpty ? stagiaire.nom[0].toUpperCase() : 'S',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.stagiaireColor,
                  ),
                ),
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
                          stagiaire.nom,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Actif',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      stagiaire.email,
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
          const SizedBox(height: 24),
          Row(
            children: [
              _buildInfoItem(Icons.groups_rounded, 'Groupe', _getGroupeName(stagiaire.groupeId)),
              const SizedBox(width: 32),
              _buildInfoItem(Icons.phone_outlined, 'Téléphone', (stagiaire.phone != null && stagiaire.phone!.isNotEmpty) ? stagiaire.phone! : 'Non renseigné'),
              const SizedBox(width: 32),
              _buildInfoItem(Icons.calendar_today_rounded, 'Inscription', stagiaire.anneeScolaire ?? 'Sept 2023'),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showAddEditDialog(stagiaire: stagiaire),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('Modifier', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _confirmDelete(stagiaire),
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

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Future<void> _showAddEditDialog({User? stagiaire}) async {
    final nomController = TextEditingController(text: stagiaire?.nom ?? '');
    final emailController = TextEditingController(text: stagiaire?.email ?? '');
    final phoneController = TextEditingController(text: stagiaire?.phone ?? '');
    final birthDateController = TextEditingController(text: stagiaire?.birthDate ?? '');
    final passwordController = TextEditingController(text: stagiaire?.password ?? '');
    final anneeScolaireController = TextEditingController(text: stagiaire?.anneeScolaire ?? '');
    int? selectedGroupeId = stagiaire?.groupeId;
    bool obscurePassword = true;
    final isEdit = stagiaire != null;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (context, setModalState) => Container(
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
                        isEdit ? 'Modifier le stagiaire' : 'Nouveau stagiaire',
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nom complet *',
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
                                hintText: 'Ex: Amine Tazi',
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Matricule / Email *',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                hintText: 'Ex: 2024001',
                                hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
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
                              'Groupe *',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int?>(
                              value: selectedGroupeId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                              items: [
                                DropdownMenuItem(value: null, child: Text('Non affecté', style: GoogleFonts.poppins(fontSize: 14))),
                                ..._groupes.map((g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Text(g.nom, style: GoogleFonts.poppins(fontSize: 14)),
                                )),
                              ],
                              onChanged: (value) => setModalState(() => selectedGroupeId = value),
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
                              'Téléphone',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '0612345678',
                                hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
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
                              'Date de naissance',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                                  firstDate: DateTime(1970),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setModalState(() {
                                    birthDateController.text = "${date.day}/${date.month}/${date.year}";
                                  });
                                }
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: birthDateController,
                                  decoration: InputDecoration(
                                    hintText: 'JJ/MM/AAAA',
                                    hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                                    suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                  ),
                                ),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Année scolaire *',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: anneeScolaireController,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\/\s]')),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Ex: 2024 - 2025',
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
                  Text(
                    isEdit ? 'Nouveau mot de passe (optionnel)' : 'Mot de passe initial *',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annuler', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                      if (nomController.text.trim().isEmpty || emailController.text.trim().isEmpty || anneeScolaireController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Veuillez remplir tous les champs obligatoires (incluant l\'année scolaire)', style: GoogleFonts.poppins()),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                        return;
                      }

                          final email = emailController.text.trim();
                          if (email.contains('@')) {
                            final emailRegex = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
                            if (!emailRegex.hasMatch(email)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Format d\'email invalide', style: GoogleFonts.poppins()), backgroundColor: AppTheme.accentRed),
                              );
                              return;
                            }
                          } else if (email.length < 4) {
                             ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Matricule trop court', style: GoogleFonts.poppins()), backgroundColor: AppTheme.accentRed),
                              );
                              return;
                          }

                          final phone = phoneController.text.trim();
                          if (phone.isNotEmpty) {
                            final phoneRegex = RegExp(r'^(0|\+212)\d{9}$');
                            if (!phoneRegex.hasMatch(phone.replaceAll(' ', ''))) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Format de téléphone invalide (Ex: 06... ou +212...)', style: GoogleFonts.poppins()), backgroundColor: AppTheme.accentRed),
                              );
                              return;
                            }
                          }

                          if (!isEdit && passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Veuillez entrer un mot de passe initial', style: GoogleFonts.poppins()),
                                backgroundColor: AppTheme.accentRed,
                              ),
                            );
                            return;
                          }

                          if (selectedGroupeId != null) {
                            final count = await DatabaseHelper.instance.getGroupeStagiairesCount(selectedGroupeId!);
                            if (count >= 20 && stagiaire?.groupeId != selectedGroupeId) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Ce groupe est complet (max 20 stagiaires)', style: GoogleFonts.poppins()),
                                    backgroundColor: AppTheme.accentOrange,
                                  ),
                                );
                              }
                              return;
                            }
                          }
                          
                          final user = Provider.of<AuthService>(context, listen: false).currentUser;
                          final newStagiaire = User(
                            id: stagiaire?.id,
                            nom: nomController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text.isNotEmpty ? passwordController.text : (stagiaire?.password ?? '123456'),
                            role: UserRole.stagiaire,
                            groupeId: selectedGroupeId,
                            phone: phoneController.text.trim(),
                            birthDate: birthDateController.text.trim(),
                            directorId: user?.id,
                            anneeScolaire: anneeScolaireController.text.trim(),
                          );
                          
                          if (isEdit) {
                            await DatabaseHelper.instance.updateUser(newStagiaire);
                          } else {
                            await DatabaseHelper.instance.insertUser(newStagiaire);
                          }
                          
                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadData();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          isEdit ? 'Modifier' : 'Inscrire',
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

  Future<void> _confirmDelete(User stagiaire) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Voulez-vous vraiment supprimer ce stagiaire ?', style: GoogleFonts.poppins()),
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
      await DatabaseHelper.instance.deleteUser(stagiaire.id!);
      _loadData();
    }
  }
}

