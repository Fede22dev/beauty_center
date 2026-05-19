import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/widgets/pin/secure_page_wrapper.dart';
import '../../providers/shop_statistics_providers.dart';
import '../widgets/predictive_insights_cards.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final _log = AppLogger.getLogger(name: 'StatisticsPage');

  late final ScrollController _scrollController;
  late final double _scrollbarThickness;
  var _isScrollbarNeeded = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollbarThickness = kIsWindows ? 8.0 : 0.0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_scrollbarThickness > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final isNeeded =
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0;
        if (isNeeded != _isScrollbarNeeded && mounted) {
          setState(() => _isScrollbarNeeded = isNeeded);
        }
      });
    }

    _log.finest('build');

    return SecurePageWrapper(
      pageColor: AppTabs.statistics.color,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: kIsWindows ? 10 : 0),
        child: Scrollbar(
          controller: _scrollController,
          thickness: _scrollbarThickness,
          thumbVisibility: kIsWindows,
          interactive: kIsWindows,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: AnimatedPadding(
              duration: kDefaultAppAnimationsDuration,
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(
                kIsWindows ? 16 : 8.w,
                0,
                (kIsWindows ? 16 : 8.w) +
                    (_isScrollbarNeeded ? _scrollbarThickness : 0),
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: kIsWindows ? 8 : 8.h),

                  // Page Title
                  _buildPageTitle(colorScheme),
                  SizedBox(height: kIsWindows ? 16 : 16.h),

                  // Predictive Analytics Insights
                  const PredictiveInsightsGrid(),
                  SizedBox(height: kIsWindows ? 24 : 24.h),

                  // KPI Overview Cards
                  _buildKPIGrid(colorScheme),
                  SizedBox(height: kIsWindows ? 24 : 24.h),
                  
                  // Revenue Section
                  _buildRevenueSection(colorScheme),
                  SizedBox(height: kIsWindows ? 24 : 24.h),
                  
                  // Client Analytics Section
                  _buildClientSection(colorScheme),
                  SizedBox(height: kIsWindows ? 24 : 24.h),
                  
                  // Service & Appointment Analytics
                  _buildServiceSection(colorScheme),
                  SizedBox(
                    height: kIsWindows ? 0 : kBottomNavigationBarHeight + 28.h,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageTitle(ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTabs.statistics.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Symbols.show_chart_rounded,
            color: AppTabs.statistics.color,
            size: 28,
          ),
        ),
        SizedBox(width: kIsWindows ? 12 : 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Analytics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              'Panoramica del centro estetico',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildKPIGrid(ColorScheme colorScheme) {
    final overviewAsync = ref.watch(shopOverviewProvider);

    return overviewAsync.when(
      data: (overview) => LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: kIsWindows ? 12 : 12.w,
            mainAxisSpacing: kIsWindows ? 12 : 12.h,
            childAspectRatio: crossAxisCount == 4 ? 1.6 : 1.4,
            children: [
              _KPICard(
                title: 'Fatturato Totale',
                value: '€${_formatCurrency(overview.totalRevenue)}',
                subtitle: 'Tutti i tempi',
                icon: Symbols.payments_rounded,
                color: colorScheme.primary,
                trend: '+${overview.revenueGrowthRate.toStringAsFixed(1)}%',
                trendUp: overview.revenueGrowthRate >= 0,
              ),
              _KPICard(
                title: 'Oggi',
                value: '€${_formatCurrency(overview.todayRevenue)}',
                subtitle: '${overview.appointmentsToday} appuntamenti',
                icon: Symbols.today_rounded,
                color: Colors.green,
                trend: 'in tempo reale',
              ),
              _KPICard(
                title: 'Clienti Totali',
                value: '${overview.totalClients}',
                subtitle: '+${overview.newClientsThisMonth} questo mese',
                icon: Symbols.group_rounded,
                color: Colors.blue,
              ),
              _KPICard(
                title: 'Ticket Medio',
                value: '€${_formatCurrency(overview.averageTicket)}',
                subtitle: 'Per transazione',
                icon: Symbols.receipt_rounded,
                color: Colors.orange,
              ),
            ],
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
        },
      ),
      loading: () => _buildKPISkeleton(colorScheme),
      error: (err, stack) => _buildErrorCard('Errore KPI', err.toString()),
    );
  }

  Widget _buildKPISkeleton(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: kIsWindows ? 12 : 12.w,
          mainAxisSpacing: kIsWindows ? 12 : 12.h,
          childAspectRatio: crossAxisCount == 4 ? 1.6 : 1.4,
          children: List.generate(
            4,
            (i) => Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRevenueSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Fatturato & Trend',
          Symbols.trending_up_rounded,
          colorScheme,
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _RevenueChartCard(colorScheme: colorScheme),
                  ),
                  SizedBox(width: kIsWindows ? 16 : 16.w),
                  Expanded(
                    child: _RevenueByCategoryCard(colorScheme: colorScheme),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _RevenueChartCard(colorScheme: colorScheme),
                SizedBox(height: kIsWindows ? 12 : 12.h),
                _RevenueByCategoryCard(colorScheme: colorScheme),
              ],
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildClientSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Analytics Clienti',
          Symbols.person_search_rounded,
          colorScheme,
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ClientRetentionCard(colorScheme: colorScheme),
                  ),
                  SizedBox(width: kIsWindows ? 16 : 16.w),
                  Expanded(
                    child: _TopClientsCard(colorScheme: colorScheme),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _ClientRetentionCard(colorScheme: colorScheme),
                SizedBox(height: kIsWindows ? 12 : 12.h),
                _TopClientsCard(colorScheme: colorScheme),
              ],
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  Widget _buildServiceSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Servizi & Appuntamenti',
          Symbols.spa_rounded,
          colorScheme,
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TopServicesCard(colorScheme: colorScheme),
                  ),
                  SizedBox(width: kIsWindows ? 16 : 16.w),
                  Expanded(
                    child: _TimeSlotDistributionCard(colorScheme: colorScheme),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _TopServicesCard(colorScheme: colorScheme),
                SizedBox(height: kIsWindows ? 12 : 12.h),
                _TimeSlotDistributionCard(colorScheme: colorScheme),
              ],
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String title, String error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Symbols.error_rounded, color: Colors.red),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(error, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}

