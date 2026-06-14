import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Provider/ORController.dart';
import '../../../Domain/ORModel.dart';
import 'EditOR.dart';

class SubjectOffering extends StatefulWidget {
  const SubjectOffering({super.key});

  @override
  State<SubjectOffering> createState() => _SubjectOfferingState();
}

class _SubjectOfferingState extends State<SubjectOffering> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ─── Auto-generate sectID format SEC001, SEC002 ──────────────────────────
  String _generateSectID(List<String> existingDocIds) {
    int max = 0;
    for (final id in existingDocIds) {
      final match = RegExp(r'^SEC(\d+)$').firstMatch(id);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > max) max = num;
      }
    }
    return 'SEC${(max + 1).toString().padLeft(3, '0')}';
  }

  // ─── Group offerings: subCode → lectSectNo → LectureGroup ───────────────
  Map<String, Map<String, _LectureGroup>> _groupOfferings(
      List<OfferingRegistration> offerings, List<String> docIds) {
    final Map<String, Map<String, _LectureGroup>> result = {};

    // Pass 1: Collect lectures
    for (int i = 0; i < offerings.length; i++) {
      final o = offerings[i];
      final id = docIds[i];
      if (o.classType == 'Lecture') {
        result.putIfAbsent(o.subCode, () => {});
        result[o.subCode]!.putIfAbsent(
          o.sectNo,
          () => _LectureGroup(lecture: o, lectureDocId: id),
        );
      }
    }

    // Pass 2: Collect Lab/Tutorial — letak bawah lecture prefix matching
    for (int i = 0; i < offerings.length; i++) {
      final o = offerings[i];
      final id = docIds[i];
      if (o.classType != 'Lecture') {
        result.putIfAbsent(o.subCode, () => {});
        final subMap = result[o.subCode]!;

        String? matchedLectSectNo;
        for (final lectSectNo in subMap.keys) {
          if (o.sectNo.startsWith(lectSectNo)) {
            matchedLectSectNo = lectSectNo;
            break;
          }
        }

        if (matchedLectSectNo != null) {
          subMap[matchedLectSectNo]!.secondaries.add(o);
          subMap[matchedLectSectNo]!.secondaryDocIds.add(id);
        } else {
          subMap.putIfAbsent(
            o.sectNo,
            () => _LectureGroup(lecture: null, lectureDocId: null),
          );
          subMap[o.sectNo]!.secondaries.add(o);
          subMap[o.sectNo]!.secondaryDocIds.add(id);
        }
      }
    }

    return result;
  }

  // ─── Kira jumlah quota semua lab dalam satu lecture group ────────────────
  int _totalSecondaryQuota(_LectureGroup group,
      {String? excludeDocId, int? overrideQuota}) {
    int total = 0;
    for (int i = 0; i < group.secondaries.length; i++) {
      final sec = group.secondaries[i];
      final secId = group.secondaryDocIds[i];
      if (excludeDocId != null && secId == excludeDocId) {
        total += overrideQuota ?? sec.quota;
      } else {
        total += sec.quota;
      }
    }
    return total;
  }

  // ─── Suggest quota untuk lab baru ────────────────────────────────────────
  int _suggestQuota(_LectureGroup group, int lectureQuota) {
    final usedQuota = _totalSecondaryQuota(group);
    final remaining = lectureQuota - usedQuota;
    return remaining > 0 ? remaining : 0;
  }

  // ─── Bottom Sheet: Add / Edit ────────────────────────────────────────────
  void _showOfferingForm(
    BuildContext context,
    ORController controller, {
    OfferingRegistration? offering,
    String? docId,
    _LectureGroup? parentGroup, // lecture group untuk validate quota lab
  }) {
    final isEdit = offering != null;
    final isSecondary = isEdit && offering.classType != 'Lecture';

    final subCodeCtrl =
        TextEditingController(text: isEdit ? offering.subCode : '');
    final subNameCtrl =
        TextEditingController(text: isEdit ? offering.subName : '');
    final sectNoCtrl =
        TextEditingController(text: isEdit ? offering.sectNo : '');
    final daysCtrl = TextEditingController(text: isEdit ? offering.days : '');
    final startTimeCtrl =
        TextEditingController(text: isEdit ? offering.startTime : '');
    final endTimeCtrl =
        TextEditingController(text: isEdit ? offering.endTime : '');
    final lectNameCtrl =
        TextEditingController(text: isEdit ? offering.lectName : '');
    final venueCtrl = TextEditingController(text: isEdit ? offering.venue : '');

    // Quota logic:
    // - Lecture: boleh set bebas
    // - Lab/Tutorial baru: suggest sisa quota
    // - Lab/Tutorial edit: pre-fill quota sedia ada
    int suggestedQuota = 0;
    if (parentGroup != null && parentGroup.lecture != null) {
      if (isEdit) {
        suggestedQuota = offering.quota;
      } else {
        suggestedQuota = _suggestQuota(parentGroup, parentGroup.lecture!.quota);
      }
    } else if (isEdit) {
      suggestedQuota = offering.quota;
    }

    final quotaCtrl =
        TextEditingController(text: isEdit ? offering.quota.toString() : '');

    String selectedClassType = isEdit ? offering.classType : 'Lecture';
    String? quotaError;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Kira max quota yang boleh diset untuk lab ini
          int? maxAllowedQuota;
          if (selectedClassType != 'Lecture' && parentGroup?.lecture != null) {
            final lectureQuota = parentGroup!.lecture!.quota;
            final usedByOthers = _totalSecondaryQuota(
              parentGroup,
              excludeDocId: isEdit ? docId : null,
              overrideQuota: 0,
            );
            maxAllowedQuota = lectureQuota - usedByOthers;
          }

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        isEdit
                            ? 'Edit Subject Offering'
                            : 'Add Subject Offering',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A5F7A),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Row: Subject Code + Subject Name
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildField(
                              controller: subCodeCtrl,
                              label: 'Subject Code',
                              hint: 'e.g. BCS2344',
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _buildField(
                              controller: subNameCtrl,
                              label: 'Subject Name',
                              hint: 'e.g. Web Engineering',
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row: Section No + Class Type
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              controller: sectNoCtrl,
                              label: 'Section No',
                              hint: 'e.g. 01 / 01A',
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedClassType,
                              decoration: InputDecoration(
                                labelText: 'Class Type',
                                labelStyle: const TextStyle(
                                    color: Color(0xFF1A5F7A), fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFFF5F7FA),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1A5F7A), width: 1.5),
                                ),
                              ),
                              // Disable class type change bila edit
                              onChanged: isEdit
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          selectedClassType = val;
                                          // Reset quota bila tukar class type
                                          quotaCtrl.clear();
                                        });
                                      }
                                    },
                              items: ['Lecture', 'Lab', 'Tutorial']
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quota field
                      // ✅ Lab/Tutorial: tunjuk max allowed + validate
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: quotaCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Quota',
                                    hintText: selectedClassType == 'Lecture'
                                        ? 'e.g. 30'
                                        : suggestedQuota > 0
                                            ? 'Suggested: $suggestedQuota'
                                            : 'e.g. 15',
                                    labelStyle: const TextStyle(
                                        color: Color(0xFF1A5F7A), fontSize: 13),
                                    hintStyle: TextStyle(
                                        color: Colors.grey[400], fontSize: 12),
                                    filled: true,
                                    fillColor: const Color(0xFFF5F7FA),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF1A5F7A), width: 1.5),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Colors.red, width: 1),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Required';
                                    final val = int.tryParse(v);
                                    if (val == null) return 'Number only';
                                    if (val <= 0) return 'Must be > 0';
                                    // ✅ Validate: quota lab tak boleh melebihi sisa lecture quota
                                    if (selectedClassType != 'Lecture' &&
                                        maxAllowedQuota != null &&
                                        val > maxAllowedQuota) {
                                      return 'Max $maxAllowedQuota (lecture quota limit)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              // ✅ Info box: tunjuk sisa quota untuk lab
                              if (selectedClassType != 'Lecture' &&
                                  maxAllowedQuota != null) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: maxAllowedQuota > 0
                                        ? const Color(0xFFD6F5F1)
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: maxAllowedQuota > 0
                                          ? const Color(0xFF1AAFA0)
                                          : Colors.red.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Max',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: maxAllowedQuota > 0
                                              ? const Color(0xFF0D8C7F)
                                              : Colors.red,
                                        ),
                                      ),
                                      Text(
                                        '$maxAllowedQuota',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: maxAllowedQuota > 0
                                              ? const Color(0xFF0D8C7F)
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // ✅ Info text untuk lab: tunjuk quota lecture dan
                          // berapa dah dipakai
                          if (selectedClassType != 'Lecture' &&
                              parentGroup?.lecture != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Builder(builder: (_) {
                                final lectQ = parentGroup!.lecture!.quota;
                                final usedQ = _totalSecondaryQuota(
                                  parentGroup,
                                  excludeDocId: isEdit ? docId : null,
                                  overrideQuota: 0,
                                );
                                final remaining = lectQ - usedQ;
                                return Text(
                                  'Lecture quota: $lectQ  •  Used by other sections: $usedQ  •  Remaining: $remaining',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: remaining > 0
                                        ? Colors.grey.shade600
                                        : Colors.red,
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Venue
                      _buildField(
                        controller: venueCtrl,
                        label: 'Venue',
                        hint: 'e.g. BZ-01-095',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Days
                      _buildField(
                        controller: daysCtrl,
                        label: 'Day(s)',
                        hint: 'e.g. Mon / Mon,Wed',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Row: Start Time + End Time
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              controller: startTimeCtrl,
                              label: 'Start Time',
                              hint: 'e.g. 08:00',
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              controller: endTimeCtrl,
                              label: 'End Time',
                              hint: 'e.g. 10:00',
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Lecturer Name
                      _buildField(
                        controller: lectNameCtrl,
                        label: 'Lecturer Name',
                        hint: 'e.g. Dr. Noorlin',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side:
                                    const BorderSide(color: Color(0xFF1A5F7A)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel',
                                  style: TextStyle(color: Color(0xFF1A5F7A))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;

                                // ✅ Tentukan semester:
                                // 1. Bila edit — guna semester offering sedia ada
                                // 2. Bila add Lab/Tutorial baru — guna semester dari lecture induk
                                // 3. Bila add Lecture baru terus dari sini — fallback ke activeSession
                                String resolvedSemester;
                                if (isEdit) {
                                  resolvedSemester = offering!.semester;
                                } else if (parentGroup?.lecture != null) {
                                  resolvedSemester =
                                      parentGroup!.lecture!.semester;
                                } else {
                                  final session = controller.activeSession;
                                  if (session == null) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text('Tiada OR session aktif.'),
                                    ));
                                    return;
                                  }
                                  resolvedSemester = session.semester;
                                }

                                final sectID = isEdit
                                    ? offering!.sectID
                                    : _generateSectID(
                                        controller.offeringsDocIds);

                                final newOffering = OfferingRegistration(
                                  sectID: sectID,
                                  subCode: subCodeCtrl.text.trim(),
                                  subName: subNameCtrl.text.trim(),
                                  sectNo: sectNoCtrl.text.trim(),
                                  classType: selectedClassType,
                                  days: daysCtrl.text.trim(),
                                  startTime: startTimeCtrl.text.trim(),
                                  endTime: endTimeCtrl.text.trim(),
                                  lectName: lectNameCtrl.text.trim(),
                                  venue: venueCtrl.text.trim(),
                                  quota:
                                      int.tryParse(quotaCtrl.text.trim()) ?? 0,
                                  enrolled: isEdit ? offering!.enrolled : 0,
                                  // ✅ Guna resolvedSemester, bukan activeSession
                                  semester: resolvedSemester,
                                  session: '',
                                );

                                if (isEdit && docId != null) {
                                  await controller.updateOffering(
                                      docId, newOffering);
                                } else {
                                  await controller.addOffering(newOffering);
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                controller.loadData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A5F7A),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isEdit ? 'Save Changes' : 'Add Offering',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, ORController controller, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Offering'),
        content: const Text(
            'Are you sure you want to delete this subject offering?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF1A5F7A))),
          ),
          ElevatedButton(
            onPressed: () async {
              await controller.deleteOffering(docId);
              if (ctx.mounted) Navigator.pop(ctx);
              controller.loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF1A5F7A), fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A5F7A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Consumer<ORController>(
        builder: (context, controller, child) {
          final filteredOfferings = <OfferingRegistration>[];
          final filteredDocIds = <String>[];

          for (int i = 0; i < controller.offerings.length; i++) {
            final o = controller.offerings[i];
            final q = _searchQuery.toLowerCase();
            if (q.isEmpty ||
                o.subCode.toLowerCase().contains(q) ||
                o.subName.toLowerCase().contains(q) ||
                o.lectName.toLowerCase().contains(q) ||
                o.sectNo.toLowerCase().contains(q)) {
              filteredOfferings.add(o);
              filteredDocIds.add(controller.offeringsDocIds[i]);
            }
          }

          final grouped = _groupOfferings(filteredOfferings, filteredDocIds);
          final subCodes = grouped.keys.toList()..sort();

          return Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A5F7A), Color(0xFF2980B9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Expanded(
                              child: Text(
                                'Subject Offering',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.school,
                                  color: Colors.white, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.activeSession != null
                              ? '${controller.activeSession!.semester} ${controller.activeSession!.sessionID}'
                              : 'Tiada session aktif',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Search ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search subject, section or lecturer',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF1A5F7A)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.grey, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ── Label ────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${subCodes.length} subject(s) offered',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A5F7A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A5F7A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        controller.activeSession?.semester ?? 'Tiada session',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1A5F7A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Grouped List ─────────────────────────────────────────
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : subCodes.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No offerings available'
                                  : 'No results for "$_searchQuery"',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: subCodes.length,
                            itemBuilder: (context, idx) {
                              final subCode = subCodes[idx];
                              final lectGroups = grouped[subCode]!;
                              final subName = filteredOfferings
                                  .firstWhere((o) => o.subCode == subCode,
                                      orElse: () => filteredOfferings.first)
                                  .subName;

                              return _SubjectCard(
                                subCode: subCode,
                                subName: subName,
                                lectGroups: lectGroups,
                                // ✅ Edit → navigate ke EditOR (detail form)
                                onEdit: (offering, docId, group) async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditOR(
                                        offeringDocId: docId,
                                        offering: offering,
                                      ),
                                    ),
                                  );
                                  if (result == true) controller.loadData();
                                },
                                // ✅ Add Lab/Tutorial → guna bottom sheet form
                                onAddSecondary: (group) => _showOfferingForm(
                                  context,
                                  controller,
                                  parentGroup: group,
                                ),
                                onDelete: (docId) =>
                                    _confirmDelete(context, controller, docId),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),

      // ── FAB ──────────────────────────────────────────────────────────
      floatingActionButton: Consumer<ORController>(
        builder: (context, controller, _) => SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FloatingActionButton.extended(
              onPressed: () => _showOfferingForm(context, controller),
              backgroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              label: const Row(
                children: [
                  Icon(Icons.add, color: Color(0xFF1A5F7A), size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Add subject offering',
                    style: TextStyle(
                      color: Color(0xFF1A5F7A),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────
class _LectureGroup {
  final OfferingRegistration? lecture;
  final String? lectureDocId;
  final List<OfferingRegistration> secondaries = [];
  final List<String> secondaryDocIds = [];

  _LectureGroup({required this.lecture, required this.lectureDocId});

  // Kira jumlah quota semua secondaries (untuk allocation validation)
  int get totalSecondaryQuota => secondaries.fold(0, (sum, s) => sum + s.quota);

  // Sisa quota yang masih available untuk tambah lab baru
  int get remainingQuota =>
      lecture != null ? lecture!.quota - totalSecondaryQuota : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — Subject Card
// ─────────────────────────────────────────────────────────────────────────────
class _SubjectCard extends StatefulWidget {
  final String subCode;
  final String subName;
  final Map<String, _LectureGroup> lectGroups;
  final void Function(OfferingRegistration, String, _LectureGroup?) onEdit;
  final void Function(_LectureGroup) onAddSecondary;
  final void Function(String) onDelete;

  const _SubjectCard({
    required this.subCode,
    required this.subName,
    required this.lectGroups,
    required this.onEdit,
    required this.onAddSecondary,
    required this.onDelete,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _expanded.addAll(widget.lectGroups.keys);
  }

  @override
  Widget build(BuildContext context) {
    final lectSectNos = widget.lectGroups.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Subject header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F4F8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subCode,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A5F7A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2D3D),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5F7A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${lectSectNos.length} lect',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Lecture groups ─────────────────────────────────────────
          ...lectSectNos.asMap().entries.map((entry) {
            final idx = entry.key;
            final lectSectNo = entry.value;
            final group = widget.lectGroups[lectSectNo]!;
            final isExpanded = _expanded.contains(lectSectNo);
            final isLast = idx == lectSectNos.length - 1;

            return Column(
              children: [
                // Lecture row
                if (group.lecture != null) ...[
                  InkWell(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expanded.remove(lectSectNo);
                      } else {
                        _expanded.add(lectSectNo);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                      child: Row(
                        children: [
                          // Expand icon
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            size: 18,
                            color: const Color(0xFF1A5F7A),
                          ),
                          const SizedBox(width: 6),

                          // Section badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A5F7A).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              group.lecture!.sectNo,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A5F7A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _TypeBadge(
                                        label: 'Lecture',
                                        color: const Color(0xFF1A5F7A)),
                                    const SizedBox(width: 6),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${group.lecture!.days} ${group.lecture!.startTime}-${group.lecture!.endTime} · ${group.lecture!.venue}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                                Text(
                                  group.lecture!.lectName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1A5F7A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Edit + Delete lecture
                          Column(
                            children: [
                              _IconBtn(
                                icon: Icons.edit,
                                color: const Color(0xFF1A5F7A),
                                onTap: () => widget.onEdit(
                                    group.lecture!, group.lectureDocId!, null),
                              ),
                              const SizedBox(height: 4),
                              _IconBtn(
                                icon: Icons.delete_outline,
                                color: Colors.red,
                                onTap: () =>
                                    widget.onDelete(group.lectureDocId!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Secondary sections ─────────────────────────────
                if (isExpanded) ...[
                  ...group.secondaries.asMap().entries.map((secEntry) {
                    final secIdx = secEntry.key;
                    final sec = secEntry.value;
                    final secDocId = group.secondaryDocIds[secIdx];

                    return Container(
                      color: const Color(0xFFFAFCFE),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 8, 12, 8),
                        child: Row(
                          children: [
                            // Connector line indicator
                            Container(
                              width: 2,
                              height: 36,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.only(right: 10),
                            ),

                            // Section badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sec.sectNo,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _TypeBadge(
                                        label: sec.classType,
                                        color: Colors.orange.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      // ✅ Quota untuk secondary
                                      Text(
                                        '${sec.enrolled}/${sec.quota}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: sec.isFull
                                              ? Colors.red
                                              : Colors.grey.shade500,
                                          fontWeight: sec.isFull
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (sec.isFull) ...[
                                        const SizedBox(width: 4),
                                        Text('• Full',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red.shade400,
                                              fontWeight: FontWeight.bold,
                                            )),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${sec.days} ${sec.startTime}-${sec.endTime} · ${sec.venue}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),

                            // Edit + Delete secondary
                            Column(
                              children: [
                                _IconBtn(
                                  icon: Icons.edit,
                                  color: const Color(0xFF1A5F7A),
                                  onTap: () =>
                                      widget.onEdit(sec, secDocId, group),
                                ),
                                const SizedBox(height: 4),
                                _IconBtn(
                                  icon: Icons.delete_outline,
                                  color: Colors.red,
                                  onTap: () => widget.onDelete(secDocId),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // ✅ Add Lab/Tutorial button — tunjuk remaining quota
                  if (group.lecture != null && group.remainingQuota > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 4, 12, 8),
                      child: GestureDetector(
                        onTap: () => widget.onAddSecondary(group),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 14, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Add Lab/Tutorial  (${group.remainingQuota} quota remaining)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],

                if (!isLast)
                  const Divider(
                      height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
              ],
            );
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
