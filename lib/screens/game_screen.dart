import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/starblaster_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/space_themes.dart';
import '../theme/space_ui.dart';

/// Game screen: renders the engine, forwards drag input, drains the engine's
/// SFX queue into StarAudio. The engine owns ALL phase transitions; this
/// screen never invents state.
class GameScreen extends StatefulWidget {
  final StarBlasterEngine engine;
  final StarAudio audio;
  final StarSettings settings;
  final StarStore store;
  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _endHandled = false;

  StarBlasterEngine get _e => widget.engine;
  SpaceThemeDef get _t =>
      SpaceThemes.byId(widget.settings.themeId, custom: widget.settings.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.attach();
    _e.addListener(_onEngineEvent);
    widget.audio.startGameMusic();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _e.removeListener(_onEngineEvent);
    _e.detach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the engine when the app is interrupted — never lose a run to a
    // phone call. Audio pause/resume is handled app-wide in main.dart.
    if (state == AppLifecycleState.paused) {
      _e.pause();
    }
  }

  void _onEngineEvent() {
    // Discrete engine events (phase changes, score popups, hits): end-of-game
    // handling and HUD refreshes.
    if (!mounted) return;
    if ((_e.phase == GamePhase.gameOver ||
            _e.phase == GamePhase.victory) &&
        !_endHandled) {
      _endHandled = true;
      _onGameEnd();
    }
    setState(() {});
  }

  void _tick(Duration now) {
    if (_last == Duration.zero) {
      _last = now;
      return;
    }
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = now;
    _e.tick(dt);
    // Drain the engine's SFX queue into the audio service.
    if (_e.sfxQueue.isNotEmpty) {
      for (final name in _e.sfxQueue) {
        _playSfx(name);
      }
      _e.sfxQueue.clear();
    }
    if (mounted) setState(() {});
  }

  void _playSfx(String name) {
    final a = widget.audio;
    switch (name) {
      case 'laser':
        a.laser();
      case 'enemyLaser':
        a.enemyLaser();
      case 'explodeSmall':
        a.explodeSmall();
      case 'explodeBig':
        a.explodeBig();
      case 'powerup':
        a.powerup();
      case 'hit':
        a.hit();
      case 'waveClear':
        a.waveClear();
      case 'bossAlarm':
        a.bossAlarm();
      case 'gameStart':
        a.gameStart();
      case 'win':
        a.win();
      case 'lose':
        a.lose();
      case 'waveStart':
        a.click();
    }
  }

  String _modeKey() {
    return switch (_e.mode) {
      BlastMode.campaign => _e.tuning.key,
      BlastMode.endless => 'endless',
      BlastMode.attack => 'attack',
    };
  }

  Future<void> _onGameEnd() async {
    final won = _e.phase == GamePhase.victory;
    await widget.settings.recordGame(
      modeKey: _modeKey(),
      score: _e.score,
      won: won,
    );
    // Sensible review moment: after the pilot's 3rd finished game, once.
    if (widget.settings.gamesPlayed >= 3 && !widget.settings.reviewAsked) {
      await widget.settings.setReviewAsked();
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final best = widget.settings.bestScores[_modeKey()] ?? 0;
    final isBest = _e.score >= best && _e.score > 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EndDialog(
        won: won,
        byTimeout: _e.wonByTimeout,
        score: _e.score,
        wave: _e.wave,
        kills: _e.kills,
        best: best,
        isBest: isBest,
        pilot: widget.settings.pilotName,
        theme: _t,
        onRetry: () {
          Navigator.of(ctx).pop();
          _retry();
        },
        onMenu: () => Navigator.of(ctx).pop(),
        onShare: _shareScore,
      ),
    );
  }

  void _retry() {
    setState(() {
      _endHandled = false;
      _last = Duration.zero;
    });
    _e.startGame();
  }

  void _shareScore() {
    SharePlus.instance.share(
      ShareParams(
        text: 'I scored ${_e.score} in Star Blaster! 🚀 Can you beat me?\n'
            'https://play.google.com/store/apps/details?id=com.gameswajiha.starblaster',
      ),
    );
  }

