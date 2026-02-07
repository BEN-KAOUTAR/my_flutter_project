import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/database_helper.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class InviterUtilisateursScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const InviterUtilisateursScreen({super.key, this.onBack});

  @override
  State<InviterUtilisateursScreen> createState() => _InviterUtilisateursScreenState();
}

class _InviterUtilisateursScreenState extends State<InviterUtilisateursScreen> {
  List<User> _stagiaires = [];
  List<User> _formateurs = [];
  final Set<int> _selectedIds = {};
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

    final stagiaires = await DatabaseHelper.instance.getUsersByRole(UserRole.stagiaire, directorId: directorId);
    final formateurs = await DatabaseHelper.instance.getUsersByRole(UserRole.formateur, directorId: directorId);
    
    setState(() {
      _stagiaires = stagiaires;
      _formateurs = formateurs;
      _isLoading = false;
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildInfoSection(),
            const SizedBox(height: 32),
            _buildTabBar(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedIds.length} sélectionné(s)',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
                ),
                if (_selectedIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invitations envoyées aux ${_selectedIds.length} utilisateurs !'))
                      );
                      setState(() => _selectedIds.clear());
                    },
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text('Envoyer les invitations', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22D3EE),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTable(_stagiaires, isStagiaire: true),
                  _buildTable(_formateurs, isStagiaire: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Créez des comptes pour les stagiaires et formateurs',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Icon(Icons.mail_outline, color: Color(0xFF0284C7), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comment ça marche ?',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0369A1)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sélectionnez les stagiaires et formateurs pour leur envoyer une invitation par email. Ils recevront un lien pour créer leur compte et accéder à la plateforme.',
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0369A1).withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
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
        tabs: [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.school_outlined, size: 16), const SizedBox(width: 8), Text('Stagiaires (${_stagiaires.length})')])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.person_outline, size: 16), const SizedBox(width: 8), Text('Formateurs (${_formateurs.length})')])),
        ],
      ),
    );
  }

  Widget _buildTable(List<User> users, {required bool isStagiaire}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1000),
          child: SizedBox(
            width: 1000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTableHeader(isStagiaire),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: users.map((user) => _buildTableRow(user, isStagiaire)).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(bool isStagiaire) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          const SizedBox(width: 24),
          Expanded(flex: 3, child: Text('Nom', style: _headerStyle)),
          Expanded(flex: 3, child: Text('Matricule', style: _headerStyle)),
          Expanded(flex: 5, child: Text('Email', style: _headerStyle)),
          if (!isStagiaire) Expanded(flex: 3, child: Text('Spécialité', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Statut', style: _headerStyle)),
        ],
      ),
    );
  }

  Widget _buildTableRow(User user, bool isStagiaire) {
    final isSelected = _selectedIds.contains(user.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.05) : null,
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) => _toggleSelection(user.id!),
            activeColor: AppTheme.primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(flex: 3, child: Text(user.nom, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13))),
          Expanded(flex: 3, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            child: Text(user.matricule ?? 'N/A', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.center),
          )),
          Expanded(flex: 5, child: Text(user.email, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary))),
          if (!isStagiaire) Expanded(flex: 3, child: Text(user.specialite ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w500))),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.invitationStatus == 'Invitée' || user.invitationStatus == 'Acceptée' 
                          ? const Color(0xFFDCFCE7) 
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (user.invitationStatus == 'Invitée' || user.invitationStatus == 'Acceptée')
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF166534)),
                          ),
                        Flexible(
                          child: Text(
                            user.invitationStatus ?? 'En attente',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: user.invitationStatus == 'Invitée' || user.invitationStatus == 'Acceptée' 
                                  ? const Color(0xFF166534) 
                                  : AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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

