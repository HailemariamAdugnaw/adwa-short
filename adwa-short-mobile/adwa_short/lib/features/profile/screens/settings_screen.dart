import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _language = 'English';
  bool _notifications = true;
  String _videoQuality = 'Auto';
  bool _autoPlayNext = true;
  bool _dataSaver = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _section('Playback'),
            _switchTile(
              icon: Icons.play_circle_outline_rounded,
              title: 'Auto-play next episode',
              value: _autoPlayNext,
              onChanged: (v) => setState(() => _autoPlayNext = v),
            ),
            _dropdownTile(
              icon: Icons.hd_outlined,
              title: 'Video quality',
              value: _videoQuality,
              options: const ['Auto', 'Low', 'Medium', 'High', 'HD'],
              onChanged: (v) => setState(() => _videoQuality = v ?? 'Auto'),
            ),
            _switchTile(
              icon: Icons.data_saver_on_rounded,
              title: 'Data Saver',
              subtitle: 'Reduce data usage on cellular',
              value: _dataSaver,
              onChanged: (v) => setState(() => _dataSaver = v),
            ),
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
            _section('General'),
            _dropdownTile(
              icon: Icons.language_rounded,
              title: 'Language',
              value: _language,
              options: const ['English', 'አማርኛ', 'Afaan Oromoo', 'Tigrinya'],
              onChanged: (v) => setState(() => _language = v ?? 'English'),
            ),
            _switchTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'New episodes, rewards & promos',
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
            ),
            _actionTile(
              icon: Icons.cleaning_services_outlined,
              title: 'Clear cache',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache cleared'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
            _section('About'),
            _actionTile(
              icon: Icons.info_outline_rounded,
              title: 'About ADWA SHORT',
              subtitle: 'Version 1.0.0',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'ADWA SHORT',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© ADWA SHORT. All rights reserved.',
                );
              },
            ),
            _actionTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () {

              },
            ),
            _actionTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () {

              },
            ),
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
            const SizedBox(height: 8),
            _logoutTile(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.overline.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.body1),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTextStyles.body3)
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.bloodRed,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _dropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.body1),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: AppColors.surfaceElevated,
        underline: const SizedBox(),
        style: AppTextStyles.body2.copyWith(color: AppColors.textPrimary),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.body1),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTextStyles.body3)
          : null,
      trailing:
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _logoutTile() {
    return ListTile(
      leading: const Icon(Icons.logout_rounded, color: AppColors.bloodRed),
      title: Text('Log Out',
          style: AppTextStyles.label.copyWith(color: AppColors.bloodRed)),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Log out?', style: AppTextStyles.h3),
            content: Text(
              'Are you sure you want to log out?',
              style: AppTextStyles.body2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bloodRed,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Log Out'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await context.read<AuthProvider>().logout();
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (_) => false);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
