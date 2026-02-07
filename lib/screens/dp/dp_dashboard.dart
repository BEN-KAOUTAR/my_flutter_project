import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import '../../data/database_helper.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import '../auth/login_screen.dart';
import 'filieres_screen.dart';
import 'modules_screen.dart';
import 'groupes_screen.dart';
import 'formateurs_screen.dart';
import 'stagiaires_screen.dart';
import 'affectations_screen.dart';
import 'planning_screen.dart';
import 'validation_screen.dart';
import 'presence_screen.dart';
import 'inviter_utilisateurs_screen.dart';
import 'statistiques_screen.dart';
import 'inscription_requests_screen.dart';
import '../common/reclamations_list_screen.dart';
import '../common/chat_list_screen.dart';
import '../common/profile_screen.dart';
import '../common/notifications_screen.dart';
import '../common/dashboard_components.dart';

import '../../providers/notification_provider.dart';

class DPDashboard extends StatefulWidget {
  const DPDashboard({super.key});

  @override
  State<DPDashboard> createState() => _DPDashboardState();
}

class _DPDashboardState extends State<DPDashboard> {
  int _currentIndex = 0;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _upcomingExams = [];
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isLoading = true;
  File? _profileImage;
  Uint8List? _profileImageBytes;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _drawerScrollController = ScrollController();
  StreamSubscription? _dataSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
    });
    
    _dataSubscription = DatabaseHelper.instance.onDataChange.listen((_) {
      if (mounted && _currentIndex == 0) {
        _loadStats();
      }
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _currentIndex == 0 && !_isLoading) {
        _loadStats(showLoading: false);
      }
    });
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      final imagePath = prefs.getString('profile_image_${user.id}');
      if (imagePath != null && imagePath.isNotEmpty) {
        if (kIsWeb) {
          if (imagePath.startsWith('data:image')) {
            setState(() {
              _profileImageBytes = base64Decode(imagePath.split(',').last);
            });
          }
        } else {
          final file = File(imagePath);
          if (await file.exists()) {
            setState(() {
              _profileImage = file;
            });
          }
        }
      }
    }
  }


  @override
  void dispose() {
    _dataSubscription?.cancel();
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _drawerScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStats({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final directorId = user?.id;

      final stats = await DatabaseHelper.instance.getGlobalStats(directorId: directorId);
      final exams = await DatabaseHelper.instance.getGlobalUpcomingExams(directorId: directorId);
      final activity = await DatabaseHelper.instance.getRecentActivity(directorId: directorId);
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _upcomingExams = exams;
          _recentActivity = activity;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading DP dashboard stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e', style: GoogleFonts.poppins()), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSidebar = !ResponsiveLayout.isMobile(context);
    
    return DashboardLayout(
      appBar: _buildAppBar(),
      drawer: showSidebar ? null : _buildDrawer(),
      sideBar: showSidebar ? _buildDrawer(isPermanent: true) : null,
      showSidebar: showSidebar,
      body: _buildBody(),
    );
  }
  String _getScreenTitle(int index) {
    switch (index) {
      case 0: return 'Academic Pro';
      case 1: return 'Groupes';
      case 2: return 'Formateurs';
      case 3: return 'Stagiaires';
      case 4: return 'Affectations';
      case 5: return 'Emplois du temps';
      case 6: return 'Validation & Publication';
      case 7: return 'Présences';
      case 8: return 'Inviter utilisateurs';
      case 9: return 'Statistiques';
      case 11: return 'Filières';
      case 12: return 'Modules';
      case 14: return 'Demandes inscription';
      case 15: return 'Messages';
      case 16: return 'Mon Profil';
      case 17: return 'Réclamations';
      default: return 'Academic Pro';
    }
  }

  PreferredSizeWidget? _buildAppBar() {
    final user = Provider.of<AuthService>(context).currentUser;
    final isHome = _currentIndex == 0;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isLargeScreen = !ResponsiveLayout.isMobile(context);

    if (isLargeScreen) {
      return null;
    }
    
    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      elevation: 4,
      shadowColor: AppTheme.primaryBlue.withOpacity(0.2),
      centerTitle: isHome,
      titleSpacing: isHome ? null : 0,
      title: Text(
        _getScreenTitle(_currentIndex),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontSize: isHome ? 22 : 20,
        ),
      ),
      leading: isDesktop && isHome
          ? null 
          : !isHome 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                onPressed: () => setState(() => _currentIndex = 0),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 30),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
      actions: [
        if (isHome)
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) => IconButton(
              icon: Badge(
                label: Text(notifProvider.unreadNotificationCount.toString()),
                isLabelVisible: notifProvider.unreadNotificationCount > 0,
                child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 30),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))
                    .then((_) {
                  final user = Provider.of<AuthService>(context, listen: false).currentUser;
                  notifProvider.refreshCounts(user);
                });
              },
            ),
          ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF1F5F9),
            backgroundImage: kIsWeb 
              ? (_profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null)
              : (_profileImage != null ? FileImage(_profileImage!) : null),
            child: (kIsWeb ? _profileImageBytes == null : _profileImage == null)
                ? Text(
                    user?.nom.substring(0, 1).toUpperCase() ?? 'D',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer({bool isPermanent = false}) {
    final user = Provider.of<AuthService>(context).currentUser;
    return Drawer(
      backgroundColor: isPermanent ? const Color(0xFF0F172A) : Colors.white,
      elevation: isPermanent ? 0 : 16,
      child: Scrollbar(
        controller: _drawerScrollController,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(3),
        child: ListView(
          controller: _drawerScrollController,
          padding: EdgeInsets.zero,
          children: [
          if (isPermanent)
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryBlue,
                    backgroundImage: kIsWeb 
                      ? (_profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null)
                      : (_profileImage != null ? FileImage(_profileImage!) : null),
                    child: (kIsWeb ? _profileImageBytes == null : _profileImage == null)
                        ? Text(user?.nom[0].toUpperCase() ?? 'A', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nom ?? 'Directeur', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Direction', style: GoogleFonts.poppins(color: AppTheme.dpColor, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.dpColor),
              accountName: Text(user?.nom ?? 'Directeur', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              accountEmail: Text(user?.email ?? '', style: GoogleFonts.poppins()),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: kIsWeb 
                  ? (_profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null)
                  : (_profileImage != null ? FileImage(_profileImage!) : null),
                child: (kIsWeb ? _profileImageBytes == null : _profileImage == null)
                    ? Text(user?.nom[0].toUpperCase() ?? 'D', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.dpColor))
                    : null,
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildDrawerItem(0, Icons.dashboard_rounded, 'Tableau de bord', isPermanent),
                Consumer<NotificationProvider>(
                  builder: (context, notifProvider, _) => _buildDrawerItem(
                    14, Icons.how_to_reg_rounded, 'Demandes inscription', isPermanent,
                    badgeCount: notifProvider.unreadInscriptionRequestsCount,
                  ),
                ),
                Consumer<NotificationProvider>(
                  builder: (context, notifProvider, _) => _buildDrawerItem(
                    17, Icons.report_problem_rounded, 'Réclamations', isPermanent,
                    badgeCount: notifProvider.unreadReclamationsCount,
                  ),
                ),
                Consumer<NotificationProvider>(
                  builder: (context, notifProvider, _) => _buildDrawerItem(
                    15, Icons.chat_bubble_outline_rounded, 'Messages', isPermanent,
                    badgeCount: notifProvider.unreadMessageCount,
                  ),
                ), 
                const Divider(),
                _buildDrawerItem(11, Icons.grid_view_rounded, 'Filières', isPermanent),
                _buildDrawerItem(12, Icons.book_rounded, 'Modules', isPermanent),
                const Divider(),
                _buildDrawerItem(1, Icons.groups_rounded, 'Groupes', isPermanent),
                _buildDrawerItem(2, Icons.person_rounded, 'Formateurs', isPermanent),
                _buildDrawerItem(3, Icons.people_rounded, 'Stagiaires', isPermanent),
                _buildDrawerItem(4, Icons.assignment_rounded, 'Affectations', isPermanent),
                _buildDrawerItem(5, Icons.calendar_month_rounded, 'Emplois du temps', isPermanent),
                Consumer<NotificationProvider>(
                  builder: (context, notifProvider, _) => _buildDrawerItem(
                    6, Icons.verified_user_rounded, 'Notes & Validation', isPermanent,
                    badgeCount: notifProvider.unreadNotesCount,
                  ),
                ),
                Consumer<NotificationProvider>(
                  builder: (context, notifProvider, _) => _buildDrawerItem(
                    7, Icons.access_time_rounded, 'Présences', isPermanent,
                    badgeCount: notifProvider.pendingPresenceValidationsCount,
                  ),
                ),
                _buildDrawerItem(8, Icons.person_add_rounded, 'Inviter utilisateurs', isPermanent),
                _buildDrawerItem(9, Icons.bar_chart_rounded, 'Statistiques', isPermanent),
                const Divider(),
                _buildDrawerItem(16, Icons.person_outline_rounded, 'Mon Profil', isPermanent),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.accentRed, size: 24),
              title: Text(
                'Déconnexion', 
                style: GoogleFonts.poppins(
                  color: AppTheme.accentRed, 
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              onTap: () async {
                await Provider.of<AuthService>(context, listen: false).logout();
                if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title, bool isPermanent, {Color? iconColor, int badgeCount = 0}) {
    return SidebarItem(
      icon: icon,
      label: title,
      isSelected: _currentIndex == index,
      isDark: isPermanent,
      badgeCount: badgeCount,
      selectedColor: AppTheme.dpColor,
      onTap: () {
          setState(() => _currentIndex = index);
          if (index == 0) _loadStats();
          if (index == 7) {
            final user = Provider.of<AuthService>(context, listen: false).currentUser;
            Provider.of<NotificationProvider>(context, listen: false).markPresencesAsSeen(user);
          }
          if (!isPermanent) Navigator.pop(context);
      },
    );
  }

  Widget _buildBody() {
    final onBack = () => setState(() => _currentIndex = 0);
    
    switch (_currentIndex) {
      case 0: return _buildDashboardHome();
      case 1: return GroupesScreen(onBack: onBack);
      case 2: return FormateursScreen(onBack: onBack);
      case 3: return StagiairesScreen(onBack: onBack);
      case 4: return AffectationsScreen(onBack: onBack);
      case 5: return PlanningScreen(onBack: onBack);
      case 6: return ValidationScreen(onBack: onBack);
      case 7: return PresenceScreen(onBack: onBack);
      case 8: return InviterUtilisateursScreen(onBack: onBack);
      case 9: return StatistiquesScreen(onBack: onBack);
      case 11: return FilieresScreen(onBack: onBack);
      case 12: return ModulesScreen(onBack: onBack);
      case 14: return InscriptionRequestsScreen(onBack: onBack);
      case 17: return ReclamationsListScreen(onBack: onBack);
      case 15: return ChatListScreen(onBack: onBack); 
      case 16:
        return ProfileScreen(
          onBack: onBack,
          onProfileUpdated: (File? newImage) {
             _loadProfileImage();
          },
        ); 
      default: return _buildDashboardHome();
    }
  }

  Widget _buildDashboardHome() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 8,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 24),
              _buildStatsSection(),
              const SizedBox(height: 24),
              _buildQuickActionsSection(),
              const SizedBox(height: 24),
              _buildUpcomingExamsSection(),
              const SizedBox(height: 24),
              _buildRecentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingExamsSection() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prochains examens',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _currentIndex = 5);
                },
                child: Text('Voir planning', style: GoogleFonts.poppins(color: AppTheme.primaryBlue)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_upcomingExams.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Aucun examen prévu', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
              ),
            )
          else
            ..._upcomingExams.map((exam) {
              final date = DateTime.parse(exam['date']);
              return Column(
                children: [
                  _buildExamRow(
                    exam['module_name'] ?? 'N/A',
                    exam['groupe_name'] ?? 'N/A',
                    DateFormat('dd MMM').format(date),
                    DateFormat('HH:mm').format(date),
                  ),
                  if (exam != _upcomingExams.last) const Divider(height: 24),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildExamRow(String module, String group, String date, String time) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.event_note_rounded, color: AppTheme.primaryBlue, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                module,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              Text(
                'Groupe: $group',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              date,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
            Text(
              time,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activité récente',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (_recentActivity.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Aucune activité récente', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
            ),
          )
        else
          ..._recentActivity.map((act) {
            final date = DateTime.parse(act['timestamp']);
            final isSeance = act['type'] == 'SEANCE';
            return _buildActivityItem(
              isSeance ? 'Séance validée' : 'Note publiée',
              '${act['text']} - ${act['subtext']}',
              DateFormat('dd/MM HH:mm').format(date),
            );
          }),
      ],
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final isLargeScreen = MediaQuery.of(context).size.width >= 600;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, ${user?.nom ?? 'Directeur Pédagogique'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveLayout.respSize(context, 22, 28, 34),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Voici un aperçu de votre établissement',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveLayout.respSize(context, 16, 17, 18),
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount;
        double aspectRatio;
        
        if (width > 1100) {
          crossAxisCount = 4;
          aspectRatio = 2.4;
        } else {
          crossAxisCount = 2;
          aspectRatio = 2.2;
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
              label: 'Filières',
              value: '${_stats['filieres'] ?? 0}',
              icon: Icons.grid_view_rounded,
              color: AppTheme.accentOrange,
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Groupes actifs',
              value: '${_stats['groupes'] ?? 0}',
              icon: Icons.groups_rounded,
              color: AppTheme.primaryBlue,
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Formateurs',
              value: '${_stats['formateurs'] ?? 0}',
              icon: Icons.person_rounded,
              color: AppTheme.formateurColor,
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Stagiaires',
              value: '${_stats['stagiaires'] ?? 0}',
              icon: Icons.people_rounded,
              color: AppTheme.stagiaireColor,
              width: double.infinity,
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Alertes et validations en attente',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _currentIndex = 6);
              },
              child: Text(
                'Voir tout',
                style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Vous avez ${_stats['seancesEnAttente'] ?? 0} séances en attente de validation pour cette semaine.',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF991B1B),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}




