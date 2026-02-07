import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../data/database_helper.dart';
import '../../models/note.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import '../auth/login_screen.dart';
import 'emploi_stagiaire_screen.dart';
import 'notes_stagiaire_screen.dart';
import 'presence_screen.dart';
import 'examens_screen.dart';
import 'releve_screen.dart';
import 'module_progress_screen.dart';
import '../common/chat_list_screen.dart';
import '../common/profile_screen.dart';
import '../common/reclamations_list_screen.dart';
import '../common/notifications_screen.dart';
import '../common/dashboard_components.dart';
import '../../services/analysis_service.dart';
import '../../providers/notification_provider.dart';

class StagiaireDashboard extends StatefulWidget {
  const StagiaireDashboard({super.key});

  @override
  State<StagiaireDashboard> createState() => _StagiaireDashboardState();
}

class _StagiaireDashboardState extends State<StagiaireDashboard> {
  int _currentIndex = 0;
  List<Note> _notes = [];
  bool _isLoading = true;
  double _averageNote = 0;
  File? _profileImage;
  Uint8List? _profileImageBytes;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadProfileImage();

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _currentIndex == 0 && !_isLoading) {
        _loadData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

  List<Map<String, dynamic>> _upcomingExams = [];

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      final notes = await DatabaseHelper.instance.getNotesByStagiaire(user.id!);
      
      List<Map<String, dynamic>> exams = [];
      if (user.groupeId != null) {
        await DatabaseHelper.instance.getEmploiBySemaineAndGroupe(1, user.groupeId!);
        exams = await DatabaseHelper.instance.getUpcomingExamsForGroup(user.groupeId!);
      }

      final validatedNotes = notes.where((n) => n.validee).toList();
      double average = 0;
      if (validatedNotes.isNotEmpty) {
        average = validatedNotes.map((n) => n.valeur).reduce((a, b) => a + b) / validatedNotes.length;
      }

      if (mounted) {
        setState(() {
          _notes = notes;
          _upcomingExams = exams;
          _averageNote = average;
          _isLoading = false;
        });
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
      case 1: return 'Emploi du temps';
      case 2: return 'Mes notes';
      case 3: return 'Mes présences';
      case 4: return 'Examens à venir';
      case 5: return 'Relevé de notes';
      case 6: return 'Progression des modules';
      case 7: return 'Messages';
      case 8: return 'Mon Profil';
      case 9: return 'Réclamations';
      default: return 'Academic Pro';
    }
  }

  PreferredSizeWidget? _buildAppBar() {
    final isLargeScreen = !ResponsiveLayout.isMobile(context);
    final isHome = _currentIndex == 0;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    
    if (isLargeScreen) {
      return null;
    }
    
    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      elevation: 4,
      shadowColor: AppTheme.primaryBlue.withOpacity(0.2),
      centerTitle: isHome,
      leadingWidth: isHome ? null : 56,
      leading: isDesktop && isHome
          ? null
          : !isHome
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                  onPressed: () => setState(() => _currentIndex = 0),
                )
              : Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
      title: Text(
        isHome ? 'Academic Pro' : _getScreenTitle(_currentIndex),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold, 
          color: Colors.white,
          fontSize: 18,
        )
      ),
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, _) => IconButton(
            icon: Badge(
              label: Text(notificationProvider.unreadNotificationCount.toString()),
              isLabelVisible: notificationProvider.unreadNotificationCount > 0,
              child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))
                  .then((_) {
                final user = Provider.of<AuthService>(context, listen: false).currentUser;
                notificationProvider.refreshCounts(user);
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Builder(
          builder: (context) {
            final user = Provider.of<AuthService>(context).currentUser;
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = 8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryBlue,
                backgroundImage: kIsWeb 
                   ? (_profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null)
                   : (_profileImage != null ? FileImage(_profileImage!) : null),
                child: (kIsWeb ? _profileImageBytes == null : _profileImage == null)
                    ? Text(
                        (user?.nom ?? 'S')[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            );
          }
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildDrawer({bool isPermanent = false}) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Drawer(
      backgroundColor: isPermanent ? const Color(0xFF0F172A) : Colors.white,
      elevation: isPermanent ? 0 : 16,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
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
                      ? Text(
                          (user?.nom ?? 'A')[0],
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.nom ?? 'User',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Stagiaire',
                        style: GoogleFonts.poppins(
                          color: AppTheme.stagiaireColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Consumer<NotificationProvider>(
                  builder: (context, notifProvider, _) => Column(
                    children: [
                      _buildSidebarItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Tableau de bord',
                        index: 0,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.how_to_reg_rounded,
                        label: 'Mes présences',
                        index: 3,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.calendar_today_rounded,
                        label: 'Emploi du temps',
                        index: 1,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.military_tech_rounded,
                        label: 'Mes notes',
                        index: 2,
                        isDark: isPermanent,
                        badgeCount: notifProvider.unreadNotesCount,
                      ),
                      _buildSidebarItem(
                        icon: Icons.assignment_outlined,
                        label: 'Examens à venir',
                        index: 4,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.description_outlined,
                        label: 'Relevé de notes',
                        index: 5,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.trending_up_rounded,
                        label: 'Progression des modules',
                        index: 6,
                        isDark: isPermanent,
                      ),
                      const Divider(),
                      _buildSidebarItem(
                         icon: Icons.chat_bubble_outline_rounded,
                         label: 'Messages',
                         index: 7,
                         isDark: isPermanent,
                         badgeCount: notifProvider.unreadMessageCount,
                       ),
                      _buildSidebarItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Mon Profil',
                        index: 8,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.report_problem_rounded,
                        label: 'Réclamations',
                        index: 9,
                        isDark: isPermanent,
                        badgeCount: notifProvider.unreadReclamationsCount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          ListTile(
            leading: Icon(
              Icons.logout_rounded,
              color: isPermanent ? Colors.white70 : AppTheme.accentRed,
            ),
            title: Text(
              'Déconnexion',
              style: GoogleFonts.poppins(
                color: isPermanent ? Colors.white70 : AppTheme.accentRed,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            onTap: () async {
              if (!isPermanent) Navigator.pop(context);
              await authService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawerHeader(User? user) {
    return Container(
      padding: const EdgeInsets.only(top: 48, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: AppTheme.stagiaireColor,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            backgroundImage: kIsWeb 
               ? (_profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null)
               : (_profileImage != null ? FileImage(_profileImage!) : null),
            child: (kIsWeb ? _profileImageBytes == null : _profileImage == null)
                ? Text(
                    user?.nom.substring(0, 1).toUpperCase() ?? 'A',
                    style: GoogleFonts.poppins(color: AppTheme.stagiaireColor, fontSize: 20, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.nom ?? 'User',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Stagiaire',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
    int badgeCount = 0,
  }) {
    return SidebarItem(
      icon: icon,
      label: label,
      isSelected: _currentIndex == index,
      isDark: isDark,
      badgeCount: badgeCount,
      selectedColor: AppTheme.primaryBlue,
      onTap: () {
        setState(() => _currentIndex = index);
        if (!isDark) {
          Navigator.pop(context);
        }
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_currentIndex) {
      case 0:
        return _buildDashboardHome();
      case 1:
        return const EmploiStagiaireScreen();
      case 2:
        return const NotesStagiaireScreen();
      case 3:
        return const PresenceScreen();
      case 4:
        return const ExamensScreen();
      case 5:
        return const ReleveScreen();
      case 6:
        return const ModuleProgressScreen();
      case 7:
        return const ChatListScreen();
      case 8:
        return ProfileScreen(
          onBack: () => setState(() => _currentIndex = 0),
          onProfileUpdated: (File? newImage) {
            _loadProfileImage();
          },
        );
      case 9:
        return const ReclamationsListScreen();
      default:
        return _buildDashboardHome();
    }
  }

  Widget _buildDashboardHome() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final validatedNotes = _notes.where((n) => n.validee).toList();
    final recentNotes = validatedNotes.take(3).toList();
    
    final analysis = AnalysisService.predictPerformance(_notes, []);
    final statusColor = _getStatusColor(analysis['status']);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
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
                        'Bonjour, ${user?.nom.split(' ').first ?? 'Stagiaire'} 👋',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveLayout.respSize(context, 28, 34, 40),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Bienvenue dans votre espace stagiaire',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveLayout.respSize(context, 16, 17, 18),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            LayoutBuilder(
              builder: (context, constraints) {
                final double availableWidth = constraints.maxWidth;
                double cardWidth;
                
                if (availableWidth > 1100) {
                  cardWidth = (availableWidth - 24) / 3;
                } else {
                  cardWidth = (availableWidth - 12) / 2;
                }
                
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    DashboardSummaryCard(
                      label: 'Moyenne générale',
                      value: _averageNote > 0 ? _averageNote.toStringAsFixed(1) : '-',
                      sublabel: 'sur 20',
                      icon: Icons.military_tech_outlined,
                      color: AppTheme.primaryBlue,
                      width: cardWidth,
                    ),
                    DashboardSummaryCard(
                      label: 'Notes publiées',
                      value: '${validatedNotes.length}',
                      icon: Icons.book_outlined,
                      color: AppTheme.accentGreen,
                      width: cardWidth,
                    ),
                    DashboardSummaryCard(
                      label: 'Examens à venir',
                      value: '${_upcomingExams.length}',
                      icon: Icons.calendar_today_outlined,
                      color: AppTheme.stagiaireColor,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            _buildAnalysisCard(analysis, statusColor),
            const SizedBox(height: 32),

            if (isDesktop || isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildUpcomingExamsCard(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildRecentNotesCard(recentNotes),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildUpcomingExamsCard(),
                  const SizedBox(height: 24),
                  _buildRecentNotesCard(recentNotes),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingExamsCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.stagiaireColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_outlined, color: AppTheme.stagiaireColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Prochains examens',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _upcomingExams.isEmpty 
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Text(
                    'Aucun examen planifié',
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                  ),
                ),
              )
            : Column(
                children: _upcomingExams.take(3).map((exam) {
                   final date = DateTime.parse(exam['date'] as String);
                   return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.stagiaireColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event, color: AppTheme.stagiaireColor, size: 20),
                      ),
                      title: Text(exam['module_name'] as String, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${date.day}/${date.month} à ${date.hour}:${date.minute.toString().padLeft(2,'0')}', style: GoogleFonts.poppins(fontSize: 12)),
                   );
                }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> analysis, Color statusColor) {
    return PremiumCard(
      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Analyse de Performance AI',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (analysis['trend'] != null)
                Icon(
                  analysis['trend'] == 'up' ? Icons.trending_up : Icons.trending_down,
                  color: analysis['trend'] == 'up' ? AppTheme.accentGreen : AppTheme.accentRed,
                  size: 20,
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
                      analysis['prediction'],
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      analysis['recommendation'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: analysis['score'],
                      strokeWidth: 8,
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                    Center(
                      child: Text(
                        '${(analysis['score'] * 100).toInt()}%',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotesCard(List<Note> recentNotes) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.military_tech_outlined, color: AppTheme.accentOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Dernières notes',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentNotes.isEmpty) ...[
             const SizedBox(height: 32),
             Center(child: Text('Aucune note publiée', style: GoogleFonts.poppins(color: AppTheme.textSecondary))),
             const SizedBox(height: 32),
          ] else ...[
            ...recentNotes.map((note) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: AppTheme.accentOrange.withValues(alpha: 0.05),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text('${note.valeur}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppTheme.accentOrange)),
               ),
               title: Text('Note: ${note.valeur}/20', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
               subtitle: Text(note.type.toString().split('.').last, style: GoogleFonts.poppins(fontSize: 12)),
            )),
          ],

          TextButton(
            onPressed: () => setState(() => _currentIndex = 2),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 40),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Voir tout', style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'success': return AppTheme.accentGreen;
      case 'warning': return AppTheme.accentOrange;
      case 'danger': return AppTheme.accentRed;
      default: return AppTheme.primaryBlue;
    }
  }

  Widget _buildLargeCard({
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? AppTheme.primaryBlue, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}
