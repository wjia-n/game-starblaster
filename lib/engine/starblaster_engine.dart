import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Game phases owned ENTIRELY by the engine. The UI only renders and forwards
/// input — it never drives transitions. This is what makes stuck states
/// impossible by construction: every phase has a live timer and a watchdog
/// repair path.
enum GamePhase {
  ready, // pre-launch: tap LAUNCH to start
  intro, // wave banner countdown -> playing
  playing, // live combat
  waveClear, // celebration pause -> next wave
  bossWarn, // boss alarm -> boss spawns -> playing
  dying, // ship explosion -> respawn or gameOver
  gameOver, // terminal: needs user action
  victory, // terminal: needs user action
  paused, // frozen: resume returns to [_pausedFrom]
}

/// Difficulty tiers (RULES.md section on modes).
class TierTuning {
  final String key; // cadet / pilot / ace
  final String name;
  final int lives;
  final double enemySpeed;
  final double spawnEvery;
  final double enemyFireMul;
  final double bulletSpeed;
  final int bossHp;

  const TierTuning({
    required this.key,
    required this.name,
    required this.lives,
    required this.enemySpeed,
    required this.spawnEvery,
    required this.enemyFireMul,
    required this.bulletSpeed,
    required this.bossHp,
  });

  static const cadet = TierTuning(
    key: 'cadet',
    name: 'Cadet',
    lives: 4,
    enemySpeed: 0.8,
    spawnEvery: 0.95,
    enemyFireMul: 0.5,
    bulletSpeed: 200,
    bossHp: 30,
  );
  static const pilot = TierTuning(
    key: 'pilot',
    name: 'Pilot',
    lives: 3,
    enemySpeed: 1.0,
    spawnEvery: 0.7,
    enemyFireMul: 1.0,
    bulletSpeed: 240,
    bossHp: 45,
  );
  static const ace = TierTuning(
    key: 'ace',
    name: 'Ace',
    lives: 2,
    enemySpeed: 1.25,
    spawnEvery: 0.5,
    enemyFireMul: 1.6,
    bulletSpeed: 280,
    bossHp: 60,
  );

  static TierTuning byIndex(int i) =>
      [cadet, pilot, ace][i.clamp(0, 2)];
}

/// Game modes (RULES.md): campaign (waves 1-10, bosses at 5 & 10),
/// endless (infinite scaling), score attack (150s timer).
enum BlastMode { campaign, endless, attack }

enum EnemyKind { dart, weaver, tank, gunner, boss }
enum PowerKind { spread, shield, rapid, life }

class Bullet {
  Offset pos;
  final Offset vel;
  final bool friendly;
  Bullet(this.pos, this.vel, {this.friendly = true});
}

class Enemy {
  Offset pos;
  double baseX;
  final EnemyKind kind;
  int hp;
  final int maxHp; // HP at spawn — drives the boss HP bar
  double t = 0;
  double fireT = 1.5;
  Enemy(this.pos, this.kind, this.hp)
      : baseX = pos.dx,
        maxHp = hp;
}

class PowerUp {
  Offset pos;
  final PowerKind kind;
  double t = 0;
  PowerUp(this.pos, this.kind);
}

class Particle {
  Offset pos;
  Offset vel;
  double t = 0;
  final double life;
  final Color color;
  final double size;
  Particle(this.pos, this.vel, this.color, {this.life = 0.7, this.size = 4});
}

class ScorePopup {
  Offset pos;
  final String text;
  double t = 0;
  ScorePopup(this.pos, this.text);
}

class StarDot {
  double x, y, speed;
  StarDot(this.x, this.y, this.speed);
}

/// Star Blaster game engine. Owns ALL state and ALL phase transitions.
///
/// Sound: the engine never touches audio directly — it appends SFX names to
/// [sfxQueue], which the game screen drains each frame and plays through
/// StarAudio. Music changes are signalled through [phase] changes.
class StarBlasterEngine extends ChangeNotifier {
  final BlastMode mode;
  final TierTuning tuning;
  final Random _rnd;

  StarBlasterEngine({
    required this.mode,
    required this.tuning,
    int? seed,
  }) : _rnd = Random(seed ?? Random().nextInt(1 << 32));

  // ------------------------------------------------------------ state
  GamePhase phase = GamePhase.ready;
  GamePhase _pausedFrom = GamePhase.playing;

  int score = 0;
  int lives = 3;
  int wave = 0;
  int combo = 0;
  double comboT = 0;
  int kills = 0;

