import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/space_themes.dart';
import '../theme/space_ui.dart';

/// Settings: audio toggles + volume, pilot callsign, stats, credits.
class SettingsScreen extends StatelessWidget {
  final StarAudio audio;
  final StarSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  SpaceThemeDef get _t =>
      SpaceThemes.byId(settings.themeId, custom: settings.customTheme);

  void _applyAudio() {
    audio.configure(
      musicOn: settings.musicOn,
      sfxOn: settings.sfxOn,
      volume: settings.volume,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return StarBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: t.text),
          title: Text('Settings', style: SpaceType.title(20, t)),
        ),
        body: ListenableBuilder(
          listenable: settings,
          builder: (_, _) => ListView(
            padding: const EdgeInsets.all(22),
            children: [
              SectionTitle('Audio', t),
              _ToggleRow(
                label: 'Music',
                value: settings.musicOn,
                theme: t,
                onChanged: (v) {
                  audio.click();
                  settings.setMusic(v);
                  _applyAudio();
                  if (v) audio.startMenuMusic();
                },
              ),
              _ToggleRow(
                label: 'Sound effects',
                value: settings.sfxOn,
                theme: t,
                onChanged: (v) {
                  settings.setSfx(v);
                  _applyAudio();
                  audio.click();
                },
              ),
              const SizedBox(height: 6),
              Text('Volume', style: SpaceType.body(15, t)),
              Slider(
                value: settings.volume,
                activeColor: t.accent,
                inactiveColor: t.card,
                onChanged: (v) {
                  settings.setVolume(v);
                  _applyAudio();
                },
                onChangeEnd: (_) => audio.click(),
              ),
              SectionTitle('Pilot', t),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Callsign',
                    style: SpaceType.body(15, t)),
                subtitle: Text(settings.pilotName,
                    style: SpaceType.body(13, t,
                        color: t.muted)),
                trailing: Icon(Icons.edit, color: t.accent),
                onTap: () {
                  audio.click();
                  _rename(context);
                },
              ),
              SectionTitle('Stats', t),
              _StatRow('Games played', '${settings.gamesPlayed}', t),
              _StatRow('Victories', '${settings.victories}', t),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    audio.invalid();
                    _confirmReset(context);
                  },
                  child: Text('Reset stats',
                      style: SpaceType.body(14, t,
                          color: const Color(0xFFE07A5F))),
                ),
              ),
              SectionTitle('About', t),
              Text(
                'Star Blaster — a toy-box space adventure.\nDodge the swarm, blast the bosses, own the galaxy!',
                style:
                    SpaceType.body(14, t, color: t.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Image.asset('assets/wajiha_logo.png',
                      width: 26, height: 26, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Text('Credits: WAJIHA',
                      style: SpaceType.label(13, t)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Version 2.0.0',
                  style:
                      SpaceType.body(12, t, color: t.muted)),
            ],
          ),
        ),
      ),
    );
  }

  void _rename(BuildContext context) {
    final t = _t;
    final ctrl = TextEditingController(text: settings.pilotName);
    final focus = FocusNode();
    // Save on EVERY keystroke (never setStringList — one JSON string);
    // commit (trim) on focus loss and on Done.
    focus.addListener(() {
      if (!focus.hasFocus) settings.setPilotName(ctrl.text);
    });
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Pilot callsign', style: SpaceType.title(18, t)),
        content: TextField(
          controller: ctrl,
          focusNode: focus,
          autofocus: true,
          maxLength: 16,
          textInputAction: TextInputAction.done,
          onChanged: (v) => settings.setPilotName(v),
          onSubmitted: (_) {
            settings.setPilotName(ctrl.text);
            Navigator.of(ctx).pop();
          },
          style: SpaceType.body(16, t),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: t.accent)),
            focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: t.accent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: SpaceType.body(15, t)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) {
                audio.invalid();
                return;
              }
              audio.click();
              settings.setPilotName(name);
              Navigator.of(ctx).pop();
            },
            child: Text('Save',
                style:
                    SpaceType.body(15, t, color: t.accent)),
          ),
        ],
      ),
    ).then((_) {
      focus.dispose();
      ctrl.dispose();
    });
  }

  void _confirmReset(BuildContext context) {
    final t = _t;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title:
            Text('Reset all stats?', style: SpaceType.title(18, t)),
        content: Text('Best scores and victories go back to zero.',
            style: SpaceType.body(14, t)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Keep them', style: SpaceType.body(15, t)),
          ),
          TextButton(
            onPressed: () {
              audio.click();
              settings.resetStats();
              Navigator.of(ctx).pop();
            },
            child: Text('Reset',
                style: SpaceType.body(15, t,
                    color: const Color(0xFFE07A5F))),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final SpaceThemeDef theme;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: SpaceType.body(15, theme))),
        Switch(
          value: value,
          activeThumbColor: theme.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final SpaceThemeDef theme;
  const _StatRow(this.label, this.value, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: SpaceType.body(14, theme,
                      color: theme.muted))),
          Text(value,
              style: SpaceType.title(16, theme)),
        ],
      ),
    );
  }
}
