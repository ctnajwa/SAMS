// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/Provider/ORController.dart
// Controller Class — PACK111-SAMS-2026
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../Domain/ORModel.dart';
import '../Services/FirebaseService.dart';

class ORController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  String _regisID = '';
  String _studentID = '';
  String _sectID = '';
  String _sessionID = '';
  String _regID = '';

  String get regisID => _regisID;
  String get studentID => _studentID;
  String get sectID => _sectID;
  String get sessionID => _sessionID;
  String get regID => _regID;

  List<OfferingRegistration> _offerings = [];
  List<String> _offeringsDocIds = [];
  List<Subject> _subjects = [];
  List<ORSession> _orSessions = [];

  List<CourseRegistrationRecord> _studentRegistrations = [];
  List<String> _studentRegDocIds = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<OfferingRegistration> get offerings => _offerings;
  List<String> get offeringsDocIds => _offeringsDocIds;
  List<Subject> get subjects => _subjects;
  List<ORSession> get orSessions => _orSessions;
  List<CourseRegistrationRecord> get studentRegistrations =>
      _studentRegistrations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ORSession? get activeSession {
    try {
      return _orSessions.firstWhere((s) => s.isActive);
    } catch (_) {
      return null;
    }
  }

  // ✅ Filter ikut semester sahaja — semua offerings dalam semester yang sama
  // available untuk semua year groups, tak kira sessionID OR period
  List<OfferingRegistration> get activeOfferings {
    final session = activeSession;
    if (session == null) return [];
    return _offerings.where((o) => o.semester == session.semester).toList();
  }

  List<Subject> get activeSubjects {
    final Map<String, Subject> seen = {};
    for (final o in activeOfferings) {
      if (!seen.containsKey(o.subCode)) {
        seen[o.subCode] = Subject(
          subCode: o.subCode,
          subName: o.subName,
          creditHour: _subjects
              .firstWhere(
                (s) => s.subCode == o.subCode,
                orElse: () => Subject(
                    subCode: '', subName: '', creditHour: 0, faculty: ''),
              )
              .creditHour,
          faculty: _subjects
              .firstWhere(
                (s) => s.subCode == o.subCode,
                orElse: () => Subject(
                    subCode: '', subName: '', creditHour: 0, faculty: ''),
              )
              .faculty,
        );
      }
    }
    return seen.values.toList();
  }

  Map<String, List<OfferingRegistration>> get offeringsBySubject {
    final Map<String, List<OfferingRegistration>> map = {};
    for (final o in activeOfferings) {
      map.putIfAbsent(o.subCode, () => []).add(o);
    }
    return map;
  }

  Set<String> get registeredSectIDs =>
      _studentRegistrations.map((r) => r.sectID).toSet();

  Set<String> get registeredSubCodes =>
      _studentRegistrations.map((r) => r.subCode).toSet();

  bool isSubjectRegistered(String subCode) =>
      registeredSubCodes.contains(subCode);

  int get totalRegisteredSubjects =>
      _studentRegistrations.where((r) => r.isLecture).length;

  int get totalCreditHours => _studentRegistrations
      .where((r) => r.isLecture)
      .fold(0, (sum, r) => sum + r.creditHour);

  // ═══════════════════════════════════════════════════════════════════════════
  // SDD METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> processOR() async => await loadData();

  Future<void> updateOR(OfferingRegistration offering, String docId) async {
    try {
      await _firebaseService.updateOffering(docId, offering);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update offering: $e';
      notifyListeners();
    }
  }

  Future<OfferingRegistration?> fetchORRecord(String sectID) async {
    for (final offering in _offerings) {
      if (offering.sectID == sectID) return offering;
    }
    return null;
  }

  void setCurrentUser({String? studentID, String? regisID}) {
    if (studentID != null) _studentID = studentID;
    if (regisID != null) _regisID = regisID;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _firebaseService.getSubjects(),
        _firebaseService.getORSessions(),
      ]);

      _subjects = results[0] as List<Subject>;
      _orSessions = results[1] as List<ORSession>;

      _listenToOfferings();

      if (_studentID.isNotEmpty) {
        _listenToStudentRegistrations();
      }
    } catch (e) {
      _errorMessage = 'Failed to load data: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Ambil SEMUA offerings tanpa filter semester di Firestore-side.
  // Ini elak masalah mismatch format semester antara or_sessions dan offerings
  // (contoh: "Sem 2" vs "Sem 2 25/26"). Filtering ikut semester (jika perlu)
  // dibuat di UI layer (SubjectOffering/ViewEnrollment) menggunakan
  // controller.offerings terus.
  void _listenToOfferings() {
    _firebaseService.getOfferingsWithIds().listen(
      (offeringsWithIds) {
        _offerings = [];
        _offeringsDocIds = [];
        for (final item in offeringsWithIds) {
          _offeringsDocIds.add(item['id'] as String);
          _offerings.add(item['data'] as OfferingRegistration);
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Stream error: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _listenToStudentRegistrations() {
    _firebaseService.getStudentRegistrations(_studentID).listen(
      (regsWithIds) {
        _studentRegistrations = [];
        _studentRegDocIds = [];
        for (final item in regsWithIds) {
          _studentRegDocIds.add(item['id'] as String);
          _studentRegistrations.add(item['data'] as CourseRegistrationRecord);
        }
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Registration stream error: $e';
        notifyListeners();
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OFFERING CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> addOffering(OfferingRegistration offering) async {
    await _firebaseService.addOffering(offering);
    notifyListeners();
  }

  Future<void> updateOffering(
      String docId, OfferingRegistration offering) async {
    await _firebaseService.updateOffering(docId, offering);
    notifyListeners();
  }

  Future<void> deleteOffering(String docId) async {
    await _firebaseService.deleteOffering(docId);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBJECT CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> addSubject(Subject subject) async {
    await _firebaseService.addSubject(subject);
    _subjects = await _firebaseService.getSubjects();
    notifyListeners();
  }

  Future<void> updateSubject(String docId, Subject subject) async {
    await _firebaseService.updateSubject(docId, subject);
    _subjects = await _firebaseService.getSubjects();
    notifyListeners();
  }

  Future<void> deleteSubject(String docId) async {
    await _firebaseService.deleteSubject(docId);
    _subjects = await _firebaseService.getSubjects();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OR SESSION MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> saveORSession(ORSession session) async {
    await _firebaseService.saveORSession(session);
    await loadData();
  }

  // ✅ activateORSession tidak diperlukan — isActive auto-calculate dari tarikh masa

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENT REGISTRATION — registerSubject()
  // ✅ sectID = Firestore doc ID, boleh guna terus untuk incrementEnrolled
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> registerSubject({
    required OfferingRegistration offering,
  }) async {
    if (_studentID.isEmpty) return 'Student not logged in.';

    final session = activeSession;
    if (session == null || !session.isActive) {
      return 'OR session is not currently active.';
    }

    if (offering.isFull) {
      return 'Section ${offering.sectNo} is full (${offering.enrollmentLabel}).';
    }

    if (offering.isLecture && isSubjectRegistered(offering.subCode)) {
      return '${offering.subCode} - ${offering.subName} sudah didaftarkan.';
    }

    if (registeredSectIDs.contains(offering.sectID)) {
      return 'Section ${offering.sectNo} sudah dipilih.';
    }

    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final newRegID = 'REG${now.millisecondsSinceEpoch}';

      _regID = newRegID;
      _sectID = offering.sectID;
      _sessionID = session.sessionID;

      final subjectRef = _subjects.firstWhere(
        (s) => s.subCode == offering.subCode,
        orElse: () =>
            Subject(subCode: '', subName: '', creditHour: 0, faculty: ''),
      );

      final record = CourseRegistrationRecord(
        regID: newRegID,
        studentID: _studentID,
        sectID: offering.sectID,
        sessionID: session.sessionID,
        totalSub: totalRegisteredSubjects + (offering.isLecture ? 1 : 0),
        regStatus: 'Registered',
        regAt: now,
        subCode: offering.subCode,
        subName: offering.subName,
        creditHour: offering.isLecture ? subjectRef.creditHour : 0,
        classType: offering.classType,
        sectNo: offering.sectNo,
        lectName: offering.lectName,
        days: offering.days,
        startTime: offering.startTime,
        endTime: offering.endTime,
        venue: offering.venue,
        semester: offering.semester,
      );

      await _firebaseService.addStudentRegistration(record);
      // ✅ offering.sectID = Firestore doc ID — betul dan konsisten dengan SDD
      await _firebaseService.incrementEnrolled(offering.sectID);

      _errorMessage = null;
      return null;
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
      return _errorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENT DROP SUBJECT — dropSubject()
  // ✅ sectID dari registration record boleh guna terus untuk decrementEnrolled
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> dropSubject(String subCode) async {
    try {
      final toRemove = <int>[];
      for (int i = 0; i < _studentRegistrations.length; i++) {
        if (_studentRegistrations[i].subCode == subCode) {
          toRemove.add(i);
        }
      }

      for (final idx in toRemove) {
        final regDocId = _studentRegDocIds[idx];
        final sectID = _studentRegistrations[idx].sectID;

        await _firebaseService.deleteStudentRegistration(regDocId);
        // ✅ sectID = Firestore doc ID untuk offerings — boleh guna terus
        await _firebaseService.decrementEnrolled(sectID);
      }
      return null;
    } catch (e) {
      return 'Failed to drop subject: $e';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENT EDIT REGISTRATION — editRegistration()
  // ✅ sectID = Firestore doc ID — boleh guna terus untuk decrement/increment
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> editRegistration({
    required String subCode,
    required String classType,
    required OfferingRegistration newOffering,
  }) async {
    try {
      // Cari rekod lama dengan trim() + toLowerCase() untuk elak mismatch
      int? existingIdx;
      for (int i = 0; i < _studentRegistrations.length; i++) {
        final r = _studentRegistrations[i];
        if (r.subCode.trim() == subCode.trim() &&
            r.classType.trim().toLowerCase() ==
                classType.trim().toLowerCase()) {
          existingIdx = i;
          break;
        }
      }

      if (existingIdx == null) {
        final found = _studentRegistrations
            .map((r) => '${r.subCode}|${r.classType}')
            .join(', ');
        return 'Registration record not found.\nLooking for: $subCode | $classType\nAvailable: $found';
      }

      if (newOffering.isFull) {
        return 'Section ${newOffering.sectNo} is full.';
      }

      final existing = _studentRegistrations[existingIdx];
      final regDocId = _studentRegDocIds[existingIdx];

      final subjectRef = _subjects.firstWhere(
        (s) => s.subCode == subCode,
        orElse: () =>
            Subject(subCode: '', subName: '', creditHour: 0, faculty: ''),
      );

      final updated = CourseRegistrationRecord(
        regID: existing.regID,
        studentID: existing.studentID,
        sectID: newOffering.sectID,
        sessionID: existing.sessionID,
        totalSub: existing.totalSub,
        regStatus: 'Registered', // Kekal 'Registered' supaya stream masih fetch
        regAt: existing.regAt,
        subCode: subCode,
        subName: newOffering.subName,
        creditHour: existing.isLecture ? subjectRef.creditHour : 0,
        classType: existing.classType,
        sectNo: newOffering.sectNo,
        lectName: newOffering.lectName,
        days: newOffering.days,
        startTime: newOffering.startTime,
        endTime: newOffering.endTime,
        venue: newOffering.venue,
        semester: existing.semester,
      );

      await _firebaseService.updateStudentRegistration(regDocId, updated);
      // ✅ sectID = Firestore doc ID — guna terus tanpa perlu cari index
      await _firebaseService.decrementEnrolled(existing.sectID);
      await _firebaseService.incrementEnrolled(newOffering.sectID);

      return null;
    } catch (e) {
      return 'Failed to edit registration: $e';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATISTICS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> getTotalEnrolled() async =>
      await _firebaseService.getTotalEnrolled();

  Future<int> getTotalOfferings() async =>
      await _firebaseService.getTotalOfferings();

  Future<int> getFullOfferings() async =>
      await _firebaseService.getFullOfferings();

  // ═══════════════════════════════════════════════════════════════════════════
  // SAMPLE DATA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initializeData() async {
    await _firebaseService.initializeSampleData();
    await loadData();
  }
}
