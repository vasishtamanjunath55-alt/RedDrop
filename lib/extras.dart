import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';
import 'requests.dart';
import 'widgets.dart';

// ============================================================== notifications

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final list = app.myNotifications();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (list.any((n) => !n.read))
                TextButton(
                  onPressed: app.markAllRead,
                  child: const Text('Mark all read',
                      style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  text:
                      'No alerts yet. Matching blood requests will show up here.')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final n = list[i];
                    return ListTile(
                      tileColor: n.read ? null : kRed.withAlpha(14),
                      leading: CircleAvatar(
                        backgroundColor: n.read ? Colors.grey : kRed,
                        child: const Icon(Icons.notifications,
                            color: Colors.white, size: 20),
                      ),
                      title: Text(n.title,
                          style: TextStyle(
                              fontWeight:
                                  n.read ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text('${n.body}\n${ago(n.time)}'),
                      isThreeLine: true,
                      onTap: () {
                        app.markRead(n);
                        final id = n.requestId;
                        if (id != null && app.requestById(id) != null) {
                          goTo(context, RequestDetailScreen(id));
                        }
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

// ============================================================== compatibility

class CompatibilityScreen extends StatefulWidget {
  const CompatibilityScreen({super.key});

  @override
  State<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends State<CompatibilityScreen> {
  String donor = 'O-';
  String recipient = 'A+';

  @override
  Widget build(BuildContext context) {
    final ok = isCompatible(donor, recipient);
    return Scaffold(
      appBar: AppBar(title: const Text('Blood compatibility guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick checker',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Pick(
                            label: 'Donor',
                            value: donor,
                            items: bloodGroups,
                            onChanged: (v) => setState(() => donor = v)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward),
                      ),
                      Expanded(
                        child: Pick(
                            label: 'Recipient',
                            value: recipient,
                            items: bloodGroups,
                            onChanged: (v) => setState(() => recipient = v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (ok ? Colors.green : Colors.red).withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(ok ? Icons.check_circle : Icons.cancel,
                            color: ok ? Colors.green : Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ok
                                ? '$donor can donate to $recipient'
                                : '$donor cannot donate to $recipient',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('All blood groups'),
          for (final g in bloodGroups)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BloodBadge(g, size: 40),
                        const SizedBox(width: 12),
                        Text('Group $g',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (g == 'O-')
                          const Pill('Universal donor', Colors.green),
                        if (g == 'AB+')
                          const Pill('Universal recipient', Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Can donate to',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in canDonateTo[g]!)
                          BloodBadge(t, size: 32, filled: false),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Can receive from',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in canReceiveFrom(g))
                          BloodBadge(t, size: 32, filled: false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================ leaderboard

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String city = 'All';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final me = app.me!;
        final board = app.leaderboard(city: city == 'All' ? null : city);
        return Scaffold(
          appBar: AppBar(title: const Text('Top donors')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Pick(
                    label: 'City',
                    value: city,
                    items: ['All', ...cities],
                    onChanged: (v) => setState(() => city = v)),
              ),
              Expanded(
                child: board.isEmpty
                    ? const EmptyState(
                        icon: Icons.emoji_events_outlined,
                        text: 'No donations recorded here yet.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: board.length,
                        itemBuilder: (c, i) {
                          final u = board[i].key;
                          final count = board[i].value;
                          final badges = app
                              .badgesFor(u)
                              .where((b) => b.earned)
                              .length;
                          final medal = i == 0
                              ? const Color(0xFFFFB300)
                              : i == 1
                                  ? const Color(0xFF9E9E9E)
                                  : i == 2
                                      ? const Color(0xFF8D6E63)
                                      : null;
                          return Card(
                            color: u.id == me.id ? kRed.withAlpha(18) : null,
                            child: ListTile(
                              leading: SizedBox(
                                width: 70,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 26,
                                      child: medal != null
                                          ? Icon(Icons.emoji_events,
                                              color: medal)
                                          : Text('${i + 1}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    BloodBadge(u.bloodGroup, size: 36),
                                  ],
                                ),
                              ),
                              title: Text(u.id == me.id ? '${u.name} (you)' : u.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text('${u.city} · $badges badges'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$count',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: kRed)),
                                  const Text('donations',
                                      style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================================================================== impact

class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final donors = app.users.where((u) => u.isDonor).toList();
        final byGroup = {
          for (final g in bloodGroups)
            g: donors.where((u) => u.bloodGroup == g).length,
        };
        final maxGroup =
            byGroup.values.fold<int>(1, (a, b) => b > a ? b : a);
        final byCity = <String, int>{};
        for (final u in donors) {
          byCity[u.city] = (byCity[u.city] ?? 0) + 1;
        }
        final cityList = byCity.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final rate = app.requestCount == 0
            ? 0
            : (app.fulfilledCount * 100 / app.requestCount).round();

        Widget tile(IconData icon, String value, String label) => SizedBox(
              width: (MediaQuery.of(context).size.width - 44) / 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: kRed),
                      const SizedBox(height: 8),
                      Text(value,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: kRed)),
                      Text(label, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ),
            );

        return Scaffold(
          appBar: AppBar(title: const Text('Impact dashboard')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  tile(Icons.people, '${app.donorCount}', 'Registered donors'),
                  tile(Icons.check_circle, '${app.availableDonorCount}',
                      'Available now'),
                  tile(Icons.bloodtype, '${app.requestCount}',
                      'Requests posted'),
                  tile(Icons.task_alt, '${app.fulfilledCount}', 'Fulfilled'),
                  tile(Icons.water_drop, '${app.unitsDonated}', 'Units donated'),
                  tile(Icons.favorite, '${app.livesHelped}', 'Lives helped'),
                ],
              ),
              const SizedBox(height: 4),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fulfilment rate: $rate%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: rate / 100,
                        minHeight: 10,
                        color: Colors.green,
                        backgroundColor: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lives helped assumes one donation can help up to 3 people.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Donors by blood group'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final g in bloodGroups)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 40,
                                  child: Text(g,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: byGroup[g]! / maxGroup,
                                  minHeight: 12,
                                  color: kRed,
                                  backgroundColor: kRed.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              SizedBox(
                                  width: 30,
                                  child: Text('${byGroup[g]}',
                                      textAlign: TextAlign.right)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Donors by city'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final e in cityList)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(child: Text(e.key)),
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
