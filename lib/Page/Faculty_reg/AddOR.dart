import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Provider/ORController.dart';
import '../../../Domain/ORModel.dart';

class AddOR extends StatefulWidget {
  final Subject subject;
  final String semester; // ✅ Semester yang dipilih di SubjectManagement

  const AddOR({
    super.key,
    required this.subject,
    required this.semester,
  });

  @override
  State<AddOR> createState() => _AddORState();
}

class _AddORState extends State<AddOR> {
  final _formKey = GlobalKey<FormState>();

  String _classType = 'Lecture';
  final _sectNoController = TextEditingController(text: '');
  final _quotaController = TextEditingController(text: '');
  final _lectNameController = TextEditingController();
  final _startTimeController = TextEditingController(text: '');
  final _endTimeController = TextEditingController(text: '');
  final _venueController = TextEditingController();
  List<String> _selectedDays = [];
  bool _isSaving = false;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  final List<String> _classTypes = ['Lecture', 'Tutorial', 'Lab'];

  // ✅ Auto-generate sectID format SEC001, SEC002
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

  @override
  void dispose() {
    _sectNoController.dispose();
    _quotaController.dispose();
    _lectNameController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A5F7A),
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveOffering() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final controller = Provider.of<ORController>(context, listen: false);

    // ✅ sectID auto-generate format SEC001
    final sectID = _generateSectID(controller.offeringsDocIds);

    final offering = OfferingRegistration(
      sectID: sectID,
      subCode: widget.subject.subCode,
      subName: widget.subject.subName,
      classType: _classType,
      sectNo: _sectNoController.text,
      quota: int.tryParse(_quotaController.text) ?? 0,
      enrolled: 0,
      lectName:
          _lectNameController.text.isEmpty ? 'TBA' : _lectNameController.text,
      days: _selectedDays.join(','),
      startTime: _startTimeController.text,
      endTime: _endTimeController.text,
      venue: _venueController.text.isEmpty ? 'TBA' : _venueController.text,
      // ✅ Guna semester yang dipilih di SubjectManagement, bukan activeSession
      semester: widget.semester,
      // session field — boleh kosongkan/letak placeholder, tak digunakan untuk filter
      session: '',
    );

    await controller.addOffering(offering);
    await controller.loadData();

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OR Section added successfully!')),
      );
      Navigator.pop(context, true);
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFF7F8C8D),
      ),
      filled: true,
      fillColor: const Color(0xFFEAF4F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A5F7A),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Add Section',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.subject.subCode}-${widget.subject.subName}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A5F7A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset(
              'assets/logo_university.png',
              height: 34,
              width: 34,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 34,
                width: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school,
                    size: 20, color: Color(0xFF1A5F7A)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Tunjuk semester yang akan digunakan
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5F7A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF1A5F7A).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Color(0xFF1A5F7A)),
                    const SizedBox(width: 8),
                    Text(
                      'Offering for: ${widget.semester}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A5F7A),
                      ),
                    ),
                  ],
                ),
              ),

              // Class Card
              _buildSectionCard(
                title: 'Class',
                child: DropdownButtonFormField<String>(
                  value: _classType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFEAF4F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF1A5F7A)),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                  ),
                  items: _classTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _classType = val);
                  },
                ),
              ),

              // Section Details Card
              _buildSectionCard(
                title: 'Section details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _sectNoController,
                      decoration: _fieldDecoration('Section'),
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF2C3E50)),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Section number required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _quotaController,
                      decoration: _fieldDecoration('Quota'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF2C3E50)),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Quota required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _lectNameController,
                      decoration: _fieldDecoration('Assign lecturer'),
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
              ),

              // Class Schedule Card
              _buildSectionCard(
                title: 'Class schedule',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Days',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _days.map((day) {
                        final bool isSelected = _selectedDays.contains(day);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedDays.remove(day);
                              } else {
                                _selectedDays.add(day);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1A5F7A)
                                  : const Color(0xFFD6EEF6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF0C447C),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(_startTimeController),
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _startTimeController,
                                decoration: _fieldDecoration(''),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2C3E50),
                                ),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '-',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2C3E50),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(_endTimeController),
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _endTimeController,
                                decoration: _fieldDecoration(''),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2C3E50),
                                ),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _venueController,
                      decoration: _fieldDecoration('Venue'),
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _saveOffering,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF1A5F7A),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1A5F7A),
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A5F7A),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
