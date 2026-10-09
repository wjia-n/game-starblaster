import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/starblaster_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/space_themes.dart';
import '../theme/space_ui.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu: logo, pilot callsign, PLAY, mode + difficulty setup,
/// theme picker, ship picker, tip jar / Pro, settings, share, review.
class MenuScreen extends StatefulWidget {
  final StarAudio audio;
  final StarSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StarStore _store = StarStore();

  StarSettings get _s => widget.settings;
  SpaceThemeDef get _t =>
      SpaceThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.powerup();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: SpaceType.body(15, _t)),
        backgroundColor: _t.bgMid,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.disposeStore();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _share() {
    SharePlus.instance.share(
      'I\'m blasting through the galaxy in Star Blaster! 🚀\n'
      'https://play.google.com/store/apps/details?id=com.gameswajiha.starblaster',
    );
  }

  void _play() {
    widget.audio.gameStart();
    final mode = BlastMode.values[_s.mode];
    final tuning = mode == BlastMode.attack
        ? TierTuning.cadet
        : mode == BlastMode.endless
            ? TierTuning.pilot
            : TierTuning.byIndex(_s.difficulty);
    final engine = StarBlasterEngine(mode: mode, tuning: tuning);
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
        store: _store,
      ),
    ))
        .then((_) {
      if (mounted) {
        widget.audio.startMenuMusic();
        setState(() {});
      }
    });
  }

  void _renamePilot() {
    final ctrl = TextEditingController(text: _s.pilotName);
    final focus = FocusNode();
    // Save on EVERY keystroke (never setStringList — one JSON string);
    // commit (trim) on focus loss and on Done.
    focus.addListener(() {
      if (!focus.hasFocus) _s.setPilotName(ctrl.text);
    });
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _t.card,
        title: Text('Pilot callsign', style: SpaceType.title(18, _t)),
        content: TextField(
          controller: ctrl,
          focusNode: focus,
          autofocus: true,
          maxLength: 16,
          textInputAction: TextInputAction.done,
          onChanged: (v) => _s.setPilotName(v),
          onSubmitted: (_) {
            _s.setPilotName(ctrl.text);
            Navigator.of(ctx).pop();
          },
          style: SpaceType.body(16, _t),
          decoration: InputDecoration(
            hintText: 'e.g. Nova',
            hintStyle: SpaceType.body(16, _t, color: _t.muted),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _t.accent)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _t.accent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: SpaceType.body(15, _t)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) {
                widget.audio.invalid();
                return;
              }
              widget.audio.click();
              _s.setPilotName(name);
              Navigator.of(ctx).pop();
            },
            child: Text('Save',
                style: SpaceType.body(15, _t, color: _t.accent)),
          ),
        ],
      ),
    ).then((_) {
      focus.dispose();
      ctrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return StarBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo plaque.
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/starblaster_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text('STAR BLASTER', style: SpaceType.display(36, t)),
                  const SizedBox(height: 4),
                  Text('DODGE THE SWARM · BLAST THE BOSSES',
                      style: SpaceType.label(11, t)),
                  const SizedBox(height: 14),
                  // Pilot callsign chip.
                  GestureDetector(
                    onTap: _renamePilot,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: t.accent.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 16, color: t.accent),
                          const SizedBox(width: 8),
                          Text('Pilot: ${_s.pilotName}',
                              style: SpaceType.body(15, t)),
                          const SizedBox(width: 6),
                          Icon(Icons.edit, size: 14, color: t.muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ChunkyButton(
                    label: '▶  LAUNCH',
                    fontSize: 22,
                    color: t.accent,
                    bevel: t.accentDark,
                    onTap: _play,
                  ),
                  SectionTitle('Mission', t),
                  _modeCards(t),
                  if (_s.mode == 0) ...[
                    SectionTitle('Difficulty', t),
                    _difficultyRow(t),
                  ],
                  SectionTitle('Paint Job (Theme)', t),
                  _themeGrid(t),
                  SectionTitle('Ship Style', t),
                  _shipGrid(t),
                  SectionTitle('More', t),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _MenuChip(
                        icon: Icons.brush,
                        label: 'Custom paint',
                        locked: !_s.isPro,
                        onTap: () {
                          widget.audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CustomThemeScreen(
                                audio: widget.audio, settings: _s),
                          ));
                        },
                      ),
                      _MenuChip(
                        icon: Icons.star,
                        label: _s.isPro ? 'PRO active' : 'Go PRO',
                        onTap: () {
                          widget.audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ProScreen(
                                audio: widget.audio,
                                settings: _s,
                                store: _store),
                          )).then((_) => setState(() {}));
                        },
                      ),
                      _MenuChip(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () {
                          widget.audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                                audio: widget.audio, settings: _s),
                          ));
                        },
                      ),
                      _MenuChip(
                        icon: Icons.share,
                        label: 'Share',
                        onTap: _share,
                      ),
                      _MenuChip(
                        icon: Icons.rate_review,
                        label: 'Rate',
                        onTap: _requestReview,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Best scores',
                      style: SpaceType.label(12, t)),
                  const SizedBox(height: 6),
                  _bestRow(t),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: SpaceType.label(12, t)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeCards(SpaceThemeDef t) {
    final modes = [
      ('Campaign', '10 waves · bosses at 5 & 10', Icons.rocket_launch, 0),
      ('Endless', 'Survive the infinite swarm', Icons.all_inclusive, 1),
      ('Score Attack', '150 seconds · max score', Icons.timer, 2),
    ];
    return Column(
      children: [
        for (final m in modes)
          GestureDetector(
            onTap: () {
              widget.audio.click();
              _s.setMode(m.$4);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _s.mode == m.$4 ? t.accent : t.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _s.mode == m.$4
                      ? t.accentDark
                      : t.accent.withValues(alpha: 0.35),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(m.$3,
                      color: _s.mode == m.$4 ? Colors.white : t.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.$1,
                            style: SpaceType.title(
                                16, t,
                                color: _s.mode == m.$4
                                    ? Colors.white
                                    : t.text)),
                        Text(m.$2,
                            style: SpaceType.body(
                                12, t,
                                color: _s.mode == m.$4
                                    ? Colors.white70
                                    : t.muted)),
                      ],
                    ),
                  ),
                  if (_s.mode == m.$4)
                    const Icon(Icons.check_circle,
                        color: Colors.white),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _difficultyRow(SpaceThemeDef t) {
    final tiers = [
      (TierTuning.cadet, 'Slower swarm · 4 ships'),
      (TierTuning.pilot, 'Classic pace · 3 ships'),
      (TierTuning.ace, 'Relentless · 2 ships'),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiers.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (i == 2 && !_s.isPro) {
                  widget.audio.invalid();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProScreen(
                        audio: widget.audio,
                        settings: _s,
                        store: _store),
                  ));
                  return;
                }
                widget.audio.click();
                _s.setDifficulty(i);
              },
              child: Container(
                margin: EdgeInsets.only(
                    right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _s.difficulty == i ? t.accent : t.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _s.difficulty == i
                        ? t.accentDark
                        : t.accent.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    if (i == 2 && !_s.isPro)
                      const ProBadge()
                    else
                      Text(tiers[i].$1.name,
                          style: SpaceType.title(
                              15, t,
                              color: _s.difficulty == i
                                  ? Colors.white
                                  : t.text)),
                    const SizedBox(height: 4),
                    Text(tiers[i].$2,
                        textAlign: TextAlign.center,
                        style: SpaceType.body(
                            11, t,
                            color: _s.difficulty == i
                                ? Colors.white70
                                : t.muted)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _themeGrid(SpaceThemeDef t) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: SpaceThemes.all.length + 1, // + custom paint
      itemBuilder: (ctx, i) {
        if (i == SpaceThemes.all.length) {
          final selected = _s.themeId == 'custom';
          final locked = !_s.isPro;
          return _Swatch(
            selected: selected,
            locked: locked,
            label: 'Custom',
            colors: [
              Color(_s.customColors['hull']!),
              Color(_s.customColors['accent']!),
              Color(_s.customColors['bgDeep']!),
            ],
            onTap: () {
              if (locked) {
                widget.audio.invalid();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProScreen(
                      audio: widget.audio,
                      settings: _s,
                      store: _store),
                ));
                return;
              }
              widget.audio.click();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CustomThemeScreen(
                    audio: widget.audio, settings: _s),
              ));
            },
          );
        }
        final th = SpaceThemes.all[i];
        final selected = _s.themeId == th.id;
        final locked = SpaceThemes.isProTheme(th.id) && !_s.isPro;
        return _Swatch(
          selected: selected,
          locked: locked,
          label: th.name,
          colors: [th.hull, th.accent, th.bgDeep],
          onTap: () {
            if (locked) {
              widget.audio.invalid();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProScreen(
                    audio: widget.audio,
                    settings: _s,
                    store: _store),
              ));
              return;
            }
            widget.audio.click();
            _s.setTheme(th.id);
          },
        );
      },
    );
  }

  Widget _shipGrid(SpaceThemeDef t) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: ShipStyles.count(),
      itemBuilder: (ctx, i) {
        final def = ShipStyles.all[i];
        final selected = _s.shipStyle == i;
        final locked = def.pro && !_s.isPro;
        return GestureDetector(
          onTap: () {
            if (locked) {
              widget.audio.invalid();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProScreen(
                    audio: widget.audio,
                    settings: _s,
                    store: _store),
              ));
              return;
            }
            widget.audio.click();
            _s.setShipStyle(i);
          },
          child: Container(
            decoration: BoxDecoration(
              color: selected ? t.accent : t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? t.accentDark
                    : t.accent.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  size: const Size(40, 40),
                  painter: _ShipThumbPainter(
                    styleIndex: i,
                    hull: selected ? Colors.white : t.hull,
                    cockpit: t.cockpit,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    def.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SpaceType.body(
                        10, t,
                        color: selected ? Colors.white : t.text),
                  ),
                ),
                if (locked)
                  const Icon(Icons.lock,
                      size: 12, color: Colors.white70),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bestRow(SpaceThemeDef t) {
    final entries = [
      ('Cadet', _s.bestScores['cadet'] ?? 0),
      ('Pilot', _s.bestScores['pilot'] ?? 0),
      ('Ace', _s.bestScores['ace'] ?? 0),
      ('Endless', _s.bestScores['endless'] ?? 0),
      ('Attack', _s.bestScores['attack'] ?? 0),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final e in entries)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.35)),
            ),
            child: Text('${e.$1}: ${e.$2}',
                style: SpaceType.body(12, t)),
          ),
      ],
    );
  }
}

