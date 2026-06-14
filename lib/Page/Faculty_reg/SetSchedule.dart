import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Provider/ORController.dart';
import '../../../Domain/ORModel.dart';

class SetSchedule extends StatefulWidget {
  const SetSchedule({super.key});

  @override
  State<SetSchedule> createState() => _SetScheduleState();
}

class _SetScheduleState extends State<SetSchedule> {
  final Map<String, Map<String, String>> _schedules = {
    'P1 & P2 students': {},
    'Year 4 students': {},
    'Year 3 students': {},
    'Year 2 students': {},
  };

  final List<String> _yearGroups = [
    'P1 & P2 students',
    'Year 4 students',
    'Year 3 students',
    'Year 2 students',
  ];

  final Map<String, String> _yearGroupToStudentYear = {
    'P1 & P2 students': 'P1P2',
    'Year 4 students': 'Year 4',
    'Year 3 students': 'Year 3',
    'Year 2 students': 'Year 2',
  };

  // ✅ Format semester konsisten dengan SubjectManagement
  final List<String> _semesterOptions = [
    'Sem 1 25/26',
    'Sem 2 25/26',
    'Short semester',
  ];

  String? _expandedGroup;
  String? _tempStartDate;
  String? _tempEndDate;
  String? _tempStartTime;
  String? _tempEndTime;
  String? _tempSemester;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingSessions();
    });
  }

  void _loadExistingSessions() {
    final ctrl = context.read<ORController>();
    for (final session in ctrl.orSessions) {
      final groupLabel = _yearGroupToStudentYear.entries
          .firstWhere(
            (e) => e.value == session.studentYear,
            orElse: () => const MapEntry('', ''),
          )
          .key;

      if (groupLabel.isNotEmpty && _schedules.containsKey(groupLabel)) {
        setState(() {
          _schedules[groupLabel] = {
            'startDate': _formatDateForDisplay(session.startDate),
            'endDate': _formatDateForDisplay(session.endDate),
            'startTime': session.startTime,
            'endTime': session.endTime,
            'sessionID': session.sessionID,
            'semester': session.semester,
            // ✅ Status dikira dari ORSession.statusLabel — bukan simpan dalam map
          };
        });
      }
    }
  }

  String _formatDateForDisplay(DateTime dt) =>
      '${dt.day}-${dt.month}-${dt.year}';

  DateTime _parseDisplayDate(String date) {
    final parts = date.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.tryParse(parts[2]) ?? DateTime.now().year,
        int.tryParse(parts[1]) ?? DateTime.now().month,
        int.tryParse(parts[0]) ?? DateTime.now().day,
      );
    }
    return DateTime.now();
  }

  // ✅ Kira status terus dari tarikh dan masa.
  // 'Ended' dianggap sama seperti 'Not set' — badge akan tunjuk 'Set' semula
  String _getStatus(String group) {
    final data = _schedules[group]!;
    if (!data.containsKey('startDate')) return 'Not set';

    final ctrl = context.read<ORController>();
    final studentYear = _yearGroupToStudentYear[group] ?? group;

    String rawStatus;
    try {
      final session = ctrl.orSessions.firstWhere(
        (s) => s.studentYear == studentYear,
      );
      rawStatus = session.statusLabel; // 'Active', 'Upcoming', 'Ended'
    } catch (_) {
      final startDate = _parseDisplayDate(data['startDate']!);
      final endDate = _parseDisplayDate(data['endDate']!);
      final startTimeParts = (data['startTime'] ?? '00:00').split(':');
      final endTimeParts = (data['endTime'] ?? '23:59').split(':');

      final sessionStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        int.tryParse(startTimeParts[0]) ?? 0,
        int.tryParse(startTimeParts[1]) ?? 0,
      );
      final sessionEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        int.tryParse(endTimeParts[0]) ?? 23,
        int.tryParse(endTimeParts[1]) ?? 59,
      );

      final now = DateTime.now();
      if (now.isBefore(sessionStart)) {
        rawStatus = 'Upcoming';
      } else if (now.isAfter(sessionEnd)) {
        rawStatus = 'Ended';
      } else {
        rawStatus = 'Active';
      }
    }

    // ✅ Ended → treat as Not set, supaya badge jadi 'Set' semula
    return rawStatus == 'Ended' ? 'Not set' : rawStatus;
  }

  Future<String?> _pickDate(BuildContext context, {String? initial}) async {
    DateTime now = DateTime.now();
    DateTime? init;
    if (initial != null) {
      final parts = initial.split('-');
      if (parts.length == 3) {
        init = DateTime(
          int.tryParse(parts[2]) ?? now.year,
          int.tryParse(parts[1]) ?? now.month,
          int.tryParse(parts[0]) ?? now.day,
        );
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: init ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A5F7A),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return null;
    return '${picked.day}-${picked.month}-${picked.year}';
  }

  Future<String?> _pickTime(BuildContext context, {String? initial}) async {
    TimeOfDay init = TimeOfDay.now();
    if (initial != null) {
      final parts = initial.split(':');
      if (parts.length == 2) {
        init = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A5F7A),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  void _openForm(String group) {
    final existing = _schedules[group]!;
    final status = _getStatus(group);

    setState(() {
      _expandedGroup = group;
      // ✅ Semester — guna yang sedia ada, atau default 'Sem 2 25/26'
      _tempSemester = existing['semester'] ?? _semesterOptions[1];
      if (status == 'Not set') {
        // ✅ Belum set ATAU session lama dah tamat — clear tarikh, set baru
        _tempStartDate = null;
        _tempEndDate = null;
        _tempStartTime = existing['startTime']; // kekal masa sebagai default
        _tempEndTime = existing['endTime'];
      } else {
        _tempStartDate = existing['startDate'];
        _tempEndDate = existing['endDate'];
        _tempStartTime = existing['startTime'];
        _tempEndTime = existing['endTime'];
      }
    });
  }

  Future<void> _saveForm(String group) async {
    if (_tempStartDate == null || _tempEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Start Date and End Date'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final ctrl = context.read<ORController>();
    final studentYear = _yearGroupToStudentYear[group] ?? group;
    final existing = _schedules[group]!;

    final sessionID = existing['sessionID'] ??
        'SES-$studentYear-${DateTime.now().millisecondsSinceEpoch}';

    // ✅ Guna semester yang dipilih dalam form (konsisten dengan SubjectManagement)
    final selectedSemester = _tempSemester ?? _semesterOptions[1];

    final session = ORSession(
      sessionID: sessionID,
      semester: selectedSemester,
      // ✅ Tiada isActive — auto-calculate dari tarikh masa
      studentYear: studentYear,
      startDate: _parseDisplayDate(_tempStartDate!),
      endDate: _parseDisplayDate(_tempEndDate!),
      startTime: _tempStartTime ?? '08:00',
      endTime: _tempEndTime ?? '23:59',
    );

    try {
      await ctrl.saveORSession(session);

      setState(() {
        _schedules[group] = {
          'startDate': _tempStartDate!,
          'endDate': _tempEndDate!,
          if (_tempStartTime != null) 'startTime': _tempStartTime!,
          if (_tempEndTime != null) 'endTime': _tempEndTime!,
          'sessionID': sessionID,
          'semester': selectedSemester,
        };
        _expandedGroup = null;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Schedule for $group saved!'),
            backgroundColor: const Color(0xFF1A5F7A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ✅ Badge tunjuk status auto — Active/Upcoming/Set (kalau Ended atau belum set)
  Widget _buildBadge(String group) {
    final status = _getStatus(group);

    if (status == 'Not set') {
      return GestureDetector(
        onTap: () => _openForm(group),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Text(
            'Set',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5A7A8A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Warna ikut status — hanya Active atau Upcoming sampai sini
    Color bgColor;
    Widget? leadingIcon;

    switch (status) {
      case 'Active':
        bgColor = const Color(0xFF27AE60);
        leadingIcon = const Icon(Icons.circle, color: Colors.white, size: 8);
        break;
      case 'Upcoming':
        bgColor = const Color(0xFF1A5F7A);
        leadingIcon = const Icon(Icons.schedule, color: Colors.white, size: 12);
        break;
      default:
        bgColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _openForm(group),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              leadingIcon,
              const SizedBox(width: 4),
            ],
            Text(
              status,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapField({
    required String label,
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7A9AAA),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value ?? hint,
              style: TextStyle(
                fontSize: 14,
                color:
                    value != null ? const Color(0xFF1A2D3D) : Colors.grey[400],
                fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F7),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A5F7A), Color(0xFF3A9CC8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Set Schedule',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.school,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF1A5F7A)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Status legend ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _legendItem(
                            color: const Color(0xFF27AE60),
                            label: 'Active — within date & time'),
                        _legendItem(
                            color: const Color(0xFF1A5F7A), label: 'Upcoming'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Priority access card ───────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Priority access',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A5F7A),
                          ),
                        ),
                        // ✅ Info — OR auto-active berdasarkan masa
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'OR session status updates automatically based on date and time set.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        ..._yearGroups.map(
                          (group) => Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF1A2D3D),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          // ✅ Tunjuk tarikh, masa & semester kalau dah set
                                          if (_schedules[group]!
                                              .containsKey('startDate'))
                                            Text(
                                              '${_schedules[group]!['semester'] ?? ''} · '
                                              '${_schedules[group]!['startDate']} ${_schedules[group]!['startTime'] ?? ''} → '
                                              '${_schedules[group]!['endDate']} ${_schedules[group]!['endTime'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    _buildBadge(group),
                                  ],
                                ),
                              ),
                              if (group != _yearGroups.last)
                                Divider(height: 1, color: Colors.grey.shade100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── OR Period form ─────────────────────────────────
                  if (_expandedGroup != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OR period for $_expandedGroup',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A5F7A),
                            ),
                          ),
                          // ✅ Info — OR akan auto-active bila masa tiba
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 16),
                            child: Text(
                              'OR will be automatically active between the start and end date & time.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          // ✅ Semester dropdown — konsisten dengan SubjectManagement
                          const Text(
                            'Semester',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7A9AAA),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _tempSemester,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down,
                                    color: Color(0xFF1A5F7A)),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A2D3D),
                                  fontWeight: FontWeight.w500,
                                ),
                                items: _semesterOptions
                                    .map((sem) => DropdownMenuItem(
                                          value: sem,
                                          child: Text(sem),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _tempSemester = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTapField(
                            label: 'Start Date',
                            value: _tempStartDate,
                            hint: 'Select date',
                            onTap: () async {
                              final d = await _pickDate(context,
                                  initial: _tempStartDate);
                              if (d != null) setState(() => _tempStartDate = d);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTapField(
                            label: 'End Date',
                            value: _tempEndDate,
                            hint: 'Select date',
                            onTap: () async {
                              final d = await _pickDate(context,
                                  initial: _tempEndDate);
                              if (d != null) setState(() => _tempEndDate = d);
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Registration time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7A9AAA),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final t = await _pickTime(context,
                                        initial: _tempStartTime);
                                    if (t != null)
                                      setState(() => _tempStartTime = t);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F0F5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _tempStartTime ?? '08:00',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1A2D3D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('-',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 18)),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final t = await _pickTime(context,
                                        initial: _tempEndTime);
                                    if (t != null)
                                      setState(() => _tempEndTime = t);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F0F5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _tempEndTime ?? '23:59',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1A2D3D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () => _saveForm(_expandedGroup!),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A9CC8),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Save',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _expandedGroup = null),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: BorderSide(color: Colors.grey[300]!),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text('Cancel',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}
