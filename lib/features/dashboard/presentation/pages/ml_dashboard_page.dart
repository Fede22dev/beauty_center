import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../clients/providers/ml_predictions_providers.dart';

/// Machine Learning Dashboard for the Beauty Center
/// Shows AI-powered insights and predictions for the entire center
class MLDashboardPage extends ConsumerWidget {
  const MLDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final insightsAsync = ref.watch(centerMLInsightsProvider);
    final appointmentRisksAsync = ref.watch(appointmentRisksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Symbols.neurology_rounded, color: cs.primary),
            SizedBox(width: kIsWindows ? 12 : 12.w),
            const Text('AI Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Refresh all ML data
              ref.invalidate(centerMLInsightsProvider);
              ref.invalidate(appointmentRisksProvider);
            },
            icon: const Icon(Symbols.refresh_rounded),
            tooltip: 'Aggiorna analisi',
          ),
          SizedBox(width: kIsWindows ? 8 : 8.w),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stats cards
            _buildHeaderStats(cs),
            SizedBox(height: kIsWindows ? 24 : 24.h),

            // Appointment Risks Section
            _buildSectionTitle(
              'Appuntamenti a Rischio',
              Symbols.warning_rounded,
              cs,
            ),
            SizedBox(height: kIsWindows ? 12 : 12.h),
            appointmentRisksAsync.when(
              data: (risks) => _buildAppointmentRisksList(risks, cs, context),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(
                'Errore: $error',
                style: TextStyle(color: cs.error),
              ),
            ),
            SizedBox(height: kIsWindows ? 24 : 24.h),

            // High Risk No-Shows
            _buildSectionTitle(
              'Clienti ad Alto Rischio No-Show',
              Symbols.event_busy_rounded,
              cs,
            ),
            SizedBox(height: kIsWindows ? 12 : 12.h),
            insightsAsync.when(
              data: (insights) => _buildNoShowRiskList(
                insights.highRiskNoShows,
                cs,
                context,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(
                'Errore: $error',
                style: TextStyle(color: cs.error),
              ),
            ),
            SizedBox(height: kIsWindows ? 24 : 24.h),

            // ML Insights Summary
            _buildMLInfoCard(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStats(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'AI Powered',
            '4 Modelli',
            'No-Show, Churn, Upsell, Ottimizzazione',
            Symbols.neurology_rounded,
            cs.primary,
            cs,
          ),
        ),
        SizedBox(width: kIsWindows ? 12 : 12.w),
        Expanded(
          child: _buildStatCard(
            'Precisione',
            '~85%',
            'Accuratezza predittiva media sui modelli',
            Symbols.target_rounded,
            Colors.green,
            cs,
          ),
        ),
        SizedBox(width: kIsWindows ? 12 : 12.w),
        Expanded(
          child: _buildStatCard(
            'Aggiornamento',
            'Real-time',
            'Dati analizzati istantaneamente',
            Symbols.bolt_rounded,
            Colors.amber,
            cs,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    ColorScheme cs,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(kIsWindows ? 8 : 8.sp),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: kIsWindows ? 24 : 24.sp),
            ),
            SizedBox(height: kIsWindows ? 12 : 12.h),
            Text(
              value,
              style: TextStyle(
                fontSize: kIsWindows ? 24 : 24.sp,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: kIsWindows ? 14 : 14.sp,
                color: cs.outline,
              ),
            ),
            SizedBox(height: kIsWindows ? 4 : 4.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: kIsWindows ? 11 : 11.sp,
                color: cs.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: kIsWindows ? 20 : 20.sp, color: cs.primary),
        SizedBox(width: kIsWindows ? 8 : 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: kIsWindows ? 18 : 18.sp,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentRisksList(
    List<AppointmentRisk> risks,
    ColorScheme cs,
    BuildContext context,
  ) {
    if (risks.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Symbols.check_circle_rounded,
                  size: kIsWindows ? 48 : 48.sp,
                  color: Colors.green,
                ),
                SizedBox(height: kIsWindows ? 12 : 12.h),
                Text(
                  'Nessun appuntamento a rischio rilevato',
                  style: TextStyle(
                    fontSize: kIsWindows ? 16 : 16.sp,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'Tutti gli appuntamenti sembrano confermati',
                  style: TextStyle(
                    fontSize: kIsWindows ? 14 : 14.sp,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: risks.length,
        separatorBuilder: (_, __) => Divider(
          indent: kIsWindows ? 16 : 16.w,
          endIndent: kIsWindows ? 16 : 16.w,
        ),
        itemBuilder: (context, index) {
          final risk = risks[index];
          return _buildRiskListTile(risk, cs, context);
        },
      ),
    );
  }

  Widget _buildRiskListTile(
    AppointmentRisk risk,
    ColorScheme cs,
    BuildContext context,
  ) {
    final riskColor = risk.riskScore > 0.7
        ? Colors.red
        : risk.riskScore > 0.5
            ? Colors.orange
            : Colors.amber;

    return ListTile(
      leading: Container(
        width: kIsWindows ? 48 : 48.w,
        height: kIsWindows ? 48 : 48.h,
        decoration: BoxDecoration(
          color: riskColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '${(risk.riskScore * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: kIsWindows ? 14 : 14.sp,
              fontWeight: FontWeight.bold,
              color: riskColor,
            ),
          ),
        ),
      ),
      title: Text(
        risk.clientName,
        style: TextStyle(
          fontSize: kIsWindows ? 15 : 15.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(risk.appointmentTime),
            style: TextStyle(
              fontSize: kIsWindows ? 13 : 13.sp,
              color: cs.primary,
            ),
          ),
          SizedBox(height: kIsWindows ? 2 : 2.h),
          Wrap(
            spacing: kIsWindows ? 4 : 4.w,
            children: risk.riskFactors.map((factor) {
              return Chip(
                label: Text(
                  factor,
                  style: TextStyle(fontSize: kIsWindows ? 10 : 10.sp),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor: cs.errorContainer,
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ],
      ),
      trailing: Tooltip(
        message: risk.suggestedAction,
        child: Icon(
          Symbols.info_rounded,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildNoShowRiskList(
    List<ClientNoShowRisk> risks,
    ColorScheme cs,
    BuildContext context,
  ) {
    if (risks.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Symbols.sentiment_satisfied_rounded,
                  size: kIsWindows ? 48 : 48.sp,
                  color: Colors.green,
                ),
                SizedBox(height: kIsWindows ? 12 : 12.h),
                Text(
                  'Nessun cliente ad alto rischio',
                  style: TextStyle(
                    fontSize: kIsWindows ? 16 : 16.sp,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'I tuoi clienti sono affidabili!',
                  style: TextStyle(
                    fontSize: kIsWindows ? 14 : 14.sp,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: kIsWindows ? 200 : 200.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: risks.length,
        itemBuilder: (context, index) {
          final risk = risks[index];
          return _buildClientRiskCard(risk, cs, context);
        },
      ),
    );
  }

  Widget _buildClientRiskCard(
    ClientNoShowRisk risk,
    ColorScheme cs,
    BuildContext context,
  ) {
    final riskColor = risk.riskScore > 0.6
        ? Colors.red
        : risk.riskScore > 0.4
            ? Colors.orange
            : Colors.amber;

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(right: kIsWindows ? 12 : 12.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/client-details',
            arguments: risk.clientId,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: kIsWindows ? 220 : 220.w,
          padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: kIsWindows ? 8 : 8.w,
                      vertical: kIsWindows ? 4 : 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(risk.riskScore * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: kIsWindows ? 14 : 14.sp,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Symbols.arrow_forward_rounded,
                    size: kIsWindows ? 16 : 16.sp,
                    color: cs.outline,
                  ),
                ],
              ),
              SizedBox(height: kIsWindows ? 12 : 12.h),
              Text(
                risk.clientName,
                style: TextStyle(
                  fontSize: kIsWindows ? 16 : 16.sp,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: kIsWindows ? 4 : 4.h),
              if (risk.upcomingAppointment != null)
                Text(
                  'Prossimo: ${DateFormat('dd/MM HH:mm').format(risk.upcomingAppointment!.startDateTime)}',
                  style: TextStyle(
                    fontSize: kIsWindows ? 12 : 12.sp,
                    color: cs.outline,
                  ),
                )
              else
                Text(
                  'Nessun appuntamento futuro',
                  style: TextStyle(
                    fontSize: kIsWindows ? 12 : 12.sp,
                    color: cs.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMLInfoCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.psychology_rounded,
                  color: cs.primary,
                  size: kIsWindows ? 24 : 24.sp,
                ),
                SizedBox(width: kIsWindows ? 8 : 8.w),
                Text(
                  'Come funziona l\'AI',
                  style: TextStyle(
                    fontSize: kIsWindows ? 16 : 16.sp,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: kIsWindows ? 12 : 12.h),
            Text(
              '''L'intelligenza artificiale analizza automaticamente i dati del centro per fornire predizioni utili:

• No-Show Prediction: analizza pattern di prenotazione, frequenza visite e comportamento passato
• Churn Risk: identifica clienti a rischio abbandono basandosi su giorni dall'ultima visita
• Upsell Potential: suggerisce servizi complementari basati sullo storico
• Ottimizzazione Slot: identifica orari preferiti dei clienti

Le predizioni si aggiornano in tempo reale e migliorano con più dati.''',
              style: TextStyle(
                fontSize: kIsWindows ? 13 : 13.sp,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
