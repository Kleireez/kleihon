import 'package:material_ui/material_ui.dart';

/// PLACEHOLDER sementara. Dipakai sampai fitur aslinya dibangun.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    this.note,
    this.actions = const [],
  });

  final String title;
  final String? note;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PLACEHOLDER: belum diimplementasikan',
                style: TextStyle(color: Colors.white60),
              ),
              if (note != null) ...[
                const SizedBox(height: 8),
                Text(note!, textAlign: TextAlign.center),
              ],
              for (final action in actions) ...[
                const SizedBox(height: 16),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
