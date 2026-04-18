import 'dart:io';

void main() {
  final file = File('lib/screens/patient/queue_tab.dart');
  var text = file.readAsStringSync();

  // 1. Remove _getWaitTimeColor and _getStepperIndex
  text = text.replaceAll(
    RegExp(
      r'  Color _getWaitTimeColor\([^}]+\}\s+',
      multiLine: true,
      dotAll: true,
    ),
    '',
  );
  text = text.replaceAll(
    RegExp(
      r'  int _getStepperIndex\([^}]+\}\s+',
      multiLine: true,
      dotAll: true,
    ),
    '',
  );

  // 2. Replace _buildProgressStepper call
  text = text.replaceAll(
    '                  _buildProgressStepper(currentAppointment),',
    '                  QueueProgressWidget(\n                    stepperAnimation: _stepperAnimation,\n                    appointmentData: currentAppointment,\n                  ),',
  );

  // 3. Remove _buildProgressStepper and _buildStepIcon definitions
  text = text.replaceAll(
    RegExp(
      r'  // ── Feature 6: Animated Progress Stepper ────────────────────────.*?  // ── Main Active Queue Card ──────────────────────────────────────',
      multiLine: true,
      dotAll: true,
    ),
    '  // ── Main Active Queue Card ──────────────────────────────────────',
  );

  // 4. Replace Stats Row
  final statsRow =
      '''                    // ── Stats Row with Feature 1: Countdown + Feature 13: Color Arc ──
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatBadge(
                            icon: Icons.people_rounded,
                            value: '\$pAhead',
                            label: 'Patients Ahead',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildCountdownBadge(wTime)),
                      ],
                    ),''';
  final statsReplacement =
      '''                    // ── Stats Row with Feature 1: Countdown + Feature 13: Color Arc ──
                    QueueStatsWidget(
                      patientsAhead: pAhead,
                      estimatedWaitTime: wTime,
                    ),''';
  text = text.replaceAll(statsRow, statsReplacement);

  // 5. Remove _buildCountdownBadge and _buildStatBadge definitions
  text = text.replaceAll(
    RegExp(
      r'  // ── Feature 1 & 13: Countdown Badge with Color Arc ──────────────.*?  // ── Queue Timeline ──────────────────────────────────────────────',
      multiLine: true,
      dotAll: true,
    ),
    '  // ── Queue Timeline ──────────────────────────────────────────────',
  );

  // 6. Append new widgets before _StepData
  final newWidgets = '''

// ══════════════════════════════════════════════════════════════════════
//  EXTRACTED WIDGETS
// ══════════════════════════════════════════════════════════════════════

class QueueProgressWidget extends StatelessWidget {
  final Animation<double> stepperAnimation;
  final Map<String, dynamic> appointmentData;

  const QueueProgressWidget({
    super.key,
    required this.stepperAnimation,
    required this.appointmentData,
  });

  int _getStepperIndex(Map<String, dynamic> data) {
    final status = data['status'] ?? 'waiting';
    final checkedIn = data['checkedIn'] == true;
    final pAhead = (data['patientsAhead'] as num?)?.toInt() ?? 0;

    if (status == 'in-progress') return 3;
    if (pAhead == 0 && status == 'waiting') return 2;
    if (checkedIn) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _getStepperIndex(appointmentData);
    final steps = const [
      _StepData(Icons.login_rounded, 'Check In'),
      _StepData(Icons.hourglass_top_rounded, 'Waiting'),
      _StepData(Icons.notifications_active_rounded, 'Your Turn'),
      _StepData(Icons.medical_services_rounded, 'Consultation'),
    ];

    return AnimatedBuilder(
      animation: stepperAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: stepperAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - stepperAnimation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00897B).withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepBefore = i ~/ 2;
              final isCompleted = stepBefore < currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: isCompleted
                        ? const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF4CAF50)],
                          )
                        : null,
                    color: isCompleted ? null : Colors.grey[200],
                  ),
                ),
              );
            }

            final stepIndex = i ~/ 2;
            final step = steps[stepIndex];
            final isActive = stepIndex == currentStep;
            final isCompleted = stepIndex < currentStep;

            return _buildStepIcon(step, isActive, isCompleted);
          }),
        ),
      ),
    );
  }

  Widget _buildStepIcon(_StepData step, bool isActive, bool isCompleted) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: isActive ? 46 : 36,
          height: isActive ? 46 : 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFF00897B)
                : isCompleted
                ? const Color(0xFF4CAF50)
                : Colors.grey[100],
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF00897B).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : step.icon,
            color: (isActive || isCompleted) ? Colors.white : Colors.grey[400],
            size: isActive ? 22 : 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? const Color(0xFF00897B)
                : isCompleted
                ? const Color(0xFF4CAF50)
                : Colors.grey[400],
          ),
        ),
      ],
    );
  }
}

class QueueStatsWidget extends StatelessWidget {
  final int patientsAhead;
  final int estimatedWaitTime;

  const QueueStatsWidget({
    super.key,
    required this.patientsAhead,
    required this.estimatedWaitTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.people_rounded, color: Colors.blue, size: 28),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    '\$patientsAhead',
                    key: ValueKey(patientsAhead),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Patients Ahead',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CountdownTimerWidget(totalMinutes: estimatedWaitTime),
        ),
      ],
    );
  }
}

class CountdownTimerWidget extends StatefulWidget {
  final int totalMinutes;

  const CountdownTimerWidget({super.key, required this.totalMinutes});

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  late int _countdownSeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalMinutes != widget.totalMinutes) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _countdownSeconds = widget.totalMinutes * 60;
    
    if (_countdownSeconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _getWaitTimeColor(int minutes) {
    if (minutes < 15) return const Color(0xFF4CAF50);
    if (minutes < 30) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '\$m:\$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getWaitTimeColor(widget.totalMinutes);
    final progress = widget.totalMinutes > 0
        ? (_countdownSeconds / (widget.totalMinutes * 60)).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(56, 56),
                  painter: _WaitTimeArcPainter(
                    progress: progress,
                    color: color,
                  ),
                ),
                Icon(Icons.timer_rounded, color: color, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _countdownSeconds > 0
                  ? _formatCountdown(_countdownSeconds)
                  : '\${widget.totalMinutes} min',
              key: ValueKey(_countdownSeconds),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated Wait',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StepData''';

  text = text.replaceAll('class _StepData', newWidgets);

  file.writeAsStringSync(text);
  print('done');
}
// ignore_for_file: avoid_print
