import 'package:flutter/material.dart';
import 'package:moksharide_user/core/theme/theme_notifier.dart';
import 'package:moksharide_user/features/profile/presentation/WebPageScreen.dart';

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
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [

          /// ------------------ PREFERENCES ------------------
          _sectionTitle("Preferences"),

          _buildSwitchTile(
            title: "Push Notifications",
            subtitle: "Receive ride updates and alerts",
            icon: Icons.notifications_active_outlined,
            value: _pushNotifications,
            onChanged: (val) {
              setState(() => _pushNotifications = val);
            },
          ),

          _buildSwitchTile(
            title: "Dark Mode",
            subtitle: "Switch between light and dark theme",
            icon: Icons.dark_mode_outlined,
            value: isDarkMode,
            onChanged: (val) {
              setState(() {
                ThemeNotifier.toggleTheme(val);
              });
            },
          ),

          const SizedBox(height: 24),

          /// ------------------ LEGAL ------------------
          _sectionTitle("Legal & About"),

          _buildListTile(
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WebPageScreen(
                    title: "Privacy Policy",
                    url: "https://www.privacypolicies.com/live/yourpolicy",
                  ),
                ),
              );
            },
          ),

          _buildListTile(
            icon: Icons.description_outlined,
            title: "Terms of Service",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WebPageScreen(
                    title: "Terms of Service",
                    url: "https://www.privacypolicies.com/live/yourpolicy",
                  ),
                ),
              );
            },
          ),

          _buildListTile(
            icon: Icons.support_agent_outlined,
            title: "Help & Support",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WebPageScreen(
                    title: "Help & Support",
                    url: "https://www.privacypolicies.com/live/yourpolicy",
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          /// APP VERSION
          Center(
            child: Text(
              "MokshaRide v1.0.0",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------ SECTION TITLE ------------------

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// ------------------ SWITCH TILE ------------------

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        secondary: _iconBox(icon),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  /// ------------------ LIST TILE ------------------

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: _iconBox(icon),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  /// ------------------ ICON BOX ------------------

  Widget _iconBox(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}


