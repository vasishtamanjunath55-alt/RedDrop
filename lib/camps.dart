import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';
import 'widgets.dart';

class CampsTab extends StatefulWidget {
  const CampsTab({super.key});

  @override
  State<CampsTab> createState() => _CampsTabState();
}

class _CampsTabState extends State<CampsTab> {
  String city = 'All';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final me = app.me!;
        final list = app.camps
            .where((c) => city == 'All' || c.city == city)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        return Column(
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
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.event_busy,
                      text: 'No donation camps listed for this city yet.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: list.length,
                      itemBuilder: (c, i) => _CampCard(list[i], me),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CampCard extends StatelessWidget {
  final Camp camp;
  final AppUser me;
  const _CampCard(this.camp, this.me);

  @override
  Widget build(BuildContext context) {
    final registered = camp.registeredIds.contains(me.id);
    final past = camp.date.isBefore(DateTime.now());
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: kRed.withAlpha(22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('${camp.date.day}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kRed)),
                      Text(monthName(camp.date).toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kRed)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(camp.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${camp.venue}, ${camp.city}',
                          style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 2),
                      Text('${fmtDateTime(camp.date)}',
                          style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text('By ${camp.organizer}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Pill('${camp.registeredIds.length} registered', Colors.blue,
                    icon: Icons.group),
                const Spacer(),
                if (past)
                  const Pill('Completed', Colors.grey)
                else if (!me.isAdmin)
                  registered
                      ? OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await confirm(context, 'Cancel registration?',
                                'You will be removed from ${camp.title}.');
                            if (ok) app.toggleCamp(camp);
                          },
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          label: const Text('Registered'),
                        )
                      : FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kRed),
                          onPressed: () {
                            app.toggleCamp(camp);
                            snack(context, 'Registered for ${camp.title}.');
                          },
                          icon: const Icon(Icons.how_to_reg),
                          label: const Text('Register'),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
