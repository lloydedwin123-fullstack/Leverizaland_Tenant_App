import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Appearance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          SwitchListTile(
            title: const Text("Dark Mode"),
            subtitle: const Text("Reduce eye strain at night"),
            value: _darkMode,
            onChanged: (val) => setState(() => _darkMode = val),
          ),
          const Divider(),
          const Text("Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          SwitchListTile(
            title: const Text("Enable Notifications"),
            subtitle: const Text("Get alerts for expiring leases"),
            value: _notifications,
            onChanged: (val) => setState(() => _notifications = val),
          ),
          const Divider(),
          const Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const ListTile(
            title: Text("Version"),
            trailing: Text("0.2 MVP"),
          ),
          const ListTile(
            title: Text("Developer"),
            trailing: Text("Leverizaland Inc."),
          ),
        ],
      ),
    );
  }
}
