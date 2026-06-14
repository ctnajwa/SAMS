import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Module Imports
import '../../provider/sams_financial_controller.dart';
import 'payment_successful.dart';
import 'payment_unsuccessful.dart';

class StuPayment extends StatefulWidget {
  final String passedStudentMatricId;

  const StuPayment({super.key, required this.passedStudentMatricId});

  @override
  State<StuPayment> createState() => _StuPaymentState();
}

class _StuPaymentState extends State<StuPayment> {
  bool _isLoading = false;

  // Form Field Input Controllers (SDD Page 44)
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _cardNoController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();

  String _paymentMethod = "FPX";
  String _selectedBank = "MAYBANK";

  // EmailJS Network pipeline execution script
  Future<void> _sendEmailReceipt({
    required String studentName,
    required String studentEmail,
    required String receiptNo,
    required String totalPaid,
    required String payMethod,
    required String bankName,
  }) async {
    const String emailJsServiceId = 'service_nhkos7p';
    const String emailJsTemplateId = 'template_oeo0484';
    const String emailJsPublicKey = '--_2ij_sFZf0k8Vtl';

    final Uri emailApiEndpoint = Uri.parse(
      'https://api.emailjs.com/api/v1.0/email/send',
    );

    try {
      await http.post(
        emailApiEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': emailJsServiceId,
          'template_id': emailJsTemplateId,
          'user_id': emailJsPublicKey,
          'template_params': {
            'name': studentName,
            'to_email': studentEmail,
            'receiptNo': receiptNo,
            'paymentDate': DateFormat('dd/MM/yyyy').format(DateTime.now()),
            'totalPaid': totalPaid,
            'paymentMethod': payMethod,
            'bankName': bankName,
          },
        }),
      );
    } catch (e) {
      debugPrint("Email delivery failure: $e");
    }
  }

  // Core Processing Engine using Controller Pipelines (SDD PACK311-SAMS-2026)
  Future<void> _processPaymentTransaction(
    Map<String, dynamic> studentProfile,
  ) async {
    final String amountInputText = _totalController.text.trim();
    final double? parsedAmount = double.tryParse(amountInputText);
    final String currentStudentMatricId = widget.passedStudentMatricId;

    // If input is non-numeric, null, or zero, route immediately to the Unsuccessful page file
    if (parsedAmount == null || parsedAmount <= 0) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PaymentUnsuccessful()),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Fetch historical data to process dynamic balance deductions chronologically
      final previousReceiptsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentStudentMatricId)
          .collection('receipts')
          .get();

      double accumulatedPastPayments = 0.0;
      for (var doc in previousReceiptsSnapshot.docs) {
        final rData = doc.data();
        if (rData['semester'] == 'SEM 2 25/26') {
          accumulatedPastPayments +=
              double.tryParse(rData['totalReceived'].toString()) ?? 0.0;
        }
      }

      double baseSemesterFee = 1510.0;
      double balanceBeforeThisPayment =
          baseSemesterFee - accumulatedPastPayments;
      double remainingNewBalance = balanceBeforeThisPayment - parsedAmount;
      if (remainingNewBalance < 0) remainingNewBalance = 0.0;

      final String generatedReceiptNo =
          (Random().nextInt(900000) + 100000).toString();

      // 2. Delegate Database Operations to the Controller (PACK311-SAMS-2026)
      final SAMSFinancialController financialController =
          SAMSFinancialController();

      bool isSuccess = await financialController.processPayment(
        matricId: currentStudentMatricId,
        receiptNo: generatedReceiptNo,
        paymentAmount: parsedAmount,
        remainingBalance: remainingNewBalance,
        method: _paymentMethod,
        bank: _selectedBank,
      );

      if (isSuccess) {
        // 3. Trigger notification copy template
        await _sendEmailReceipt(
          studentName: studentProfile['name'] ?? 'Student',
          studentEmail: studentProfile['email'] ?? 'surayahisyam00@gmail.com',
          receiptNo: generatedReceiptNo,
          totalPaid: parsedAmount.toStringAsFixed(2),
          payMethod: _paymentMethod,
          bankName: _selectedBank,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PaymentSuccessful()),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PaymentUnsuccessful()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PaymentUnsuccessful()),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentStudentMatricId = widget.passedStudentMatricId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
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
              .doc(currentStudentMatricId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String nameStr = data['name'] ?? 'N/A';
            final String todayDateStr =
                DateFormat('dd-MM-yyyy').format(DateTime.now());

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Payment',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  _buildLockedFormRow('Date', todayDateStr),
                  _buildLockedFormRow(
                    'Payment',
                    'STUDENT FEE FOR $currentStudentMatricId',
                  ),
                  _buildLockedFormRow('Name', nameStr),
                  _buildLockedFormRow(
                    'IC Number',
                    data['icNumber'] ?? '080714-06-0132',
                  ),
                  _buildLockedFormRow('Receiver', 'UMPSA'),

                  // Text input row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Total (RM)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _totalController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Radio buttons row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Payment\nMethod',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Radio<String?>(
                                    value: "FPX",
                                    groupValue: _paymentMethod,
                                    onChanged: (String? val) {
                                      if (val != null) {
                                        setState(() => _paymentMethod = val);
                                      }
                                    },
                                  ),
                                  const Text(
                                    'FPX\n(Internet Banking)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 16),
                                  Radio<String?>(
                                    value: "VISA",
                                    groupValue: _paymentMethod,
                                    onChanged: (String? val) {
                                      if (val != null) {
                                        setState(() => _paymentMethod = val);
                                      }
                                    },
                                  ),
                                  const Text(
                                    'VISA\n(Credit/Debit)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dropdown row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Bank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: DropdownButtonFormField<String>(
                              value: _selectedBank,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "MAYBANK",
                                  child: Text(
                                    "MAYBANK",
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "CIMB",
                                  child: Text(
                                    "CIMB",
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "BANK ISLAM",
                                  child: Text(
                                    "BANK ISLAM",
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedBank = val!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Visa expansion fields
                  if (_paymentMethod == "VISA") ...[
                    _buildDynamicInputField(
                      'Card\nNumber',
                      _cardNoController,
                      'XXXX-XXXX-XXXX',
                    ),
                    _buildDynamicInputField(
                      'PIN Number',
                      _pinController,
                      'XXX',
                      obscure: true,
                    ),
                    _buildDynamicInputField(
                      'Expiry Date',
                      _expiryController,
                      'MM/YY',
                    ),
                  ],
                  const SizedBox(height: 32),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: 140,
                          height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1632A8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _processPaymentTransaction(data),
                            child: const Text(
                              'PAY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 140,
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black87),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLockedFormRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                enabled: false,
                decoration: InputDecoration(
                  hintText: value,
                  hintStyle:
                      const TextStyle(color: Colors.black87, fontSize: 14),
                  fillColor: const Color(0xFFEEEEEE),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicInputField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