  Offset ship = Offset.zero;
  Offset shipTarget = Offset.zero;
  double shipTilt = 0;
  Size area = Size.zero;

  final List<Bullet> bullets = [];
  final List<Bullet> ebullets = [];
  final List<Enemy> enemies = [];
  final List<PowerUp> powers = [];
  final List<Particle> parts = [];
  final List<ScorePopup> popups = [];
  final List<StarDot> stars = [];
  double starT = 0;

  int toSpawn = 0;
  double spawnT = 0;
  double fireT = 0;
  double invulnT = 0;
  double shieldT = 0;
  double spreadT = 0;
  double rapidT = 0;
  bool get shield => shieldT > 0;

  String banner = '';
  double bannerT = 0;

  double shakeT = 0;
  double flashT = 0;
  double slowmoT = 0;

  // Phase timers — every non-terminal phase owns a live timer.
  double introT = 0;
  double clearT = -1; // <0 = not armed
  double warnT = 0;
  double deathT = 0;
  double attackT = 150; // score-attack countdown

  bool bossWave = false;
  bool wonByTimeout = false;

  /// SFX names queued for the screen to play (drained per frame).
  final List<String> sfxQueue = [];

  /// Watchdog diagnostics.
  int watchdogRepairs = 0;
  String lastRepair = '';

  Timer? _watchdog;
  bool _disposed = false;

