import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models.dart';

/// Single global app state. Firebase Auth handles accounts and Cloud Firestore
/// is the shared, live database. Firestore listeners keep these lists up to
/// date in real time, so every screen simply reads from here.
final AppState app = AppState();

class AppState extends ChangeNotifier {
  List<AppUser> users = [];
  List<BloodRequest> requests = [];
  List<Donation> donations = [];
  List<Camp> camps = [];
  List<AppNotification> notifications = [];

  String? currentUserId;
  bool booting = true;
  bool usersLoaded = false;
  bool profilePending = false;
  String? syncError;

  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription<dynamic>> _subs = [];

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

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

  // ------------------------------------------------------------ live syncing

  /// Call once after Firebase.initializeApp.
  void init() {
    _authSub = _auth.authStateChanges().listen((u) {
      booting = false;
      if (u == null) {
        _stopListening();
        currentUserId = null;
      } else if (u.uid != currentUserId || _subs.isEmpty) {
        currentUserId = u.uid;
        _startListening(u.uid);
      }
      notifyListeners();
    });
  }

  void _startListening(String uid) {
    _stopListening();
    usersLoaded = false;
    _subs.add(_db.collection('users').snapshots().listen((s) {
      users = _parse(s, AppUser.fromJson);
      usersLoaded = true;
      syncError = null;
      notifyListeners();
    }, onError: _onStreamError));
    _subs.add(_db.collection('requests').snapshots().listen((s) {
      requests = _parse(s, BloodRequest.fromJson);
      syncError = null;
      notifyListeners();
    }, onError: _onStreamError));
    _subs.add(_db.collection('donations').snapshots().listen((s) {
      donations = _parse(s, Donation.fromJson);
      notifyListeners();
    }, onError: _onStreamError));
    _subs.add(_db.collection('camps').snapshots().listen((s) {
      camps = _parse(s, Camp.fromJson);
      notifyListeners();
    }, onError: _onStreamError));
    _subs.add(_db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((s) {
      notifications = _parse(s, AppNotification.fromJson);
      notifyListeners();
    }, onError: _onStreamError));
  }

