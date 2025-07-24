import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/task.dart';
import '../providers/timeline_provider.dart';
import '../providers/energy_provider.dart';

class QuickAddTaskSheet extends ConsumerStatefulWidget {
  final DateTime? suggestedTime;

  const QuickAddTaskSheet({
    super.key,
    this.suggestedTime,
  });

  @override
  ConsumerState<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends ConsumerState<QuickAddTaskSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  Duration _selectedDuration = const Duration(minutes: 45);
  TaskType _selectedType = TaskType.focus;
  int _energyRequired = 3;
  DateTime? _selectedTime;
  List<DateTime> _suggestedSlots = [];
  bool _isFlexible = true;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.suggestedTime ?? DateTime.now().add(const Duration(hours: 1));
    _loadSuggestedSlots();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedSlots() async {
    final slots = await ref.read(timelineProvider.notifier).getSuggestedTimeSlots(
      _selectedDuration,
      _energyRequired,
    );
    setState(() {
      _suggestedSlots = slots;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(quickAddTaskProvider).isLoading;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Title
            Text(
              'Quick Add Task',
              style: Theme.of(context).textTheme.headlineMedium,
            ).animate().fadeIn().slideX(begin: -0.1),
            
            const SizedBox(height: 20),
            
            // Task title input
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ).animate().fadeIn(delay: 100.ms),
            
            const SizedBox(height: 16),
            
            // Duration selection
            _buildSectionTitle('Duration'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDurationChip(15),
                _buildDurationChip(30),
                _buildDurationChip(45),
                _buildDurationChip(60),
                _buildDurationChip(90),
                _buildDurationChip(120),
              ],
            ).animate().fadeIn(delay: 200.ms),
            
            const SizedBox(height: 20),
            
            // Task type selection
            _buildSectionTitle('Task Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildTaskTypeCard(TaskType.focus, Icons.center_focus_strong, 'Focus')),
                const SizedBox(width: 8),
                Expanded(child: _buildTaskTypeCard(TaskType.meeting, Icons.groups, 'Meeting')),
                const SizedBox(width: 8),
                Expanded(child: _buildTaskTypeCard(TaskType.breakTask, Icons.coffee, 'Break')),
                const SizedBox(width: 8),
                Expanded(child: _buildTaskTypeCard(TaskType.admin, Icons.task_alt, 'Admin')),
              ],
            ).animate().fadeIn(delay: 300.ms),
            
            const SizedBox(height: 20),
            
            // Energy requirement
            _buildSectionTitle('Energy Required'),
            const SizedBox(height: 8),
            _buildEnergySelector().animate().fadeIn(delay: 400.ms),
            
            const SizedBox(height: 20),
            
            // Flexible scheduling toggle
            SwitchListTile(
              value: _isFlexible,
              onChanged: (value) => setState(() => _isFlexible = value),
              title: const Text('Flexible Scheduling'),
              subtitle: Text(
                'Allow AI to reschedule if needed',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
            ).animate().fadeIn(delay: 500.ms),
            
            const SizedBox(height: 20),
            
            // Suggested time slots
            if (_suggestedSlots.isNotEmpty) ...[
              _buildSectionTitle('AI Suggested Times'),
              const SizedBox(height: 8),
              ..._suggestedSlots.take(3).map((slot) => _buildTimeSlot(slot)),
            ],
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _createTask,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add to Timeline'),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildDurationChip(int minutes) {
    final isSelected = _selectedDuration.inMinutes == minutes;
    final label = minutes < 60 ? '$minutes min' : '${minutes ~/ 60} hr${minutes > 60 ? 's' : ''}';

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDuration = Duration(minutes: minutes);
          });
          _loadSuggestedSlots();
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardDark,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontSize: 14,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.borderSubtle,
      ),
    );
  }

  Widget _buildTaskTypeCard(TaskType type, IconData icon, String label) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? _getTaskTypeColor(type).withValues(alpha: 0.15) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _getTaskTypeColor(type) : AppColors.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? _getTaskTypeColor(type) : AppColors.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final level = index + 1;
              final isSelected = level <= _energyRequired;
              
              return GestureDetector(
                onTap: () => setState(() => _energyRequired = level),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? _getEnergyColor(_energyRequired * 20)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? _getEnergyColor(_energyRequired * 20)
                          : AppColors.borderSubtle,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.bolt,
                      size: 20,
                      color: isSelected ? Colors.white : AppColors.textTertiary,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _getEnergyDescription(_energyRequired),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlot(DateTime slot) {
    final isSelected = _selectedTime?.isAtSameMomentAs(slot) ?? false;
    final timeStr = '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
    final energyLevel = ref.read(predictedEnergyLevelsProvider).value?[slot.hour] ?? 70;

    return GestureDetector(
      onTap: () => setState(() => _selectedTime = slot),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getEnergyColor(energyLevel),
                  ),
                ),
                Text(
                  'Energy: $energyLevel%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTask() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    await ref.read(quickAddTaskProvider.notifier).createTask(
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      scheduledAt: _selectedTime!,
      duration: _selectedDuration,
      taskType: _selectedType,
      energyRequired: _energyRequired,
      isFlexible: _isFlexible,
    );

    if (mounted && !ref.read(quickAddTaskProvider).hasError) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task added successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Color _getTaskTypeColor(TaskType type) {
    switch (type) {
      case TaskType.focus:
        return AppColors.focus;
      case TaskType.meeting:
        return AppColors.warning;
      case TaskType.breakTask:
        return AppColors.success;
      case TaskType.admin:
        return AppColors.secondary;
    }
  }

  Color _getEnergyColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.focus;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _getEnergyDescription(int level) {
    switch (level) {
      case 1:
        return 'Low effort - routine tasks';
      case 2:
        return 'Light work - emails, admin';
      case 3:
        return 'Moderate focus required';
      case 4:
        return 'Deep work - high concentration';
      case 5:
        return 'Peak performance needed';
      default:
        return '';
    }
  }
}