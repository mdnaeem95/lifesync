import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/task.dart';
import '../providers/focus_session_provider.dart';
import '../providers/timeline_provider.dart';
import '../providers/energy_provider.dart';
import '../widgets/focus_mode_widgets.dart';

class FocusModeScreen extends ConsumerStatefulWidget {
  final Task? task;
  
  const FocusModeScreen({
    super.key,
    this.task,
  });

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _breathingController;
  late AnimationController _pulseController;
  
  FocusProtocol _selectedProtocol = FocusProtocol.pomodoro;
  bool _isSessionActive = false;
  bool _isPaused = false;
  int _sessionDuration = 25 * 60; // 25 minutes in seconds
  int _remainingTime = 25 * 60;
  int _completedSessions = 0;
  
  @override
  void initState() {
    super.initState();
    
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _sessionDuration),
    );
    
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _timerController.addListener(() {
      if (_isSessionActive && !_isPaused) {
        setState(() {
          _remainingTime = (_sessionDuration * (1 - _timerController.value)).round();
          
          if (_remainingTime <= 0) {
            _completeSession();
          }
        });
      }
    });
    
    // Initialize with task duration if provided
    if (widget.task != null) {
      _sessionDuration = widget.task!.duration.inSeconds;
      _remainingTime = _sessionDuration;
    }
  }
  
  @override
  void dispose() {
    _timerController.dispose();
    _breathingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  void _startSession() {
    setState(() {
      _isSessionActive = true;
      _isPaused = false;
    });
    
    ref.read(focusSessionProvider.notifier).startSession(
      taskId: widget.task?.id,
      duration: Duration(seconds: _sessionDuration),
      protocol: _selectedProtocol,
    );
    
    _timerController.forward();
  }
  
  void _pauseSession() {
    setState(() {
      _isPaused = true;
    });
    _timerController.stop();
    
    ref.read(focusSessionProvider.notifier).pauseSession();
  }
  
  void _resumeSession() {
    setState(() {
      _isPaused = false;
    });
    _timerController.forward();
    
    ref.read(focusSessionProvider.notifier).resumeSession();
  }
  
  void _stopSession() {
    setState(() {
      _isSessionActive = false;
      _isPaused = false;
      _remainingTime = _sessionDuration;
    });
    
    _timerController.reset();
    
    ref.read(focusSessionProvider.notifier).endSession();
  }
  
  void _completeSession() {
    setState(() {
      _completedSessions++;
      _isSessionActive = false;
      _isPaused = false;
    });
    
    _timerController.reset();
    
    // Mark task as completed if this was a task-based session
    if (widget.task != null) {
      ref.read(timelineProvider.notifier).toggleTaskComplete(widget.task!.id);
    }
    
    ref.read(focusSessionProvider.notifier).completeSession();
    
    // Show completion dialog
    _showCompletionDialog();
  }
  
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionCompletionDialog(
        sessionDuration: _sessionDuration,
        onContinue: () {
          Navigator.of(context).pop();
          setState(() {
            _remainingTime = _sessionDuration;
          });
        },
        onFinish: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final currentEnergy = ref.watch(currentEnergyProvider);
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _isSessionActive ? null : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Focus Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showProtocolSettings(),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Breathing animation background
            if (_isSessionActive)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _breathingController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.8 + (_breathingController.value * 0.2),
                          colors: [
                            AppColors.primary.withValues(alpha: 0.1),
                            AppColors.backgroundDark,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Main content
            Column(
              children: [
                const Spacer(),
                
                // Timer display
                Center(
                  child: GestureDetector(
                    onTap: _isSessionActive ? null : _showProtocolPicker,
                    child: SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Progress ring
                          if (_isSessionActive)
                            CustomPaint(
                              size: const Size(280, 280),
                              painter: ProgressRingPainter(
                                progress: _timerController.value,
                                color: _getEnergyColor(currentEnergy.value ?? 75),
                              ),
                            ).animate()
                                .fadeIn(duration: 600.ms)
                                .scale(begin: const Offset(0.8, 0.8)),
                          
                          // Pulse effect when active
                          if (_isSessionActive && !_isPaused)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 260,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3 * (1 - _pulseController.value),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          
                          // Time display
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_isSessionActive)
                                Text(
                                  _selectedProtocol.displayName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ).animate()
                                    .fadeIn()
                                    .slideY(begin: -0.1),
                              
                              Text(
                                _formatTime(_remainingTime),
                                style: const TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: -2,
                                  color: AppColors.textPrimary,
                                ),
                              ).animate()
                                  .fadeIn(duration: 800.ms)
                                  .scale(begin: const Offset(0.9, 0.9)),
                              
                              if (_isSessionActive && widget.task != null)
                                Text(
                                  widget.task!.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ).animate()
                                    .fadeIn(delay: 200.ms)
                                    .slideY(begin: 0.1),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Session stats
                if (_completedSessions > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem('Sessions', _completedSessions.toString()),
                        _buildStatItem('Focus Time', '${_completedSessions * (_sessionDuration ~/ 60)}m'),
                        _buildStatItem('Energy', '${currentEnergy.value ?? 0}%'),
                      ],
                    ),
                  ).animate()
                      .fadeIn(delay: 400.ms)
                      .slideY(begin: 0.2),
                
                const SizedBox(height: 48),
                
                // Control buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: _buildControlButtons(),
                ),
                
                const SizedBox(height: 48),
              ],
            ),
            
            // Exit button when session is active
            if (_isSessionActive)
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  onPressed: () => _showExitConfirmation(),
                  color: AppColors.textTertiary,
                ).animate()
                    .fadeIn(delay: 600.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildControlButtons() {
    if (!_isSessionActive) {
      return ElevatedButton(
        onPressed: _startSession,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Start Focus Session',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ).animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: 0.2);
    }
    
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _stopSession,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 56),
              side: BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Stop',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isPaused ? _resumeSession : _pauseSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPaused ? AppColors.success : AppColors.warning,
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _isPaused ? 'Resume' : 'Pause',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ).animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2);
  }
  
  Color _getEnergyColor(int energy) {
    if (energy >= 80) return AppColors.success;
    if (energy >= 60) return AppColors.primary;
    if (energy >= 40) return AppColors.warning;
    return AppColors.error;
  }
  
  void _showProtocolPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ProtocolPickerSheet(
        selectedProtocol: _selectedProtocol,
        onProtocolSelected: (protocol, duration) {
          setState(() {
            _selectedProtocol = protocol;
            _sessionDuration = duration;
            _remainingTime = duration;
          });
        },
      ),
    );
  }
  
  void _showProtocolSettings() {
    // Show protocol settings sheet
  }
  
  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('End Session?'),
        content: const Text('Your progress will be saved, but the session will end early.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopSession();
            },
            child: Text(
              'End Session',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}