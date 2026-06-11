import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.highContrast = false,
    this.voiceGender = 'female',
    this.speechSpeed = 1.0,
  });

  final ThemeMode themeMode;
  final bool highContrast;
  final String voiceGender;
  final double speechSpeed;

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? highContrast,
    String? voiceGender,
    double? speechSpeed,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      highContrast: highContrast ?? this.highContrast,
      voiceGender: voiceGender ?? this.voiceGender,
      speechSpeed: speechSpeed ?? this.speechSpeed,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      themeMode: ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.system.index],
      highContrast: prefs.getBool('highContrast') ?? false,
      voiceGender: prefs.getString('voiceGender') ?? 'female',
      speechSpeed: prefs.getDouble('speechSpeed') ?? 1.0,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    (await SharedPreferences.getInstance()).setInt('themeMode', mode.index);
  }

  Future<void> setHighContrast(bool value) async {
    state = state.copyWith(highContrast: value);
    (await SharedPreferences.getInstance()).setBool('highContrast', value);
  }

  Future<void> setVoiceGender(String gender) async {
    state = state.copyWith(voiceGender: gender);
    (await SharedPreferences.getInstance()).setString('voiceGender', gender);
  }

  Future<void> setSpeechSpeed(double speed) async {
    state = state.copyWith(speechSpeed: speed);
    (await SharedPreferences.getInstance()).setDouble('speechSpeed', speed);
  }
}
