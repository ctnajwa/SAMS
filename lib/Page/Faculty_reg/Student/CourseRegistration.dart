// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/Page/OR/CourseRegistrationPage.dart
// Boundary Class — PACK108-SAMS-2026 (CourseRegistration)
// Ref: SDD Section 4.1.8 CourseRegistration
// ✅ Lab/Tutorial sections kini filter mengikut prefix lecture yang dipilih
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Provider/ORController.dart';
import '../../../Domain/ORModel.dart';

class CourseRegistration extends StatefulWidget {
  final Subject subject;
  final List<OfferingRegistration>
      offerings; // semua sections untuk subject ini

  const CourseRegistration({
    super.key,
    required this.subject,
    required this.offerings,
  });

  @override
  State<CourseRegistration> createState() => _CourseRegistrationState();
}

class _CourseRegistrationState extends State<CourseRegistration> {
  // Section yang dipilih student
  OfferingRegistration? _selectedLecture;
  OfferingRegistration? _selectedSecondary; // Lab atau Tutorial

  bool _isRegistering = false;

  // ── Group offerings mengikut classType ───────────────────────────────────

  List<OfferingRegistration> get _lectureSections =>
      widget.offerings.where((o) => o.classType == 'Lecture').toList();

  // ✅ Secondary sections — filter mengikut prefix lecture yang DIPILIH.
  // Contoh: lecture '01' dipilih → hanya '01A', '01B' ditunjukkan (bukan '02A').
  List<OfferingRegistration> get _secondarySections {
    if (_selectedLecture == null) return [];
    final lectSectNo = _selectedLecture!.sectNo;
    return widget.offerings
        .where((o) =>
            (o.classType == 'Lab' || o.classType == 'Tutorial') &&
            o.sectNo.startsWith(lectSectNo))
        .toList();
  }

  bool get _hasSecondary => _secondarySections.isNotEmpty;

  // ── Label untuk secondary section (Lab / Tutorial) ───────────────────────
  String get _secondaryLabel {
    if (_secondarySections.isEmpty) return '';
    return _secondarySections.first.classType == 'Lab'
        ? 'Lab Section'
        : 'Tutorial Section';
  }

  @override
  void initState() {
    super.initState();
    // Auto-select first available (not full) lecture section
    _selectedLecture = _lectureSections.where((o) => !o.isFull).firstOrNull ??
        (_lectureSections.isNotEmpty ? _lectureSections.first : null);

    // ✅ Auto-select secondary berdasarkan lecture yang terpilih
    _autoSelectSecondary();
  }

  void _autoSelectSecondary() {
    if (_hasSecondary) {
      _selectedSecondary =
          _secondarySections.where((o) => !o.isFull).firstOrNull ??
              _secondarySections.first;
    } else {
      _selectedSecondary = null;
    }
  }

  // ── registerSubject() ─────────────────────────────────────────────────────

