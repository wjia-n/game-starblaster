import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

enum _EK { dart, weaver, tank, boss }
enum _PK { spread, shield, rapid }

class _Bullet {
  Offset pos;
  final Offset vel;
  _Bullet(this.pos, this.vel);
}

class _Enemy {
  Offset pos;
  double baseX;
  final _EK kind;
  int hp;
  double t = 0;
  double fireT = 1.0;
  _Enemy(this.pos, this.kind, this.hp) : baseX = pos.dx;
}

class _PowerUp {
  Offset pos;
  final _PK kind;
  _PowerUp(this.pos, this.kind);
}

class _Particle {
  Offset pos;
  Offset vel;
  double t = 0;
  final Color color;
  _Particle(this.pos, this.vel, this.color);
}

class StarBlasterScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const StarBlasterScreen({super.key, required this.players, required this.callbacks});

  @override
  State<StarBlasterScreen> createState() => _StarBlasterScreenState();
}

class _StarBlasterScreenState extends State<StarBlasterScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _area = Size.zero;

  Offset _ship = Offset.zero;
  final List<_Bullet> _bullets = [];
  final List<_Bullet> _ebullets = [];
  final List<_Enemy> _enemies = [];
  final List<_PowerUp> _powers = [];
  final List<_Particle> _parts = [];
  final List<Offset> _stars = [];
  double _starT = 0;

  int _wave = 0, _lives = 3, _best = 0;
  int _toSpawn = 0;
  double _spawnT = 0, _fireT = 0, _wavePause = 0, _invulnT = 0;
  double _spreadT = 0, _rapidT = 0;
  bool _shield = false;
  bool _over = false, _bossActive = false;
  String _banner = '';
  double _bannerT = 0;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _loadBest();
    _ticker = createTicker(_tick)..start();
  }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _best = p.getInt('starblaster_best') ?? 0);
  }

  Future<void> _saveBest(int s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('starblaster_best', s);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _addScore(int pts) {
    widget.players[0].score += pts;
    if (widget.players[0].score > _best) {
      _best = widget.players[0].score;
      _saveBest(_best);
    }
    widget.callbacks.refreshHud();
  }

  void _nextWave() {
    _wave++;
    if (_wave > 10) {
      _finish(true);
      return;
    }
    _banner = _wave % 5 == 0 ? '⚠️ BOSS INCOMING ⚠️' : 'WAVE $_wave';
    _bannerT = 2.0;
    Sfx.win();
    if (_wave % 5 == 0) {
      final w = _area.width;
      _enemies.add(_Enemy(Offset(w / 2, 130), _EK.boss, 40 + 20 * (_wave ~/ 5 - 1)));
      _bossActive = true;
      _toSpawn = 0;
    } else {
      _toSpawn = min(3 + _wave, 12);
      _spawnT = 0.5;
      _bossActive = false;
    }
  }

  void _spawnEnemy() {
    final w = _area.width;
    final roll = _rnd.nextDouble();
    _EK kind;
    if (_wave >= 3 && roll < 0.22) {
      kind = _EK.tank;
    } else if (_wave >= 2 && roll < 0.55) {
      kind = _EK.weaver;
    } else {
      kind = _EK.dart;
    }
    final hp = kind == _EK.tank ? 3 : 1;
    _enemies.add(_Enemy(Offset(30 + _rnd.nextDouble() * (w - 60), -30), kind, hp));
  }

  void _explode(Offset pos, Color color, [int n = 14]) {
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * 2 * pi;
      final s = 60 + _rnd.nextDouble() * 160;
      _parts.add(_Particle(pos, Offset(cos(a) * s, sin(a) * s), color));
    }
  }

  void _playerHit() {
    if (_invulnT > 0 || _over) return;
    if (_shield) {
      _shield = false;
      _invulnT = 1.0;
      _explode(_ship, Colors.cyan, 10);
      Sfx.lose();
      return;
    }
    _lives--;
    _invulnT = 2.0;
    _explode(_ship, Colors.orange, 22);
    Sfx.lose();
    if (_lives <= 0) _finish(false);
  }

  void _finish(bool won) {
    if (_over) return;
    _over = true;
    _ticker.stop();
    final s = widget.players[0].score;
    if (won) {
      Sfx.win();
      widget.callbacks.finish(
        headline: 'Galaxy saved! 🚀🏆',
        subline: 'You destroyed the wave-10 boss with $s points.',
      );
    } else {
      Sfx.lose();
      widget.callbacks.finish(
        headline: 'Ship down!',
        subline: 'Final score: $s (best: $_best). The stars await your return.',
      );
    }
  }

  void _tick(Duration now) {
    if (_area == Size.zero) {
      _last = now;
      return;
    }
    if (_over) {
      _last = now;
      return;
    }
    if (_ship == Offset.zero) {
      _ship = Offset(_area.width / 2, _area.height - 130);
      _nextWave();
    }
    final dt = min((now - _last).inMicroseconds / 1e6, 1 / 30);
    _last = now;

    _bannerT = max(0, _bannerT - dt);
    _invulnT = max(0, _invulnT - dt);
    _spreadT = max(0, _spreadT - dt);
    _rapidT = max(0, _rapidT - dt);
    _starT += dt;

    if (_stars.length < 90) {
      _stars.add(Offset(_rnd.nextDouble() * _area.width, _rnd.nextDouble() * _area.height));
    }

    // spawning
    if (_toSpawn > 0) {
      _spawnT -= dt;
      if (_spawnT <= 0) {
        _spawnT = max(0.35, 0.8 - _wave * 0.04);
        _toSpawn--;
        _spawnEnemy();
      }
    }

    // player fire
    _fireT -= dt;
    if (_fireT <= 0) {
      _fireT = _rapidT > 0 ? 0.13 : 0.26;
      final angles = _spreadT > 0 ? [-0.22, 0.0, 0.22] : [0.0];
      for (final a in angles) {
        _bullets.add(_Bullet(_ship + const Offset(0, -24), Offset(sin(a) * 620, -cos(a) * 620)));
      }
      Sfx.tap();
    }

    // bullets
    for (var i = _bullets.length - 1; i >= 0; i--) {
      final b = _bullets[i];
      b.pos = b.pos + b.vel * dt;
      if (b.pos.dy < -20 || b.pos.dx < -20 || b.pos.dx > _area.width + 20) {
        _bullets.removeAt(i);
        continue;
      }
      var consumed = false;
      for (var j = _enemies.length - 1; j >= 0; j--) {
        final e = _enemies[j];
        final rad = e.kind == _EK.boss ? 44 : 20;
        if ((e.pos - b.pos).distance < rad) {
          e.hp--;
          _explode(b.pos, Colors.yellow, 4);
          if (e.hp <= 0) {
            _killEnemy(j);
          }
          consumed = true;
          break;
        }
      }
      if (consumed) _bullets.removeAt(i);
    }

    // enemies
    for (final e in _enemies) {
      e.t += dt;
      switch (e.kind) {
        case _EK.dart:
          e.pos = e.pos + Offset(0, (130 + _wave * 8) * dt);
        case _EK.weaver:
          e.pos = Offset(e.baseX + sin(e.t * 3.2) * 110, e.pos.dy + 105 * dt);
        case _EK.tank:
          e.pos = e.pos + Offset(sin(e.t * 1.4) * 40 * dt, 62 * dt);
          e.fireT -= dt;
          if (e.fireT <= 0 && e.pos.dy > 0 && e.pos.dy < _area.height * 0.6) {
            e.fireT = 2.2;
            final dir = (_ship - e.pos);
            final d = dir.distance.clamp(1.0, 999.0);
            _ebullets.add(_Bullet(e.pos, dir / d * 230));
          }
        case _EK.boss:
          e.pos = Offset(_area.width / 2 + sin(e.t * 0.9) * (_area.width * 0.32), 130);
          e.fireT -= dt;
          if (e.fireT <= 0) {
            e.fireT = 1.1;
            final dir = (_ship - e.pos);
            final d = dir.distance.clamp(1.0, 999.0);
            _ebullets.add(_Bullet(e.pos + const Offset(0, 30), dir / d * 260));
            if ((e.t ~/ 3).isEven) {
              for (var k = 0; k < 8; k++) {
                final a = k / 8 * 2 * pi + e.t;
                _ebullets.add(_Bullet(e.pos, Offset(cos(a), sin(a)) * 170));
              }
            }
          }
      }
    }
    _enemies.removeWhere((e) => e.pos.dy > _area.height + 60);

    // enemy bullets
    for (var i = _ebullets.length - 1; i >= 0; i--) {
      final b = _ebullets[i];
      b.pos = b.pos + b.vel * dt;
      if (b.pos.dy < -20 || b.pos.dy > _area.height + 20 || b.pos.dx < -20 || b.pos.dx > _area.width + 20) {
        _ebullets.removeAt(i);
      } else if ((b.pos - _ship).distance < 20) {
        _ebullets.removeAt(i);
        _playerHit();
      }
    }

    // enemy-ship collision
    for (var j = _enemies.length - 1; j >= 0; j--) {
      if ((_enemies[j].pos - _ship).distance < 30) {
        _killEnemy(j, false);
        _playerHit();
      }
    }

    // powerups
    for (var i = _powers.length - 1; i >= 0; i--) {
      final p = _powers[i];
      p.pos = p.pos + Offset(0, 120 * dt);
      if ((_ship - p.pos).distance < 30) {
        _powers.removeAt(i);
        switch (p.kind) {
          case _PK.spread:
            _spreadT = 10;
            _banner = 'SPREAD SHOT!';
          case _PK.shield:
            _shield = true;
            _banner = 'SHIELD UP!';
          case _PK.rapid:
            _rapidT = 10;
            _banner = 'RAPID FIRE!';
        }
        _bannerT = 1.2;
        Sfx.win();
      } else if (p.pos.dy > _area.height + 20) {
        _powers.removeAt(i);
      }
    }

    // particles
    for (final p in _parts) {
      p.t += dt;
      p.pos = p.pos + p.vel * dt;
      p.vel = p.vel * (1 - 2.2 * dt);
    }
    _parts.removeWhere((p) => p.t > 0.7);

    // wave clear
    if (_toSpawn == 0 && _enemies.isEmpty) {
      _wavePause += dt;
      if (_wavePause > 1.6) {
        _wavePause = 0;
        if (_bossActive) {
          _bossActive = false;
          _addScore(500);
          _banner = 'BOSS DOWN! +500';
          _bannerT = 1.6;
        }
        _nextWave();
      }
    } else {
      _wavePause = 0;
    }

    if (mounted) setState(() {});
  }

  void _killEnemy(int j, [bool scored = true]) {
    final e = _enemies[j];
    _enemies.removeAt(j);
    final col = e.kind == _EK.dart
        ? Colors.redAccent
        : e.kind == _EK.weaver
            ? Colors.purpleAccent
            : e.kind == _EK.tank
                ? Colors.orangeAccent
                : Colors.red;
    _explode(e.pos, col, e.kind == _EK.boss ? 40 : 14);
    if (scored) {
      _addScore(e.kind == _EK.dart ? 10 : e.kind == _EK.weaver ? 15 : e.kind == _EK.tank ? 30 : 500);
      Sfx.click();
    }
    if (_rnd.nextDouble() < 0.13 && e.kind != _EK.boss) {
      _powers.add(_PowerUp(e.pos, _PK.values[_rnd.nextInt(3)]));
    }
  }

  String _activePowerText() {
    final bits = [
      if (_spreadT > 0) '🔱 spread',
      if (_rapidT > 0) '⚡ rapid',
      if (_shield) '🛡️ shield',
    ];
    return bits.isEmpty ? 'Drag to fly — guns blaze on their own!' : bits.join('  ');
  }

  void _onDrag(DragUpdateDetails d) {    if (_over || _area == Size.zero) return;
    setState(() {
      _ship = Offset(
        (_ship.dx + d.delta.dx).clamp(20.0, _area.width - 20),
        (_ship.dy + d.delta.dy).clamp(_area.height * 0.35, _area.height - 40),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    final boss = _enemies.where((e) => e.kind == _EK.boss).firstOrNull;
    final bossMax = 40 + 20 * (_wave ~/ 5 - 1);
    return Column(
      children: [
        ScoreChips(players: widget.players, activeIndex: 0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('❤️ × $_lives', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
              Text('WAVE $_wave / 10', style: TextStyle(color: theme.muted, fontWeight: FontWeight.bold)),
              Text('BEST $_best', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (boss != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (boss.hp / bossMax).clamp(0.0, 1.0),
                backgroundColor: theme.surface,
                color: Colors.red,
                minHeight: 8,
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _area = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanUpdate: _onDrag,
                child: CustomPaint(
                  painter: _SpacePainter(
                    stars: _stars,
                    starT: _starT,
                    ship: _ship,
                    invuln: _invulnT > 0,
                    shield: _shield,
                    bullets: _bullets,
                    ebullets: _ebullets,
                    enemies: _enemies,
                    powers: _powers,
                    parts: _parts,
                    banner: _bannerT > 0 ? _banner : '',
                    spread: _spreadT > 0,
                    rapid: _rapidT > 0,
                    bg: theme.background,
                    accent: theme.accent,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _activePowerText(),
            style: TextStyle(color: theme.muted),
          ),
        ),
      ],
    );
  }
}

class _SpacePainter extends CustomPainter {
  final List<Offset> stars;
  final double starT;
  final Offset ship;
  final bool invuln, shield, spread, rapid;
  final List<_Bullet> bullets, ebullets;
  final List<_Enemy> enemies;
  final List<_PowerUp> powers;
  final List<_Particle> parts;
  final String banner;
  final Color bg, accent;

  _SpacePainter({
    required this.stars,
    required this.starT,
    required this.ship,
    required this.invuln,
    required this.shield,
    required this.spread,
    required this.rapid,
    required this.bullets,
    required this.ebullets,
    required this.enemies,
    required this.powers,
    required this.parts,
    required this.banner,
    required this.bg,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    // starfield
    final sp = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      final y = (s.dy + starT * (30 + (i % 5) * 18)) % size.height;
      canvas.drawCircle(Offset(s.dx, y), 1 + (i % 3) * 0.6, sp);
    }

    // powerups
    const pkCol = {_PK.spread: Colors.green, _PK.shield: Colors.cyan, _PK.rapid: Colors.yellow};
    const pkGlyph = {_PK.spread: 'S', _PK.shield: 'O', _PK.rapid: 'R'};
    for (final p in powers) {
      canvas.drawCircle(p.pos, 14, Paint()..color = pkCol[p.kind]!);
      final tp = TextPainter(
        text: TextSpan(
            text: pkGlyph[p.kind],
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p.pos - Offset(tp.width / 2, tp.height / 2));
    }

    // enemies
    for (final e in enemies) {
      switch (e.kind) {
        case _EK.dart:
          final path = Path()
            ..moveTo(e.pos.dx, e.pos.dy + 16)
            ..lineTo(e.pos.dx - 12, e.pos.dy - 10)
            ..lineTo(e.pos.dx + 12, e.pos.dy - 10)
            ..close();
          canvas.drawPath(path, Paint()..color = Colors.redAccent);
        case _EK.weaver:
          final path = Path()
            ..moveTo(e.pos.dx, e.pos.dy + 14)
            ..lineTo(e.pos.dx + 13, e.pos.dy)
            ..lineTo(e.pos.dx, e.pos.dy - 14)
            ..lineTo(e.pos.dx - 13, e.pos.dy)
            ..close();
          canvas.drawPath(path, Paint()..color = Colors.purpleAccent);
        case _EK.tank:
          canvas.drawCircle(e.pos, 20, Paint()..color = Colors.orangeAccent);
          canvas.drawCircle(e.pos, 20, Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 3);
          canvas.drawCircle(e.pos, 8, Paint()..color = Colors.deepOrange);
        case _EK.boss:
          final path = Path()
            ..moveTo(e.pos.dx, e.pos.dy + 44)
            ..lineTo(e.pos.dx - 40, e.pos.dy - 20)
            ..lineTo(e.pos.dx - 18, e.pos.dy - 34)
            ..lineTo(e.pos.dx + 18, e.pos.dy - 34)
            ..lineTo(e.pos.dx + 40, e.pos.dy - 20)
            ..close();
          canvas.drawPath(path, Paint()..color = const Color(0xFFB71C1C));
          canvas.drawCircle(e.pos + const Offset(0, -8), 12, Paint()..color = Colors.redAccent);
      }
    }

    // bullets
    final bp = Paint()..color = Colors.cyanAccent;
    for (final b in bullets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: b.pos, width: 5, height: 16), const Radius.circular(2.5)),
        bp,
      );
    }
    for (final b in ebullets) {
      canvas.drawCircle(b.pos, 7, Paint()..color = Colors.red);
      canvas.drawCircle(b.pos, 3.5, Paint()..color = Colors.white);
    }

    // particles
    for (final p in parts) {
      canvas.drawCircle(p.pos, 4 * (1 - p.t / 0.7), Paint()..color = p.color.withValues(alpha: (1 - p.t / 0.7).clamp(0.0, 1.0)));
    }

    // ship
    if (ship != Offset.zero && !(invuln && (starT * 12).floor().isEven)) {
      if (shield) {
        canvas.drawCircle(ship, 30, Paint()..color = Colors.cyan.withValues(alpha: 0.3));
        canvas.drawCircle(ship, 30, Paint()..color = Colors.cyan..style = PaintingStyle.stroke..strokeWidth = 2);
      }
      final path = Path()
        ..moveTo(ship.dx, ship.dy - 24)
        ..lineTo(ship.dx - 16, ship.dy + 14)
        ..lineTo(ship.dx, ship.dy + 6)
        ..lineTo(ship.dx + 16, ship.dy + 14)
        ..close();
      canvas.drawPath(path, Paint()..color = accent);
      canvas.drawCircle(ship + const Offset(0, -6), 6, Paint()..color = Colors.white);
      // flame
      final flame = 10 + 6 * sin(starT * 30);
      final fp = Path()
        ..moveTo(ship.dx - 7, ship.dy + 12)
        ..lineTo(ship.dx, ship.dy + 12 + flame)
        ..lineTo(ship.dx + 7, ship.dy + 12)
        ..close();
      canvas.drawPath(fp, Paint()..color = Colors.orange);
    }

    if (banner.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: banner, style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 30)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.4));
    }
  }

  @override
  bool shouldRepaint(covariant _SpacePainter old) => true;
}
