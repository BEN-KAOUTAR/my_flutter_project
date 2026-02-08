import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../data/database_helper.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import '../auth/login_screen.dart';
import 'seances_screen.dart';
import 'notes_formateur_screen.dart';
import '../common/chat_list_screen.dart';
import '../common/profile_screen.dart';
import '../common/reclamations_list_screen.dart';
import '../common/notifications_screen.dart';
import '../common/dashboard_components.dart';
import 'emploi_formateur_screen.dart';
import 'exam_planning_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'presence_screen.dart';

import '../../providers/notification_provider.dart';

class FormateurDashboard extends StatefulWidget {
  const FormateurDashboard({super.key});

  @override
  State<FormateurDashboard> createState() => _FormateurDashboardState();
}

class _FormateurDashboardState extends State<FormateurDashboard> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _affectationsWithProgress = [];
  bool _isLoading = true;
  double _totalHeures = 0;
  File? _profileImage;
  Uint8List? _profileImageBytes;
  String? _profileName;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
    });

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

  List<Map<String, dynamic>> _upcomingExams = [];

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.id;
    
    if (userId != null) {
      final affectationsWithProgress = await DatabaseHelper.instance.getAffectationsWithProgress(userId);
      final totalHeures = await DatabaseHelper.instance.getFormateurTotalHours(userId);
      final exams = await DatabaseHelper.instance.getUpcomingExams(userId);
      
      if (mounted) {
        setState(() {
          _affectationsWithProgress = affectationsWithProgress;
          _totalHeures = totalHeures;
          _upcomingExams = exams;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      final imagePath = prefs.getString('profile_image_${user.id}');
      if (imagePath != null && imagePath.isNotEmpty) {
        if (kIsWeb) {
          if (imagePath.startsWith('data:image')) {
            if (mounted) {
              setState(() {
                _profileImageBytes = base64Decode(imagePath.split(',').last);
                _profileName = user.nom;
              });
            }
          }
        } else {
          final file = File(imagePath);
          if (await file.exists()) {
            if (mounted) {
              setState(() {
                _profileImage = file;
                _profileName = user.nom;
              });
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _profileImage = null;
            _profileImageBytes = null;
            _profileName = user.nom;
          });
        }
      }
    }
  }


  String _getScreenTitle(int index) {
    switch (index) {
      case 0: return 'Academic Pro';
      case 1: return 'Mes séances';
      case 2: return 'Emploi du temps';
      case 3: return 'Gestion des notes';
      case 4: return 'Messages';
      case 5: return 'Mon Profil';
      case 6: return 'Réclamations';
      case 7: return 'Planification Examens';
      case 8: return 'Suivi de présence';
      default: return 'Academic Pro';
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


  PreferredSizeWidget? _buildAppBar() {
    final isLargeScreen = !ResponsiveLayout.isMobile(context);
    final authService = Provider.of<AuthService>(context);
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
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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
        if (!isDesktop)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: (kIsWeb ? _profileImageBytes != null : _profileImage != null) ? Colors.transparent : AppTheme.formateurColor.withOpacity(0.1),
              backgroundImage: kIsWeb 
                 ? (_profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null)
                 : (_profileImage != null ? FileImage(_profileImage!) : null),
              child: (kIsWeb ? _profileImageBytes == null : _profileImage == null) ? Text(
                (_profileName ?? (Provider.of<AuthService>(context, listen: false).currentUser?.nom ?? 'A'))[0],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.formateurColor,
                  fontSize: 14,
                ),
              ) : null,
            ),
          ),
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
          if (isPermanent)
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.formateurColor,
                    backgroundImage: kIsWeb 
                       ? (_profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null)
                       : (_profileImage != null ? FileImage(_profileImage!) : null),
                    child: (kIsWeb ? _profileImageBytes == null : _profileImage == null) ? Text(
                      (user?.nom ?? 'F')[0],
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ) : null,
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
                          'Formateur',
                          style: GoogleFonts.poppins(
                            color: AppTheme.formateurColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            _buildMobileDrawerHeader(user),

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
                        icon: Icons.history_rounded,
                        label: 'Mes séances',
                        index: 1,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.calendar_today_rounded,
                        label: 'Emploi du temps',
                        index: 2,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.grade_rounded,
                        label: 'Gestion des notes',
                        index: 3,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.event_note_rounded,
                        label: 'Planification Examens',
                        index: 7,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.checklist_rtl_rounded,
                        label: 'Suivi de présence',
                        index: 8,
                        isDark: isPermanent,
                      ),
                      const Divider(),
                      _buildSidebarItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Messages',
                        index: 4,
                        isDark: isPermanent,
                        badgeCount: notifProvider.unreadMessageCount,
                      ),
                      _buildSidebarItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Mon Profil',
                        index: 5,
                        isDark: isPermanent,
                      ),
                      _buildSidebarItem(
                        icon: Icons.report_problem_rounded,
                        label: 'Réclamations',
                        index: 6,
                        isDark: isPermanent,
                        badgeCount: notifProvider.unreadReclamationsCount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawerHeader(User? user) {
    return Container(
      padding: const EdgeInsets.only(top: 48, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: AppTheme.formateurColor,
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
            child: (kIsWeb ? _profileImageBytes == null : _profileImage == null) ? Text(
              (user?.nom ?? 'F')[0],
              style: GoogleFonts.poppins(color: AppTheme.formateurColor, fontWeight: FontWeight.bold, fontSize: 20),
            ) : null,
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
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Formateur',
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
      selectedColor: AppTheme.formateurColor,
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

    final onBack = () => setState(() => _currentIndex = 0);

    switch (_currentIndex) {
      case 0:
        return _buildDashboardHome();
      case 1:
        return SeancesScreen(onBack: onBack);
      case 2:
        return EmploiFormateurScreen(onBack: onBack);
      case 3:
        return NotesFormateurScreen(onBack: onBack);
      case 4:
        return ChatListScreen(onBack: onBack);
      case 5:
        return ProfileScreen(
          onBack: onBack,
          onProfileUpdated: (File? newImage) {
            _loadProfileImage();
          },
        );
      case 6:
        return ReclamationsListScreen(onBack: onBack);
      case 7:
        return ExamPlanningScreen(onBack: () => setState(() => _currentIndex = 0));
      case 8:
        return PresenceFormateurScreen(onBack: () => setState(() => _currentIndex = 0));
      default:
        return _buildDashboardHome();
    }
  }

  Widget _buildDashboardHome() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
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
                        'Bonjour, ${user?.nom.split(' ').first ?? 'Formateur'} 👋',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveLayout.respSize(context, 28, 34, 40),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Bienvenue dans votre espace formateur',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveLayout.respSize(context, 16, 17, 18),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!ResponsiveLayout.isMobile(context))
                  Consumer<NotificationProvider>(
                    builder: (context, notifProvider, _) => IconButton(
                      icon: Badge(
                        label: Text(notifProvider.unreadNotificationCount.toString()),
                        isLabelVisible: notifProvider.unreadNotificationCount > 0,
                        child: const Icon(Icons.notifications_none_rounded, color: AppTheme.formateurColor, size: 36),
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
              ],
            ),
            const SizedBox(height: 32),

            LayoutBuilder(
              builder: (context, constraints) {
                final double availableWidth = constraints.maxWidth;
                double cardWidth;
                
                if (availableWidth > 1100) {
                  cardWidth = (availableWidth - 32) / 3;
                } else {
                  cardWidth = (availableWidth - 16) / 2;
                }

                if (cardWidth < 200) cardWidth = availableWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    DashboardSummaryCard(
                      label: 'Modules affectés',
                      value: '${_affectationsWithProgress.length}',
                      icon: Icons.book_outlined,
                      color: AppTheme.primaryBlue,
                      width: cardWidth,
                    ),
                    DashboardSummaryCard(
                      label: 'Heures effectuées',
                      value: '${_totalHeures.toInt()}h',
                      sublabel: 'sur 910h',
                      icon: Icons.timer_outlined,
                      color: AppTheme.formateurColor,
                       width: cardWidth,
                    ),
                    DashboardSummaryCard(
                      label: 'Groupes suivis',
                      value: '${_affectationsWithProgress.map((a) => a['groupe_id']).toSet().length}',
                      icon: Icons.groups_outlined,
                      color: AppTheme.accentOrange,
                       width: cardWidth,
                    ),
                  ],
                );
              }
            ),
            const SizedBox(height: 32),

            Text(
              'Mes modules & Progression',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (_affectationsWithProgress.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun module affecté',
                        style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._affectationsWithProgress.map((data) => _buildModuleCard(data)),

            const SizedBox(height: 32),
            _buildUpcomingExams(),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingExams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Examens à venir',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 7),
              child: Text('Voir tout', style: GoogleFonts.poppins(color: AppTheme.formateurColor)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_upcomingExams.isEmpty)
          PremiumCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_note_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.3), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun examen programmé',
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          ..._upcomingExams.map((exam) {
             final date = DateTime.parse(exam['date'] as String);
             return PremiumCard(
               margin: const EdgeInsets.only(bottom: 12),
               padding: const EdgeInsets.all(16),
               child: Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                       borderRadius: BorderRadius.circular(10),
                     ),
                     child: Column(
                       children: [
                         Text(
                           '${date.day}',
                           style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                         ),
                         Text(
                           _getMonthName(date.month),
                           style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
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
                           exam['module_name'] as String,
                           style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                         ),
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                               decoration: BoxDecoration(
                                 color: AppTheme.stagiaireColor.withValues(alpha: 0.1),
                                 borderRadius: BorderRadius.circular(4),
                               ),
                               child: Text(
                                 exam['groupe_name'] as String,
                                 style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.stagiaireColor),
                               ),
                             ),
                             const SizedBox(width: 8),
                             Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textSecondary),
                             const SizedBox(width: 4),
                             Text(
                               '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                               style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                             ),
                           ],
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
             );
          }),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['JAN', 'FEV', 'MAR', 'AVR', 'MAI', 'JUIN', 'JUIL', 'AOUT', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  Widget _buildModuleCard(Map<String, dynamic> data) {
    final moduleName = data['module_name'] ?? 'N/A';
    final groupeName = data['groupe_name'] ?? 'N/A';
    final double totalHours = (data['masse_horaire_totale'] as num?)?.toDouble() ?? 0;
    final double hoursDone = (data['hours_done'] as num?)?.toDouble() ?? 0;
    final double progress = totalHours > 0 ? hoursDone / totalHours : 0;

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book_rounded, color: AppTheme.primaryBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moduleName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.stagiaireColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              groupeName,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.stagiaireColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.timer_outlined, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${hoursDone.toInt()}h / ${totalHours.toInt()}h',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
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
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryBlue, AppTheme.formateurColor],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
