import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tabs/app_tabs.dart';

/// Optimized loading screen shown during app startup
/// Shows branded splash with smooth transition to app
class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({required this.child, super.key});

  final Widget child;

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showContent = false;
  bool _fadeOutSplash = false;
  bool _isControllerDisposed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Start loading sequence
    _startLoadingSequence();
  }

  Future<void> _startLoadingSequence() async {
    // Phase 1: Show splash with animation (500ms)
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Phase 2: Fade in content behind splash
    setState(() => _showContent = true);

    // Phase 3: Let content render
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    // Phase 4: Fade out splash to reveal content
    setState(() => _fadeOutSplash = true);

    // Phase 5: Complete transition
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    if (!_isControllerDisposed) {
      _controller.dispose();
      _isControllerDisposed = true;
    }
  }

  @override
  void dispose() {
    if (!_isControllerDisposed) {
      _controller.dispose();
      _isControllerDisposed = true;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main app content (loaded immediately but hidden)
        AnimatedOpacity(
          opacity: _showContent ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: widget.child,
        ),

        // Branded splash overlay
        AnimatedOpacity(
          opacity: _fadeOutSplash ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: _buildSplashContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildSplashContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = AppTabs.clients.color;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App icon/logo
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, color: Colors.white24)
              .scaleXY(
                begin: 0.9,
                end: 1.0,
                duration: 600.ms,
                curve: Curves.easeOutCubic,
              ),

          const SizedBox(height: 32),

          // App name
          Text(
                'Beauty Center',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              )
              .animate()
              .fadeIn(delay: 200.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 12),

          // Tagline
          Text(
            'Gestione professionale per centri estetici',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

          const SizedBox(height: 48),

          // Loading indicator
          SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              borderRadius: BorderRadius.circular(4),
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 300.ms),
        ],
      ),
    );
  }
}

/// Skeleton loading placeholder for lists
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 5, this.itemHeight = 80, super.key});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonCard(height: itemHeight)
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 1000.ms),
    );
  }
}

/// Skeleton card placeholder
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({this.height = 80, this.showAvatar = true, super.key});

  final double height;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (showAvatar) ...[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for images while loading
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    this.width,
    this.height,
    this.borderRadius,
    super.key,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: borderRadius,
          ),
          child: Icon(Icons.image_outlined, color: colorScheme.outline),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1200.ms);
  }
}

/// Fade-in widget wrapper for smooth content appearance
class FadeInContent extends StatelessWidget {
  const FadeInContent({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(delay: delay, duration: 400.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
