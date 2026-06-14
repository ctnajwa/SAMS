import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Provider/ORController.dart';
import '../../../Domain/ORModel.dart';
import 'CourseRegistration.dart';

class StudentOR extends StatefulWidget {
  final String studentID;
  final String studentName;
  final String programme;

  const StudentOR({
    super.key,
    required this.studentID,
    required this.studentName,
    required this.programme,
  });

  @override
  State<StudentOR> createState() => _StudentORState();
}

class _StudentORState extends State<StudentOR> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<ORController>();
      ctrl.setCurrentUser(studentID: widget.studentID);
      ctrl.processOR();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // viewSection() — navigate ke CourseRegistrationPage
  void _onViewSubject(
    BuildContext context,
    Subject subject,
    List<OfferingRegistration> sections,
  ) {
    // Get the existing ORController from the current context
    final orController = Provider.of<ORController>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: orController, // Reuse the same controller instance
          child: CourseRegistration(
            subject: subject,
            offerings: sections,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Consumer<ORController>(
        builder: (context, ctrl, _) {
          return Column(
            children: [
              _buildHeader(ctrl),
              Expanded(
                child: ctrl.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1AAFA0),
                        ),
                      )
                    : _buildBody(context, ctrl),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ORController ctrl) {
    final session = ctrl.activeSession;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Course Registration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (session != null)
                      Text(
                        session.semester,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
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

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, ORController ctrl) {
    final session = ctrl.activeSession;

    if (session == null || !session.isActive) {
      return _buildEmptyState(
        icon: Icons.event_busy_outlined,
        message: 'No active OR session at the moment.',
        subtitle: 'Please check with your Faculty Registrar.',
      );
    }

    // Group offerings by subCode untuk cari unique subjects
    final offeringsBySubject = ctrl.offeringsBySubject;

    // Build unique subject list dari offerings
    final Map<String, Subject> subjectMap = {};
    for (final sub in ctrl.subjects) {
      subjectMap[sub.subCode] = sub;
    }

    // Filter berdasarkan search
    final query = _searchQuery.toLowerCase().trim();
    final List<String> subCodes = offeringsBySubject.keys.where((code) {
      if (query.isEmpty) return true;
      final name = subjectMap[code]?.subName ?? '';
      return code.toLowerCase().contains(query) ||
          name.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _buildORBanner(session),
        const SizedBox(height: 16),
        _buildSearchBar(),
        const SizedBox(height: 20),
        _buildSubjectList(
            context, ctrl, subCodes, subjectMap, offeringsBySubject),
      ],
    );
  }

  // ── OR Active Banner ──────────────────────────────────────────────────────

  Widget _buildORBanner(ORSession session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD6F5F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1AAFA0).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF1AAFA0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'OR is active . ${session.displayDateRange}',
            style: const TextStyle(
              color: Color(0xFF0D8C7F),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          suffixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── Subject List ──────────────────────────────────────────────────────────

  Widget _buildSubjectList(
    BuildContext context,
    ORController ctrl,
    List<String> subCodes,
    Map<String, Subject> subjectMap,
    Map<String, List<OfferingRegistration>> offeringsBySubject,
  ) {
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
              'Available subject',
              style: TextStyle(
                color: Color(0xFF1AAFA0),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          if (subCodes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No subjects found.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subCodes.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFF0F0F0),
              ),
              itemBuilder: (context, index) {
                final subCode = subCodes[index];
                final subject = subjectMap[subCode];
                final offerings = offeringsBySubject[subCode] ?? [];

                // Kira lecture sections sahaja untuk display
                final lectureSections =
                    offerings.where((o) => o.classType == 'Lecture').toList();

                final isRegistered = ctrl.isSubjectRegistered(subCode);

                return _SubjectTile(
                  subCode: subCode,
                  subName: subject?.subName ?? subCode,
                  creditHour: subject?.creditHour ?? 0,
                  sectionsCount: lectureSections.length,
                  isRegistered: isRegistered,
                  onView: () => _onViewSubject(
                    context,
                    subject ??
                        Subject(
                          subCode: subCode,
                          subName: subCode,
                          creditHour: 0,
                          faculty: '',
                        ),
                    offerings,
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT TILE — satu row dalam senarai subject
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectTile extends StatelessWidget {
  final String subCode;
  final String subName;
  final int creditHour;
  final int sectionsCount;
  final bool isRegistered;
  final VoidCallback onView;

  const _SubjectTile({
    required this.subCode,
    required this.subName,
    required this.creditHour,
    required this.sectionsCount,
    required this.isRegistered,
    required this.onView,
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
                  '$subCode - $subName',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$creditHour Credit hours-$sectionsCount sections available',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (isRegistered)
                  const Text(
                    'Registered ✓',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1AAFA0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: onView,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRegistered
                    ? const Color(0xFF1AAFA0)
                    : const Color(0xFFE8F7F5),
                foregroundColor:
                    isRegistered ? Colors.white : const Color(0xFF1AAFA0),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('View'),
            ),
          ),
        ],
      ),
    );
  }
}
