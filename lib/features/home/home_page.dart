import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KleiHon',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories_rounded, size: 75, color: AppTheme.seed),
            SizedBox(height: 20),
            Text(
              'Welcome to KleiHon',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your little world of stories.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}