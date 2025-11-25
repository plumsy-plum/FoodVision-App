import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../sevices/StepTrackerProvider.dart';

class StepTrackerCard extends StatefulWidget {
  const StepTrackerCard({
    super.key,
    this.showWeeklyChart = true,
    this.enableCelebrations = true,
    this.compact = false,
  });

  final bool showWeeklyChart;
  final bool enableCelebrations;
  final bool compact;

  @override
  State<StepTrackerCard> createState() => _StepTrackerCardState();
}

class _StepTrackerCardState extends State<StepTrackerCard> {
  ConfettiController? _confettiController;

  @override
  void initState() {
    super.initState();
    if (widget.enableCelebrations) {
      _confettiController =
          ConfettiController(duration: const Duration(seconds: 2));
    }
  }

  @override
  void didUpdateWidget(covariant StepTrackerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableCelebrations && _confettiController == null) {
      _confettiController =
          ConfettiController(duration: const Duration(seconds: 2));
    } else if (!widget.enableCelebrations && _confettiController != null) {
      _confettiController?.dispose();
      _confettiController = null;
    }
  }

  @override
  void dispose() {
    _confettiController?.dispose();
    super.dispose();
  }

  void _maybeCelebrate(StepTrackerProvider provider) {
    if (!widget.enableCelebrations || _confettiController == null) return;
    if (provider.shouldCelebrate) {
      _confettiController!.play();
      provider.acknowledgeCelebration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<StepTrackerProvider>(
      builder: (context, stepProvider, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeCelebrate(stepProvider);
        });

        final double circleSize = widget.compact ? 140 : 170;
        final double padding = widget.compact ? 14 : 20;
        final double numberSize = widget.compact ? 30 : 38;

        final weeklyData = stepProvider.weeklyStepsData;
        final bool showWeeklyChart =
            widget.showWeeklyChart && weeklyData.isNotEmpty;
        final maxSteps = weeklyData.fold<int>(
            stepProvider.dailyGoal, (max, entry) => entry.steps > max ? entry.steps : max);

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF1F1F1F), Color(0xFF0D0D0D)]
                      : const [Color(0xFF5DE0E6), Color(0xFF004AAD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(widget.compact ? 18 : 24),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.45)
                        : Colors.blueGrey.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: circleSize,
                        width: circleSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: stepProvider.progress,
                              ),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeInOut,
                              builder: (context, value, _) {
                                return CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: widget.compact ? 10 : 12,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  valueColor: const AlwaysStoppedAnimation(
                                      Colors.white),
                                );
                              },
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(
                                          scale: animation, child: child),
                                  child: Text(
                                    '${stepProvider.dailySteps}',
                                    key: ValueKey(stepProvider.dailySteps),
                                    style: TextStyle(
                                      fontSize: numberSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'steps',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Goal: ${stepProvider.dailyGoal}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: widget.compact ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _MetricChip(
                              label: 'Distance',
                              value:
                                  '${stepProvider.distanceKm.toStringAsFixed(2)} km',
                            ),
                            const SizedBox(height: 8),
                            _MetricChip(
                              label: 'Calories',
                              value:
                                  '${stepProvider.caloriesBurned.toStringAsFixed(0)} kcal',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (stepProvider.permissionDenied)
                    _PermissionBanner(
                      onGrant: stepProvider.retryPermissionRequest,
                    )
                  else if (!stepProvider.isTracking)
                    Text(
                      'Connect a physical device and keep the app open to start counting steps.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: widget.compact ? 12 : 13,
                      ),
                    )
                  else
                    Text(
                      'Keep moving! We update this in real time while you walk.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: widget.compact ? 12 : 13,
                      ),
                    ),
                  if (showWeeklyChart) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Last 7 days',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: widget.compact ? 14 : 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: widget.compact ? 140 : 160,
                      child: BarChart(
                        BarChartData(
                          barGroups: List.generate(
                            weeklyData.length,
                            (index) => _buildBar(
                              index,
                              weeklyData[index].steps.toDouble(),
                              stepProvider.dailyGoal.toDouble(),
                            ),
                          ),
                          maxY: maxSteps.toDouble(),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles:
                                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles:
                                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles:
                                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= weeklyData.length) {
                                    return const SizedBox();
                                  }
                                  final day = weeklyData[index].date;
                                  final label = _dayLabel(day.weekday);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                        fontSize: widget.compact ? 10 : 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.enableCelebrations && _confettiController != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ConfettiWidget(
                    confettiController: _confettiController!,
                    blastDirectionality: BlastDirectionality.explosive,
                    maxBlastForce: 25,
                    minBlastForce: 8,
                    emissionFrequency: 0.02,
                    numberOfParticles: 20,
                    gravity: 0.2,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _dayLabel(int weekday) {
    const labels = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    return labels[weekday] ?? '';
  }

  BarChartGroupData _buildBar(int index, double steps, double goal) {
    final normalized = steps == 0 ? 0.5 : steps;
    final hitGoal = steps >= goal;

    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: normalized,
          width: widget.compact ? 10 : 14,
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: hitGoal
                ? const [Color(0xFFFFC107), Color(0xFFFF9800)]
                : const [Colors.white, Color(0xFFE0F7FA)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: goal,
            color: Colors.white.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onGrant});

  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We need motion permissions to track your steps.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
          ),
          onPressed: onGrant,
          icon: const Icon(Icons.directions_walk),
          label: const Text('Grant Permission'),
        ),
      ],
    );
  }
}

