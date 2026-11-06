import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

const Color kRed = Color(0xFFC62828);
const Color kDarkRed = Color(0xFF8E0000);

void snack(BuildContext c, String msg) {
  final m = ScaffoldMessenger.of(c);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(msg)));
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String monthName(DateTime d) => _months[d.month - 1];

String fmtDate(DateTime d) => '${d.day} ${monthName(d)} ${d.year}';

String fmtDateTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '${fmtDate(d)}, $h:$m $ap';
}

String timeLeft(DateTime d) {
  final diff = d.difference(DateTime.now());
  if (diff.isNegative) return 'Expired';
  if (diff.inDays >= 1) return '${diff.inDays}d ${diff.inHours % 24}h left';
  if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
  return '${diff.inMinutes}m left';
}

String ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

Color urgencyColor(String u) {
  switch (u) {
    case 'Critical':
      return const Color(0xFFD32F2F);
    case 'Urgent':
      return const Color(0xFFEF6C00);
    default:
      return const Color(0xFF1976D2);
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'Open':
      return const Color(0xFFEF6C00);
    case 'Donor found':
      return const Color(0xFF1976D2);
    case 'Fulfilled':
      return const Color(0xFF2E7D32);
    default:
      return Colors.grey;
  }
}

// ------------------------------------------------------------ contact actions

Future<void> _open(BuildContext c, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && c.mounted) snack(c, 'Could not open this on your phone.');
  } catch (_) {
    if (c.mounted) snack(c, 'Could not open this on your phone.');
  }
}

Future<void> callNumber(BuildContext c, String phone) {
  final n = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  return _open(c, Uri.parse('tel:$n'));
}

Future<void> whatsapp(BuildContext c, String phone, String message) {
  var n = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.length == 10) n = '91$n';
  return _open(
      c, Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(message)}'));
}

class ContactButtons extends StatelessWidget {
  final String phone;
  final String message;
  const ContactButtons({super.key, required this.phone, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Call',
          onPressed: () => callNumber(context, phone),
          icon: const Icon(Icons.call, size: 20),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'WhatsApp',
          onPressed: () => whatsapp(context, phone, message),
          icon: const Icon(Icons.chat, size: 20),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- dialogs

Future<bool> confirm(BuildContext c, String title, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm')),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> askText(BuildContext c, String title, String hint) async {
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save')),
      ],
    ),
  );
  return r;
}

// ------------------------------------------------------------------- widgets

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class BloodBadge extends StatelessWidget {
  final String group;
  final double size;
  final bool filled;
  const BloodBadge(this.group,
      {super.key, this.size = 44, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? kRed : kRed.withAlpha(25),
        border: Border.all(color: kRed, width: filled ? 0 : 1.2),
      ),
      child: Text(
        group,
        style: TextStyle(
          color: filled ? Colors.white : kRed,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: kRed),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class Pick extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const Pick({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items
          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

Widget availabilityPill(AppUser u) {
  if (!u.available) return const Pill('Unavailable', Colors.grey);
  if (!u.isEligible) {
    return Pill('Eligible in ${u.daysUntilEligible}d', Colors.orange,
        icon: Icons.timer);
  }
  return const Pill('Available', Colors.green, icon: Icons.check_circle);
}

String roleLabel(String role) {
  switch (role) {
    case 'donor':
      return 'Donor';
    case 'requester':
      return 'Requester';
    case 'admin':
      return 'Admin';
    default:
      return 'Donor & Requester';
  }
}

void goTo(BuildContext c, Widget screen) {
  Navigator.push(c, MaterialPageRoute(builder: (_) => screen));
}
