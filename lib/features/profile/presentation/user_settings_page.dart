import 'package:flutter/material.dart';
import 'package:moksharide_user/core/theme/theme_notifier.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  bool _pushNotifications = true;
  

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = ThemeNotifier.themeMode.value == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader("Preferences"),
          _buildSwitchTile(
            title: "Push Notifications",
            subtitle: "Receive ride updates and alerts",
            icon: Icons.notifications_active_outlined,
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
          ),
          _buildSwitchTile(
            title: "Dark Mode",
            subtitle: "Switch to dark theme",
            icon: Icons.dark_mode_outlined,
            value: isDarkMode,
            onChanged: (val) => setState(() => ThemeNotifier.toggleTheme(val)),
          ),
          
          const SizedBox(height: 20),
          _buildSectionHeader("Legal & About"),
          _buildListTile(Icons.privacy_tip_outlined, "Privacy Policy"),
          _buildListTile(Icons.description_outlined, "Terms of Service"),
          _buildListTile(Icons.help_outline, "Help & Support"),
          
          const SizedBox(height: 40),
          const Center(
            child: Text(
              "MokshaRide v1.0.0",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10, top: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          // TODO: Add Navigation to webviews or internal pages
        },
      ),
    );
  }
}