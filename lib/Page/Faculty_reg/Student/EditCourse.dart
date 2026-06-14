// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/Page/OR/EditCourse.dart
// Boundary Class — PACK110-SAMS-2026 (EditCourse)
// Ref: SDD Section 4.1.10 EditCourse
// ✅ Lab/Tutorial sections kini filter mengikut prefix lecture yang dipilih
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Provider/ORController.dart';
import '../../../Domain/ORModel.dart';

class EditCourse extends StatefulWidget {
  final Subject subject;
  final List<OfferingRegistration> offerings;
  final String currentLectSectID;
  final String currentSecSectID;

  const EditCourse({
    super.key,
    required this.subject,
    required this.offerings,
    required this.currentLectSectID,
    this.currentSecSectID = '',
  });

  @override
  State<EditCourse> createState() => _EditCourseState();
}

class _EditCourseState extends State<EditCourse> {
  OfferingRegistration? _selectedLecture;
  OfferingRegistration? _selectedSecondary;
  bool _isSaving = false;

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

  String get _secondaryLabel {
    if (_secondarySections.isEmpty) return '';
    return _secondarySections.first.classType == 'Lab'
        ? 'Lab Section'
        : 'Tutorial Section';
  }

  @override
  void initState() {
    super.initState();
    _selectedLecture = _lectureSections.firstWhere(
      (o) => o.sectID == widget.currentLectSectID,
      orElse: () => _lectureSections.first,
    );

    // ✅ Selepas lecture diset, cari secondary yang sepadan dengan currentSecSectID
    // (kalau ada dalam list secondary untuk lecture ni)
    _autoSelectSecondary(preferCurrent: true);
  }

  // ✅ Auto-select secondary berdasarkan lecture yang terpilih
  void _autoSelectSecondary({bool preferCurrent = false}) {
    if (!_hasSecondary) {
      _selectedSecondary = null;
      return;
    }

    if (preferCurrent && widget.currentSecSectID.isNotEmpty) {
      final match = _secondarySections
          .where((o) => o.sectID == widget.currentSecSectID)
          .firstOrNull;
      if (match != null) {
        _selectedSecondary = match;
        return;
      }
    }

    // Default: pilih yang belum penuh, atau yang pertama
    _selectedSecondary =
        _secondarySections.where((o) => !o.isFull).firstOrNull ??
            _secondarySections.first;
  }

  bool get _hasChanges {
    final lectChanged = _selectedLecture?.sectID != widget.currentLectSectID;
    final secChanged =
        _hasSecondary && _selectedSecondary?.sectID != widget.currentSecSectID;
    return lectChanged || secChanged;
  }

  Future<void> _onSave() async {
    if (!_hasChanges) {
      _showSnack('No changes made.', isError: false);
      return;
    }
    if (_selectedLecture == null) {
      _showSnack('Please select a lecture section.', isError: true);
      return;
    }
    if (_hasSecondary && _selectedSecondary == null) {
      _showSnack('Please select a $_secondaryLabel.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final ctrl = context.read<ORController>();
    String? error;

    if (_selectedLecture!.sectID != widget.currentLectSectID) {
      error = await ctrl.editRegistration(
        subCode: widget.subject.subCode,
        classType: _selectedLecture!.classType,
        newOffering: _selectedLecture!,
      );
    }

    if (error == null &&
        _hasSecondary &&
        _selectedSecondary != null &&
        _selectedSecondary!.sectID != widget.currentSecSectID) {
      error = await ctrl.editRegistration(
        subCode: widget.subject.subCode,
        classType: _selectedSecondary!.classType,
        newOffering: _selectedSecondary!,
      );
    }

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack('Changes saved for ${widget.subject.subName}!');
      Navigator.pop(context, true);
    }
  }

  void _onCancel() => Navigator.pop(context, false);

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
    final semLabel = context.read<ORController>().activeSession?.semester ??
        'Sem 2 2025/2026';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Column(
        children: [
          _buildHeader(semLabel),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildSubjectInfoCard(),
                const SizedBox(height: 16),
                _buildLectureSectionCard(),
                // ✅ Lab/Tutorial card sentiasa selepas lecture, auto-refresh
                // ikut lecture yang dipilih
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
                onPressed: _onCancel,
                icon: const Icon(Icons.menu, color: Colors.white, size: 24),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Edit Registration',
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

  Widget _buildLectureSectionCard() {
    return _SectionCard(
      title: 'Lecture Section',
      child: Column(
        children: _lectureSections.asMap().entries.map((entry) {
          final idx = entry.key;
          final o = entry.value;
          final isLast = idx == _lectureSections.length - 1;
          final isCurrent = o.sectID == widget.currentLectSectID;

          return Column(
            children: [
              _OfferingTile(
                offering: o,
                isSelected: _selectedLecture?.sectID == o.sectID,
                isCurrent: isCurrent,
                showLecturer: true,
                onTap: o.isFull
                    ? null
                    : () => setState(() {
                          _selectedLecture = o;
                          // ✅ Lecture berubah → refresh secondary selection
                          // supaya hanya tunjuk lab/tutorial dengan prefix sama.
                          // preferCurrent: false sebab lecture dah ditukar,
                          // current secondary (lecture lama) tak relevan lagi.
                          _autoSelectSecondary(preferCurrent: false);
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

  Widget _buildSecondarySectionCard() {
    return _SectionCard(
      // ✅ Tunjuk lecture yang dipilih dalam title untuk konteks jelas
      title: _selectedLecture != null
          ? '$_secondaryLabel  ·  Lecture ${_selectedLecture!.sectNo}'
          : _secondaryLabel,
      child: Column(
        children: _secondarySections.asMap().entries.map((entry) {
          final idx = entry.key;
          final o = entry.value;
          final isLast = idx == _secondarySections.length - 1;
          final isCurrent = o.sectID == widget.currentSecSectID;

          return Column(
            children: [
              _OfferingTile(
                offering: o,
                isSelected: _selectedSecondary?.sectID == o.sectID,
                isCurrent: isCurrent,
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isSaving ? null : _onSave,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1AAFA0),
              side: const BorderSide(color: Color(0xFF1AAFA0), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1AAFA0),
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('Save changes'),
          ),
        ),
        const SizedBox(height: 12),
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

class _OfferingTile extends StatelessWidget {
  final OfferingRegistration offering;
  final bool isSelected;
  final bool isCurrent;
  final bool showLecturer;
  final VoidCallback? onTap;

  const _OfferingTile({
    required this.offering,
    required this.isSelected,
    required this.isCurrent,
    required this.showLecturer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = offering.isFull && !isCurrent;
    final textColor = disabled ? Colors.grey.shade400 : const Color(0xFF1A1A2E);
    final subColor = disabled ? Colors.grey.shade300 : Colors.grey.shade600;

    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
            if (isCurrent) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6F2ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'current',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D8C7F),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 4),
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
                          color: offering.isFull
                              ? Colors.red.shade400
                              : Colors.grey.shade500,
                          fontWeight: offering.isFull
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (offering.isFull) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• full',
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