  void _showPauseMenu() {
    // Nothing to pause before launch, after the run ends, or when already
    // paused — only live combat phases are pausable.
    if (_e.phase != GamePhase.playing &&
        _e.phase != GamePhase.intro &&
        _e.phase != GamePhase.waveClear &&
        _e.phase != GamePhase.bossWarn) return;
    _e.pause();
    widget.audio.click();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _t.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PAUSED', style: SpaceType.display(30, _t)),
              const SizedBox(height: 8),
              Text('The swarm waits for no pilot… except now.',
                  style: SpaceType.body(13, _t, color: _t.muted)),
              const SizedBox(height: 20),
              ChunkyButton(
                label: '▶  RESUME',
                color: _t.accent,
                bevel: _t.accentDark,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(ctx).pop();
                  _e.resume();
                },
              ),
              const SizedBox(height: 10),
              ChunkyButton(
                label: '↻  RESTART',
                color: _t.card,
                bevel: Colors.black54,
                fontSize: 15,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(ctx).pop();
                  _retry();
                },
              ),
              const SizedBox(height: 10),
              ChunkyButton(
                label: '🏠  QUIT TO MENU',
                color: _t.card,
                bevel: Colors.black54,
                fontSize: 15,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final e = _e;
    final boss = e.enemies.where((x) => x.kind == EnemyKind.boss).firstOrNull;
    final bossMax = boss != null ? boss.maxHp : 1;
    return StarBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // HUD
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    ChunkyIconButton(
                      icon: Icons.pause,
                      theme: t,
                      size: 42,
                      onTap: _showPauseMenu,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.mode == BlastMode.attack
                                ? '⏱ ${_e.attackT.ceil()}s'
                                : e.mode == BlastMode.endless
                                    ? 'WAVE ${e.wave} · ENDLESS'
                                    : 'WAVE ${e.wave} / 10',
                            style: SpaceType.title(16, t),
                          ),
                          Text(
                            'SCORE ${e.score}',
                            style: SpaceType.body(13, t,
                                color: t.accent),
                          ),
                        ],
                      ),
                    ),
                    if (e.combo > 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('COMBO x${e.combo}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '🚀' * e.lives.clamp(0, 5),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              if (boss != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text('VOID MAULER',
                          style: SpaceType.label(11, t)),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (boss.hp / bossMax).clamp(0.0, 1.0),
                          backgroundColor: Colors.black45,
                          color: t.enemyBoss,
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              // Play field
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    e.ensureShip(size);
                    return GestureDetector(
                      onPanUpdate: (d) => e.moveShip(d.delta),
                      onTap: () {
                        if (e.phase == GamePhase.ready) {
                          e.startGame();
                        }
                      },
                      child: CustomPaint(
                        painter: _SpacePainter(
                          e: e,
                          theme: t,
                          shipStyle: widget.settings.shipStyle,
                        ),
                        size: Size.infinite,
                      ),
                    );
                  },
                ),
              ),
              // Power-up status strip
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _statusText(),
                  style: SpaceType.body(13, t, color: t.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText() {
    final e = _e;
    if (e.phase == GamePhase.ready) {
      return 'Tap the starfield or press LAUNCH to take off!';
    }
    final bits = [
      if (e.spreadT > 0) '🔱 spread ${e.spreadT.ceil()}s',
      if (e.rapidT > 0) '⚡ rapid ${e.rapidT.ceil()}s',
      if (e.shield) '🛡 shield ${e.shieldT.ceil()}s',
    ];
    if (bits.isEmpty) {
      return e.phase == GamePhase.paused
          ? 'Paused'
          : 'Drag to fly — guns blaze on their own!';
    }
    return bits.join('   ');
  }
}

class _EndDialog extends StatelessWidget {
  final bool won;
  final bool byTimeout;
  final int score;
  final int wave;
  final int kills;
  final int best;
  final bool isBest;
  final String pilot;
  final SpaceThemeDef theme;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final VoidCallback onShare;

