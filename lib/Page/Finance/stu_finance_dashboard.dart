import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'stu_payment.dart';

class StuFinanceDashboard extends StatefulWidget {
  final String loggedInStudentMatricId;

  const StuFinanceDashboard({
    super.key,
    required this.loggedInStudentMatricId,
  });

  @override
  State<StuFinanceDashboard> createState() => _StuFinanceDashboardViewState();
}

class _StuFinanceDashboardViewState extends State<StuFinanceDashboard> {
  bool _showRecordView = false;

  @override
  Widget build(BuildContext context) {
    final String currentStudentMatricId = widget.loggedInStudentMatricId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Padding(
            padding: EdgeInsets.only(top: 20.0),
            child: Text(
              'STUDENT ACADEMIC\nMANAGEMENT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo_umpsa.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF11A06E),
                  Color(0xFF48C598),
                  Color(0xFF88E5BE),
                ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(
                  currentStudentMatricId) // 👈 Automatically fetches CB23001's document profile
              .get(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                  child: Text(
                      'Financial records missing for ID: $currentStudentMatricId'));
            }

            final studentData = snapshot.data!.data() as Map<String, dynamic>;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentStudentMatricId)
                  .collection('receipts')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, receiptSnapshot) {
                double totalReceivedAllSemesters = 0.0;
                double currentSemReceivedAccumulator = 0.0;
                double totalRefundAccumulator = 0.0;
                List<QueryDocumentSnapshot> receiptDocs = [];

                if (receiptSnapshot.hasData) {
                  receiptDocs = receiptSnapshot.data!.docs;
                  for (var doc in receiptDocs) {
                    final rData = doc.data() as Map<String, dynamic>;
                    double amount =
                        double.tryParse(rData['totalReceived'].toString()) ??
                            0.0;
                    String semStr = (rData['semester'] ?? '').toString();
                    double refund =
                        double.tryParse((rData['refund'] ?? 0.0).toString()) ??
                            0.0;

                    totalReceivedAllSemesters += amount;
                    totalRefundAccumulator += refund;

                    if (semStr == 'SEM II 25/26' || semStr == 'SEM 2 25/26') {
                      currentSemReceivedAccumulator += amount;
                    }
                  }
                }

                double calculatedCurrentTotalFee =
                    1510.0 - currentSemReceivedAccumulator;
                if (calculatedCurrentTotalFee < 0) {
                  calculatedCurrentTotalFee = 0.0;
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Student Finance',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // --- TAB TOGGLE SELECTION NAVIGATION ROW ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showRecordView = false),
                            child: Text(
                              'Payment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: !_showRecordView
                                    ? Colors.black87
                                    : Colors.grey,
                                decoration: !_showRecordView
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('|',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showRecordView = true),
                            child: Text(
                              'Record',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _showRecordView
                                    ? Colors.black87
                                    : Colors.grey,
                                decoration: _showRecordView
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _showRecordView
                          ? _buildRecordView(
                              currentStudentMatricId, // 👈 Pass down dynamically
                              studentData,
                              receiptDocs,
                              totalReceivedAllSemesters,
                              calculatedCurrentTotalFee,
                              totalRefundAccumulator,
                            )
                          : _buildPaymentDashboardView(
                              currentStudentMatricId, // 👈 Pass down dynamically
                              calculatedCurrentTotalFee,
                              studentData['status'] ?? 'NOT BLOCKED',
                            ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaymentDashboardView(
      String matricId, double unpaidBalance, String statusValue) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF8CC5AA), Color(0xFFC0AFA2), Color(0xFFC68A81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Unsettled Total',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                'RM ${unpaidBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Status   ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              statusValue,
              style: TextStyle(
                color: statusValue.trim().toUpperCase() == 'BLOCKED'
                    ? Colors.red
                    : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: 180,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1632A8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StuPayment(
                      passedStudentMatricId: matricId), // 👈 Passes ID to form
                ),
              );
            },
            child: const Text(
              'PAY',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordView(
    String matricId,
    Map<String, dynamic> data,
    List<QueryDocumentSnapshot> receipts,
    double totalRec,
    double finalOutstandingBalance,
    double totalRef,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLedgerRow('Name', data['name'] ?? 'N/A'),
        _buildLedgerRow('Matric ID', matricId), // 👈 Dynamic display
        _buildLedgerRow('Email', data['email'] ?? 'N/A'),
        _buildLedgerRow('Contact Number', data['contact'] ?? 'N/A'),
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Text(
              data['status'] ?? 'N/A',
              style: TextStyle(
                color: (data['status'] ?? '').toString().trim().toUpperCase() ==
                        'BLOCKED'
                    ? Colors.red
                    : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildLedgerRow('Sponsor', data['sponsor'] ?? 'NONE'),
        _buildLedgerRow('Bank Number', data['bankNumber'] ?? 'N/A'),
        _buildLedgerRow('Bank', data['bankName'] ?? 'N/A'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              const SizedBox(
                width: 140,
                child: Text('Current Total Fee',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Text(
                'RM ${finalOutstandingBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Table(
          border: TableBorder.all(color: Colors.grey.shade400),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(1.3),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.0),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade50),
              children: const [
                _TableCellHeader('Receipt No.'),
                _TableCellHeader('Semester'),
                _TableCellHeader('Payment Date'),
                _TableCellHeader('Total Received'),
                _TableCellHeader('Balance'),
                _TableCellHeader('Refund'),
              ],
            ),
            ...(() {
              double runningSem2FeeBalance = 1510.0;

              return receipts.map((doc) {
                final receiptNo = doc.id;
                final rData = doc.data() as Map<String, dynamic>;
                double singleReceived =
                    double.tryParse(rData['totalReceived'].toString()) ?? 0.0;
                String semStr = (rData['semester'] ?? '').toString();
                final String? docUrlString = rData['documentUrl'];

                double displayRowBalance = 0.0;

                if (semStr == 'SEM II 25/26' || semStr == 'SEM 2 25/26') {
                  runningSem2FeeBalance -= singleReceived;
                  displayRowBalance = runningSem2FeeBalance;
                } else {
                  displayRowBalance = 0.00;
                }

                if (displayRowBalance < 0) displayRowBalance = 0.0;

                return TableRow(
                  children: [
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: InkWell(
                        onTap: () async {
                          if (docUrlString != null && docUrlString.isNotEmpty) {
                            final Uri urlValue = Uri.parse(docUrlString);
                            if (await canLaunchUrl(urlValue)) {
                              await launchUrl(urlValue,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Could not open document link.')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Receipt #$receiptNo has no attachment.')),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            receiptNo,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    _TableCellText(rData['semester'] ?? ''),
                    _TableCellText(rData['paymentDate'] ?? ''),
                    _TableCellText(singleReceived.toStringAsFixed(2)),
                    _TableCellText(displayRowBalance.toStringAsFixed(2),
                        color: Colors.red),
                    _TableCellText(
                      double.parse((rData['refund'] ?? 0.0).toString())
                          .toStringAsFixed(2),
                      color: Colors.red,
                    ),
                  ],
                );
              }).toList();
            })(),
            TableRow(
              children: [
                const TableCell(child: SizedBox()),
                const TableCell(child: SizedBox()),
                const TableCell(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                ),
                _TableCellText(totalRec.toStringAsFixed(2), isBold: true),
                _TableCellText(finalOutstandingBalance.toStringAsFixed(2),
                    isBold: true, color: Colors.red),
                _TableCellText(totalRef.toStringAsFixed(2),
                    isBold: true, color: Colors.red),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLedgerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 15, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

class _TableCellHeader extends StatelessWidget {
  final String text;
  const _TableCellHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          textAlign: TextAlign.center),
    );
  }
}

class _TableCellText extends StatelessWidget {
  final String text;
  final bool isBold;
  final Color color;
  const _TableCellText(this.text,
      {this.isBold = false, this.color = Colors.black87});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      child: Text(
        text,
        style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
            fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}
