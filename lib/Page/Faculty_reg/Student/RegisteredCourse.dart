// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/Page/OR/RegisteredCourse.dart
// Boundary Class — PACK109-SAMS-2026 (RegisteredCourse)
// Ref: SDD Section 4.1.9 RegisteredCourse
// ✅ "+ Add more subject" sekarang navigate ke StudentOR
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Provider/ORController.dart';
import '../../../Domain/ORModel.dart';
import 'EditCourse.dart';
import 'StudentOR.dart';

class RegisteredCourse extends StatefulWidget {
  const RegisteredCourse({super.key});

  @override
  State<RegisteredCourse> createState() => _RegisteredCourseState();
}

class _RegisteredCourseState extends State<RegisteredCourse> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_SubjectEntry> _groupBySubject(List<CourseRegistrationRecord> records) {
    final Map<String, _SubjectEntry> map = {};
    for (final r in records) {
      if (r.regStatus == 'Dropped') continue;
      if (!map.containsKey(r.subCode)) {
        map[r.subCode] = _SubjectEntry(subCode: r.subCode);
      }
      if (r.isLecture) {
        map[r.subCode]!.lecture = r;
      } else {
        map[r.subCode]!.secondary = r;
      }
    }
    return map.values.toList();
  }

  List<_SubjectEntry> _filter(List<_SubjectEntry> entries) {
    if (_searchQuery.isEmpty) return entries;
    final q = _searchQuery.toLowerCase();
    return entries.where((e) {
      final lect = e.lecture;
      if (lect == null) return false;
      return lect.subCode.toLowerCase().contains(q) ||
          lect.subName.toLowerCase().contains(q) ||
          lect.lectName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _onDrop(_SubjectEntry entry) async {
    final subCode = entry.lecture?.subCode ?? entry.secondary?.subCode ?? '';
    final subName = entry.lecture?.subName ?? entry.secondary?.subName ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Drop Course',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          'Are you sure you want to drop\n$subCode - $subName?\n\nThis action cannot be undone.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Drop',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final error = await context.read<ORController>().dropSubject(subCode);
      if (!mounted) return;
      _showSnack(
        error ?? 'Successfully dropped $subCode.',
        isError: error != null,
      );
    }
  }

  // ── Edit — navigate ke EditCourse ─────────────────────────────────────────

  void _onEdit(_SubjectEntry entry) {
    final ctrl = context.read<ORController>();
    final rec = entry.lecture ?? entry.secondary;
    if (rec == null) return;

    final subject = Subject(
      subCode: rec.subCode,
      subName: rec.subName,
      creditHour: rec.creditHour,
      faculty: '',
    );

    // Ambil semua offerings untuk subject ini dari cache
    final offerings =
        ctrl.activeOfferings.where((o) => o.subCode == rec.subCode).toList();

    // sectID semasa untuk lecture dan lab/tutorial
    final currentLectSectID = entry.lecture?.sectID ?? '';
    final currentSecSectID = entry.secondary?.sectID ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: ctrl,
          child: EditCourse(
            subject: subject,
            offerings: offerings,
            currentLectSectID: currentLectSectID,
            currentSecSectID: currentSecSectID,
          ),
        ),
      ),
    );
  }

  // ✅ "+ Add more subject" — navigate ke StudentOR (Course Registration list)
  // guna ORController yang sama supaya state (registrations, offerings) konsisten
  void _onAddMore() {
    final ctrl = context.read<ORController>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: ctrl,
          child: StudentOR(
            studentID: ctrl.studentID,
            studentName: '',
            programme: '',
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? Colors.red.shade600 : const Color(0xFF1AAFA0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Consumer<ORController>(
        builder: (context, ctrl, _) {
          final semLabel = ctrl.activeSession?.semester ?? 'Sem 2 2025/2026';
          final entries = _groupBySubject(ctrl.studentRegistrations);
          final filtered = _filter(entries);

          return Column(
            children: [
              _buildHeader(semLabel),
              Expanded(
                child: ctrl.isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF1AAFA0)),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        children: [
                          _buildStatCards(ctrl),
                          const SizedBox(height: 16),
                          _buildSearchBar(),
                          const SizedBox(height: 20),
                          _buildCourseListCard(filtered),
                          const SizedBox(height: 24),
                          _buildAddMoreButton(),
                          const SizedBox(height: 20),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String semLabel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1AAFA0), Color(0xFF0D8C7F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.menu, color: Colors.white, size: 24),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Registered Course',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      semLabel,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://upload.wikimedia.org/wikipedia/en/thumb/b/b4/Universiti_Malaysia_Pahang_logo.svg/200px-Universiti_Malaysia_Pahang_logo.svg.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school,
                      color: Color(0xFF1AAFA0),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(ORController ctrl) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: ctrl.totalRegisteredSubjects.toString(),
            label: 'Subjects',
            backgroundColor: const Color(0xFFDDE8F5),
            valueColor: const Color(0xFF3A6FA6),
            labelColor: const Color(0xFF3A6FA6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: ctrl.totalCreditHours.toString(),
            label: 'Credit hours',
            backgroundColor: const Color(0xFFD6F2ED),
            valueColor: const Color(0xFF1AAFA0),
            labelColor: const Color(0xFF1AAFA0),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon:
                      Icon(Icons.close, color: Colors.grey.shade400, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCourseListCard(List<_SubjectEntry> entries) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Registered course',
              style: TextStyle(
                color: Color(0xFF1AAFA0),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'No courses found for "$_searchQuery".'
                      : 'No registered courses yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ...entries.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isLast = idx == entries.length - 1;
              return Column(
                children: [
                  _CourseItemTile(
                    entry: item,
                    onEdit: () => _onEdit(item),
                    onDrop: () => _onDrop(item),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAddMoreButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _onAddMore,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        child: const Text(
          '+ Add more subject',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectEntry {
  final String subCode;
  CourseRegistrationRecord? lecture;
  CourseRegistrationRecord? secondary;

  _SubjectEntry({required this.subCode});

  String get sectDisplay {
    final l = lecture?.sectNo ?? '';
    final s = secondary?.sectNo ?? '';
    if (l.isNotEmpty && s.isNotEmpty) return '$l/$s';
    return l.isNotEmpty ? l : s;
  }

  String get subName => lecture?.subName ?? secondary?.subName ?? '';
  String get lectName => lecture?.lectName ?? secondary?.lectName ?? '';
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color backgroundColor;
  final Color valueColor;
  final Color labelColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.backgroundColor,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseItemTile extends StatelessWidget {
  final _SubjectEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDrop;

  const _CourseItemTile({
    required this.entry,
    required this.onEdit,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.subCode} - ${entry.subName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Section ${entry.sectDisplay}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (entry.lectName.isNotEmpty && entry.lectName != '-')
                  Text(
                    entry.lectName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionIconButton(
            icon: Icons.edit_outlined,
            iconColor: const Color(0xFF3A6FA6),
            borderColor: const Color(0xFF3A6FA6),
            onTap: onEdit,
          ),
          const SizedBox(width: 8),
          _DropButton(onTap: onDrop),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 17),
      ),
    );
  }
}

class _DropButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DropButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Drop',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