  const _EndDialog({
    required this.won,
    required this.byTimeout,
    required this.score,
    required this.wave,
    required this.kills,
    required this.best,
    required this.isBest,
    required this.pilot,
    required this.theme,
    required this.onRetry,
    required this.onMenu,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final headline = won
        ? (byTimeout ? 'TIME UP!' : 'GALAXY SAVED!')
        : 'SHIP DOWN!';
    final sub = won
        ? (byTimeout
            ? '$pilot held the line for the full attack run.'
            : '$pilot destroyed the Void Mauler. Legendary!')
        : '$pilot fought bravely to wave $wave. The stars await your return.';
    return Dialog(
      backgroundColor: theme.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(won ? '🏆' : '💥',
                style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(headline,
                style: SpaceType.display(30, theme)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style:
                    SpaceType.body(14, theme, color: theme.muted)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat('SCORE', '$score', theme),
                const SizedBox(width: 18),
                _Stat('WAVE', '$wave', theme),
                const SizedBox(width: 18),
                _Stat('KILLS', '$kills', theme),
              ],
            ),
            const SizedBox(height: 10),
            if (isBest)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('★ NEW BEST! ★',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900)),
              )
            else
              Text('Best: $best',
                  style:
                      SpaceType.body(13, theme, color: theme.muted)),
            const SizedBox(height: 20),
            ChunkyButton(
              label: won ? '↻  FLY AGAIN' : '↻  RETRY',
              color: theme.accent,
              bevel: theme.accentDark,
              onTap: onRetry,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onShare,
                  icon: Icon(Icons.share, color: theme.accent),
                  label: Text('Share score',
                      style: SpaceType.body(14, theme)),
                ),
                TextButton(
                  onPressed: onMenu,
                  child: Text('Menu',
                      style: SpaceType.body(14, theme)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final SpaceThemeDef theme;
  const _Stat(this.label, this.value, this.theme);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: SpaceType.label(11, theme)),
        Text(value, style: SpaceType.display(24, theme)),
      ],
    );
  }
}

// ---------------------------------------------------------------- painter
/// Toy-like physical renderer: chunky painted ships with bevels and shine,
/// soft round enemies, warm particles. No neon, no holograms.
class _SpacePainter extends CustomPainter {
  final StarBlasterEngine e;
  final SpaceThemeDef theme;
  final int shipStyle;

