import 'package:cloud_firestore/cloud_firestore.dart';
import '../Domain/ORModel.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== SUBJECT OPERATIONS ==========
  Future<List<Subject>> getSubjects() async {
    final snapshot = await _firestore.collection('subjects').get();
    List<Subject> subjects = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      subjects.add(Subject(
        subCode: data['subCode'] as String? ?? '',
        subName: data['subName'] as String? ?? '',
        creditHour: data['creditHour'] as int? ?? 0,
        faculty: data['faculty'] as String? ?? '',
      ));
    }
    return subjects;
  }

  Future<void> addSubject(Subject subject) async {
    await _firestore.collection('subjects').add(subject.toMap());
  }

  Future<void> updateSubject(String docId, Subject subject) async {
    await _firestore.collection('subjects').doc(docId).update(subject.toMap());
  }

  Future<void> deleteSubject(String docId) async {
    await _firestore.collection('subjects').doc(docId).delete();
  }

  // ========== OFFERING / SECTION OPERATIONS ==========
  // SDD Section Table: sectID adalah PK — guna sebagai Firestore doc ID
  // Ini konsisten dengan SDD dan mengelakkan kekeliruan antara sectID dan Firestore docId

  // ✅ Filter ikut semester sahaja — session/sessionID tak relevan untuk offerings
  Stream<List<Map<String, dynamic>>> getOfferingsWithIds({String? semester}) {
    Query query = _firestore.collection('offerings');
    if (semester != null) {
      query = query.where('semester', isEqualTo: semester);
    }
    return query.snapshots().map((snapshot) {
      List<Map<String, dynamic>> result = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        result.add({
          // ✅ id = doc.id = sectID (kerana kita guna sectID sebagai doc ID)
          'id': doc.id,
          'data': OfferingRegistration(
            sectID:
                doc.id, // ✅ Ambil terus dari doc.id untuk pastikan konsisten
            subCode: data['subCode'] as String? ?? '',
            subName: data['subName'] as String? ?? '',
            classType: data['classType'] as String? ?? '',
            sectNo: data['sectNo'] as String? ?? '',
            quota: data['quota'] as int? ?? 0,
            enrolled: data['enrolled'] as int? ?? 0,
            lectName: data['lectName'] as String? ?? '',
            days: data['days'] as String? ?? '',
            startTime: data['startTime'] as String? ?? '',
            endTime: data['endTime'] as String? ?? '',
            venue: data['venue'] as String? ?? '',
            semester: data['semester'] as String? ?? '',
            session: data['session'] as String? ?? '',
          ),
        });
      }
      return result;
    });
  }

  // ✅ Guna sectID sebagai Firestore doc ID (.doc(sectID).set())
  Future<void> addOffering(OfferingRegistration offering) async {
    await _firestore
        .collection('offerings')
        .doc(offering.sectID) // ✅ sectID = doc ID, konsisten dengan SDD PK
        .set({
      'subCode': offering.subCode,
      'subName': offering.subName,
      'classType': offering.classType,
      'sectNo': offering.sectNo,
      'quota': offering.quota,
      'enrolled': offering.enrolled,
      'lectName': offering.lectName,
      'days': offering.days,
      'startTime': offering.startTime,
      'endTime': offering.endTime,
      'venue': offering.venue,
      'semester': offering.semester,
      'session': offering.session,
      // sectID tidak perlu disimpan sebagai field kerana ia sudah jadi doc ID
      // tapi simpan jugak untuk backward compatibility dan query
      'sectID': offering.sectID,
    });
  }

  Future<void> updateOffering(
      String docId, OfferingRegistration offering) async {
    await _firestore.collection('offerings').doc(docId).update({
      'subCode': offering.subCode,
      'subName': offering.subName,
      'classType': offering.classType,
      'sectNo': offering.sectNo,
      'quota': offering.quota,
      'enrolled': offering.enrolled,
      'lectName': offering.lectName,
      'days': offering.days,
      'startTime': offering.startTime,
      'endTime': offering.endTime,
      'venue': offering.venue,
      'semester': offering.semester,
      'session': offering.session,
      'sectID': offering.sectID,
    });
  }

  Future<void> deleteOffering(String docId) async {
    await _firestore.collection('offerings').doc(docId).delete();
  }

  // ========== STATISTICS ==========
  Future<int> getTotalEnrolled() async {
    final snapshot = await _firestore.collection('offerings').get();
    int total = 0;
    for (var doc in snapshot.docs) {
      total += doc.data()['enrolled'] as int? ?? 0;
    }
    return total;
  }

  Future<int> getTotalOfferings() async {
    final snapshot = await _firestore.collection('offerings').get();
    return snapshot.docs.length;
  }

  Future<int> getFullOfferings() async {
    final snapshot = await _firestore.collection('offerings').get();
    int count = 0;
    for (var doc in snapshot.docs) {
      final enrolled = doc.data()['enrolled'] as int? ?? 0;
      final quota = doc.data()['quota'] as int? ?? 0;
      if (enrolled >= quota) count++;
    }
    return count;
  }

  // ========== OR SESSION OPERATIONS ==========
  Future<void> saveORSession(ORSession session) async {
    // ✅ Tidak simpan isActive — dikira auto dari tarikh dan masa
    await _firestore.collection('or_sessions').doc(session.sessionID).set({
      'sessionID': session.sessionID,
      'semester': session.semester,
      'studentYear': session.studentYear,
      'startDate': session.startDate.toIso8601String(),
      'endDate': session.endDate.toIso8601String(),
      'startTime': session.startTime,
      'endTime': session.endTime,
    });
  }

  Future<List<ORSession>> getORSessions() async {
    final snapshot = await _firestore.collection('or_sessions').get();
    List<ORSession> sessions = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      sessions.add(ORSession(
        sessionID: data['sessionID'] as String? ?? '',
        semester: data['semester'] as String? ?? '',
        // ✅ isActive dikira auto — tidak perlu dari Firestore
        studentYear: data['studentYear'] as String? ?? '',
        startDate: DateTime.tryParse(data['startDate'] as String? ?? '') ??
            DateTime.now(),
        endDate: DateTime.tryParse(data['endDate'] as String? ?? '') ??
            DateTime.now(),
        startTime: data['startTime'] as String? ?? '00:00',
        endTime: data['endTime'] as String? ?? '23:59',
      ));
    }
    return sessions;
  }

  // ✅ activateORSession tidak diperlukan lagi
  // isActive dikira auto dari startDate+startTime hingga endDate+endTime

  // ========== STUDENT REGISTRATION OPERATIONS ==========
  // SDD Registration Table: regID adalah PK — guna sebagai Firestore doc ID

  Stream<List<Map<String, dynamic>>> getStudentRegistrations(String studentID) {
    return _firestore
        .collection('registrations')
        .where('studentID', isEqualTo: studentID)
        // ✅ Fetch 'Registered' DAN 'Edited' supaya rekod yang diedit masih kelihatan
        .where('regStatus', whereIn: ['Registered', 'Edited'])
        .snapshots()
        .map((snapshot) {
          List<Map<String, dynamic>> result = [];
          for (var doc in snapshot.docs) {
            result.add({
              'id': doc.id,
              'data': CourseRegistrationRecord.fromMap(doc.data()),
            });
          }
          return result;
        });
  }

  // ✅ Guna regID sebagai Firestore doc ID, konsisten dengan SDD PK
  Future<void> addStudentRegistration(CourseRegistrationRecord record) async {
    await _firestore
        .collection('registrations')
        .doc(record.regID) // regID = doc ID
        .set(record.toMap());
  }

  Future<void> updateStudentRegistration(
      String docId, CourseRegistrationRecord record) async {
    await _firestore
        .collection('registrations')
        .doc(docId)
        .update(record.toMap());
  }

  Future<void> deleteStudentRegistration(String docId) async {
    await _firestore.collection('registrations').doc(docId).delete();
  }

  // ✅ sectID = Firestore doc ID untuk offerings collection
  // Ini betul sekarang kerana addOffering() guna .doc(sectID).set()
  Future<void> incrementEnrolled(String sectID) async {
    await _firestore
        .collection('offerings')
        .doc(sectID) // sectID = doc ID ✅
        .update({'enrolled': FieldValue.increment(1)});
  }

  Future<void> decrementEnrolled(String sectID) async {
    await _firestore
        .collection('offerings')
        .doc(sectID) // sectID = doc ID ✅
        .update({'enrolled': FieldValue.increment(-1)});
  }

  // ========== INITIALIZE SAMPLE DATA ==========
  Future<void> initializeSampleData() async {
    final subjectsSnapshot = await _firestore.collection('subjects').get();
    if (subjectsSnapshot.docs.isNotEmpty) return;

    final subjects = [
      {
        'subCode': 'BCS2344',
        'subName': 'Web Engineering',
        'creditHour': 3,
        'faculty': 'Faculty of Computing'
      },
      {
        'subCode': 'BCS3133',
        'subName': 'Software Engineering Practices',
        'creditHour': 3,
        'faculty': 'Faculty of Computing'
      },
      {
        'subCode': 'ULE2342',
        'subName': 'English for Professional Communication',
        'creditHour': 2,
        'faculty': 'Center of Modern Language'
      },
      {
        'subCode': 'BUM2413',
        'subName': 'Applied Statistic',
        'creditHour': 3,
        'faculty': 'Center of Mathematical Science'
      },
      {
        'subCode': 'BCC3012',
        'subName': 'Undergraduate Project 1',
        'creditHour': 2,
        'faculty': 'Faculty of Computing'
      },
    ];
    for (var subject in subjects) {
      await _firestore.collection('subjects').add(subject);
    }

    // ✅ Sample offerings guna sectID sebagai doc ID
    final offerings = [
      {
        'docId': 'SEC001',
        'data': {
          'sectID': 'SEC001',
          'subCode': 'BCS2344',
          'subName': 'Web Engineering',
          'classType': 'Lecture',
          'sectNo': '01',
          'quota': 60,
          'enrolled': 45,
          'lectName': 'Dr. Noorlin',
          'days': 'Mon,Wed',
          'startTime': '08:00',
          'endTime': '10:00',
          'venue': 'BZ-01-095',
          'semester': 'Sem 2',
          'session': '2025/2026',
        }
      },
      {
        'docId': 'SEC002',
        'data': {
          'sectID': 'SEC002',
          'subCode': 'BCS2344',
          'subName': 'Web Engineering',
          'classType': 'Tutorial',
          'sectNo': '01A',
          'quota': 30,
          'enrolled': 24,
          'lectName': 'Dr. Noorlin',
          'days': 'Thu',
          'startTime': '14:00',
          'endTime': '16:00',
          'venue': 'BK-03-001',
          'semester': 'Sem 2',
          'session': '2025/2026',
        }
      },
      {
        'docId': 'SEC003',
        'data': {
          'sectID': 'SEC003',
          'subCode': 'BUM2413',
          'subName': 'Applied Statistic',
          'classType': 'Lecture',
          'sectNo': '01',
          'quota': 60,
          'enrolled': 55,
          'lectName': 'Ts.Dr.Zahirah',
          'days': 'Mon,Wed',
          'startTime': '08:00',
          'endTime': '10:00',
          'venue': 'BZ-01-095',
          'semester': 'Sem 2',
          'session': '2025/2026',
        }
      },
    ];

    for (var offering in offerings) {
      await _firestore
          .collection('offerings')
          .doc(offering['docId'] as String)
          .set(offering['data'] as Map<String, dynamic>);
    }
  }
}