// ============================================================================
// KPI CARD WIDGET
// ============================================================================

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool? trendUp;

  const _KPICard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trend,
    this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trendUp == true
                          ? Colors.green.withValues(alpha: 0.1)
                          : trendUp == false
                              ? Colors.red.withValues(alpha: 0.1)
                              : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trend!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: trendUp == true
                            ? Colors.green
                            : trendUp == false
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REVENUE CHART CARD
// ============================================================================

class _RevenueChartCard extends ConsumerWidget {
  final ColorScheme colorScheme;

  const _RevenueChartCard({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyDataAsync = ref.watch(monthlyRevenueTrendProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 20 : 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trend Fatturato',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ultimi 12 mesi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: kIsWindows ? 20 : 16.h),
            SizedBox(
              height: kIsWindows ? 200 : 180.h,
              child: monthlyDataAsync.when(
                data: (data) => _buildChart(data),
                loading: () => Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => Center(
                  child: Icon(Symbols.error_rounded, color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<MonthlyRevenueData> data) {
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.revenue);
    }).toList();

    final maxY = data.isNotEmpty
        ? data.map((d) => d.revenue).reduce((a, b) => a > b ? a : b)
        : 100;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '€${(value / 1000).toStringAsFixed(0)}k',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length && index % 2 == 0) {
                  return Text(
                    data[index].monthName,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REVENUE BY CATEGORY CARD
// ============================================================================

class _RevenueByCategoryCard extends ConsumerWidget {
  final ColorScheme colorScheme;

  const _RevenueByCategoryCard({required this.colorScheme});

  final colors = const [
    Color(0xFF6750A4), // Primary
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF2196F3), // Blue
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryDataAsync = ref.watch(revenueByCategoryProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 20 : 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Per Categoria',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: kIsWindows ? 16 : 12.h),
            categoryDataAsync.when(
              data: (data) => _buildContent(data),
              loading: () => Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Center(
                child: Icon(Symbols.error_rounded, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<RevenueByCategory> data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'Nessun dato disponibile',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final color = colors[index % colors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${item.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: item.percentage / 100,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                    SizedBox(height: 2),
                    Text(
                      '€${NumberFormat('#,##0').format(item.amount)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// CLIENT RETENTION CARD
// ============================================================================

class _ClientRetentionCard extends ConsumerWidget {
  final ColorScheme colorScheme;

  const _ClientRetentionCard({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retentionAsync = ref.watch(clientRetentionMetricsProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 20 : 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.loyalty_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Retention Clienti',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: kIsWindows ? 20 : 16.h),
            retentionAsync.when(
              data: (metrics) => _buildMetrics(metrics),
              loading: () => Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Center(
                child: Icon(Symbols.error_rounded, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(ClientRetentionMetrics metrics) {
    return Row(
      children: [
        Expanded(
          child: _buildDonutChart(metrics),
        ),
        SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              _buildLegendItem(
                'Attivi',
                metrics.activeClients,
                Colors.green,
                metrics.activePercentage,
              ),
              SizedBox(height: 12),
              _buildLegendItem(
                'A Rischio',
                metrics.atRiskClients,
                Colors.orange,
                metrics.atRiskPercentage,
              ),
              SizedBox(height: 12),
              _buildLegendItem(
                'Persi',
                metrics.lostClients,
                Colors.red,
                metrics.lostPercentage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(ClientRetentionMetrics metrics) {
    final total = metrics.activeClients + metrics.atRiskClients + metrics.lostClients;
    if (total == 0) {
      return Container(
        height: 100,
        child: Center(
          child: Text('Nessun dato', style: TextStyle(fontSize: 12)),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 35,
          sections: [
            PieChartSectionData(
              value: metrics.activeClients.toDouble(),
              color: Colors.green,
              radius: 20,
              showTitle: false,
            ),
            PieChartSectionData(
              value: metrics.atRiskClients.toDouble(),
              color: Colors.orange,
              radius: 20,
              showTitle: false,
            ),
            PieChartSectionData(
              value: metrics.lostClients.toDouble(),
              color: Colors.red,
              radius: 20,
              showTitle: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    int count,
    Color color,
    double percentage,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '$count (${percentage.toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TOP CLIENTS CARD
// ============================================================================

class _TopClientsCard extends ConsumerWidget {
  final ColorScheme colorScheme;

  const _TopClientsCard({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topClientsAsync = ref.watch(topClientsByRevenueProvider(limit: 5));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 20 : 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.emoji_events_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Top Clienti',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: kIsWindows ? 16 : 12.h),
            topClientsAsync.when(
              data: (clients) => _buildList(clients),
              loading: () => Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Center(
                child: Icon(Symbols.error_rounded, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<TopClientData> clients) {
    if (clients.isEmpty) {
      return Center(
        child: Text(
          'Nessun dato disponibile',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: clients.asMap().entries.map((entry) {
        final index = entry.key;
        final client = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: index < 3
                      ? Colors.amber.withValues(alpha: 0.2)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: index < 3 ? Colors.amber.shade700 : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.clientName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '€${NumberFormat('#,##0.00').format(client.totalRevenue)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// TOP SERVICES CARD
// ============================================================================

class _TopServicesCard extends ConsumerWidget {
  final ColorScheme colorScheme;

  const _TopServicesCard({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topServicesAsync = ref.watch(topPerformingServicesProvider(limit: 5));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 20 : 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.favorite_rounded,
                  color: Colors.pink,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Servizi Top',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: kIsWindows ? 16 : 12.h),
            topServicesAsync.when(
              data: (services) => _buildList(services),
              loading: () => Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Center(
                child: Icon(Symbols.error_rounded, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<TopServiceData> services) {
    if (services.isEmpty) {
      return Center(
        child: Text(
          'Nessun dato disponibile',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: services.asMap().entries.map((entry) {
        final index = entry.key;
        final service = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.pink.withValues(alpha: 0.3),
                      Colors.purple.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.serviceName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${service.usageCount} sedute',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// TIME SLOT DISTRIBUTION CARD
// ============================================================================

class _TimeSlotDistributionCard extends ConsumerWidget {
  final ColorScheme colorScheme;

  const _TimeSlotDistributionCard({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(servicePopularityByTimeSlotProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 20 : 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.schedule_rounded,
                  color: Colors.teal,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Fasce Orarie',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: kIsWindows ? 20 : 16.h),
            slotsAsync.when(
              data: (slots) => _buildChart(slots),
              loading: () => Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Center(
                child: Icon(Symbols.error_rounded, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<TimeSlotPopularity> slots) {
    final maxCount = slots.isNotEmpty
        ? slots.map((s) => s.appointmentCount).reduce((a, b) => a > b ? a : b)
        : 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: slots.map((slot) {
        final height = maxCount > 0
            ? (slot.appointmentCount / maxCount) * 80
            : 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 40,
              height: height + 20,
              alignment: Alignment.bottomCenter,
              child: Text(
                '${slot.appointmentCount}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: 40,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.teal,
                    Colors.teal.shade300,
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              slot.timeSlot.split(' ')[0],
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

