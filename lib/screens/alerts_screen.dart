import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  final _divisions = const [
    'Dhaka','Chattogram','Rajshahi','Khulna',
    'Barishal','Sylhet','Rangpur','Mymensingh',
  ];
  String? _selectedDivision;

  final _thresholds = const [50, 100, 150, 200, 300];
  int? _selectedThreshold;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.notifications_none,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('AQI Alerts',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),

        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subscribe to Alerts',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Get notified when AQI levels exceed your threshold',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),

              _label('Full Name'),
              _textField(_name, hint: 'Enter your full name'),
              const SizedBox(height: 12),

              _label('Email Address'),
              _textField(_email, hint: 'Enter your email', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),

              _label('District'),
              _dropdown<String>(
                value: _selectedDivision,
                items: _divisions,
                labelBuilder: (s) => s,
                hint: 'Select your district',
                onChanged: (v) => setState(() => _selectedDivision = v),
              ),
              const SizedBox(height: 12),

              _label('Alert Threshold (AQI)'),
              _dropdown<int>(
                value: _selectedThreshold,
                items: _thresholds,
                labelBuilder: (i) => i.toString(),
                hint: 'Select AQI threshold',
                onChanged: (v) => setState(() => _selectedThreshold = v),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subscribed (demo). Connect your backend later.'),
                      ),
                    );
                  },
                  child: const Text('Subscribe to Alerts'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alert Types',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _alertTypeTile(
                title: 'Daily Summary',
                subtitle: 'Daily AQI report at 8 AM',
                chipLabel: 'Email',
              ),
              const SizedBox(height: 10),
              _alertTypeTile(
                title: 'Threshold Alerts',
                subtitle: 'When AQI exceeds your limit',
                chipLabel: 'SMS + Email',
              ),
              const SizedBox(height: 10),
              _alertTypeTile(
                title: 'Health Warnings',
                subtitle: 'Critical air quality alerts',
                chipLabel: 'Push + SMS',
                danger: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // UI helpers -------------------------------------------------------

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _textField(TextEditingController c,
      {String? hint, TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required String hint,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(labelBuilder(e)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _alertTypeTile({
    required String title,
    required String subtitle,
    required String chipLabel,
    bool danger = false,
  }) {
    final chipColor = danger
        ? Colors.red.withOpacity(0.12)
        : Theme.of(context).colorScheme.primary.withOpacity(0.12);
    final chipTextColor = danger ? Colors.red : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipTextColor.withOpacity(0.25)),
            ),
            child: Text(chipLabel,
                style: TextStyle(
                    color: chipTextColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: child,
    );
  }
}