  Future<void> _onRegister() async {
    if (_selectedLecture == null) {
      _showSnack('Please select a lecture section.', isError: true);
      return;
    }
    if (_hasSecondary && _selectedSecondary == null) {
      _showSnack('Please select a $_secondaryLabel.', isError: true);
      return;
    }

    setState(() => _isRegistering = true);
    final ctrl = context.read<ORController>();

    // Daftar lecture section
    String? error = await ctrl.registerSubject(offering: _selectedLecture!);

    // Daftar lab/tutorial section jika ada dan lecture berjaya
    if (error == null && _hasSecondary && _selectedSecondary != null) {
      error = await ctrl.registerSubject(offering: _selectedSecondary!);
    }

    setState(() => _isRegistering = false);
    if (!mounted) return;

    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack('Successfully registered for ${widget.subject.subName}!');
      Navigator.pop(context);
    }
  }

  // ── cancelRegister() ──────────────────────────────────────────────────────

  void _onCancel() => Navigator.pop(context);

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
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildSubjectInfoCard(),
                const SizedBox(height: 16),
                _buildLectureSectionCard(),
                // ✅ Lab/Tutorial card sentiasa ditunjukkan SELEPAS lecture,
                // dan akan auto-refresh ikut lecture yang dipilih
                if (_hasSecondary) ...[
                  const SizedBox(height: 16),
                  _buildSecondarySectionCard(),
                ],
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
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
                onPressed: _onCancel,
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
              ),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Course Registration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Select Section',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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

  // ── Subject Info Card ─────────────────────────────────────────────────────

  Widget _buildSubjectInfoCard() {
    return _SectionCard(
      title: 'Subject Info',
      child: Column(
        children: [
          _InfoRow(label: 'Code', value: widget.subject.subCode),
          const _RowDivider(),
          _InfoRow(label: 'Subject', value: widget.subject.subName),
          const _RowDivider(),
          _InfoRow(
            label: 'Credit hour',
            value: widget.subject.creditHour.toString(),
          ),
        ],
      ),
    );
  }

  // ── Lecture Section Card ──────────────────────────────────────────────────

  Widget _buildLectureSectionCard() {
    return _SectionCard(
      title: 'Lecture Section',
      child: Column(
        children: _lectureSections.asMap().entries.map((entry) {
          final idx = entry.key;
          final o = entry.value;
          final isLast = idx == _lectureSections.length - 1;
          return Column(
            children: [
              _OfferingTile(
                offering: o,
                isSelected: _selectedLecture?.sectID == o.sectID,
                showLecturer: true,
                onTap: o.isFull
                    ? null
                    : () => setState(() {
                          _selectedLecture = o;
                          // ✅ Lecture berubah → refresh secondary selection
                          // supaya hanya tunjuk lab/tutorial dengan prefix sama
                          _autoSelectSecondary();
                        }),
              ),
              if (!isLast)
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Lab / Tutorial Section Card ───────────────────────────────────────────

  Widget _buildSecondarySectionCard() {
    return _SectionCard(
      // ✅ Tunjuk section lecture yang dipilih dalam title, contoh
      // "Lab Section (for Lecture 01)"
      title: _selectedLecture != null
          ? '$_secondaryLabel  ·  Lecture ${_selectedLecture!.sectNo}'
          : _secondaryLabel,
      child: Column(
        children: _secondarySections.asMap().entries.map((entry) {
          final idx = entry.key;
          final o = entry.value;
          final isLast = idx == _secondarySections.length - 1;
          return Column(
            children: [
              _OfferingTile(
                offering: o,
                isSelected: _selectedSecondary?.sectID == o.sectID,
                showLecturer: false,
                onTap: o.isFull
                    ? null
                    : () => setState(() => _selectedSecondary = o),
              ),
              if (!isLast)
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Register + Cancel buttons ─────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Register button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isRegistering ? null : _onRegister,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1AAFA0),
              side: const BorderSide(color: Color(0xFF1AAFA0), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: _isRegistering
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1AAFA0),
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('Register'),
          ),
        ),
        const SizedBox(height: 12),
        // Cancel button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Card putih dengan tajuk teal
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1AAFA0),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          child,
        ],
      ),
    );
  }
}

/// Row info: "Code        BCS2344"
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              )),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: Color(0xFFF0F0F0),
      );
}

/// Satu row section dengan radio button
class _OfferingTile extends StatelessWidget {
  final OfferingRegistration offering;
  final bool isSelected;
  final bool showLecturer;
  final VoidCallback? onTap;

  const _OfferingTile({
    required this.offering,
    required this.isSelected,
    required this.showLecturer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = offering.isFull;
    final textColor = disabled ? Colors.grey.shade400 : const Color(0xFF1A1A2E);
    final subColor = disabled ? Colors.grey.shade300 : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Section number
            SizedBox(
              width: 36,
              child: Text(
                offering.sectNo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Schedule + Lecturer + Enrollment
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offering.scheduleLabel,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                  if (showLecturer &&
                      offering.lectName.isNotEmpty &&
                      offering.lectName != '-')
                    Text(
                      offering.lectName,
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  Row(
                    children: [
                      Text(
                        offering.enrollmentLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: disabled
                              ? Colors.red.shade400
                              : Colors.grey.shade500,
                          fontWeight:
                              disabled ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (disabled) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• Full',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Radio button
            Radio<bool>(
              value: true,
              groupValue: isSelected ? true : null,
              onChanged: disabled ? null : (_) => onTap?.call(),
              activeColor: const Color(0xFF1AAFA0),
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (disabled) return Colors.grey.shade300;
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF1AAFA0);
                }
                return Colors.grey.shade400;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
