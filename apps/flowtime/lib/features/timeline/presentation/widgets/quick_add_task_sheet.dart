import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/task.dart';
import '../providers/timeline_provider.dart';

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
    if (mounted) {
      setState(() {
        _suggestedSlots = slots;
      });
    }
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
            
            const SizedBox(height: 12),
            
            // Description input (optional)
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Add details (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ).animate().fadeIn(delay: 150.ms),
            
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
            
            // Time selection
            _buildSectionTitle('When'),
            const SizedBox(height: 8),
            _buildTimeSelection().animate().fadeIn(delay: 500.ms),
            
            const SizedBox(height: 20),
            
            // Flexible scheduling toggle
            SwitchListTile(
              value: _isFlexible,
              onChanged: (value) => setState(() => _isFlexible = value),
              title: const Text('Flexible Scheduling'),
              subtitle: Text(
                'Allow AI to reschedule if needed',
                style: TextStyle(color: AppColors.textTertiary),
              ),
              contentPadding: EdgeInsets.zero,
            ).animate().fadeIn(delay: 600.ms),
            
            const SizedBox(height: 24),
            
            // Submit button
            SizedBox(
              width: double.infinity,
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
                    : const Text('Add Task'),
              ),
            ).animate().fadeIn(delay: 700.ms).scale(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDurationChip(int minutes) {
    final isSelected = _selectedDuration.inMinutes == minutes;
    
    return ChoiceChip(
      label: Text('${minutes}m'),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedDuration = Duration(minutes: minutes));
        _loadSuggestedSlots();
      },
    );
  }

  Widget _buildTaskTypeCard(TaskType type, IconData icon, String label) {
    final isSelected = _selectedType == type;
    
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _getTaskTypeColor(type).withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? _getTaskTypeColor(type) : AppColors.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? _getTaskTypeColor(type) : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? _getTaskTypeColor(type) : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergySelector() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final level = index + 1;
            final isSelected = _energyRequired == level;
            
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _energyRequired = level);
                  _loadSuggestedSlots();
                },
                child: Container(
                  height: 40,
                  margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: isSelected ? _getEnergyColor(level * 20).withValues(alpha: 0.2) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? _getEnergyColor(level * 20) : AppColors.borderSubtle,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$level',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? _getEnergyColor(level * 20) : AppColors.textSecondary,
                      ),
                    ),
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
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelection() {
    return Column(
      children: [
        // Selected time display
        InkWell(
          onTap: _selectCustomTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  _formatDateTime(_selectedTime!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        
        if (_suggestedSlots.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Suggested times based on your energy',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          ...(_suggestedSlots.take(3).map((slot) => _buildSuggestedSlot(slot))),
        ],
      ],
    );
  }

  Widget _buildSuggestedSlot(DateTime slot) {
    final isSelected = _selectedTime?.isAtSameMomentAs(slot) ?? false;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedTime = slot),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                _formatDateTime(slot),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.flash_on,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                'Optimal',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectCustomTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTime!,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedTime!),
      );
      
      if (time != null && mounted) {
        setState(() {
          _selectedTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year && 
                     dateTime.month == now.month && 
                     dateTime.day == now.day;
    final isTomorrow = dateTime.year == now.year && 
                        dateTime.month == now.month && 
                        dateTime.day == now.day + 1;
    
    String dateStr;
    if (isToday) {
      dateStr = 'Today';
    } else if (isTomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}';
    }
    
    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }

  Future<void> _createTask() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await ref.read(quickAddTaskProvider.notifier).createTask(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
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
        return AppColors.primary;
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
    if (level >= 60) return AppColors.primary;
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