  _SpacePainter({
    required this.e,
    required this.theme,
    required this.shipStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Screen shake on hits / boss kills.
    if (e.shakeT > 0) {
      final m = e.shakeT * 22;
      canvas.translate(
        (e.starT * 91 % 1 - 0.5) * 2 * m,
        (e.starT * 57 % 1 - 0.5) * 2 * m,
      );
    }

    // Starfield.
    final sp = Paint();
    for (var i = 0; i < e.stars.length; i++) {
      final s = e.stars[i];
      final y = (s.y + e.starT * s.speed) % size.height;
      sp.color = Colors.white.withValues(alpha: 0.35 + (i % 4) * 0.12);
      canvas.drawCircle(Offset(s.x, y), 0.8 + (i % 3) * 0.7, sp);
    }

    _paintPowerups(canvas);
    _paintEnemies(canvas);
    _paintBullets(canvas);
    _paintParticles(canvas);
    _paintPopups(canvas);
    _paintShip(canvas);

    // Hit flash.
    if (e.flashT > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.red.withValues(alpha: e.flashT * 1.4),
      );
    }

    // Banner.
    if (e.bannerT > 0 && e.banner.isNotEmpty) {
      final scale = (1 + (1 - (e.bannerT / 2.0).clamp(0.0, 1.0)) * 0.12)
          .clamp(1.0, 1.15);
      final tp = TextPainter(
        text: TextSpan(
          text: e.banner,
          style: TextStyle(
            color: theme.text,
            fontWeight: FontWeight.w900,
            fontSize: 26 * scale,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  offset: const Offset(0, 3),
                  blurRadius: 8),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, size.height * 0.38));
    }

    // Ready overlay: big LAUNCH prompt.
    if (e.phase == GamePhase.ready) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'TAP TO LAUNCH',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 30,
            letterSpacing: 2,
            shadows: [
              Shadow(
                  color: Colors.black,
                  offset: Offset(0, 3),
                  blurRadius: 8),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pulse = 1 + 0.06 * sin(e.starT * 3);
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.42);
      canvas.scale(pulse);
      canvas.translate(-tp.width / 2, -tp.height / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  void _paintPowerups(Canvas canvas) {
    const cols = {
      PowerKind.spread: Color(0xFF7CB350),
      PowerKind.shield: Color(0xFF7FB8D9),
      PowerKind.rapid: Color(0xFFF2A541),
      PowerKind.life: Color(0xFFE4572E),
    };
    const glyph = {
      PowerKind.spread: 'S',
      PowerKind.shield: 'O',
      PowerKind.rapid: 'R',
      PowerKind.life: '+',
    };
    for (final p in e.powers) {
      final bob = 3 * sin(p.t * 4);
      final pos = p.pos + Offset(0, bob);
      // Chunky capsule: dark rim, colored body, white glyph.
      canvas.drawCircle(pos, 16, Paint()..color = Colors.black45);
      canvas.drawCircle(pos, 14, Paint()..color = cols[p.kind]!);
      canvas.drawCircle(
          pos + const Offset(-4, -4), 5, Paint()..color = Colors.white38);
      final tp = TextPainter(
        text: TextSpan(
            text: glyph[p.kind],
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintEnemies(Canvas canvas) {
    for (final en in e.enemies) {
      switch (en.kind) {
        case EnemyKind.dart:
          _dart(canvas, en.pos, theme.enemyA);
        case EnemyKind.weaver:
          _weaver(canvas, en.pos, theme.enemyA);
        case EnemyKind.tank:
          _tank(canvas, en.pos, theme.enemyB, en.hp);
        case EnemyKind.gunner:
          _gunner(canvas, en.pos, theme.enemyB);
        case EnemyKind.boss:
          _boss(canvas, en.pos, theme.enemyBoss, en.t);
      }
    }
  }

  void _dart(Canvas canvas, Offset pos, Color c) {
    final dark = _darken(c, 0.35);
    final path = Path()
      ..moveTo(pos.dx, pos.dy + 17)
      ..lineTo(pos.dx - 13, pos.dy - 11)
      ..lineTo(pos.dx + 13, pos.dy - 11)
      ..close();
    canvas.drawPath(path, Paint()..color = dark);
    canvas.drawPath(
        Path()
          ..moveTo(pos.dx, pos.dy + 13)
          ..lineTo(pos.dx - 10, pos.dy - 9)
          ..lineTo(pos.dx + 10, pos.dy - 9)
          ..close(),
        Paint()..color = c);
    canvas.drawCircle(pos + const Offset(0, -2), 4,
        Paint()..color = const Color(0xFFFFD166));
  }

  void _weaver(Canvas canvas, Offset pos, Color c) {
    final dark = _darken(c, 0.35);
    final path = Path()
      ..moveTo(pos.dx, pos.dy + 15)
      ..lineTo(pos.dx + 14, pos.dy)
      ..lineTo(pos.dx, pos.dy - 15)
      ..lineTo(pos.dx - 14, pos.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = dark);
    final inner = Path()
      ..moveTo(pos.dx, pos.dy + 10)
      ..lineTo(pos.dx + 9, pos.dy)
      ..lineTo(pos.dx, pos.dy - 10)
      ..lineTo(pos.dx - 9, pos.dy)
      ..close();
    canvas.drawPath(inner, Paint()..color = c);
    canvas.drawCircle(pos, 3.5, Paint()..color = Colors.white70);
  }

  void _tank(Canvas canvas, Offset pos, Color c, int hp) {
    final dark = _darken(c, 0.4);
    canvas.drawCircle(pos + const Offset(0, 2), 22, Paint()..color = dark);
    canvas.drawCircle(pos, 20, Paint()..color = c);
    canvas.drawCircle(pos + const Offset(-6, -6), 7,
        Paint()..color = Colors.white.withValues(alpha: 0.25));
    canvas.drawCircle(pos, 9, Paint()..color = dark);
    // HP pips.
    for (var i = 0; i < hp.clamp(0, 5); i++) {
      canvas.drawCircle(
          pos + Offset(-12 + i * 6, -30),
          2.5,
          Paint()..color = const Color(0xFFFFD166));
    }
  }

  void _gunner(Canvas canvas, Offset pos, Color c) {
    final dark = _darken(c, 0.4);
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: 44, height: 26),
        const Radius.circular(10));
    canvas.drawRRect(body.shift(const Offset(0, 2)),
        Paint()..color = dark);
    canvas.drawRRect(body, Paint()..color = c);
    // Twin cannons.
    for (final dx in [-10.0, 10.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: pos + Offset(dx, 16), width: 8, height: 14),
              const Radius.circular(3)),
          Paint()..color = dark);
    }
    canvas.drawCircle(pos + const Offset(0, -4), 5,
        Paint()..color = const Color(0xFFFFD166));
  }

  void _boss(Canvas canvas, Offset pos, Color c, double t) {
    final dark = _darken(c, 0.45);
    final wobble = 3 * sin(t * 2);
    final p = pos + Offset(0, wobble);
    final path = Path()
      ..moveTo(p.dx, p.dy + 48)
      ..lineTo(p.dx - 44, p.dy - 22)
      ..lineTo(p.dx - 20, p.dy - 38)
      ..lineTo(p.dx + 20, p.dy - 38)
      ..lineTo(p.dx + 44, p.dy - 22)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 4)), Paint()..color = dark);
    canvas.drawPath(path, Paint()..color = c);
    // Armor plates.
    for (final dx in [-26.0, 0.0, 26.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: p + Offset(dx, -18), width: 16, height: 22),
              const Radius.circular(5)),
          Paint()..color = dark);
    }
    // Glowing core (warm, not neon).
    canvas.drawCircle(p + const Offset(0, -6), 13,
        Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(p + const Offset(0, -6), 7,
        Paint()..color = const Color(0xFFE4572E));
  }

  Color _darken(Color c, double amt) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amt).clamp(0.0, 1.0)).toColor();
  }

  void _paintBullets(Canvas canvas) {
    final bp = Paint()..color = theme.bullet;
    for (final b in e.bullets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: b.pos, width: 6, height: 18),
            const Radius.circular(3)),
        bp,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: b.pos + const Offset(0, -4), width: 3, height: 8),
            const Radius.circular(1.5)),
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }
    for (final b in e.ebullets) {
      canvas.drawCircle(b.pos + const Offset(0, 1), 8,
          Paint()..color = Colors.black45);
      canvas.drawCircle(b.pos, 7, Paint()..color = const Color(0xFFE4572E));
      canvas.drawCircle(b.pos, 3.5, Paint()..color = Colors.white);
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final p in e.parts) {
      final k = (1 - p.t / p.life).clamp(0.0, 1.0);
      canvas.drawCircle(
          p.pos,
          p.size * k,
          Paint()..color = p.color.withValues(alpha: k));
    }
  }

  void _paintPopups(Canvas canvas) {
    for (final p in e.popups) {
      final k = (1 - p.t / 0.9).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: k),
            fontWeight: FontWeight.w900,
            fontSize: 17,
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.7 * k),
                  offset: const Offset(0, 2),
                  blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p.pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintShip(Canvas canvas) {
    if (e.ship == Offset.zero) return;
    // Invulnerability blink.
    if (e.invulnT > 0 && (e.starT * 12).floor().isEven) return;
    final pos = e.ship;
    final hull = theme.hull;
    final dark = _darken(hull, 0.35);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(e.shipTilt * 0.28);

    // Engine flame.
    final flame = 12 + 7 * sin(e.starT * 30);
    final fp = Path()
      ..moveTo(-7, 14)
      ..lineTo(0, 14 + flame)
      ..lineTo(7, 14)
      ..close();
    canvas.drawPath(fp, Paint()..color = const Color(0xFFF2A541));
    final fp2 = Path()
      ..moveTo(-4, 14)
      ..lineTo(0, 14 + flame * 0.55)
      ..lineTo(4, 14)
      ..close();
    canvas.drawPath(fp2, Paint()..color = const Color(0xFFFFD166));

    _paintShipBody(canvas, hull, dark, theme.cockpit);

    canvas.restore();

    // Shield bubble.
    if (e.shield) {
      canvas.drawCircle(pos, 32,
          Paint()..color = const Color(0xFF7FB8D9).withValues(alpha: 0.25));
      canvas.drawCircle(
          pos,
          32,
          Paint()
            ..color = const Color(0xFF7FB8D9).withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }
  }

  void _paintShipBody(Canvas canvas, Color hull, Color dark, Color cockpit) {
    final hp = Paint()..color = hull;
    final dp = Paint()..color = dark;
    final cp = Paint()..color = cockpit;
    switch (shipStyle) {
      case 1: // dart
        canvas.drawPath(
            Path()
              ..moveTo(0, -26)
              ..lineTo(-11, 18)
              ..lineTo(11, 18)
              ..close(),
            dp);
        canvas.drawPath(
            Path()
              ..moveTo(0, -22)
              ..lineTo(-8, 15)
              ..lineTo(8, 15)
              ..close(),
            hp);
      case 2: // bulwark
        final r = RRect.fromRectAndRadius(
            const Rect.fromLTWH(-15, -18, 30, 36), const Radius.circular(9));
        canvas.drawRRect(r.shift(const Offset(0, 3)), dp);
        canvas.drawRRect(r, hp);
      case 3: // needle
        canvas.drawPath(
            Path()
              ..moveTo(0, -30)
              ..lineTo(-7, 20)
              ..lineTo(7, 20)
              ..close(),
            dp);
        canvas.drawPath(
            Path()
              ..moveTo(0, -26)
              ..lineTo(-5, 17)
              ..lineTo(5, 17)
              ..close(),
            hp);
      case 4: // falcon
        canvas.drawPath(
            Path()
              ..moveTo(0, -26)
              ..lineTo(-22, 14)
              ..lineTo(-8, 9)
              ..lineTo(8, 9)
              ..lineTo(22, 14)
              ..close(),
            dp);
        canvas.drawPath(
            Path()
              ..moveTo(0, -22)
              ..lineTo(-18, 12)
              ..lineTo(-7, 8)
              ..lineTo(7, 8)
              ..lineTo(18, 12)
              ..close(),
            hp);
      case 5: // mantis
        canvas.drawOval(const Rect.fromLTWH(-17, -14, 34, 28), dp);
        canvas.drawOval(const Rect.fromLTWH(-14, -16, 28, 24), hp);
      case 6: // titan
        final r2 = RRect.fromRectAndRadius(
            const Rect.fromLTWH(-18, -16, 36, 34), const Radius.circular(11));
        canvas.drawRRect(r2.shift(const Offset(0, 3)), dp);
        canvas.drawRRect(r2, hp);
      case 7: // comet
        canvas.drawPath(
            Path()
              ..moveTo(0, -24)
              ..quadraticBezierTo(16, 0, 0, 20)
              ..quadraticBezierTo(-16, 0, 0, -24)
              ..close(),
            dp);
        canvas.drawPath(
            Path()
              ..moveTo(0, -20)
              ..quadraticBezierTo(12, 0, 0, 16)
              ..quadraticBezierTo(-12, 0, 0, -20)
              ..close(),
            hp);
      default: // classic rocket
        canvas.drawPath(
            Path()
              ..moveTo(0, -26)
              ..lineTo(-15, 12)
              ..lineTo(0, 6)
              ..lineTo(15, 12)
              ..close(),
            dp);
        canvas.drawPath(
            Path()
              ..moveTo(0, -22)
              ..lineTo(-12, 10)
              ..lineTo(0, 5)
              ..lineTo(12, 10)
              ..close(),
            hp);
    }
    // Cockpit glass with shine.
    canvas.drawCircle(const Offset(0, -6), 7, dp);
    canvas.drawCircle(const Offset(0, -6), 5.5, cp);
    canvas.drawCircle(const Offset(-1.8, -7.8), 1.8,
        Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
