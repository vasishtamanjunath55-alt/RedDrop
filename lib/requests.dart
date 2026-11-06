import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';
import 'widgets.dart';

// ================================================================ requests tab

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  String groupFilter = 'All';

  Widget _list(List<BloodRequest> items, String emptyText) {
    if (items.isEmpty) {
      return EmptyState(icon: Icons.bloodtype_outlined, text: emptyText);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: items.length,
      itemBuilder: (c, i) => RequestCard(items[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final me = app.me!;
        final forYou = app.requestsForDonor(me);
        final all = app
            .sortedRequests()
            .where((r) => groupFilter == 'All' || r.bloodGroup == groupFilter)
            .toList();
        final mine = app
            .sortedRequests()
            .where((r) => r.requesterId == me.id || r.acceptedIds.contains(me.id))
            .toList();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: me.isAdmin
                ? null
                : FloatingActionButton.extended(
                    backgroundColor: kRed,
                    foregroundColor: Colors.white,
                    onPressed: () => goTo(context, const CreateRequestScreen()),
                    icon: const Icon(Icons.add),
                    label: const Text('Request blood'),
                  ),
            body: Column(
              children: [
                const TabBar(
                  labelColor: kRed,
                  indicatorColor: kRed,
                  tabs: [
                    Tab(text: 'For you'),
                    Tab(text: 'All'),
                    Tab(text: 'Mine'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _list(
                        forYou,
                        me.isDonor
                            ? 'No open requests match your blood group right now.'
                            : 'Set your role to Donor or Both in Profile to get matched requests.',
                      ),
                      Column(
                        children: [
                          SizedBox(
                            height: 52,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              children: [
                                for (final g in ['All', ...bloodGroups])
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(g),
                                      selected: groupFilter == g,
                                      onSelected: (_) =>
                                          setState(() => groupFilter = g),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                              child: _list(all, 'No requests for this group.')),
                        ],
                      ),
                      _list(mine,
                          'You have not posted or accepted any requests yet.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RequestCard extends StatelessWidget {
  final BloodRequest r;
  const RequestCard(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => goTo(context, RequestDetailScreen(r.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BloodBadge(r.bloodGroup),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.units} unit${r.units > 1 ? 's' : ''} · ${r.hospital}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text('${r.patientName} · ${r.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Pill(r.urgency, urgencyColor(r.urgency)),
                        Pill(r.displayStatus, statusColor(r.displayStatus)),
                        if (r.isActive)
                          Pill(timeLeft(r.deadline), Colors.grey.shade700,
                              icon: Icons.schedule),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ request details

class StatusTracker extends StatelessWidget {
  final String status;
  const StatusTracker(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final idx = requestStatuses.indexOf(status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < requestStatuses.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Container(
                  height: 3,
                  color: i <= idx ? kRed : Colors.grey.shade300,
                ),
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= idx ? kRed : Colors.grey.shade300,
                child: Icon(i <= idx ? Icons.check : Icons.circle_outlined,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(requestStatuses[i], style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ],
    );
  }
}

class RequestDetailScreen extends StatelessWidget {
  final String id;
  const RequestDetailScreen(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final r = app.requestById(id);
        final me = app.me;
        if (r == null || me == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Blood request')),
            body: const EmptyState(
                icon: Icons.delete_outline,
                text: 'This request is no longer available.'),
          );
        }
        final isOwner = r.requesterId == me.id;
        final canRespond = me.isDonor &&
            !isOwner &&
            r.isActive &&
            isCompatible(me.bloodGroup, r.bloodGroup);
        final accepted = r.acceptedIds.contains(me.id);
        final declined = r.declinedIds.contains(me.id);
        final matches = app.matchingDonors(r);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Blood request'),
            actions: [
              if (isOwner || me.isAdmin)
                IconButton(
                  tooltip: 'Delete request',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await confirm(context, 'Delete request?',
                        'This will remove the request for everyone.');
                    if (ok) {
                      app.deleteRequest(r.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          BloodBadge(r.bloodGroup, size: 64),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.units} unit${r.units > 1 ? 's' : ''} of ${r.bloodGroup}',
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Pill(r.urgency, urgencyColor(r.urgency)),
                                    Pill(r.displayStatus,
                                        statusColor(r.displayStatus)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      StatusTracker(r.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      InfoRow(Icons.person, 'Patient', r.patientName),
                      InfoRow(Icons.local_hospital, 'Hospital', r.hospital),
                      InfoRow(Icons.location_city, 'City', r.city),
                      InfoRow(Icons.schedule, 'Needed by',
                          '${fmtDateTime(r.deadline)}  (${timeLeft(r.deadline)})'),
                      InfoRow(Icons.access_time, 'Posted', ago(r.createdAt)),
                      if (r.note.isNotEmpty)
                        InfoRow(Icons.notes, 'Note', r.note),
                    ],
                  ),
                ),
              ),
              if (!isOwner)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: kRed,
                        child: Icon(Icons.person, color: Colors.white)),
                    title: Text(r.requesterName),
                    subtitle: const Text('Requested by'),
                    trailing: ContactButtons(
                      phone: r.phone,
                      message:
                          'Hi, I saw your ${r.bloodGroup} blood request at ${r.hospital} on RedDrop.',
                    ),
                  ),
                ),
              if (canRespond) ...[
                const SectionTitle('Can you help?'),
                if (accepted)
                  Card(
                    color: Colors.green.withAlpha(25),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 10),
                          const Expanded(
                              child: Text(
                                  'You accepted. The requester has been notified.')),
                          TextButton(
                            onPressed: () => app.respond(r, false),
                            child: const Text('Withdraw'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: kRed,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () {
                            app.respond(r, true);
                            snack(context, 'Thank you! The requester was notified.');
                          },
                          icon: const Icon(Icons.favorite),
                          label: const Text('I can donate'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: declined
                              ? null
                              : () {
                                  app.respond(r, false);
                                  snack(context, 'Marked as not available.');
                                },
                          child: Text(declined ? 'Declined' : "Can't donate"),
                        ),
                      ),
                    ],
                  ),
              ],
              if (isOwner || me.isAdmin) ...[
                SectionTitle('Donors who accepted (${r.acceptedIds.length})'),
                if (r.acceptedIds.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        r.status == 'Fulfilled'
                            ? 'This request was fulfilled.'
                            : 'No donor has accepted yet. Matching donors in ${r.city} were notified. You can also contact them below.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                for (final did in r.acceptedIds)
                  Builder(builder: (context) {
                    final d = app.userById(did);
                    if (d == null) return const SizedBox.shrink();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                BloodBadge(d.bloodGroup, size: 40),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(d.city,
                                          style: TextStyle(
                                              color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                ContactButtons(
                                  phone: d.phone,
                                  message:
                                      'Hi ${d.name}, thank you for accepting the ${r.bloodGroup} request at ${r.hospital}.',
                                ),
                              ],
                            ),
                            if (isOwner && r.status != 'Fulfilled')
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final ok = await confirm(
                                        context,
                                        'Mark as donated?',
                                        '${d.name} donated blood. This records the donation and starts their $eligibilityDays day timer.');
                                    if (ok) {
                                      app.markFulfilled(r, donorId: d.id);
                                      if (context.mounted) {
                                        snack(context, 'Request marked fulfilled.');
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.verified),
                                  label: const Text('Mark donated'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                if (isOwner && r.status != 'Fulfilled')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await confirm(context, 'Mark fulfilled?',
                            'Use this if the blood was arranged another way.');
                        if (ok) app.markFulfilled(r);
                      },
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Mark request as fulfilled'),
                    ),
                  ),
                SectionTitle('Matching donors in ${r.city} (${matches.length})'),
                if (matches.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                          'No compatible donors registered in ${r.city} yet.',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ),
                  ),
                for (final d in matches.take(20))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          BloodBadge(d.bloodGroup, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(d.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    if (d.verified)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.verified,
                                            size: 16, color: Colors.blue),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                availabilityPill(d),
                              ],
                            ),
                          ),
                          ContactButtons(
                            phone: d.phone,
                            message:
                                'Hi ${d.name}, we urgently need ${r.bloodGroup} blood at ${r.hospital}, ${r.city}. Can you help? (via RedDrop)',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================ new request

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _patient = TextEditingController();
  final _hospital = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  String group = 'O+';
  String city = cities.first;
  String urgency = 'Urgent';
  int units = 1;
  DateTime deadline = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    final me = app.me;
    if (me != null) {
      _phone.text = me.phone;
      city = me.city;
    }
  }

  @override
  void dispose() {
    _patient.dispose();
    _hospital.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final d = await showDatePicker(
      context: context,
      initialDate: deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(deadline),
    );
    if (t == null) return;
    setState(() => deadline = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (deadline.isBefore(DateTime.now())) {
      snack(context, 'Choose a deadline in the future.');
      return;
    }
    final n = app.createRequest(
      patient: _patient.text,
      bloodGroup: group,
      units: units,
      hospital: _hospital.text,
      city: city,
      urgency: urgency,
      deadline: deadline,
      phone: _phone.text,
      note: _note.text,
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(n == 0
          ? 'Request posted. No available donors matched yet.'
          : 'Request posted. $n matching donor${n > 1 ? 's' : ''} notified.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final me = app.me!;
    final compatible = app.compatibleDonors(group, city, excludeId: me.id);
    final ready = compatible.where((u) => u.canDonateNow).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Request blood')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _patient,
              decoration: const InputDecoration(
                  labelText: 'Patient name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter patient name' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Pick(
                      label: 'Blood group needed',
                      value: group,
                      items: bloodGroups,
                      onChanged: (v) => setState(() => group = v)),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade500),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed:
                            units > 1 ? () => setState(() => units--) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$units unit${units > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed:
                            units < 10 ? () => setState(() => units++) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hospital,
              decoration: const InputDecoration(
                  labelText: 'Hospital name',
                  prefixIcon: Icon(Icons.local_hospital),
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter hospital name' : null,
            ),
            const SizedBox(height: 12),
            Pick(
                label: 'City',
                value: city,
                items: cities,
                onChanged: (v) => setState(() => city = v)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kRed.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.groups, color: kRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${compatible.length} compatible donor${compatible.length == 1 ? '' : 's'} in $city, $ready available now',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Urgency'),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: [
                for (final u in urgencies)
                  ButtonSegment(value: u, label: Text(u)),
              ],
              selected: {urgency},
              onSelectionChanged: (s) => setState(() => urgency = s.first),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event),
              label: Text('Needed by: ${fmtDateTime(deadline)}'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Contact phone',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.replaceAll(RegExp(r'[^0-9]'), '').length < 10)
                      ? 'Enter a 10 digit number'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: kRed,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.send),
              label: const Text('Post request and alert donors'),
            ),
          ],
        ),
      ),
    );
  }
}
