import 'package:flutter/material.dart';

const List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

const List<String> cities = [
  'Bengaluru',
  'Mumbai',
  'Delhi',
  'Chennai',
  'Hyderabad',
  'Kolkata',
  'Pune',
  'Ahmedabad',
  'Jaipur',
  'Kochi',
];

const List<String> urgencies = ['Critical', 'Urgent', 'Normal'];
const List<String> requestStatuses = ['Open', 'Donor found', 'Fulfilled'];
const int eligibilityDays = 90;

/// Donor blood group -> recipient groups it can donate to.
const Map<String, List<String>> canDonateTo = {
  'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
  'O+': ['O+', 'A+', 'B+', 'AB+'],
  'A-': ['A-', 'A+', 'AB-', 'AB+'],
  'A+': ['A+', 'AB+'],
  'B-': ['B-', 'B+', 'AB-', 'AB+'],
  'B+': ['B+', 'AB+'],
  'AB-': ['AB-', 'AB+'],
  'AB+': ['AB+'],
};

bool isCompatible(String donor, String recipient) {
  final list = canDonateTo[donor];
  return list != null && list.contains(recipient);
}

/// Groups a recipient can safely receive from.
List<String> canReceiveFrom(String recipient) {
  return bloodGroups.where((d) => isCompatible(d, recipient)).toList();
}

class AppUser {
  String id;
  String name;
  String email;
  String phone;
  String city;
  String bloodGroup;
  String role; // donor | requester | both | admin
  bool available;
  bool verified;
  DateTime? lastDonation;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.bloodGroup,
    required this.role,
    this.available = true,
    this.verified = false,
    this.lastDonation,
  });

  bool get isDonor => role == 'donor' || role == 'both';
  bool get isAdmin => role == 'admin';

  /// Days left before the donor can give blood again (0 = eligible).
  int get daysUntilEligible {
    final last = lastDonation;
    if (last == null) return 0;
    final next = last.add(const Duration(days: eligibilityDays));
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return (diff.inHours / 24).ceil();
  }

  bool get isEligible => daysUntilEligible == 0;
  bool get canDonateNow => isDonor && available && isEligible;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'city': city,
        'bloodGroup': bloodGroup,
        'role': role,
        'available': available,
        'verified': verified,
        'lastDonation': lastDonation?.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String,
        city: j['city'] as String,
        bloodGroup: j['bloodGroup'] as String,
        role: j['role'] as String,
        available: j['available'] as bool,
        verified: j['verified'] as bool,
        lastDonation: j['lastDonation'] == null
            ? null
            : DateTime.parse(j['lastDonation'] as String),
      );
}

class BloodRequest {
  String id;
  String requesterId;
  String requesterName;
  String patientName;
  String bloodGroup;
  int units;
  String hospital;
  String city;
  String urgency;
  DateTime deadline;
  String phone;
  String note;
  String status; // Open | Donor found | Fulfilled
  DateTime createdAt;
  List<String> acceptedIds;
  List<String> declinedIds;
  String? fulfilledBy;

  BloodRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.patientName,
    required this.bloodGroup,
    required this.units,
    required this.hospital,
    required this.city,
    required this.urgency,
    required this.deadline,
    required this.phone,
    required this.note,
    required this.status,
    required this.createdAt,
    List<String>? acceptedIds,
    List<String>? declinedIds,
    this.fulfilledBy,
  })  : acceptedIds = acceptedIds ?? [],
        declinedIds = declinedIds ?? [];

  bool get isExpired =>
      status != 'Fulfilled' && deadline.isBefore(DateTime.now());
  bool get isActive => status != 'Fulfilled' && !isExpired;
  String get displayStatus => isExpired ? 'Expired' : status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'patientName': patientName,
        'bloodGroup': bloodGroup,
        'units': units,
        'hospital': hospital,
        'city': city,
        'urgency': urgency,
        'deadline': deadline.toIso8601String(),
        'phone': phone,
        'note': note,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'acceptedIds': acceptedIds,
        'declinedIds': declinedIds,
        'fulfilledBy': fulfilledBy,
      };

  factory BloodRequest.fromJson(Map<String, dynamic> j) => BloodRequest(
        id: j['id'] as String,
        requesterId: j['requesterId'] as String,
        requesterName: j['requesterName'] as String,
        patientName: j['patientName'] as String,
        bloodGroup: j['bloodGroup'] as String,
        units: j['units'] as int,
        hospital: j['hospital'] as String,
        city: j['city'] as String,
        urgency: j['urgency'] as String,
        deadline: DateTime.parse(j['deadline'] as String),
        phone: j['phone'] as String,
        note: j['note'] as String,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        acceptedIds: List<String>.from(j['acceptedIds'] as List),
        declinedIds: List<String>.from(j['declinedIds'] as List),
        fulfilledBy: j['fulfilledBy'] as String?,
      );
}

class Donation {
  String id;
  String donorId;
  DateTime date;
  String place;
  String bloodGroup;
  String? requestId;

  Donation({
    required this.id,
    required this.donorId,
    required this.date,
    required this.place,
    required this.bloodGroup,
    this.requestId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'donorId': donorId,
        'date': date.toIso8601String(),
        'place': place,
        'bloodGroup': bloodGroup,
        'requestId': requestId,
      };

  factory Donation.fromJson(Map<String, dynamic> j) => Donation(
        id: j['id'] as String,
        donorId: j['donorId'] as String,
        date: DateTime.parse(j['date'] as String),
        place: j['place'] as String,
        bloodGroup: j['bloodGroup'] as String,
        requestId: j['requestId'] as String?,
      );
}

class Camp {
  String id;
  String title;
  String venue;
  String city;
  DateTime date;
  String organizer;
  List<String> registeredIds;

  Camp({
    required this.id,
    required this.title,
    required this.venue,
    required this.city,
    required this.date,
    required this.organizer,
    List<String>? registeredIds,
  }) : registeredIds = registeredIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'venue': venue,
        'city': city,
        'date': date.toIso8601String(),
        'organizer': organizer,
        'registeredIds': registeredIds,
      };

  factory Camp.fromJson(Map<String, dynamic> j) => Camp(
        id: j['id'] as String,
        title: j['title'] as String,
        venue: j['venue'] as String,
        city: j['city'] as String,
        date: DateTime.parse(j['date'] as String),
        organizer: j['organizer'] as String,
        registeredIds: List<String>.from(j['registeredIds'] as List),
      );
}

class AppNotification {
  String id;
  String userId;
  String title;
  String body;
  String? requestId;
  DateTime time;
  bool read;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.time,
    this.requestId,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'requestId': requestId,
        'time': time.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['userId'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        requestId: j['requestId'] as String?,
        time: DateTime.parse(j['time'] as String),
        read: j['read'] as bool,
      );
}

class BadgeInfo {
  final String name;
  final String description;
  final IconData icon;
  final bool earned;
  const BadgeInfo(this.name, this.description, this.icon, this.earned);
}