  // ------------------------------------------------------- lifecycle
  /// Starts the watchdog. The game screen calls this in initState.
  void attach() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => watchdogTick(),
    );
  }

  /// Stops the watchdog. The game screen calls this in dispose.
  void detach() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    super.dispose();
  }

  void _sfx(String name) => sfxQueue.add(name);

  void _setPhase(GamePhase p) {
    if (phase == p) return;
    phase = p;
    notifyListeners();
  }

  // ------------------------------------------------------- public API
  /// Player taps LAUNCH on the ready screen, or RETRY / FLY AGAIN on the
  /// end dialog. Accepted from ready, gameOver and victory so a finished run
  /// always restarts (RULES.md §4).
  void startGame() {
    if (phase != GamePhase.ready &&
        phase != GamePhase.gameOver &&
        phase != GamePhase.victory) return;
    lives = tuning.lives;
    score = 0;
    wave = 0;
    combo = 0;
    kills = 0;
    attackT = 150;
    wonByTimeout = false;
    bullets.clear();
    ebullets.clear();
    enemies.clear();
    powers.clear();
    parts.clear();
    popups.clear();
    _sfx('gameStart');
    _nextWave();
  }

  void pause() {
    if (phase == GamePhase.playing ||
        phase == GamePhase.intro ||
        phase == GamePhase.waveClear ||
        phase == GamePhase.bossWarn) {
      _pausedFrom = phase;
      _setPhase(GamePhase.paused);
    }
  }

  void resume() {
    if (phase == GamePhase.paused) {
      _setPhase(_pausedFrom);
    }
  }

  /// Drag input: the ship chases the target (called from onPanUpdate).
  void moveShip(Offset delta) {
    if (phase != GamePhase.playing && phase != GamePhase.intro) return;
    if (area == Size.zero) return;
    final nx = (shipTarget.dx + delta.dx).clamp(24.0, area.width - 24);
    final ny = (shipTarget.dy + delta.dy)
        .clamp(area.height * 0.35, area.height - 44);
    shipTarget = Offset(nx, ny);
  }

  /// Place the ship the first time the play area is known.
  void ensureShip(Size a) {
    area = a;
    if (ship == Offset.zero) {
      ship = Offset(a.width / 2, a.height - 130);
      shipTarget = ship;
    }
  }

  // ------------------------------------------------- phase transitions
  void _nextWave() {
    wave++;
    if (mode == BlastMode.campaign && wave > 10) {
      _win(false);
      return;
    }
    if (mode == BlastMode.campaign && wave % 5 == 0) {
      bossWave = true;
      banner = 'WARNING: BOSS INCOMING';
      bannerT = 2.0;
      warnT = 2.0;
      _sfx('bossAlarm');
      _setPhase(GamePhase.bossWarn);
    } else {
      bossWave = false;
      banner = mode == BlastMode.attack ? 'SCORE ATTACK!' : 'WAVE $wave';
      bannerT = 1.4;
      introT = 1.4;
      _sfx('waveStart');
      _setPhase(GamePhase.intro);
    }
  }

  void _enterPlaying() {
    if (bossWave && mode == BlastMode.campaign) {
      _spawnBoss();
    } else {
      final scale = mode == BlastMode.endless ? 1 + (wave ~/ 4) * 0.5 : 1.0;
      toSpawn = ((3 + wave) * scale).round().clamp(3, 16);
      spawnT = 0.4;
    }
    banner = '';
    bannerT = 0;
    _setPhase(GamePhase.playing);
  }

  void _spawnBoss() {
    final w = area.width == 0 ? 400 : area.width;
    final hp = mode == BlastMode.campaign
        ? tuning.bossHp + 15 * (wave ~/ 5 - 1)
        : (tuning.bossHp * (1 + wave * 0.08)).round();
    enemies.add(Enemy(Offset(w / 2, 130), EnemyKind.boss, hp));
    banner = 'BOSS: VOID MAULER';
    bannerT = 1.6;
    toSpawn = 0;
    _setPhase(GamePhase.playing);
  }

  void _enterWaveClear({required bool bossDown}) {
    final bonus = bossDown ? 500 : 100 * wave;
    score += bonus;
    popups.add(ScorePopup(
      Offset(area.width / 2, area.height * 0.45),
      bossDown ? 'BOSS DOWN! +$bonus' : 'WAVE $wave CLEAR! +$bonus',
    ));
    banner = bossDown ? 'BOSS DOWN! +$bonus' : 'WAVE $wave CLEAR! +$bonus';
    bannerT = 1.6;
    clearT = 1.6;
    combo = 0;
    if (bossDown) {
      shakeT = 0.5;
      slowmoT = 0.7;
      _sfx('explodeBig');
    }
    _sfx('waveClear');
    _setPhase(GamePhase.waveClear);
  }

  void _playerHit() {
    if (invulnT > 0 || phase != GamePhase.playing) return;
    if (shield) {
      shieldT = 0;
      invulnT = 1.0;
      _explode(ship, const Color(0xFF8FC3DE), 12);
      _sfx('hit');
      notifyListeners();
      return;
    }
    lives--;
    invulnT = 2.0;
    shakeT = 0.4;
    flashT = 0.25;
    combo = 0;
    _explode(ship, const Color(0xFFE4572E), 26);
    _sfx('hit');
    if (lives <= 0) {
      deathT = 1.3;
      _explode(ship, const Color(0xFFFFD166), 40);
      _sfx('explodeBig');
      _setPhase(GamePhase.dying);
    }
    notifyListeners();
  }

  void _settleDeath() {
    // Respawn with fresh invulnerability, or game over.
    if (lives > 0) {
      ship = Offset(area.width / 2, area.height - 130);
      shipTarget = ship;
      invulnT = 2.5;
      _setPhase(GamePhase.playing);
    } else {
      _lose();
    }
  }

  void _win(bool byTimeout) {
    wonByTimeout = byTimeout;
    _sfx('win');
    _setPhase(GamePhase.victory);
  }

  void _lose() {
    _sfx('lose');
    _setPhase(GamePhase.gameOver);
  }

  // --------------------------------------------------------- watchdog
  /// Verifies every phase owns a live timer and repairs stuck states.
  /// Called every 400ms by the watchdog timer and directly by tests.
  @pragma('vm:notify-debugger-on-exception')
  void watchdogTick() {
    if (_disposed) return;
    String? repair;
    switch (phase) {
      case GamePhase.intro:
        if (introT <= 0) {
          _enterPlaying();
          repair = 'intro timer expired without transition -> playing';
        }
      case GamePhase.playing:
        if (toSpawn == 0 && enemies.isEmpty && clearT < 0) {
          _enterWaveClear(bossDown: false);
          repair = 'playing with no enemies/spawns -> waveClear';
        }
      case GamePhase.waveClear:
        if (clearT <= 0) {
          _advanceAfterClear();
          repair = 'waveClear timer expired without transition -> next wave';
        }
      case GamePhase.bossWarn:
        if (warnT <= 0) {
          _spawnBoss();
          repair = 'bossWarn timer expired without transition -> boss spawn';
        }
      case GamePhase.dying:
        if (deathT <= 0) {
          _settleDeath();
          repair = 'dying timer expired without transition -> settle death';
        }
      case GamePhase.ready:
      case GamePhase.gameOver:
      case GamePhase.victory:
      case GamePhase.paused:
        break; // terminal / user-driven: nothing to repair
    }
    if (repair != null) {
      watchdogRepairs++;
      lastRepair = repair;
    }
  }

  void _advanceAfterClear() {
    clearT = -1;
    _nextWave();
  }

  // ------------------------------------------------------------ tick
  /// Advance the simulation by [dt] seconds. Called every frame by the
  /// game screen's ticker (and directly by tests).
  void tick(double rawDt) {
    // Cosmetic clock always advances so ready-screen animations (TAP TO
    // LAUNCH pulse) stay alive; gameplay freezes in terminal phases.
    starT += rawDt;
    if (phase == GamePhase.paused ||
        phase == GamePhase.ready ||
        phase == GamePhase.gameOver ||
        phase == GamePhase.victory) {
      return;
    }
    final dt = (rawDt * (slowmoT > 0 ? 0.35 : 1.0)).clamp(0.0, 1 / 20);
    slowmoT = max(0, slowmoT - rawDt);

    if (stars.length < 90 && area != Size.zero) {
      stars.add(StarDot(_rnd.nextDouble() * area.width,
          _rnd.nextDouble() * area.height, 20 + _rnd.nextDouble() * 90));
    }
    shakeT = max(0, shakeT - rawDt);
    flashT = max(0, flashT - rawDt);
    bannerT = max(0, bannerT - rawDt);
    invulnT = max(0, invulnT - rawDt);
    shieldT = max(0, shieldT - rawDt);
    spreadT = max(0, spreadT - rawDt);
    rapidT = max(0, rapidT - rawDt);
    comboT = max(0, comboT - rawDt);
    if (comboT <= 0) combo = 0;

    // Ship chases its drag target (smooth, weighty).
    if (area != Size.zero) {
      final toT = shipTarget - ship;
      final dist = toT.distance;
      if (dist > 1) {
        final step = min(dist, 900 * dt);
        final prevX = ship.dx;
        ship = ship + toT / dist * step;
        shipTilt = ((ship.dx - prevX) / max(dt, 1e-4) / 900).clamp(-1.0, 1.0);
      } else {
        shipTilt *= (1 - 6 * dt);
      }
    }

    switch (phase) {
      case GamePhase.intro:
        introT -= dt;
        if (introT <= 0) _enterPlaying();
      case GamePhase.bossWarn:
        warnT -= dt;
        if (warnT <= 0) _spawnBoss();
      case GamePhase.waveClear:
        clearT -= dt;
        _updateParticles(dt);
        _updatePopups(dt);
        if (clearT <= 0) _advanceAfterClear();
      case GamePhase.dying:
        deathT -= dt;
        _updateParticles(dt);
        if (deathT <= 0) _settleDeath();
      case GamePhase.playing:
        _tickPlaying(dt, rawDt);
      case GamePhase.ready:
      case GamePhase.gameOver:
      case GamePhase.victory:
      case GamePhase.paused:
        break;
    }
  }

  void _tickPlaying(double dt, double rawDt) {
    // Score-attack countdown.
    if (mode == BlastMode.attack) {
      attackT -= rawDt;
      if (attackT <= 0) {
        attackT = 0;
        _win(true);
        return;
      }
    }

    // Spawning.
    if (toSpawn > 0) {
      spawnT -= dt;
      if (spawnT <= 0) {
        spawnT = tuning.spawnEvery * (0.8 + _rnd.nextDouble() * 0.4);
        toSpawn--;
        _spawnEnemy();
      }
    }

    // Player auto-fire.
    fireT -= dt;
    if (fireT <= 0 && ship != Offset.zero) {
      fireT = rapidT > 0 ? 0.13 : 0.26;
      final angles = spreadT > 0 ? [-0.22, 0.0, 0.22] : [0.0];
      for (final a in angles) {
        bullets.add(Bullet(ship + const Offset(0, -24),
            Offset(sin(a) * 640, -cos(a) * 640)));
      }
      _sfx('laser');
    }

    _tickBullets(dt);
    _tickEnemies(dt);
    _tickEnemyBullets(dt);
    _tickPowerups(dt);
    _updateParticles(dt);
    _updatePopups(dt);

    // Wave cleared: no pending spawns and no live enemies.
    if (toSpawn == 0 && enemies.isEmpty && clearT < 0) {
      _enterWaveClear(bossDown: bossWave);
    }
  }

  void _spawnEnemy() {
    final w = area.width == 0 ? 400 : area.width;
    final roll = _rnd.nextDouble();
    final EnemyKind kind;
    if (wave >= 4 && roll < 0.16) {
      kind = EnemyKind.gunner;
    } else if (wave >= 3 && roll < 0.34) {
      kind = EnemyKind.tank;
    } else if (wave >= 2 && roll < 0.62) {
      kind = EnemyKind.weaver;
    } else {
      kind = EnemyKind.dart;
    }
    final hpMul = mode == BlastMode.endless ? 1 + wave * 0.06 : 1.0;
    final hp = ((kind == EnemyKind.tank
                ? 3
                : kind == EnemyKind.gunner
                    ? 2
                    : 1) *
            hpMul)
        .round()
        .clamp(1, 12);
    enemies.add(Enemy(
        Offset(30 + _rnd.nextDouble() * (w - 60), -30), kind, hp));
  }

  void _tickBullets(double dt) {
    for (var i = bullets.length - 1; i >= 0; i--) {
      final b = bullets[i];
      b.pos = b.pos + b.vel * dt;
      if (b.pos.dy < -20 ||
          b.pos.dx < -20 ||
          b.pos.dx > area.width + 20) {
        bullets.removeAt(i);
        continue;
      }
      var consumed = false;
      for (var j = enemies.length - 1; j >= 0; j--) {
        final e = enemies[j];
        final rad = e.kind == EnemyKind.boss ? 46 : 22;
        if ((e.pos - b.pos).distance < rad) {
          e.hp--;
          _burst(b.pos, const Color(0xFFFFD166), 4, 0.25);
          if (e.hp <= 0) {
            _killEnemy(j);
          } else {
            _sfx('explodeSmall');
          }
          consumed = true;
          break;
        }
      }
      if (consumed) bullets.removeAt(i);
    }
  }

  void _tickEnemies(double dt) {
    final sm = tuning.enemySpeed;
    for (final e in enemies) {
      e.t += dt;
      switch (e.kind) {
        case EnemyKind.dart:
          e.pos = e.pos + Offset(0, (130 + wave * 8) * sm * dt);
        case EnemyKind.weaver:
          e.pos = Offset(e.baseX + sin(e.t * 3.2) * 110, e.pos.dy + 105 * sm * dt);
        case EnemyKind.tank:
          e.pos = e.pos + Offset(sin(e.t * 1.4) * 40 * dt, 62 * sm * dt);
          _enemyFire(e, dt, 2.2, aimed: true);
        case EnemyKind.gunner:
          final targetY = area.height * 0.22;
          final dy = (targetY - e.pos.dy).clamp(-1.0, 1.0);
          e.pos = Offset(
            e.baseX + sin(e.t * 2.1) * 130,
            e.pos.dy + dy * 90 * sm * dt,
          );
          _enemyFire(e, dt, 1.6, aimed: true, burst: 3);
        case EnemyKind.boss:
          e.pos = Offset(area.width / 2 + sin(e.t * 0.9) * (area.width * 0.32), 130);
          _enemyFire(e, dt, 1.1, aimed: true);
          if ((e.t ~/ 3).isEven && e.fireT <= 0.05) {
            for (var k = 0; k < 8; k++) {
              final a = k / 8 * 2 * pi + e.t;
              ebullets.add(Bullet(e.pos, Offset(cos(a), sin(a)) * 170,
                  friendly: false));
            }
            _sfx('enemyLaser');
          }
      }
    }
    enemies.removeWhere((e) => e.pos.dy > area.height + 60);

    // Enemy rams the ship.
    for (var j = enemies.length - 1; j >= 0; j--) {
      if ((enemies[j].pos - ship).distance < 30) {
        _killEnemy(j, scored: false);
        _playerHit();
      }
    }
  }

  void _enemyFire(Enemy e, double dt, double every,
      {bool aimed = false, int burst = 1}) {
    e.fireT -= dt;
    if (e.fireT > 0 || e.pos.dy < 0 || e.pos.dy > area.height * 0.6) return;
    e.fireT = every / tuning.enemyFireMul;
    for (var k = 0; k < burst; k++) {
      final delay = k * 0.12;
      final dir = aimed
          ? (ship - e.pos)
          : const Offset(0, 1);
      final d = dir.distance.clamp(1.0, 999.0);
      final vel = dir / d * tuning.bulletSpeed;
      if (delay == 0) {
        ebullets.add(Bullet(e.pos + const Offset(0, 18), vel, friendly: false));
      } else {
        // Staggered burst: schedule via a short-lived approach — approximate
        // by spawning slightly behind with the same velocity.
        ebullets.add(Bullet(
            e.pos + const Offset(0, 18) - vel * delay, vel,
            friendly: false));
      }
    }
    _sfx('enemyLaser');
  }

  void _tickEnemyBullets(double dt) {
    for (var i = ebullets.length - 1; i >= 0; i--) {
      final b = ebullets[i];
      b.pos = b.pos + b.vel * dt;
      if (b.pos.dy < -20 ||
          b.pos.dy > area.height + 20 ||
          b.pos.dx < -20 ||
          b.pos.dx > area.width + 20) {
        ebullets.removeAt(i);
      } else if ((b.pos - ship).distance < 18) {
        ebullets.removeAt(i);
        _playerHit();
      }
    }
  }

  void _tickPowerups(double dt) {
    for (var i = powers.length - 1; i >= 0; i--) {
      final p = powers[i];
      p.t += dt;
      p.pos = p.pos + Offset(0, 120 * dt);
      if ((ship - p.pos).distance < 32) {
        powers.removeAt(i);
        _collectPower(p.kind);
      } else if (p.pos.dy > area.height + 20) {
        powers.removeAt(i);
      }
    }
  }

  void _collectPower(PowerKind kind) {
    switch (kind) {
      case PowerKind.spread:
        spreadT = 10;
        banner = 'SPREAD SHOT!';
      case PowerKind.shield:
        shieldT = 12;
        banner = 'SHIELD UP!';
      case PowerKind.rapid:
        rapidT = 10;
        banner = 'RAPID FIRE!';
      case PowerKind.life:
        lives = min(lives + 1, 5);
        banner = '+1 SHIP!';
    }
    bannerT = 1.2;
    _burst(ship, const Color(0xFFFFD166), 10, 0.4);
    _sfx('powerup');
    notifyListeners();
  }

  void _killEnemy(int j, {bool scored = true}) {
    final e = enemies[j];
    enemies.removeAt(j);
    final col = switch (e.kind) {
      EnemyKind.dart => const Color(0xFF6B8E4E),
      EnemyKind.weaver => const Color(0xFF7A9A5E),
      EnemyKind.tank => const Color(0xFFB5651D),
      EnemyKind.gunner => const Color(0xFF8A7A3E),
      EnemyKind.boss => const Color(0xFFA31621),
    };
    _explode(e.pos, col, e.kind == EnemyKind.boss ? 44 : 14);
    if (scored) {
      combo++;
      comboT = 2.5;
      final base = switch (e.kind) {
        EnemyKind.dart => 10,
        EnemyKind.weaver => 15,
        EnemyKind.gunner => 20,
        EnemyKind.tank => 30,
        EnemyKind.boss => 500,
      };
      final bonus = combo > 1 ? combo * 5 : 0;
      final pts = base + bonus;
      score += pts;
      popups.add(ScorePopup(
          e.pos, '+$pts${combo > 2 ? '  x$combo' : ''}'));
      kills++;
      _sfx(e.kind == EnemyKind.boss ? 'explodeBig' : 'explodeSmall');
      // Power-up drop (not from bosses — bosses pay out in score).
      if (e.kind != EnemyKind.boss) {
        final roll = _rnd.nextDouble();
        if (roll < 0.02) {
          powers.add(PowerUp(e.pos, PowerKind.life));
        } else if (roll < 0.15) {
          powers.add(PowerUp(
              e.pos, PowerKind.values[_rnd.nextInt(3)]));
        }
      }
    }
    notifyListeners();
  }

  void _explode(Offset pos, Color color, int n) {
    _burst(pos, color, n, 0.7);
  }

  void _burst(Offset pos, Color color, int n, double life) {
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * 2 * pi;
      final s = 60 + _rnd.nextDouble() * 170;
      parts.add(Particle(pos, Offset(cos(a) * s, sin(a) * s), color,
          life: life, size: 3 + _rnd.nextDouble() * 3));
    }
  }

  void _updateParticles(double dt) {
    for (final p in parts) {
      p.t += dt;
      p.pos = p.pos + p.vel * dt;
      p.vel = p.vel * (1 - 2.2 * dt);
    }
    parts.removeWhere((p) => p.t > p.life);
  }

  void _updatePopups(double dt) {
    for (final p in popups) {
      p.t += dt;
      p.pos = p.pos + const Offset(0, -46) * dt;
    }
    popups.removeWhere((p) => p.t > 0.9);
  }

  // ------------------------------------------------------- test hooks
  /// Force a stuck state for watchdog tests (sets a phase timer to 0).
  @visibleForTesting
  void debugExpireTimer() {
    introT = 0;
    clearT = 0;
    warnT = 0;
    deathT = 0;
  }
}
