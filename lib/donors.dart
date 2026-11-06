import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';
import 'widgets.dart';

class DonorsTab extends StatefulWidget {
  const DonorsTab({super.key});

  @override
  State<DonorsTab> createState() => _DonorsTabState();
}

class _DonorsTabState extends State<DonorsTab> {
  String need = 'All';
  String city = 'All';
  bool onlyAvailable = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final me = app.me!;
        final list = app.users.where((u) {
          if (!u.isDonor || u.id == me.id) return false;
          if (city != 'All' && u.city != city) return false;
          if (need != 'All' && !isCompatible(u.bloodGroup, need)) return false;
          if (onlyAvailable && !u.canDonateNow) return false;
          return true;
        }).toList();
        list.sort((a, b) {
          int score(AppUser u) =>
              (u.canDonateNow ? 0 : 4) +
              (need != 'All' && u.bloodGroup == need ? 0 : 2) +
              (u.verified ? 0 : 1);
          return score(a).compareTo(score(b));
        });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Pick(
                        label: 'Blood needed',
                        value: need,
                        items: ['All', ...bloodGroups],
                        onChanged: (v) => setState(() => need = v)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Pick(
                        label: 'City',
                        value: city,
                        items: ['All', ...cities],
                        onChanged: (v) => setState(() => city = v)),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Available now only'),
              value: onlyAvailable,
              activeColor: kRed,
              onChanged: (v) => setState(() => onlyAvailable = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  need == 'All'
                      ? '${list.length} donors'
                      : '${list.length} donors who can give $need',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.person_search,
                      text: 'No donors found for these filters.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                      itemCount: list.length,
                      itemBuilder: (c, i) => DonorCard(list[i], need: need),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class DonorCard extends StatelessWidget {
  final AppUser u;
  final String need;
  const DonorCard(this.u, {super.key, this.need = 'All'});

  @override
  Widget build(BuildContext context) {
    final msg = need == 'All'
        ? 'Hi ${u.name}, I found you on RedDrop. Are you available to donate blood?'
        : 'Hi ${u.name}, I found you on RedDrop. We urgently need $need blood. Can you help?';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            BloodBadge(u.bloodGroup),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(u.name,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (u.verified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child:
                              Icon(Icons.verified, size: 16, color: Colors.blue),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${u.city} · ${app.donationCount(u.id)} donation${app.donationCount(u.id) == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  availabilityPill(u),
                ],
              ),
            ),
            ContactButtons(phone: u.phone, message: msg),
          ],
        ),
      ),
    );
  }
}
