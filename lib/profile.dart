import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';
import 'widgets.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final me = app.me;
    if (me == null) return const SizedBox.shrink();
    final history = app.donationsOf(me.id);
    final badges = app.badgesFor(me);
    final earned = badges.where((b) => b.earned).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    BloodBadge(me.bloodGroup, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(me.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (me.verified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.verified,
                                      size: 18, color: Colors.blue),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(roleLabel(me.role),
                              style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                InfoRow(Icons.email, 'Email', me.email),
                InfoRow(Icons.phone, 'Phone', me.phone),
                InfoRow(Icons.location_city, 'City', me.city),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => goTo(context, const EditProfileScreen()),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (me.isDonor) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: CircularProgressIndicator(
                                value: me.isEligible
                                    ? 1
                                    : 1 - me.daysUntilEligible / eligibilityDays,
                                strokeWidth: 7,
                                color: me.isEligible
                                    ? Colors.green
                                    : Colors.orange,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    me.isEligible
                                        ? 'OK'
                                        : '${me.daysUntilEligible}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                if (!me.isEligible)
                                  const Text('days',
                                      style: TextStyle(fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Eligibility timer',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              me.isEligible
                                  ? 'You can donate now. The gap between donations is $eligibilityDays days.'
                                  : 'You can donate again in ${me.daysUntilEligible} days. You are hidden from alerts until then.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available to donate'),
                    value: me.available,
                    activeColor: kRed,
                    onChanged: (v) => app.setAvailability(v),
                  ),
                ],
              ),
            ),
          ),
          SectionTitle(
            'Donation history (${history.length})',
            trailing: TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                  lastDate: DateTime.now(),
                );
                if (date == null || !context.mounted) return;
                final place = await askText(
                    context, 'Where did you donate?', 'Hospital or camp name');
                if (place == null) return;
                app.logDonation(date, place);
                if (context.mounted) snack(context, 'Donation logged.');
              },
              icon: const Icon(Icons.add),
              label: const Text('Log'),
            ),
          ),
          if (history.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No donations yet. Your first one earns a badge!',
                    style: TextStyle(color: Colors.grey.shade700)),
              ),
            ),
          for (final d in history.take(5))
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                    backgroundColor: kRed,
                    child: Icon(Icons.water_drop, color: Colors.white)),
                title: Text(d.place),
                subtitle: Text(fmtDate(d.date)),
                trailing: BloodBadge(d.bloodGroup, size: 34, filled: false),
              ),
            ),
          if (history.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => goTo(context, const CertificateScreen()),
                icon: const Icon(Icons.workspace_premium),
                label: const Text('View donor certificate'),
              ),
            ),
          SectionTitle('Badges ($earned/${badges.length})'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.0,
            children: [for (final b in badges) _BadgeTile(b)],
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kRed),
          onPressed: () => app.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeInfo b;
  const _BadgeTile(this.b);

  @override
  Widget build(BuildContext context) {
    final color = b.earned ? kRed : Colors.grey.shade400;
    return Container(
      decoration: BoxDecoration(
        color: b.earned ? kRed.withAlpha(18) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: b.earned ? kRed : Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(b.icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(b.name,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          Text(b.description,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- edit profile

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late String city;
  late String group;
  late String role;

  @override
  void initState() {
    super.initState();
    final me = app.me!;
    _name = TextEditingController(text: me.name);
    _phone = TextEditingController(text: me.phone);
    city = me.city;
    group = me.bloodGroup;
    role = me.role;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = app.me!.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Full name', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Phone', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.replaceAll(RegExp(r'[^0-9]'), '').length < 10)
                      ? 'Enter a 10 digit number'
                      : null,
            ),
            const SizedBox(height: 12),
            Pick(
                label: 'Blood group',
                value: group,
                items: bloodGroups,
                onChanged: (v) => setState(() => group = v)),
            const SizedBox(height: 12),
            Pick(
                label: 'City',
                value: city,
                items: cities,
                onChanged: (v) => setState(() => city = v)),
            if (!isAdmin) ...[
              const SizedBox(height: 16),
              const Text('I want to'),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'donor', label: Text('Donate')),
                  ButtonSegment(value: 'requester', label: Text('Request')),
                  ButtonSegment(value: 'both', label: Text('Both')),
                ],
                selected: {role},
                onSelectionChanged: (s) => setState(() => role = s.first),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: kRed,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                app.updateProfile(
                  name: _name.text,
                  phone: _phone.text,
                  city: city,
                  bloodGroup: group,
                  role: role,
                );
                final m = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                m.showSnackBar(
                    const SnackBar(content: Text('Profile updated.')));
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- certificate

class CertificateScreen extends StatelessWidget {
  const CertificateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = app.me!;
    final n = app.donationCount(me.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Donor certificate')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: kRed, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.water_drop, color: kRed, size: 56),
                const SizedBox(height: 8),
                const Text('Certificate of Appreciation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kRed)),
                const SizedBox(height: 16),
                const Text('This is proudly presented to'),
                const SizedBox(height: 8),
                Text(me.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Blood group ${me.bloodGroup}  ·  ${me.city}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                Text(
                  'for $n blood donation${n == 1 ? '' : 's'}, helping up to ${n * 3} lives.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text('Issued ${fmtDate(DateTime.now())} via RedDrop',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
