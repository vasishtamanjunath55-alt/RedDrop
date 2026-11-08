import 'package:flutter/material.dart';

import 'admin.dart';
import 'app_state.dart';
import 'camps.dart';
import 'donors.dart';
import 'extras.dart';
import 'models.dart';
import 'profile.dart';
import 'requests.dart';
import 'widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final me = app.me;
        if (me == null) return const SizedBox.shrink();
        final isAdmin = me.isAdmin;
        final titles = <String>[
          'RedDrop',
          'Blood requests',
          'Find donors',
          'Donation camps',
          if (isAdmin) 'Admin panel',
          'My profile',
        ];
        final icons = <IconData>[
          Icons.home,
          Icons.bloodtype,
          Icons.people,
          Icons.event,
          if (isAdmin) Icons.admin_panel_settings,
          Icons.person,
        ];
        final labels = <String>[
          'Home',
          'Requests',
          'Donors',
          'Camps',
          if (isAdmin) 'Admin',
          'Profile',
        ];
        final pages = <Widget>[
          HomeTab(onGoTab: (i) => setState(() => idx = i)),
          const RequestsTab(),
          const DonorsTab(),
          const CampsTab(),
          if (isAdmin) const AdminTab(),
          const ProfileTab(),
        ];
        if (idx >= pages.length) idx = 0;
        final unread = app.unreadCount;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                if (idx == 0) ...[
                  const Icon(Icons.water_drop, size: 22),
                  const SizedBox(width: 6),
                ],
                Text(titles[idx]),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => goTo(context, const NotificationsScreen()),
                icon: Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications),
                ),
              ),
            ],
          ),
          body: IndexedStack(index: idx, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) => setState(() => idx = i),
            destinations: [
              for (var i = 0; i < labels.length; i++)
                NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
            ],
          ),
        );
      },
    );
  }
}

class HomeTab extends StatelessWidget {
  final void Function(int) onGoTab;
  const HomeTab({super.key, required this.onGoTab});

  @override
  Widget build(BuildContext context) {
    final me = app.me!;
    final reqs = me.isDonor
        ? app.requestsForDonor(me)
        : app.sortedRequests().where((r) => r.isActive).toList();
    final firstName = me.name.split(' ').first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (app.syncError != null) ...[
          Card(
            color: Colors.red.withAlpha(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: kRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(app.syncError!,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [kRed, kDarkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(me.bloodGroup,
                    style: const TextStyle(
                        color: kRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, $firstName',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${me.city}  ·  ${roleLabel(me.role)}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (me.isDonor) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(me.isEligible ? Icons.favorite : Icons.timer,
                          color: me.isEligible ? Colors.green : Colors.orange,
                          size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              me.isEligible
                                  ? 'You are eligible to donate'
                                  : 'Next donation in ${me.daysUntilEligible} days',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              me.lastDonation == null
                                  ? 'No donation recorded yet'
                                  : 'Last donated ${fmtDate(me.lastDonation!)}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!me.isEligible)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(
                        value: 1 - me.daysUntilEligible / eligibilityDays,
                        minHeight: 8,
                        color: Colors.orange,
                        backgroundColor: Colors.orange.withAlpha(40),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available to donate'),
                    subtitle:
                        const Text('Get alerts for matching requests nearby'),
                    value: me.available,
                    activeColor: kRed,
                    onChanged: (v) => app.setAvailability(v),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SectionTitle('Quick actions'),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [
            if (!me.isAdmin)
              _Action(Icons.add_circle, 'Request\nblood',
                  () => goTo(context, const CreateRequestScreen())),
            _Action(Icons.search, 'Find\ndonors', () => onGoTab(2)),
            _Action(Icons.swap_horiz, 'Blood\nguide',
                () => goTo(context, const CompatibilityScreen())),
            _Action(Icons.leaderboard, 'Leader-\nboard',
                () => goTo(context, const LeaderboardScreen())),
            _Action(Icons.insights, 'Impact',
                () => goTo(context, const ImpactScreen())),
            _Action(Icons.event, 'Camps', () => onGoTab(3)),
            _Action(Icons.bloodtype, 'All\nrequests', () => onGoTab(1)),
            _Action(Icons.notifications, 'Alerts',
                () => goTo(context, const NotificationsScreen())),
          ],
        ),
        const SectionTitle('Community impact'),
        Row(
          children: [
            _Stat('${app.donorCount}', 'Donors'),
            _Stat('${app.fulfilledCount}', 'Fulfilled'),
            _Stat('${app.livesHelped}', 'Lives helped'),
          ],
        ),
        SectionTitle(
          me.isDonor ? 'Needs your help' : 'Active requests',
          trailing:
              TextButton(onPressed: () => onGoTab(1), child: const Text('See all')),
        ),
        if (reqs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No open requests right now.',
                style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          for (final r in reqs.take(3)) RequestCard(r),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kRed, size: 28),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, height: 1.15)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: kRed)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
