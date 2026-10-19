import 'package:flutter/material.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

enum AsyncScreenStatus { loading, empty, error, success }

/// Shared loading, empty, error-with-retry, and success body for screens.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.status,
    required this.onRetry,
    required this.empty,
    required this.child,
    this.errorMessage,
  });

  final AsyncScreenStatus status;
  final VoidCallback onRetry;
  final Widget empty;
  final Widget child;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AsyncScreenStatus.loading:
        return const _LoadingBody();
      case AsyncScreenStatus.empty:
        return empty;
      case AsyncScreenStatus.error:
        return _ErrorBody(
          message: errorMessage ?? AppStrings.errorGeneric,
          onRetry: onRetry,
        );
      case AsyncScreenStatus.success:
        return child;
    }
  }
}

class _LoadingBody extends StatefulWidget {
  const _LoadingBody();

  @override
  State<_LoadingBody> createState() => _LoadingBodyState();
}

class _LoadingBodyState extends State<_LoadingBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.loading,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;
          return ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Top skeleton card
              _buildShimmerBox(height: 84, borderRadius: 12, t: t),
              const SizedBox(height: 16),
              // Filter chips row skeleton
              Row(
                children: [
                  _buildShimmerBox(
                    width: 80,
                    height: 32,
                    borderRadius: 999,
                    t: t,
                  ),
                  const SizedBox(width: 8),
                  _buildShimmerBox(
                    width: 100,
                    height: 32,
                    borderRadius: 999,
                    t: t,
                  ),
                  const SizedBox(width: 8),
                  _buildShimmerBox(
                    width: 90,
                    height: 32,
                    borderRadius: 999,
                    t: t,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // List item skeletons
              for (var i = 0; i < 3; i++) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildShimmerBox(
                            width: 36,
                            height: 36,
                            borderRadius: 18,
                            t: t,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildShimmerBox(
                                width: 110,
                                height: 12,
                                borderRadius: 4,
                                t: t,
                              ),
                              const SizedBox(height: 6),
                              _buildShimmerBox(
                                width: 70,
                                height: 10,
                                borderRadius: 4,
                                t: t,
                              ),
                            ],
                          ),
                          const Spacer(),
                          _buildShimmerBox(
                            width: 50,
                            height: 20,
                            borderRadius: 999,
                            t: t,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildShimmerBox(
                        width: double.infinity,
                        height: 12,
                        borderRadius: 4,
                        t: t,
                      ),
                      const SizedBox(height: 6),
                      _buildShimmerBox(
                        width: 220,
                        height: 12,
                        borderRadius: 4,
                        t: t,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF09090B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SECURE BUFFER SYNCING...',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF71717A).withValues(
                          alpha: 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmerBox({
    double? width,
    required double height,
    required double borderRadius,
    required double t,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + 3.0 * t, 0),
          end: Alignment(-0.5 + 3.0 * t, 0),
          colors: const [
            Color(0xFFF4F4F5),
            Color(0xFFE4E4E7),
            Color(0xFFF4F4F5),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