class _MenuChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;
  const _MenuChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3352),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
            if (locked) ...[
              const SizedBox(width: 6),
              const ProBadge(),
            ],
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final bool selected;
  final bool locked;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const _Swatch({
    required this.selected,
    required this.locked,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A3352),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFE4572E)
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 3 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in colors)
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.black45, width: 1),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (locked)
              const Icon(Icons.lock,
                  size: 12, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

/// Tiny ship thumbnail painter (shares geometry with the game painter).
class _ShipThumbPainter extends CustomPainter {
  final int styleIndex;
  final Color hull;
  final Color cockpit;
  _ShipThumbPainter(
      {required this.styleIndex, required this.hull, required this.cockpit});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()..color = hull;
    switch (styleIndex) {
      case 1: // dart
        canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - 18)
              ..lineTo(c.dx - 8, c.dy + 16)
              ..lineTo(c.dx + 8, c.dy + 16)
              ..close(),
            p);
      case 2: // bulwark
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: c, width: 26, height: 34),
                const Radius.circular(8)),
            p);
        canvas.drawCircle(c + const Offset(0, -4), 6,
            Paint()..color = cockpit);
      case 3: // needle
        canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - 20)
              ..lineTo(c.dx - 5, c.dy + 18)
              ..lineTo(c.dx + 5, c.dy + 18)
              ..close(),
            p);
      case 4: // falcon
        canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - 18)
              ..lineTo(c.dx - 16, c.dy + 12)
              ..lineTo(c.dx - 6, c.dy + 8)
              ..lineTo(c.dx + 6, c.dy + 8)
              ..lineTo(c.dx + 16, c.dy + 12)
              ..close(),
            p);
      case 5: // mantis
        canvas.drawOval(
            Rect.fromCenter(center: c, width: 30, height: 24), p);
        canvas.drawCircle(c + const Offset(0, -6), 6,
            Paint()..color = cockpit);
      case 6: // titan
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: c, width: 32, height: 30),
                const Radius.circular(10)),
            p);
        canvas.drawCircle(c, 7, Paint()..color = cockpit);
      case 7: // comet
        canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - 16)
              ..quadraticBezierTo(
                  c.dx + 14, c.dy, c.dx, c.dy + 18)
              ..quadraticBezierTo(
                  c.dx - 14, c.dy, c.dx, c.dy - 16)
              ..close(),
            p);
      default: // classic rocket
        canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - 18)
              ..lineTo(c.dx - 11, c.dy + 10)
              ..lineTo(c.dx, c.dy + 5)
              ..lineTo(c.dx + 11, c.dy + 10)
              ..close(),
            p);
    }
    if (styleIndex != 2 && styleIndex != 5 && styleIndex != 6) {
      canvas.drawCircle(c + const Offset(0, -4), 5,
          Paint()..color = cockpit);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
