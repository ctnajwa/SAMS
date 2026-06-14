import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Provider/ORController.dart';
import '../../../Domain/ORModel.dart';

class ViewEnrollment extends StatefulWidget {
  const ViewEnrollment({super.key});

  @override
  State<ViewEnrollment> createState() => _ViewEnrollmentState();
}

class _ViewEnrollmentState extends State<ViewEnrollment> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _closedSections = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ORController>(context, listen: false).loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmClose(
      BuildContext context, OfferingRegistration offering, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${offering.subCode} - ${offering.sectNo}',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1A2D3D)),
        ),
        content: const Text(
          'Do you really want to close this section?',
          style: TextStyle(fontSize: 14, color: Color(0xFF5A7A8A)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child:
                      Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _closedSections.add(docId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${offering.subCode} - ${offering.sectNo} closed'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close Section'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F7),
      body: Consumer<ORController>(
        builder: (context, controller, _) {
          final offerings = controller.offerings;
          final docIds = controller.offeringsDocIds;

          // Lab/Tutorial sections sahaja
          final secondaryOfferings = <MapEntry<String, OfferingRegistration>>[];
          for (int i = 0; i < offerings.length; i++) {
            if (offerings[i].classType != 'Lecture') {
              secondaryOfferings.add(MapEntry(docIds[i], offerings[i]));
            }
          }

          // ✅ Total enrolled dikira dari Lab/Tutorial sahaja,
          // konsisten dengan Section rate card di bawah
          final totalEnrolled = secondaryOfferings.fold<int>(
              0, (sum, e) => sum + e.value.enrolled);
          final openSections = secondaryOfferings
              .where((e) => !e.value.isFull && !_closedSections.contains(e.key))
              .length;
          final fullSections =
              secondaryOfferings.where((e) => e.value.isFull).length;

          // Filter search
          final filtered = secondaryOfferings.where((e) {
            final o = e.value;
            final q = _searchQuery.toLowerCase();
            return q.isEmpty ||
                o.subCode.toLowerCase().contains(q) ||
                o.sectNo.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              // ── Header ────────────────────────────────────────────────
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
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                'View Enrollment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                controller.activeSession?.semester ??
                                    'Sem 2 2025/2026',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
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

              // ── Body ──────────────────────────────────────────────────
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Stats ────────────────────────────────
                            Row(
                              children: [
                                _buildStatCard(
                                  value: totalEnrolled.toString(),
                                  label: 'Total\nEnrolled',
                                  valueColor: const Color(0xFF1A7FC4),
                                  bgColor: const Color(0xFFDDEFF9),
                                ),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                  value: openSections.toString(),
                                  label: 'Sections\nOpen',
                                  valueColor: const Color(0xFF27AE60),
                                  bgColor: const Color(0xFFD5F0E0),
                                ),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                  value: fullSections.toString(),
                                  label: 'Sections\nFull',
                                  valueColor: const Color(0xFFE08C2D),
                                  bgColor: const Color(0xFFFAEDD5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // ── Search ───────────────────────────────
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
                                controller: _searchController,
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(Icons.search,
                                      color: Color(0xFF1A5F7A)),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear,
                                              color: Colors.grey[400],
                                              size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── Section Rate Card ─────────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Section rate',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A5F7A),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD5F0E0),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Active',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF27AE60),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (filtered.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 24),
                                      child: Center(
                                        child: Text(
                                          _searchQuery.isEmpty
                                              ? 'No Lab/Tutorial sections found'
                                              : 'No results for "$_searchQuery"',
                                          style: TextStyle(
                                              color: Colors.grey[500]),
                                        ),
                                      ),
                                    )
                                  else
                                    ...filtered.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final docId = entry.value.key;
                                      final o = entry.value.value;
                                      final isClosed =
                                          _closedSections.contains(docId);
                                      final isFull = o.isFull;
                                      final isLast = idx == filtered.length - 1;

                                      return Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 11),
                                            child: Row(
                                              children: [
                                                // ✅ Simple: "BCS2344 - 01A"
                                                // Merah kalau full
                                                Expanded(
                                                  child: Text(
                                                    '${o.subCode} - ${o.sectNo}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isFull
                                                          ? Colors.red
                                                          : const Color(
                                                              0xFF1A2D3D),
                                                    ),
                                                  ),
                                                ),

                                                // Enrolled count
                                                Text(
                                                  '${o.enrolled}/${o.quota}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isFull
                                                        ? Colors.red
                                                        : Colors.grey[500],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),

                                                // Close / Closed button
                                                isClosed
                                                    ? Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 14,
                                                                vertical: 7),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[200],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Text(
                                                          'Closed',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[500],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      )
                                                    : GestureDetector(
                                                        onTap: () =>
                                                            _confirmClose(
                                                                context,
                                                                o,
                                                                docId),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      14,
                                                                  vertical: 7),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isFull
                                                                ? Colors
                                                                    .red.shade50
                                                                : const Color(
                                                                    0xFFE8F0F5),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: isFull
                                                                ? Border.all(
                                                                    color: Colors
                                                                        .red
                                                                        .shade200,
                                                                    width: 1)
                                                                : null,
                                                          ),
                                                          child: Text(
                                                            'Close',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: isFull
                                                                  ? Colors.red
                                                                      .shade600
                                                                  : const Color(
                                                                      0xFF1A5F7A),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                              ],
                                            ),
                                          ),
                                          if (!isLast)
                                            Divider(
                                                height: 1,
                                                color: Colors.grey[100]),
                                        ],
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color valueColor,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: valueColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
