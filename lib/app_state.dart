import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Single global app state. Data is stored on the device with
/// shared_preferences, so the app works with no backend or internet.
final AppState app = AppState();

class AppState extends ChangeNotifier {
  List<AppUser> users = [];
  List<BloodRequest> requests = [];
  List<Donation> donations = [];
  List<Camp> camps = [];
  List<AppNotification> notifications = [];
  String? currentUserId;

  static const String _key = 'reddrop_data_v1';
  final Random _rnd = Random();

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}${_rnd.nextInt(9999)}';

  // ---------------------------------------------------------------- lookups

  AppUser? get me => userById(currentUserId);

  AppUser? userById(String? id) {
    if (id == null) return null;
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  BloodRequest? requestById(String id) {
    for (final r in requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ------------------------------------------------------------ persistence

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) {
      _seed();
      await _save();
    } else {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _seed();
        await _save();
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_toJson()));
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  Map<String, dynamic> _toJson() => {
        'users': users.map((e) => e.toJson()).toList(),
        'requests': requests.map((e) => e.toJson()).toList(),
        'donations': donations.map((e) => e.toJson()).toList(),
        'camps': camps.map((e) => e.toJson()).toList(),
        'notifications': notifications.map((e) => e.toJson()).toList(),
        'currentUserId': currentUserId,
      };

  void _fromJson(Map<String, dynamic> j) {
    users = (j['users'] as List)
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
    requests = (j['requests'] as List)
        .map((e) => BloodRequest.fromJson(e as Map<String, dynamic>))
        .toList();
    donations = (j['donations'] as List)
        .map((e) => Donation.fromJson(e as Map<String, dynamic>))
        .toList();
    camps = (j['camps'] as List)
        .map((e) => Camp.fromJson(e as Map<String, dynamic>))
        .toList();
    notifications = (j['notifications'] as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    currentUserId = j['currentUserId'] as String?;
  }

  /// Wipes everything and restores the demo data.
  void resetDemo() {
    _seed();
    _changed();
  }

  // ------------------------------------------------------------------- auth

  String? register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String city,
    required String bloodGroup,
    required String role,
  }) {
    final e = email.trim().toLowerCase();
    if (users.any((u) => u.email == e)) {
      return 'An account with this email already exists.';
    }
    final u = AppUser(
      id: _id(),
      name: name.trim(),
      email: e,
      password: password,
      phone: phone.trim(),
      city: city,
      bloodGroup: bloodGroup,
      role: role,
    );
    users.add(u);
    currentUserId = u.id;
    _changed();
    return null;
  }

  String? login(String email, String password) {
    final e = email.trim().toLowerCase();
    for (final u in users) {
      if (u.email == e) {
        if (u.password != password) return 'Wrong password.';
        currentUserId = u.id;
        _changed();
        return null;
      }
    }
    return 'No account found with this email.';
  }

  void logout() {
    currentUserId = null;
    _changed();
  }

  void updateProfile({
    required String name,
    required String phone,
    required String city,
    required String bloodGroup,
    required String role,
  }) {
    final m = me;
    if (m == null) return;
    m.name = name.trim();
    m.phone = phone.trim();
    m.city = city;
    m.bloodGroup = bloodGroup;
    m.role = role;
    _changed();
  }

  void setAvailability(bool value) {
    final m = me;
    if (m == null) return;
    m.available = value;
    _changed();
  }

  // --------------------------------------------------------------- matching

  /// Donors who can give to [recipientGroup] in [city].
  List<AppUser> compatibleDonors(
    String recipientGroup,
    String city, {
    String? excludeId,
    bool onlyAvailable = false,
  }) {
    final list = users.where((u) {
      if (!u.isDonor) return false;
      if (u.id == excludeId) return false;
      if (u.city != city) return false;
      if (!isCompatible(u.bloodGroup, recipientGroup)) return false;
      if (onlyAvailable && !u.canDonateNow) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      int score(AppUser u) =>
          (u.canDonateNow ? 0 : 4) +
          (u.bloodGroup == recipientGroup ? 0 : 2) +
          (u.verified ? 0 : 1);
      return score(a).compareTo(score(b));
    });
    return list;
  }

  List<AppUser> matchingDonors(BloodRequest r, {bool onlyAvailable = false}) {
    return compatibleDonors(r.bloodGroup, r.city,
        excludeId: r.requesterId, onlyAvailable: onlyAvailable);
  }

  List<BloodRequest> requestsForDonor(AppUser u) {
    if (!u.isDonor) return [];
    final list = requests
        .where((r) =>
            r.isActive &&
            r.requesterId != u.id &&
            isCompatible(u.bloodGroup, r.bloodGroup))
        .toList();
    list.sort((a, b) {
      int score(BloodRequest r) =>
          (r.city == u.city ? 0 : 10) + urgencies.indexOf(r.urgency);
      return score(a).compareTo(score(b));
    });
    return list;
  }

  List<BloodRequest> sortedRequests() {
    final list = List<BloodRequest>.from(requests);
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  // --------------------------------------------------------------- requests

  /// Creates a request and notifies matching donors. Returns how many.
  int createRequest({
    required String patient,
    required String bloodGroup,
    required int units,
    required String hospital,
    required String city,
    required String urgency,
    required DateTime deadline,
    required String phone,
    String note = '',
  }) {
    final m = me!;
    final r = BloodRequest(
      id: _id(),
      requesterId: m.id,
      requesterName: m.name,
      patientName: patient.trim(),
      bloodGroup: bloodGroup,
      units: units,
      hospital: hospital.trim(),
      city: city,
      urgency: urgency,
      deadline: deadline,
      phone: phone.trim(),
      note: note.trim(),
      status: 'Open',
      createdAt: DateTime.now(),
    );
    requests.insert(0, r);
    final donors = matchingDonors(r, onlyAvailable: true);
    for (final d in donors) {
      _notify(
        d.id,
        '$urgency: $bloodGroup needed in $city',
        '$units unit(s) at ${r.hospital}. You can help - tap to respond.',
        requestId: r.id,
      );
    }
    _changed();
    return donors.length;
  }

  void respond(BloodRequest r, bool accept) {
    final m = me;
    if (m == null) return;
    if (accept) {
      if (!r.acceptedIds.contains(m.id)) r.acceptedIds.add(m.id);
      r.declinedIds.remove(m.id);
      if (r.status == 'Open') r.status = 'Donor found';
      _notify(
        r.requesterId,
        '${m.name} accepted your request',
        '${m.bloodGroup} donor in ${m.city}. Open the request to contact them.',
        requestId: r.id,
      );
    } else {
      if (!r.declinedIds.contains(m.id)) r.declinedIds.add(m.id);
      r.acceptedIds.remove(m.id);
      if (r.acceptedIds.isEmpty && r.status == 'Donor found') {
        r.status = 'Open';
      }
    }
    _changed();
  }

  /// Marks the request fulfilled. If [donorId] is given, records a donation
  /// for that donor and starts their 90 day eligibility timer.
  void markFulfilled(BloodRequest r, {String? donorId}) {
    r.status = 'Fulfilled';
    r.fulfilledBy = donorId;
    final d = userById(donorId);
    if (d != null) {
      d.lastDonation = DateTime.now();
      donations.insert(
        0,
        Donation(
          id: _id(),
          donorId: d.id,
          date: DateTime.now(),
          place: r.hospital,
          bloodGroup: d.bloodGroup,
          requestId: r.id,
        ),
      );
      _notify(
        d.id,
        'Thank you for donating!',
        'Your donation at ${r.hospital} was recorded. You can donate again in $eligibilityDays days.',
        requestId: r.id,
      );
    }
    _changed();
  }

  void deleteRequest(String id) {
    requests.removeWhere((r) => r.id == id);
    notifications.removeWhere((n) => n.requestId == id);
    _changed();
  }

  // -------------------------------------------------------------- donations

  void logDonation(DateTime date, String place) {
    final m = me;
    if (m == null) return;
    donations.insert(
      0,
      Donation(
        id: _id(),
        donorId: m.id,
        date: date,
        place: place.isEmpty ? 'Blood donation' : place,
        bloodGroup: m.bloodGroup,
      ),
    );
    final last = m.lastDonation;
    if (last == null || date.isAfter(last)) m.lastDonation = date;
    _changed();
  }

  int donationCount(String userId) =>
      donations.where((d) => d.donorId == userId).length;

  List<Donation> donationsOf(String userId) {
    final list = donations.where((d) => d.donorId == userId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // ------------------------------------------------------------------ camps

  void toggleCamp(Camp c) {
    final m = me;
    if (m == null) return;
    if (c.registeredIds.contains(m.id)) {
      c.registeredIds.remove(m.id);
    } else {
      c.registeredIds.add(m.id);
    }
    _changed();
  }

  void addCamp(String title, String venue, String city, DateTime date,
      String organizer) {
    camps.add(Camp(
      id: _id(),
      title: title.trim(),
      venue: venue.trim(),
      city: city,
      date: date,
      organizer: organizer.trim(),
    ));
    _changed();
  }

  void deleteCamp(String id) {
    camps.removeWhere((c) => c.id == id);
    _changed();
  }

  // ----------------------------------------------------------- notifications

  void _notify(String userId, String title, String body, {String? requestId}) {
    notifications.insert(
      0,
      AppNotification(
        id: _id(),
        userId: userId,
        title: title,
        body: body,
        requestId: requestId,
        time: DateTime.now(),
      ),
    );
  }

  List<AppNotification> myNotifications() =>
      notifications.where((n) => n.userId == currentUserId).toList();

  int get unreadCount => notifications
      .where((n) => n.userId == currentUserId && !n.read)
      .length;

  void markRead(AppNotification n) {
    n.read = true;
    _changed();
  }

  void markAllRead() {
    for (final n in notifications) {
      if (n.userId == currentUserId) n.read = true;
    }
    _changed();
  }

  // ------------------------------------------------------------------ admin

  void setVerified(String userId, bool value) {
    final u = userById(userId);
    if (u == null) return;
    u.verified = value;
    _changed();
  }

  void deleteUser(String userId) {
    users.removeWhere((u) => u.id == userId);
    requests.removeWhere((r) => r.requesterId == userId);
    for (final r in requests) {
      r.acceptedIds.remove(userId);
      r.declinedIds.remove(userId);
    }
    donations.removeWhere((d) => d.donorId == userId);
    notifications.removeWhere((n) => n.userId == userId);
    for (final c in camps) {
      c.registeredIds.remove(userId);
    }
    _changed();
  }

  // ------------------------------------------------------------------ stats

  int get donorCount => users.where((u) => u.isDonor).length;
  int get availableDonorCount => users.where((u) => u.canDonateNow).length;
  int get requestCount => requests.length;
  int get fulfilledCount =>
      requests.where((r) => r.status == 'Fulfilled').length;
  int get activeRequestCount => requests.where((r) => r.isActive).length;
  int get unitsDonated => donations.length;
  int get livesHelped => unitsDonated * 3; // one donation can help up to 3 lives

  List<MapEntry<AppUser, int>> leaderboard({String? city}) {
    final list = <MapEntry<AppUser, int>>[];
    for (final u in users) {
      if (!u.isDonor) continue;
      if (city != null && u.city != city) continue;
      final n = donationCount(u.id);
      if (n > 0) list.add(MapEntry(u, n));
    }
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<BadgeInfo> badgesFor(AppUser u) {
    final n = donationCount(u.id);
    final inCamp = camps.any((c) => c.registeredIds.contains(u.id));
    return [
      BadgeInfo('First Drop', '1 donation', Icons.water_drop, n >= 1),
      BadgeInfo('Life Saver', '3 donations', Icons.favorite, n >= 3),
      BadgeInfo('Blood Hero', '5 donations', Icons.military_tech, n >= 5),
      BadgeInfo('Legend', '10 donations', Icons.emoji_events, n >= 10),
      BadgeInfo('Verified', 'Admin verified', Icons.verified, u.verified),
      BadgeInfo('Camp Goer', 'Joined a camp', Icons.event_available, inCamp),
    ];
  }

  // ------------------------------------------------------------------- seed

  void _seed() {
    final now = DateTime.now();
    users = [];
    requests = [];
    donations = [];
    camps = [];
    notifications = [];
    currentUserId = null;

    void add(
      String id,
      String name,
      String email,
      String group,
      String city,
      String role, {
      String password = 'demo123',
      bool verified = true,
      bool available = true,
      int? lastDays,
      int past = 0,
    }) {
      final phone =
          '+91 00000 000${users.length.toString().padLeft(2, '0')}';
      final u = AppUser(
        id: id,
        name: name,
        email: email,
        password: password,
        phone: phone,
        city: city,
        bloodGroup: group,
        role: role,
        verified: verified,
        available: available,
      );
      final base = lastDays ?? (past > 0 ? 200 : null);
      if (base != null) {
        u.lastDonation = now.subtract(Duration(days: base));
        for (var i = 0; i < past; i++) {
          donations.add(Donation(
            id: '${id}_d$i',
            donorId: id,
            date: now.subtract(Duration(days: base + i * 110)),
            place: 'City Blood Bank',
            bloodGroup: group,
          ));
        }
      }
      users.add(u);
    }

    add('admin', 'RedDrop Admin', 'admin@reddrop.com', 'O+', 'Bengaluru',
        'admin',
        password: 'admin123');
    add('demo', 'Demo User', 'demo@reddrop.com', 'B+', 'Bengaluru', 'both',
        past: 2, lastDays: 130);
    add('d1', 'Aarav Sharma', 'aarav@demo.com', 'O+', 'Bengaluru', 'donor',
        past: 5, lastDays: 100);
    add('d2', 'Priya Nair', 'priya@demo.com', 'A+', 'Bengaluru', 'donor',
        past: 3, lastDays: 95);
    add('d3', 'Rohan Gupta', 'rohan@demo.com', 'B+', 'Bengaluru', 'donor',
        past: 1, lastDays: 200);
    add('d4', 'Sneha Reddy', 'sneha@demo.com', 'O-', 'Bengaluru', 'donor',
        past: 7, lastDays: 120);
    add('d5', 'Karthik Iyer', 'karthik@demo.com', 'AB+', 'Bengaluru', 'donor',
        verified: false);
    add('d6', 'Meera Joshi', 'meera@demo.com', 'A-', 'Bengaluru', 'donor',
        past: 2, lastDays: 20);
    add('d7', 'Vikram Singh', 'vikram@demo.com', 'B-', 'Bengaluru', 'donor',
        available: false);
    add('d8', 'Ananya Das', 'ananya@demo.com', 'O+', 'Mumbai', 'donor',
        past: 4, lastDays: 150);
    add('d9', 'Imran Khan', 'imran@demo.com', 'A+', 'Mumbai', 'donor',
        past: 2, lastDays: 180);
    add('d10', 'Divya Menon', 'divya@demo.com', 'B+', 'Chennai', 'donor',
        past: 1, lastDays: 110);
    add('d11', 'Arjun Patel', 'arjun@demo.com', 'O+', 'Delhi', 'both',
        past: 6, lastDays: 101);
    add('d12', 'Fatima Sheikh', 'fatima@demo.com', 'AB-', 'Hyderabad', 'donor');
    add('d13', 'Rahul Verma', 'rahul@demo.com', 'A+', 'Delhi', 'donor',
        past: 3, lastDays: 140);
    add('d14', 'Lakshmi Rao', 'lakshmi@demo.com', 'O-', 'Hyderabad', 'donor',
        past: 8, lastDays: 99);
    add('r1', 'Kavya Rao', 'kavya@demo.com', 'A+', 'Bengaluru', 'requester');
    add('r2', 'Suresh Kumar', 'suresh@demo.com', 'B+', 'Bengaluru',
        'requester');
    add('r3', 'Neha Kapoor', 'neha@demo.com', 'A-', 'Mumbai', 'requester');

    String phoneOf(String id) => userById(id)?.phone ?? '';

    requests = [
      BloodRequest(
        id: 'q1',
        requesterId: 'r2',
        requesterName: 'Suresh Kumar',
        patientName: 'Ramesh Kumar',
        bloodGroup: 'B+',
        units: 2,
        hospital: 'Lifeline Hospital',
        city: 'Bengaluru',
        urgency: 'Critical',
        deadline: now.add(const Duration(hours: 8)),
        phone: phoneOf('r2'),
        note: 'Surgery is scheduled this evening.',
        status: 'Open',
        createdAt: now.subtract(const Duration(minutes: 40)),
      ),
      BloodRequest(
        id: 'q2',
        requesterId: 'r1',
        requesterName: 'Kavya Rao',
        patientName: 'Lata Rao',
        bloodGroup: 'A+',
        units: 1,
        hospital: 'Sunrise Medical Centre',
        city: 'Bengaluru',
        urgency: 'Urgent',
        deadline: now.add(const Duration(days: 1)),
        phone: phoneOf('r1'),
        note: '',
        status: 'Open',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      BloodRequest(
        id: 'q3',
        requesterId: 'r1',
        requesterName: 'Kavya Rao',
        patientName: 'Mohan Das',
        bloodGroup: 'O-',
        units: 2,
        hospital: 'City General Hospital',
        city: 'Bengaluru',
        urgency: 'Urgent',
        deadline: now.add(const Duration(hours: 20)),
        phone: phoneOf('r1'),
        note: 'Accident case, needs rare group.',
        status: 'Donor found',
        createdAt: now.subtract(const Duration(hours: 6)),
        acceptedIds: ['d4'],
      ),
      BloodRequest(
        id: 'q4',
        requesterId: 'r3',
        requesterName: 'Neha Kapoor',
        patientName: 'Sunita Kapoor',
        bloodGroup: 'A-',
        units: 1,
        hospital: 'Harbour View Hospital',
        city: 'Mumbai',
        urgency: 'Normal',
        deadline: now.add(const Duration(days: 3)),
        phone: phoneOf('r3'),
        note: '',
        status: 'Open',
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      BloodRequest(
        id: 'q5',
        requesterId: 'r1',
        requesterName: 'Kavya Rao',
        patientName: 'Anil Rao',
        bloodGroup: 'O+',
        units: 1,
        hospital: 'City General Hospital',
        city: 'Bengaluru',
        urgency: 'Normal',
        deadline: now.subtract(const Duration(days: 9)),
        phone: phoneOf('r1'),
        note: '',
        status: 'Fulfilled',
        createdAt: now.subtract(const Duration(days: 10)),
        acceptedIds: ['d1'],
        fulfilledBy: 'd1',
      ),
    ];

    notifications = [
      AppNotification(
        id: 'n1',
        userId: 'demo',
        title: 'Critical: B+ needed in Bengaluru',
        body: '2 unit(s) at Lifeline Hospital. You can help - tap to respond.',
        requestId: 'q1',
        time: now.subtract(const Duration(minutes: 38)),
      ),
    ];

    camps = [
      Camp(
        id: 'c1',
        title: 'Campus Blood Donation Drive',
        venue: 'University Auditorium',
        city: 'Bengaluru',
        date: now.add(const Duration(days: 4, hours: 3)),
        organizer: 'Campus Health Club',
        registeredIds: ['d1', 'd2'],
      ),
      Camp(
        id: 'c2',
        title: 'Community Blood Camp',
        venue: 'Community Hall, Indiranagar',
        city: 'Bengaluru',
        date: now.add(const Duration(days: 9)),
        organizer: 'City Blood Bank',
      ),
      Camp(
        id: 'c3',
        title: 'Mega Donation Day',
        venue: 'Andheri Community Centre',
        city: 'Mumbai',
        date: now.add(const Duration(days: 6)),
        organizer: 'Lions Youth Group',
      ),
      Camp(
        id: 'c4',
        title: 'Save A Life Camp',
        venue: 'Civic Centre',
        city: 'Delhi',
        date: now.add(const Duration(days: 12)),
        organizer: 'Hope Foundation',
      ),
    ];
  }
}
