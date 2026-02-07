import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class FormateursScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const FormateursScreen({super.key, this.onBack});

  @override
  State<FormateursScreen> createState() => _FormateursScreenState();
}

class _FormateursScreenState extends State<FormateursScreen> {
  List<User> _formateurs = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFormateurs();

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isLoading) {
        _loadFormateurs(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<User> get _filteredFormateurs {
    List<User> filtered = _formateurs;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((f) => 
        f.nom.toLowerCase().startsWith(_searchQuery.toLowerCase()) ||
        f.email.toLowerCase().startsWith(_searchQuery.toLowerCase())
      ).toList();
    }
    
    if (_sortBy == 'name_asc') {
      filtered.sort((a, b) => a.nom.compareTo(b.nom));
    } else if (_sortBy == 'name_desc') {
      filtered.sort((a, b) => b.nom.compareTo(a.nom));
    } else if (_sortBy == 'worked_hrs') {
      filtered.sort((a, b) => b.totalHeuresAffectees.compareTo(a.totalHeuresAffectees));
    }
    
    return filtered;
  }
  
  String _sortBy = 'name_asc';

  Future<void> _loadFormateurs({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final directorId = user?.id;
    final formateurs = await DatabaseHelper.instance.getUsersByRole(UserRole.formateur, directorId: directorId);
    setState(() {
      _formateurs = formateurs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFormateurs,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFormateurs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _filteredFormateurs.length,
                        itemBuilder: (context, index) => _buildFormateurCard(_filteredFormateurs[index]),
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
                      'Gérez votre équipe pédagogique',
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
                  isMobile ? 'Ajouter' : 'Ajouter un formateur',
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
                      hintText: 'Rechercher un formateur...',
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
                  borderRadius:BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    hint: Text('Trier par', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                    icon: const Icon(Icons.filter_list_rounded, color: AppTheme.textSecondary, size: 20),
                    items: [
                      DropdownMenuItem(
                        value: 'name_asc',
                        child: Text('Nom (A-Z)', style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: 'name_desc',
                        child: Text('Nom (Z-A)', style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: 'worked_hrs',
                        child: Text('Heures affectées', style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _sortBy = value!),
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
          Icon(Icons.person_outline, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Aucun formateur',
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

  Widget _buildFormateurCard(User formateur) {
    final heures = formateur.totalHeuresAffectees;
    final maxHeures = 910;
    final isOverLimit = heures > maxHeures;
    final progress = (heures / maxHeures).clamp(0.0, 1.0);

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
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.formateurColor.withValues(alpha: 0.1),
                    child: Text(
                      formateur.nom.isNotEmpty ? formateur.nom[0].toUpperCase() : 'F',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.formateurColor,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formateur.nom,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Formateur Expert • Digital Web',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                   _buildIconButton(Icons.mail_outline_rounded, () => _launchEmail(formateur.email)),
                  const SizedBox(width: 8),
                  _buildIconButton(Icons.phone_outlined, () {
                    if (formateur.phone != null && formateur.phone!.isNotEmpty) {
                       _launchPhone(formateur.phone!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Aucun numéro de téléphone renseigné')),
                      );
                    }
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildFactItem('Modules', '4 assigned'),
              const SizedBox(width: 32),
              _buildFactItem('Heures', '${heures.toInt()}h / $maxHeures h'),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverLimit ? AppTheme.accentRed : AppTheme.primaryBlue,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showAddEditDialog(formateur: formateur),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('Modifier', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _confirmDelete(formateur),
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

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textPrimary),
      ),
    );
  }


  Widget _buildFactItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Future<void> _showAddEditDialog({User? formateur}) async {
    final nomController = TextEditingController(text: formateur?.nom ?? '');
    final emailController = TextEditingController(text: formateur?.email ?? '');
    final phoneController = TextEditingController(text: formateur?.phone ?? '');
    final passwordController = TextEditingController(text: formateur?.password ?? '');
    bool obscurePassword = true;
    final isEdit = formateur != null;

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
                    isEdit ? 'Modifier le formateur' : 'Nouveau formateur',
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
                  hintText: 'Ex: Mohammed Alami',
                  hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Email académique *',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'formateur@academicpro.ma',
                  hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                ),
              ),
              const SizedBox(height: 20),
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
                  hintText: 'Ex: 06 12 34 56 78',
                  hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                ),
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
                      if (nomController.text.trim().isEmpty || emailController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Veuillez remplir tous les champs obligatoires', style: GoogleFonts.poppins()), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }

                      final email = emailController.text.trim();
                      final emailRegex = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
                      if (!emailRegex.hasMatch(email)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Format d\'email invalide', style: GoogleFonts.poppins()), backgroundColor: AppTheme.accentRed),
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
                          SnackBar(content: Text('Veuillez entrer un mot de passe initial', style: GoogleFonts.poppins()), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }
                      final user = Provider.of<AuthService>(context, listen: false).currentUser;
                      final newUser = User(
                        id: formateur?.id,
                        nom: nomController.text.trim(),
                        email: emailController.text.trim(),
                        phone: phoneController.text.trim(),
                        password: passwordController.text.isNotEmpty ? passwordController.text : (formateur?.password ?? '123456'),
                        role: UserRole.formateur,
                        totalHeuresAffectees: formateur?.totalHeuresAffectees ?? 0,
                        directorId: user?.id,
                      );
                      if (isEdit) {
                        await DatabaseHelper.instance.updateUser(newUser);
                      } else {
                        await DatabaseHelper.instance.insertUser(newUser);
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadFormateurs();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isEdit ? 'Modifier' : 'Ajouter',
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

  Future<void> _confirmDelete(User formateur) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Voulez-vous vraiment supprimer ce formateur ?', style: GoogleFonts.poppins()),
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
      await DatabaseHelper.instance.deleteUser(formateur.id!);
      _loadFormateurs();
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir l\'application d\'email')),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneLaunchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunchUrl(phoneLaunchUri)) {
      await launchUrl(phoneLaunchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer l\'appel')),
        );
      }
    }
  }
}
