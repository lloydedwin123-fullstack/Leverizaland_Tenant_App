import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // bool _notifications = true; // Kept for UI state, but disabled

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Appearance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 12),
          Center(
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.settings_brightness),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: <ThemeMode>{themeService.themeMode},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                if (newSelection.isNotEmpty) {
                  themeService.setThemeMode(newSelection.first);
                }
              },
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.blueGrey.shade800,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const Text("Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          SwitchListTile(
            title: const Text("Enable Notifications"),
            subtitle: const Text("Feature coming soon"), // ✅ Added subtitle
            value: false, // Visually off
            onChanged: null, // ✅ Disabled
          ),
          const Divider(),
          const Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const ListTile(
            title: Text("Version"),
            trailing: Text("2.6 MVP"),
          ),
          const ListTile(
            title: Text("Developer"),
            trailing: Text("Leverizaland Software Devt."),
          ),
        ],
      ),
    );
  }
}
