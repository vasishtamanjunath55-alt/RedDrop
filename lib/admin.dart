import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';
import 'requests.dart';
import 'widgets.dart';

class AdminTab extends StatelessWidget {
  const AdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final people = app.users.where((u) => !u.isAdmin).toList();
        final requests = app.sortedRequests();
        final camps = List<Camp>.from(app.camps)
          ..sort((a, b) => a.date.compareTo(b.date));

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                labelColor: kRed,
                indicatorColor: kRed,
                tabs: [
                  Tab(text: 'Users (${people.length})'),
                  Tab(text: 'Requests (${requests.length})'),
                  Tab(text: 'Camps (${camps.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: people.length,
                      itemBuilder: (c, i) {
                        final u = people[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                BloodBadge(u.bloodGroup, size: 40),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(u.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text('${u.role} · ${u.city}',
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Verified',
                                        style: TextStyle(fontSize: 10)),
                                    Switch(
                                      value: u.verified,
                                      activeColor: Colors.blue,
                                      onChanged: (v) =>
                                          app.setVerified(u.id, v),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  tooltip: 'Remove user',
                                  icon: const Icon(Icons.delete_outline,
                                      color: kRed),
                                  onPressed: () async {
                                    final ok = await confirm(
                                        context,
                                        'Remove ${u.name}?',
                                        'Their requests and donations will be removed too.');
                                    if (ok) app.deleteUser(u.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: requests.length,
                      itemBuilder: (c, i) {
                        final r = requests[i];
                        return Card(
                          child: ListTile(
                            leading: BloodBadge(r.bloodGroup, size: 40),
                            title: Text('${r.units}u · ${r.hospital}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${r.patientName} · ${r.city} · ${r.displayStatus}'),
                            onTap: () => goTo(context, RequestDetailScreen(r.id)),
                            trailing: IconButton(
                              tooltip: 'Remove request',
                              icon: const Icon(Icons.delete_outline,
                                  color: kRed),
                              onPressed: () async {
                                final ok = await confirm(
                                    context,
                                    'Remove this request?',
                                    'Use this for fake or duplicate requests.');
                                if (ok) app.deleteRequest(r.id);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style:
                                  FilledButton.styleFrom(backgroundColor: kRed),
                              onPressed: () =>
                                  goTo(context, const AddCampScreen()),
                              icon: const Icon(Icons.add),
                              label: const Text('Add donation camp'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: camps.length,
                            itemBuilder: (c, i) {
                              final camp = camps[i];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                      backgroundColor: kRed,
                                      child: Icon(Icons.event,
                                          color: Colors.white)),
                                  title: Text(camp.title),
                                  subtitle: Text(
                                      '${camp.city} · ${fmtDate(camp.date)} · ${camp.registeredIds.length} registered'),
                                  trailing: IconButton(
                                    tooltip: 'Remove camp',
                                    icon: const Icon(Icons.delete_outline,
                                        color: kRed),
                                    onPressed: () async {
                                      final ok = await confirm(
                                          context,
                                          'Remove camp?',
                                          'Registrations will be lost.');
                                      if (ok) app.deleteCamp(camp.id);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AddCampScreen extends StatefulWidget {
  const AddCampScreen({super.key});

  @override
  State<AddCampScreen> createState() => _AddCampScreenState();
}

class _AddCampScreenState extends State<AddCampScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _organizer = TextEditingController();
  String city = cities.first;
  DateTime date = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _organizer.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t == null) return;
    setState(() => date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add donation camp')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Camp title', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venue,
              decoration: const InputDecoration(
                  labelText: 'Venue', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a venue' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _organizer,
              decoration: const InputDecoration(
                  labelText: 'Organizer', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter an organizer' : null,
            ),
            const SizedBox(height: 12),
            Pick(
                label: 'City',
                value: city,
                items: cities,
                onChanged: (v) => setState(() => city = v)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(fmtDateTime(date)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: kRed,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                app.addCamp(
                    _title.text, _venue.text, city, date, _organizer.text);
                final m = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                m.showSnackBar(const SnackBar(content: Text('Camp added.')));
              },
              child: const Text('Save camp'),
            ),
          ],
        ),
      ),
    );
  }
}
