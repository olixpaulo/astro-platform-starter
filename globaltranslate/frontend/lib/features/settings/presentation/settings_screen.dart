import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user.fullName.isEmpty ? user.email : user.fullName),
              subtitle: Text(user.email),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Plano Premium'),
            subtitle: const Text('Traduções ilimitadas, vozes premium, sem anúncios'),
            onTap: () => context.push('/premium'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Pacotes offline'),
            onTap: () => context.push('/offline'),
          ),
          const Divider(),
          const _SectionHeader('Aparência'),
          RadioListTile<ThemeMode>(
            title: const Text('Sistema'),
            value: ThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (mode) => notifier.setThemeMode(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Claro'),
            value: ThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (mode) => notifier.setThemeMode(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Escuro (Dark Mode)'),
            value: ThemeMode.dark,
            groupValue: settings.themeMode,
            onChanged: (mode) => notifier.setThemeMode(mode!),
          ),
          SwitchListTile(
            title: const Text('Alto contraste'),
            subtitle: const Text('Melhora a legibilidade'),
            value: settings.highContrast,
            onChanged: notifier.setHighContrast,
          ),
          const Divider(),
          const _SectionHeader('Voz e pronúncia'),
          ListTile(
            title: const Text('Voz'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'female', label: Text('Feminina')),
                ButtonSegment(value: 'male', label: Text('Masculina')),
              ],
              selected: {settings.voiceGender},
              onSelectionChanged: (selection) => notifier.setVoiceGender(selection.first),
            ),
          ),
          ListTile(
            title: Text('Velocidade da fala: ${settings.speechSpeed.toStringAsFixed(2)}x'),
            subtitle: Slider(
              value: settings.speechSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: '${settings.speechSpeed.toStringAsFixed(2)}x',
              onChanged: notifier.setSpeechSpeed,
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Terminar sessão', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
