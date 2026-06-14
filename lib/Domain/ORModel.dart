// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/Domain/ORModel.dart
// Entity Class — PACK112-SAMS-2026
// ─────────────────────────────────────────────────────────────────────────────

class Registrar {
  String regisID;
  String name;
  String email;
  String password;

  Registrar({
    required this.regisID,
    required this.name,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toMap() => {
        'regisID': regisID,
        'name': name,
        'email': email,
        'password': password,
      };

  factory Registrar.fromMap(Map<String, dynamic> map) => Registrar(
        regisID: map['regisID'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        password: map['password'] ?? '',
      );
}

class Subject {
  String subCode;
  String subName;
  int creditHour;
  String faculty;

  Subject({
    required this.subCode,
    required this.subName,
    required this.creditHour,
    required this.faculty,
  });

  Map<String, dynamic> toMap() => {
        'subCode': subCode,
        'subName': subName,
        'creditHour': creditHour,
        'faculty': faculty,
      };

  factory Subject.fromMap(Map<String, dynamic> map) => Subject(
        subCode: map['subCode'] ?? '',
        subName: map['subName'] ?? '',
        creditHour: map['creditHour'] ?? 0,
        faculty: map['faculty'] ?? '',
      );
}

class OfferingRegistration {
  String sectID;
  String subCode;
  String subName;
  String classType;
  String sectNo;
  int quota;
  int enrolled;
  String lectName;
  String days;
  String startTime;
  String endTime;
  String venue;
  String semester;
  String session;

  OfferingRegistration({
    required this.sectID,
    required this.subCode,
    required this.subName,
    required this.classType,
    required this.sectNo,
    required this.quota,
    required this.enrolled,
    required this.lectName,
    required this.days,
    required this.startTime,
    required this.endTime,
    required this.venue,
    required this.semester,
    required this.session,
  });

  bool get isFull => enrolled >= quota;
  double get fillPercentage => quota > 0 ? enrolled / quota : 0;
  String get enrollmentLabel => '$enrolled/$quota';
  String get scheduleLabel => '$days $startTime-$endTime . $venue';
  bool get isLecture => classType == 'Lecture';
  bool get isLab => classType == 'Lab';

  Map<String, dynamic> toMap() => {
        'sectID': sectID,
        'subCode': subCode,
        'subName': subName,
        'classType': classType,
        'sectNo': sectNo,
        'quota': quota,
        'enrolled': enrolled,
        'lectName': lectName,
        'days': days,
        'startTime': startTime,
        'endTime': endTime,
        'venue': venue,
        'semester': semester,
        'session': session,
      };

  factory OfferingRegistration.fromMap(Map<String, dynamic> map) =>
      OfferingRegistration(
        sectID: map['sectID'] ?? '',
        subCode: map['subCode'] ?? '',
        subName: map['subName'] ?? '',
        classType: map['classType'] ?? '',
        sectNo: map['sectNo'] ?? '',
        quota: map['quota'] ?? 0,
        enrolled: map['enrolled'] ?? 0,
        lectName: map['lectName'] ?? '',
        days: map['days'] ?? '',
        startTime: map['startTime'] ?? '',
        endTime: map['endTime'] ?? '',
        venue: map['venue'] ?? '',
        semester: map['semester'] ?? '',
        session: map['session'] ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// OR SESSION
// ✅ isActive dikira AUTO dari startDate+startTime hingga endDate+endTime
// Tidak perlu simpan isActive dalam Firestore — dikira setiap kali dari masa semasa
// ─────────────────────────────────────────────────────────────────────────────
class ORSession {
  String sessionID;
  String semester;
  String studentYear;
  DateTime startDate;
  DateTime endDate;
  String startTime; // format "HH:mm"
  String endTime; // format "HH:mm"

  ORSession({
    required this.sessionID,
    required this.semester,
    required this.studentYear,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
  });

  // ✅ Auto-calculate isActive dari tarikh DAN masa semasa
  // isActive = true bila now >= startDate+startTime DAN now <= endDate+endTime
  bool get isActive {
    final now = DateTime.now();

    // Parse startTime "HH:mm" → gabung dengan startDate
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    final sessionStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startParts.length == 2 ? (int.tryParse(startParts[0]) ?? 0) : 0,
      startParts.length == 2 ? (int.tryParse(startParts[1]) ?? 0) : 0,
    );

    final sessionEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      endParts.length == 2 ? (int.tryParse(endParts[0]) ?? 23) : 23,
      endParts.length == 2 ? (int.tryParse(endParts[1]) ?? 59) : 59,
    );

    return now.isAfter(sessionStart) && now.isBefore(sessionEnd);
  }

  // Status label untuk display
  String get statusLabel {
    final now = DateTime.now();
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    final sessionStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startParts.length == 2 ? (int.tryParse(startParts[0]) ?? 0) : 0,
      startParts.length == 2 ? (int.tryParse(startParts[1]) ?? 0) : 0,
    );

    final sessionEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      endParts.length == 2 ? (int.tryParse(endParts[0]) ?? 23) : 23,
      endParts.length == 2 ? (int.tryParse(endParts[1]) ?? 59) : 59,
    );

    if (now.isBefore(sessionStart)) return 'Upcoming';
    if (now.isAfter(sessionEnd)) return 'Ended';
    return 'Active';
  }

  String get displayDateRange {
    String fmt(DateTime d) {
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${months[d.month]}';
    }

    return '${fmt(startDate)} $startTime - ${fmt(endDate)} $endTime';
  }

  Map<String, dynamic> toMap() => {
        'sessionID': sessionID,
        'semester': semester,
        // ✅ Tidak simpan isActive dalam Firestore
        'studentYear': studentYear,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'startTime': startTime,
        'endTime': endTime,
      };

  factory ORSession.fromMap(Map<String, dynamic> map) => ORSession(
        sessionID: map['sessionID'] ?? '',
        semester: map['semester'] ?? '',
        // ✅ Ignore isActive dari Firestore — kira sendiri
        studentYear: map['studentYear'] ?? '',
        startDate: DateTime.tryParse(map['startDate'] ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(map['endDate'] ?? '') ?? DateTime.now(),
        startTime: map['startTime'] ?? '00:00',
        endTime: map['endTime'] ?? '23:59',
      );
}

class CourseRegistrationRecord {
  String regID;
  String studentID;
  String sectID;
  String sessionID;
  int totalSub;
  String regStatus;
  DateTime regAt;
  String subCode;
  String subName;
  int creditHour;
  String classType;
  String sectNo;
  String lectName;
  String days;
  String startTime;
  String endTime;
  String venue;
  String semester;

  CourseRegistrationRecord({
    required this.regID,
    required this.studentID,
    required this.sectID,
    required this.sessionID,
    required this.totalSub,
    required this.regStatus,
    required this.regAt,
    this.subCode = '',
    this.subName = '',
    this.creditHour = 0,
    this.classType = '',
    this.sectNo = '',
    this.lectName = '',
    this.days = '',
    this.startTime = '',
    this.endTime = '',
    this.venue = '',
    this.semester = '',
  });

  bool get isLecture => classType == 'Lecture';
  bool get isLab => classType == 'Lab';
  String get scheduleLabel => '$days $startTime-$endTime . $venue';

  Map<String, dynamic> saveOR() => toMap();

  Map<String, dynamic> toMap() => {
        'regID': regID,
        'studentID': studentID,
        'sectID': sectID,
        'sessionID': sessionID,
        'totalSub': totalSub,
        'regStatus': regStatus,
        'regAt': regAt.toIso8601String(),
        'subCode': subCode,
        'subName': subName,
        'creditHour': creditHour,
        'classType': classType,
        'sectNo': sectNo,
        'lectName': lectName,
        'days': days,
        'startTime': startTime,
        'endTime': endTime,
        'venue': venue,
        'semester': semester,
      };

  factory CourseRegistrationRecord.fromMap(Map<String, dynamic> map) =>
      CourseRegistrationRecord(
        regID: map['regID'] ?? '',
        studentID: map['studentID'] ?? '',
        sectID: map['sectID'] ?? '',
        sessionID: map['sessionID'] ?? '',
        totalSub: map['totalSub'] ?? 0,
        regStatus: map['regStatus'] ?? 'Registered',
        regAt: DateTime.tryParse(map['regAt'] ?? '') ?? DateTime.now(),
        subCode: map['subCode'] ?? '',
        subName: map['subName'] ?? '',
        creditHour: map['creditHour'] ?? 0,
        classType: map['classType'] ?? '',
        sectNo: map['sectNo'] ?? '',
        lectName: map['lectName'] ?? '',
        days: map['days'] ?? '',
        startTime: map['startTime'] ?? '',
        endTime: map['endTime'] ?? '',
        venue: map['venue'] ?? '',
        semester: map['semester'] ?? '',
      );
}
