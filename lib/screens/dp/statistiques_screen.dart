import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../models/filiere.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_service.dart';
import '../common/dashboard_components.dart';


class StatistiquesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const StatistiquesScreen({super.key, this.onBack});

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Filiere> _filieres = [];
  int? _selectedFiliereId;
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

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final directorId = user?.id;
      final stats = await DatabaseHelper.instance.getDashboardStats(filiereId: _selectedFiliereId, directorId: directorId);
      final filieres = await DatabaseHelper.instance.getAllFilieres(directorId: directorId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _filieres = filieres;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des statistiques: $e', style: GoogleFonts.poppins()), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _generateProgressReport() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final directorId = user?.id;
    final progressData = await DatabaseHelper.instance.getAllAffectationsWithProgress(
      filiereId: _selectedFiliereId,
      directorId: directorId,
    );
    if (progressData.isNotEmpty) {
      await PdfService.generateProgressReportPdf(progressData);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucune donnée de progression disponible', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildTopCards(),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildRepartitionChart()),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildDistributionChart()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildRepartitionChart(),
                    const SizedBox(height: 24),
                    _buildDistributionChart(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildChargeSection()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildAvancementSection()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildChargeSection(),
                    const SizedBox(height: 24),
                    _buildAvancementSection(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble des performances',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedFiliereId,
                  hint: Text('Toutes les filières', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary)),
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary),
                  items: [
                    DropdownMenuItem<int>(
                      value: null, 
                      child: Text('Toutes les filières', style: GoogleFonts.poppins(fontSize: 13))
                    ),
                    ..._filieres.map((f) => DropdownMenuItem(
                      value: f.id, 
                      child: Text(f.nom, style: GoogleFonts.poppins(fontSize: 13))
                    )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedFiliereId = val);
                    _loadData();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              width: 60,
              child:  ElevatedButton(
                onPressed: _generateProgressReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.picture_as_pdf, size: 22,weight: 20,),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount;
        double aspectRatio;
        
        if (width > 800) {
          crossAxisCount = 4;
          aspectRatio = 2.0;
        } else if (width > 700) {
          crossAxisCount = 2;
          aspectRatio = 2.2;
        } else {
          crossAxisCount = 1;
          aspectRatio = 2.8;
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
              label: 'Taux de réussite',
              value: '${(_stats['tauxReussite'] * 100).toInt()}%',
              icon: Icons.trending_up_rounded,
              color: AppTheme.accentOrange,
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Stagiaires actifs',
              value: _stats['stagiairesActifs'].toString(),
              icon: Icons.school_rounded,
              color: const Color(0xFF3B82F6),
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Formateurs actifs',
              value: _stats['formateursActifs'].toString(),
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF8B5CF6),
              width: double.infinity,
            ),
            DashboardSummaryCard(
              label: 'Heures validées',
              value: '${_stats['heuresValidees'].toInt()}h',
              icon: Icons.access_time_filled_rounded,
              color: const Color(0xFF06B6D4),
              width: double.infinity,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRepartitionChart() {
    final data = (_stats['repartitionFiliere'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chrome_reader_mode_outlined, size: 20, color: Color(0xFF06B6D4)),
              const SizedBox(width: 12),
              Text('Répartition par filière', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: () {
                  double maxVal = 10;
                  for (var item in data) {
                    final stagVal = (item['stagiaires'] as int).toDouble();
                    final grpVal = (item['groupes'] as int).toDouble();
                    final modVal = (item['modules'] as int).toDouble();
                    final currentMax = [stagVal, grpVal, modVal].reduce((a, b) => a > b ? a : b);
                    if (currentMax > maxVal) maxVal = currentMax;
                  }
                  return maxVal + 2;
                }(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()}',
                        GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        if (val.toInt() < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(data[val.toInt()]['nom'], style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 2),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(toY: (e.value['stagiaires'] as int).toDouble(), color: const Color(0xFF06B6D4), width: 16, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: (e.value['groupes'] as int).toDouble(), color: const Color(0xFF8B5CF6), width: 16, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: (e.value['modules'] as int).toDouble(), color: const Color(0xFF10B981), width: 16, borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend('Stagiaires', const Color(0xFF06B6D4)),
              const SizedBox(width: 16),
              _buildLegend('Groupes', const Color(0xFF8B5CF6)),
              const SizedBox(width: 16),
              _buildLegend('Modules', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildDistributionChart() {
    final rawData = (_stats['distributionNotes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final Map<String, int> dataMap = {
      '0-5': 0, '5-8': 0, '8-10': 0, '10-12': 0, '12-15': 0, '15-20': 0,
    };
    for (var d in rawData) {
      dataMap[d['range']] = (d['count'] as int);
    }
    final labels = dataMap.keys.toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 12),
              Text('Distribution des notes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (dataMap.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2).ceilToDouble(),
                minY: 0,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        if (val.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(labels[val.toInt()], style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: labels.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: dataMap[e.value]!.toDouble(),
                        color: const Color(0xFFDDD6FE),
                        width: 32,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargeSection() {
    final data = (_stats['chargeFormateurs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              Text('Charge horaire des formateurs', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          ...data.map((f) {
            final double done = (f['done'] as num?)?.toDouble() ?? 0.0;
            final double totalTarget = (f['total'] as num?)?.toDouble() ?? 500.0;
            final percent = totalTarget > 0 ? (done / totalTarget).clamp(0.0, 1.0) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(f['nom'], style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${done.toInt()}h / ${totalTarget.toInt()}h', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAvancementSection() {
    final data = (_stats['avancementModules'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chrome_reader_mode_outlined, size: 20, color: Color(0xFF10B981)),
              const SizedBox(width: 12),
              Text('Avancement des modules', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          ...data.map((m) {
            final double done = (m['done'] as num?)?.toDouble() ?? 0.0;
            final double total = (m['total'] as num?)?.toDouble() ?? 100.0;
            final percent = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(m['nom'], style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${done.toInt()}h / ${total.toInt()}h (${(percent * 100).toInt()}%)', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

