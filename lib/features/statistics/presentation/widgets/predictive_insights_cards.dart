import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../providers/predictive_analytics_providers.dart';

/// Grid of predictive insight cards
class PredictiveInsightsGrid extends ConsumerWidget {
  const PredictiveInsightsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(predictiveInsightsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) {
          return _buildEmptyState(colorScheme);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 16 : 16.sp,
                vertical: kIsWindows ? 8 : 8.sp,
              ),
              child: Row(
                children: [
                  Icon(
                    Symbols.insights_rounded,
                    color: colorScheme.primary,
                    size: kIsWindows ? 24 : 24.sp,
                  ),
                  SizedBox(width: kIsWindows ? 8 : 8.w),
                  Text(
                    'Insight Predittivi',
                    style: TextStyle(
                      fontSize: kIsWindows ? 18 : 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => ref.invalidate(predictiveInsightsProvider),
                    icon: const Icon(Symbols.refresh_rounded),
                    tooltip: 'Aggiorna',
                  ),
                ],
              ),
            ),

            // Cards Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 16 : 16.sp,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: kIsWindows ? 2 : 1,
                childAspectRatio: kIsWindows ? 1.5 : 1.8,
                crossAxisSpacing: kIsWindows ? 12 : 12.w,
                mainAxisSpacing: kIsWindows ? 12 : 12.h,
              ),
              itemCount: insights.length,
              itemBuilder: (context, index) {
                return PredictiveInsightCard(
                  insight: insights[index],
                  index: index,
                );
              },
            ),
          ],
        );
      },
      loading: () => _buildLoadingState(colorScheme),
      error: (error, _) => _buildErrorState(colorScheme, error, ref),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Card(
      margin: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      child: Container(
        padding: EdgeInsets.all(kIsWindows ? 32 : 32.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.insights_rounded,
              color: colorScheme.outline,
              size: kIsWindows ? 64 : 64.sp,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              'Nessun insight disponibile',
              style: TextStyle(
                fontSize: kIsWindows ? 16 : 16.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: kIsWindows ? 8 : 8.h),
            Text(
              'Inizia ad utilizzare l\'app per generare analisi predittive',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Card(
      margin: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      child: Container(
        padding: EdgeInsets.all(kIsWindows ? 48 : 48.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              'Analisi dati in corso...',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ColorScheme colorScheme,
    Object error,
    WidgetRef ref,
  ) {
    return Card(
      margin: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      child: Container(
        padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error_rounded,
              color: colorScheme.error,
              size: kIsWindows ? 48 : 48.sp,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              'Errore caricamento insight',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            SizedBox(height: kIsWindows ? 8 : 8.h),
            Text(
              '$error',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: kIsWindows ? 12 : 12.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(predictiveInsightsProvider),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single Predictive Insight Card
class PredictiveInsightCard extends StatelessWidget {
  final PredictiveInsight insight;
  final int index;

  const PredictiveInsightCard({
    required this.insight,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: insight.actionRoute != null
                ? () => _handleAction(context, insight.actionRoute!)
                : null,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getGradientColors(colorScheme),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon and risk badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight.title,
                            style: TextStyle(
                              fontSize: kIsWindows ? 13 : 13.sp,
                              fontWeight: FontWeight.w600,
                              color: _getTextColor(colorScheme),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (insight.riskLevel != null)
                          _RiskBadge(
                            riskLevel: insight.riskLevel!,
                            colorScheme: colorScheme,
                          ),
                      ],
                    ),

                    SizedBox(height: kIsWindows ? 12 : 12.h),

                    // Main value
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          insight.subtitle,
                          style: TextStyle(
                            fontSize: kIsWindows ? 24 : 24.sp,
                            fontWeight: FontWeight.bold,
                            color: _getTextColor(colorScheme),
                          ),
                        ),
                        if (insight.value != null) ...[
                          SizedBox(width: kIsWindows ? 8 : 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: kIsWindows ? 6 : 6.w,
                              vertical: kIsWindows ? 2 : 2.sp,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${insight.value} ${insight.valueLabel ?? ''}',
                              style: TextStyle(
                                fontSize: kIsWindows ? 11 : 11.sp,
                                color: _getTextColor(
                                  colorScheme,
                                ).withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Trend indicator
                    if (insight.trendPercentage != null)
                      Padding(
                        padding: EdgeInsets.only(top: kIsWindows ? 4 : 4.h),
                        child: Row(
                          children: [
                            Icon(
                              _getTrendIcon(),
                              size: kIsWindows ? 14 : 14.sp,
                              color: _getTrendColor(colorScheme),
                            ),
                            SizedBox(width: kIsWindows ? 4 : 4.w),
                            Text(
                              '${insight.trendPercentage!.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: kIsWindows ? 12 : 12.sp,
                                fontWeight: FontWeight.w500,
                                color: _getTrendColor(colorScheme),
                              ),
                            ),
                            SizedBox(width: kIsWindows ? 4 : 4.w),
                            Text(
                              insight.trendLabel,
                              style: TextStyle(
                                fontSize: kIsWindows ? 11 : 11.sp,
                                color: _getTextColor(
                                  colorScheme,
                                ).withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Description
                    Text(
                      insight.description,
                      style: TextStyle(
                        fontSize: kIsWindows ? 11 : 11.sp,
                        color: _getTextColor(
                          colorScheme,
                        ).withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Action button
                    if (insight.actionLabel != null) ...[
                      SizedBox(height: kIsWindows ? 12 : 12.h),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              _handleAction(context, insight.actionRoute!),
                          style: TextButton.styleFrom(
                            foregroundColor: _getTextColor(colorScheme),
                            padding: EdgeInsets.symmetric(
                              horizontal: kIsWindows ? 12 : 12.w,
                              vertical: kIsWindows ? 6 : 6.sp,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                insight.actionLabel!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: kIsWindows ? 4 : 4.w),
                              const Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (100 * index).ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  List<Color> _getGradientColors(ColorScheme colorScheme) {
    // Default subtle gradient
    var baseColor = colorScheme.primaryContainer;

    // Adjust based on risk level
    if (insight.riskLevel == RiskLevel.high) {
      baseColor = colorScheme.errorContainer;
    } else if (insight.riskLevel == RiskLevel.medium) {
      baseColor = colorScheme.secondaryContainer;
    }

    // Adjust based on trend
    if (insight.trend == TrendDirection.up) {
      baseColor = colorScheme.tertiaryContainer;
    }

    return [baseColor.withValues(alpha: 0.8), baseColor];
  }

  Color _getTextColor(ColorScheme colorScheme) {
    if (insight.riskLevel == RiskLevel.high) {
      return colorScheme.onErrorContainer;
    } else if (insight.riskLevel == RiskLevel.medium) {
      return colorScheme.onSecondaryContainer;
    }
    return colorScheme.onPrimaryContainer;
  }

  IconData _getTrendIcon() {
    return switch (insight.trend) {
      TrendDirection.up => Symbols.trending_up,
      TrendDirection.down => Symbols.trending_down,
      TrendDirection.stable => Symbols.trending_flat,
    };
  }

  Color _getTrendColor(ColorScheme colorScheme) {
    return switch (insight.trend) {
      TrendDirection.up => Colors.green,
      TrendDirection.down =>
        insight.riskLevel != null ? colorScheme.error : Colors.orange,
      TrendDirection.stable => colorScheme.outline,
    };
  }

  void _handleAction(BuildContext context, String route) {
    // Navigate to route
    // context.push(route);
  }
}

/// Risk level badge
class _RiskBadge extends StatelessWidget {
  final RiskLevel riskLevel;
  final ColorScheme colorScheme;

  const _RiskBadge({required this.riskLevel, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (riskLevel) {
      RiskLevel.low => (Colors.green, 'BASSO'),
      RiskLevel.medium => (Colors.orange, 'MEDIO'),
      RiskLevel.high => (colorScheme.error, 'ALTO'),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWindows ? 6 : 6.w,
        vertical: kIsWindows ? 2 : 2.sp,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: kIsWindows ? 9 : 9.sp,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// Client Retention Predictions List
class ClientRetentionPredictionsWidget extends ConsumerWidget {
  const ClientRetentionPredictionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictionsAsync = ref.watch(clientRetentionPredictionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return predictionsAsync.when(
      data: (predictions) {
        if (predictions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
                child: Row(
                  children: [
                    Icon(
                      Symbols.psychology_rounded,
                      color: colorScheme.primary,
                    ),
                    SizedBox(width: kIsWindows ? 12 : 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Predizioni Retention',
                            style: TextStyle(
                              fontSize: kIsWindows ? 16 : 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${predictions.where((p) => p.churnRisk != RiskLevel.low).length} clienti a rischio',
                            style: TextStyle(
                              fontSize: kIsWindows ? 12 : 12.sp,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),

              // High risk clients first
              ...predictions.take(5).map((prediction) {
                return _ClientPredictionTile(prediction: prediction);
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ClientPredictionTile extends StatelessWidget {
  final ClientRetentionPrediction prediction;

  const _ClientPredictionTile({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (riskColor, riskLabel) = switch (prediction.churnRisk) {
      RiskLevel.low => (Colors.green, 'Fedele'),
      RiskLevel.medium => (Colors.orange, 'Attenzione'),
      RiskLevel.high => (colorScheme.error, 'A Rischio'),
    };

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: riskColor.withValues(alpha: 0.1),
            child: Text(
              prediction.clientName.substring(0, 1).toUpperCase(),
              style: TextStyle(color: riskColor),
            ),
          ),
          if (prediction.churnRisk == RiskLevel.high)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        prediction.clientName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score: ${prediction.retentionScore.toInt()}/100',
            style: TextStyle(
              fontSize: kIsWindows ? 12 : 12.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (prediction.predictedNextVisit != null)
            Text(
              'Prossima visita stimata: ${_formatDate(prediction.predictedNextVisit!)}',
              style: TextStyle(
                fontSize: kIsWindows ? 11 : 11.sp,
                color: colorScheme.outline,
              ),
            ),
        ],
      ),
      trailing: Chip(
        label: Text(
          riskLabel,
          style: TextStyle(
            fontSize: kIsWindows ? 10 : 10.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: riskColor.withValues(alpha: 0.1),
        side: BorderSide(color: riskColor.withValues(alpha: 0.3)),
        padding: EdgeInsets.zero,
      ),
      onTap: () {
        // Navigate to client details
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Revenue Forecast Widget
class RevenueForecastWidget extends ConsumerWidget {
  const RevenueForecastWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(revenueForecastProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return forecastAsync.when(
      data: (forecast) {
        return Card(
          margin: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
          child: Padding(
            padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Symbols.account_balance_wallet_rounded,
                      color: colorScheme.primary,
                    ),
                    SizedBox(width: kIsWindows ? 12 : 12.w),
                    Expanded(
                      child: Text(
                        'Previsione Fatturato',
                        style: TextStyle(
                          fontSize: kIsWindows ? 16 : 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _ConfidenceBadge(confidence: forecast.confidence),
                  ],
                ),

                SizedBox(height: kIsWindows ? 16 : 16.h),

                // Forecast values
                Row(
                  children: [
                    _ForecastValue(
                      label: 'Oggi',
                      value: '€${forecast.predictedDaily.toStringAsFixed(0)}',
                      color: colorScheme,
                    ),
                    SizedBox(width: kIsWindows ? 16 : 16.w),
                    _ForecastValue(
                      label: 'Questa settimana',
                      value: '€${forecast.predictedWeekly.toStringAsFixed(0)}',
                      color: colorScheme,
                    ),
                    SizedBox(width: kIsWindows ? 16 : 16.w),
                    _ForecastValue(
                      label: 'Questo mese',
                      value: '€${forecast.predictedMonthly.toStringAsFixed(0)}',
                      color: colorScheme,
                      isLarge: true,
                    ),
                  ],
                ),

                SizedBox(height: kIsWindows ? 16 : 16.h),

                // Trend
                Row(
                  children: [
                    Icon(
                      _getTrendIcon(forecast.trend),
                      color: _getTrendColor(forecast.trend, colorScheme),
                      size: kIsWindows ? 20 : 20.sp,
                    ),
                    SizedBox(width: kIsWindows ? 8 : 8.w),
                    Text(
                      'Trend: ${_getTrendLabel(forecast.trend)}',
                      style: TextStyle(
                        color: _getTrendColor(forecast.trend, colorScheme),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  IconData _getTrendIcon(TrendDirection trend) {
    return switch (trend) {
      TrendDirection.up => Symbols.trending_up,
      TrendDirection.down => Symbols.trending_down,
      TrendDirection.stable => Symbols.trending_flat,
    };
  }

  Color _getTrendColor(TrendDirection trend, ColorScheme colorScheme) {
    return switch (trend) {
      TrendDirection.up => Colors.green,
      TrendDirection.down => colorScheme.error,
      TrendDirection.stable => colorScheme.outline,
    };
  }

  String _getTrendLabel(TrendDirection trend) {
    return switch (trend) {
      TrendDirection.up => 'In crescita',
      TrendDirection.down => 'In calo',
      TrendDirection.stable => 'Stabile',
    };
  }
}

class _ForecastValue extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme color;
  final bool isLarge;

  const _ForecastValue({
    required this.label,
    required this.value,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: kIsWindows ? 11 : 11.sp,
              color: color.onSurfaceVariant,
            ),
          ),
          SizedBox(height: kIsWindows ? 4 : 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge
                  ? (kIsWindows ? 20 : 20.sp)
                  : (kIsWindows ? 16 : 16.sp),
              fontWeight: FontWeight.bold,
              color: color.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Affidabilità previsione basata su dati storici',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: kIsWindows ? 8 : 8.w,
          vertical: kIsWindows ? 4 : 4.sp,
        ),
        decoration: BoxDecoration(
          color: _getConfidenceColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getConfidenceColor().withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.psychology_rounded,
              size: kIsWindows ? 14 : 14.sp,
              color: _getConfidenceColor(),
            ),
            SizedBox(width: kIsWindows ? 4 : 4.w),
            Text(
              '${confidence.toInt()}%',
              style: TextStyle(
                fontSize: kIsWindows ? 11 : 11.sp,
                fontWeight: FontWeight.bold,
                color: _getConfidenceColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor() {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }
}