  void _stopListening() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    users = [];
    requests = [];
    donations = [];
    camps = [];
    notifications = [];
    usersLoaded = false;
  }

  List<T> _parse<T>(QuerySnapshot<Map<String, dynamic>> s,
      T Function(Map<String, dynamic>) fromJson) {
    final out = <T>[];
    for (final d in s.docs) {
      try {
        out.add(fromJson(d.data()));
      } catch (_) {
        // skip a malformed document instead of breaking the whole list
      }
    }
    return out;
  }

  void _onStreamError(Object e) {
    syncError = _errText(e);
    notifyListeners();
  }

  String _errText(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'Permission denied by Firestore. Publish the rules from the README.';
    }
    final s = e.toString();
    return s.length > 140 ? '${s.substring(0, 140)}...' : s;
  }

  /// Runs a write without blocking the UI. The local cache updates at once and
  /// Firestore syncs in the background (and queues the write while offline).
  void _fire(Future<void> f) {
    f.catchError((Object e) {
      syncError = 'Could not save: ${_errText(e)}';
      notifyListeners();
    });
  }

  // ------------------------------------------------------------------- auth

  String _authMsg(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Wrong email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in your Firebase project.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      default:
        return e.message ?? 'Sign in failed (${e.code}).';
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String city,
    required String bloodGroup,
    required String role,
  }) async {
    profilePending = true;
    notifyListeners();
    UserCredential? cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = AppUser(
        id: cred.user!.uid,
        name: name.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        city: city,
        bloodGroup: bloodGroup,
        role: role,
      );
      await _db.collection('users').doc(u.id).set(u.toJson());
      profilePending = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      profilePending = false;
      notifyListeners();
      return _authMsg(e);
    } catch (e) {
      // The account was created but the profile could not be saved.
      try {
        await cred?.user?.delete();
      } catch (_) {}
      profilePending = false;
      notifyListeners();
      return 'Could not save your profile. ${_errText(e)}';
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMsg(e);
    } catch (e) {
      return 'Could not log in. Check your internet connection.';
    }
  }

  Future<void> logout() => _auth.signOut();

  void updateProfile({
    required String name,
    required String phone,
    required String city,
    required String bloodGroup,
    required String role,
  }) {
    final m = me;
    if (m == null) return;
    _fire(_db.collection('users').doc(m.id).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'city': city,
      'bloodGroup': bloodGroup,
      'role': role,
    }));
  }

  void setAvailability(bool value) {
    final m = me;
    if (m == null) return;
    _fire(_db.collection('users').doc(m.id).update({'available': value}));
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

  /// Creates a request and alerts matching donors. Returns how many.
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
    final ref = _db.collection('requests').doc();
    final r = BloodRequest(
      id: ref.id,
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
    final donors = matchingDonors(r, onlyAvailable: true);
    final batch = _db.batch();
    batch.set(ref, r.toJson());
    for (final d in donors) {
      final nref = _db.collection('notifications').doc();
      batch.set(
        nref,
        AppNotification(
          id: nref.id,
          userId: d.id,
          title: '$urgency: $bloodGroup needed in $city',
          body:
              '$units unit(s) at ${r.hospital}. You can help - tap to respond.',
          requestId: r.id,
          time: DateTime.now(),
        ).toJson(),
      );
    }
    _fire(batch.commit());
    return donors.length;
  }

  void respond(BloodRequest r, bool accept) {
    final m = me;
    if (m == null) return;
    final ref = _db.collection('requests').doc(r.id);
    if (accept) {
      _fire(ref.update({
        'acceptedIds': FieldValue.arrayUnion([m.id]),
        'declinedIds': FieldValue.arrayRemove([m.id]),
        if (r.status == 'Open') 'status': 'Donor found',
      }));
      _notify(
        r.requesterId,
        '${m.name} accepted your request',
        '${m.bloodGroup} donor in ${m.city}. Open the request to contact them.',
        requestId: r.id,
      );
    } else {
      final remaining = r.acceptedIds.where((id) => id != m.id).length;
      _fire(ref.update({
        'declinedIds': FieldValue.arrayUnion([m.id]),
        'acceptedIds': FieldValue.arrayRemove([m.id]),
        if (r.status == 'Donor found' && remaining == 0) 'status': 'Open',
      }));
    }
  }

  /// Marks the request fulfilled. If [donorId] is given, records a donation
  /// for that donor and starts their 90 day eligibility timer.
  void markFulfilled(BloodRequest r, {String? donorId}) {
    final batch = _db.batch();
    batch.update(_db.collection('requests').doc(r.id), {
      'status': 'Fulfilled',
      'fulfilledBy': donorId,
    });
    final d = userById(donorId);
    if (d != null) {
      final now = DateTime.now();
      final dref = _db.collection('donations').doc();
      batch.set(
        dref,
        Donation(
          id: dref.id,
          donorId: d.id,
          date: now,
          place: r.hospital,
          bloodGroup: d.bloodGroup,
          requestId: r.id,
        ).toJson(),
      );
      batch.update(_db.collection('users').doc(d.id), {
        'lastDonation': now.toIso8601String(),
      });
      final nref = _db.collection('notifications').doc();
      batch.set(
        nref,
        AppNotification(
          id: nref.id,
          userId: d.id,
          title: 'Thank you for donating!',
          body:
              'Your donation at ${r.hospital} was recorded. You can donate again in $eligibilityDays days.',
          requestId: r.id,
          time: now,
        ).toJson(),
      );
    }
    _fire(batch.commit());
  }

  void deleteRequest(String id) {
    _fire(_db.collection('requests').doc(id).delete());
  }

  // -------------------------------------------------------------- donations

  void logDonation(DateTime date, String place) {
    final m = me;
    if (m == null) return;
    final batch = _db.batch();
    final dref = _db.collection('donations').doc();
    batch.set(
      dref,
      Donation(
        id: dref.id,
        donorId: m.id,
        date: date,
        place: place.isEmpty ? 'Blood donation' : place,
        bloodGroup: m.bloodGroup,
      ).toJson(),
    );
    final last = m.lastDonation;
    if (last == null || date.isAfter(last)) {
      batch.update(_db.collection('users').doc(m.id), {
        'lastDonation': date.toIso8601String(),
      });
    }
    _fire(batch.commit());
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
    final joined = c.registeredIds.contains(m.id);
    _fire(_db.collection('camps').doc(c.id).update({
      'registeredIds': joined
          ? FieldValue.arrayRemove([m.id])
          : FieldValue.arrayUnion([m.id]),
    }));
  }

  void addCamp(String title, String venue, String city, DateTime date,
      String organizer) {
    final ref = _db.collection('camps').doc();
    _fire(ref.set(Camp(
      id: ref.id,
      title: title.trim(),
      venue: venue.trim(),
      city: city,
      date: date,
      organizer: organizer.trim(),
    ).toJson()));
  }

  void deleteCamp(String id) {
    _fire(_db.collection('camps').doc(id).delete());
  }

  // ----------------------------------------------------------- notifications

  void _notify(String userId, String title, String body, {String? requestId}) {
    final ref = _db.collection('notifications').doc();
    _fire(ref.set(AppNotification(
      id: ref.id,
      userId: userId,
      title: title,
      body: body,
      requestId: requestId,
      time: DateTime.now(),
    ).toJson()));
  }

  List<AppNotification> myNotifications() {
    final list =
        notifications.where((n) => n.userId == currentUserId).toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  int get unreadCount => notifications
      .where((n) => n.userId == currentUserId && !n.read)
      .length;

  void markRead(AppNotification n) {
    _fire(_db.collection('notifications').doc(n.id).update({'read': true}));
  }

  void markAllRead() {
    final batch = _db.batch();
    var any = false;
    for (final n in notifications) {
      if (n.userId == currentUserId && !n.read) {
        batch.update(_db.collection('notifications').doc(n.id), {'read': true});
        any = true;
      }
    }
    if (any) _fire(batch.commit());
  }

  // ------------------------------------------------------------------ admin

  void setVerified(String userId, bool value) {
    _fire(_db.collection('users').doc(userId).update({'verified': value}));
  }

  /// Removes the user's profile and their requests. (Their login account stays
  /// in Firebase Auth; delete it in the Firebase console if needed.)
  void deleteUser(String userId) {
    _fire(_deleteUser(userId));
  }

  Future<void> _deleteUser(String userId) async {
    final reqs = await _db
        .collection('requests')
        .where('requesterId', isEqualTo: userId)
        .get();
    final batch = _db.batch();
    for (final d in reqs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_db.collection('users').doc(userId));
    await batch.commit();
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
}
