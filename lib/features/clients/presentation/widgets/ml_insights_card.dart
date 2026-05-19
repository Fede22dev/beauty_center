import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../providers/ml_predictions_providers.dart';

/// Card widget to display ML insights for a client
class ClientMLInsightsCard extends ConsumerWidget {
  const ClientMLInsightsCard({required this.clientId, super.key});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mlProfileAsync = ref.watch(clientMLProfileProvider(clientId));
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: mlProfileAsync.when(
          data: (profile) => _buildContent(context, profile, cs),
          loading: () =>
              const Center(heightFactor: 2, child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Errore analisi: $error',
              style: TextStyle(color: cs.error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ClientMLProfile profile,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with AI badge
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(kIsWindows ? 8 : 8.sp),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Symbols.neurology_rounded,
                color: cs.onPrimaryContainer,
                size: kIsWindows ? 24 : 24.sp,
              ),
            ),
            SizedBox(width: kIsWindows ? 12 : 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Insights',
                    style: TextStyle(
                      fontSize: kIsWindows ? 18 : 18.sp,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Analisi predittiva cliente',
                    style: TextStyle(
                      fontSize: kIsWindows ? 13 : 13.sp,
                      color: cs.outline,
                    ),
                  ),
                ],
              ),
            ),
            // Risk level chip
            Chip(
              label: Text(
                'Rischio ${profile.riskLevel}',
                style: TextStyle(
                  fontSize: kIsWindows ? 12 : 12.sp,
                  color: profile.riskColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: profile.riskColor.withValues(alpha: 0.1),
              side: BorderSide(color: profile.riskColor.withValues(alpha: 0.3)),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        SizedBox(height: kIsWindows ? 16 : 16.h),

        // Risk indicators row
        Row(
          children: [
            Expanded(
              child: _buildRiskIndicator(
                'No-Show',
                profile.noShowProbability,
                Symbols.event_busy_rounded,
                cs,
              ),
            ),
            SizedBox(width: kIsWindows ? 8 : 8.w),
            Expanded(
              child: _buildRiskIndicator(
                'Tasso abbandono',
                profile.churnRisk,
                Symbols.person_off_rounded,
                cs,
              ),
            ),
            SizedBox(width: kIsWindows ? 8 : 8.w),
            Expanded(
              child: _buildRiskIndicator(
                'Vendita',
                profile.upsellPotential,
                Symbols.trending_up_rounded,
                cs,
                isPositive: true,
              ),
            ),
          ],
        ),
        SizedBox(height: kIsWindows ? 16 : 16.h),

        // Next visit prediction
        if (profile.predictedNextVisit != null) ...[
          _buildPredictionCard(
            'Prossima visita prevista',
            '${profile.predictedVisit!.predictedDate.day}/${profile.predictedVisit!.predictedDate.month}/${profile.predictedVisit!.predictedDate.year}',
            'Intervallo medio: ${profile.predictedNextVisit!.averageIntervalDays.toStringAsFixed(0)} giorni',
            Symbols.event_rounded,
            cs.primary,
            cs,
          ),
          SizedBox(height: kIsWindows ? 12 : 12.h),
        ],

        // Optimal slots
        if (profile.optimalTimeSlots.isNotEmpty) ...[
          _buildSectionTitle(
            'Orari preferiti del cliente',
            Symbols.schedule_rounded,
            cs,
          ),
          SizedBox(height: kIsWindows ? 8 : 8.h),
          Wrap(
            spacing: kIsWindows ? 8 : 8.w,
            runSpacing: kIsWindows ? 8 : 8.h,
            children: profile.optimalTimeSlots.take(3).map((slot) {
              return Chip(
                avatar: Icon(
                  Symbols.access_time_rounded,
                  size: kIsWindows ? 16 : 16.sp,
                  color: cs.primary,
                ),
                label: Text(
                  '${slot.weekdayName} ${slot.timeLabel}',
                  style: TextStyle(fontSize: kIsWindows ? 12 : 12.sp),
                ),
                backgroundColor: cs.primaryContainer,
              );
            }).toList(),
          ),
          SizedBox(height: kIsWindows ? 12 : 12.h),
        ],

        // Service recommendations
        if (profile.serviceRecommendations.isNotEmpty) ...[
          _buildSectionTitle('Suggerimenti AI', Symbols.lightbulb_rounded, cs),
          SizedBox(height: kIsWindows ? 8 : 8.h),
          ...profile.serviceRecommendations.map((rec) {
            return _buildRecommendationTile(rec, cs);
          }),
        ],

        // Last updated
        SizedBox(height: kIsWindows ? 12 : 12.h),
        Center(
          child: Text(
            'Analisi aggiornata: ${_formatDate(profile.lastUpdated)}',
            style: TextStyle(
              fontSize: kIsWindows ? 11 : 11.sp,
              color: cs.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskIndicator(
    String label,
    double value,
    IconData icon,
    ColorScheme cs, {
    bool isPositive = false,
  }) {
    final percentage = (value * 100).toStringAsFixed(0);
    Color color;

    if (isPositive) {
      // For upsell, higher is better
      if (value > 0.6)
        color = Colors.green;
      else if (value > 0.3)
        color = Colors.orange;
      else
        color = cs.outline;
    } else {
      // For risks, higher is worse
      if (value > 0.6)
        color = Colors.red;
      else if (value > 0.3)
        color = Colors.orange;
      else
        color = Colors.green;
    }

    return Container(
      padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: kIsWindows ? 20 : 20.sp, color: color),
          SizedBox(height: kIsWindows ? 4 : 4.h),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: kIsWindows ? 16 : 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: kIsWindows ? 11 : 11.sp,
              color: cs.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    ColorScheme cs,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(kIsWindows ? 8 : 8.sp),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: kIsWindows ? 20 : 20.sp),
          ),
          SizedBox(width: kIsWindows ? 12 : 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: kIsWindows ? 12 : 12.sp,
                    color: cs.outline,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: kIsWindows ? 16 : 16.sp,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: kIsWindows ? 11 : 11.sp,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: kIsWindows ? 16 : 16.sp, color: cs.primary),
        SizedBox(width: kIsWindows ? 6 : 6.w),
        Text(
          title,
          style: TextStyle(
            fontSize: kIsWindows ? 14 : 14.sp,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationTile(ServiceRecommendation rec, ColorScheme cs) {
    return Container(
      margin: EdgeInsets.only(bottom: kIsWindows ? 8 : 8.h),
      padding: EdgeInsets.all(kIsWindows ? 10 : 10.sp),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(kIsWindows ? 6 : 6.sp),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.star_rounded,
              size: kIsWindows ? 16 : 16.sp,
              color: Colors.amber,
            ),
          ),
          SizedBox(width: kIsWindows ? 10 : 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.serviceName,
                  style: TextStyle(
                    fontSize: kIsWindows ? 14 : 14.sp,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  rec.reason,
                  style: TextStyle(
                    fontSize: kIsWindows ? 12 : 12.sp,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: kIsWindows ? 8 : 8.w,
              vertical: kIsWindows ? 4 : 4.h,
            ),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(rec.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: kIsWindows ? 11 : 11.sp,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// Extension to fix the typo in the class
extension on ClientMLProfile {
  DateTimePrediction? get predictedVisit => predictedNextVisit;
}
