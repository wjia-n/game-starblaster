import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/space_themes.dart';
import '../theme/space_ui.dart';
import 'menu_screen.dart';

/// Launch splash, two beats:
/// 1. Company moment — the official WAJIHA winged-W logo, unchanged.
/// 2. Game splash — game logo + name, animated loading line, Credits: WAJIHA.
/// Audio is pre-warmed and menu music starts under the splash.
class SplashScreen extends StatefulWidget {
  final StarAudio audio;
  final StarSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  int _stage = 0; // 0 = company moment, 1 = game splash

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Beat 1: company moment.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _stage = 1);
    // Beat 2: game splash with the loading line.
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SpaceThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.bgDeep,
      body: StarBackdrop(
        theme: theme,
        child: Center(
          child: _stage == 0 ? _companyMoment(theme) : _gameSplash(theme),
        ),
      ),
    );
  }

  Widget _companyMoment(SpaceThemeDef theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/wajiha_logo.png',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 18),
        Text('WAJIHA', style: SpaceType.display(34, theme)),
        const SizedBox(height: 6),
        Text('PRESENTS', style: SpaceType.label(12, theme)),
      ],
    );
  }

  Widget _gameSplash(SpaceThemeDef theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.accent, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/starblaster_logo.png',
              fit: BoxFit.cover),
        ),
        const SizedBox(height: 22),
        Text('STAR BLASTER',
            style: SpaceType.display(44, theme)),
        const SizedBox(height: 6),
        Text(
          'A TOY-BOX SPACE ADVENTURE',
          style: SpaceType.label(13, theme),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: 220,
          child: AnimatedBuilder(
            animation: _loader,
            builder: (_, _) => Column(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.black.withValues(alpha: 0.45),
                    border: Border.all(
                        color:
                            theme.accent.withValues(alpha: 0.5)),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loader.value.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: theme.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _loader.value < 1
                      ? 'Fueling the rockets…'
                      : 'Ready!',
                  style: SpaceType.body(13, theme,
                      color:
                          theme.text.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 44),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/wajiha_logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              'Credits: WAJIHA',
              style: SpaceType.label(14, theme),
            ),
          ],
        ),
      ],
    );
  }
}
