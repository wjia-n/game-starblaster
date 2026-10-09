import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starblaster/engine/starblaster_engine.dart';
import 'package:starblaster/services/settings_service.dart';

/// RULES.md §13 test cases + regression tests for the exemplar patterns.
///
/// The engine owns its phase state machine; tests drive the public API with
/// a fixed RNG seed and call [tick]/[watchdogTick] directly. No UI involved.
StarBlasterEngine makeEngine({
  BlastMode mode = BlastMode.campaign,
  TierTuning tuning = TierTuning.pilot,
}) {
  final e = StarBlasterEngine(mode: mode, tuning: tuning, seed: 42);
  e.ensureShip(const Size(400, 800));
  addTearDown(e.dispose);
  return e;
}

/// Advance the engine by [secs] seconds in 1/60 steps.
void pump(StarBlasterEngine e, double secs) {
  final steps = (secs * 60).round();
  for (var i = 0; i < steps; i++) {
    e.tick(1 / 60);
  }
}

void main() {
  test('1. Launch from ready -> intro -> playing', () {
    final e = makeEngine();
    expect(e.phase, GamePhase.ready);
    e.startGame();
    expect(e.phase, GamePhase.intro);
    pump(e, 1.5);
    expect(e.phase, GamePhase.playing);
  });

  test('2. Clearing a wave advances to the next wave', () {
    final e = makeEngine();
    e.startGame();
    pump(e, 1.5); // intro -> playing
    // Kill everything the wave can spawn.
    e.toSpawn = 0;
    e.enemies.clear();
    e.tick(1 / 60);
    expect(e.phase, GamePhase.waveClear);
    final wave = e.wave;
    pump(e, 1.7); // clear timer -> next wave
    expect(e.phase, GamePhase.intro);
    expect(e.wave, wave + 1);
  });

  test('3. Wave 5 triggers the boss warning, then the boss', () {
    final e = makeEngine();
    e.startGame();
    e.wave = 4; // next wave is 5
    pump(e, 1.5);
    e.toSpawn = 0;
    e.enemies.clear();
    e.tick(1 / 60);
    expect(e.phase, GamePhase.waveClear);
    pump(e, 1.7);
    expect(e.phase, GamePhase.bossWarn);
    expect(e.sfxQueue, contains('bossAlarm'));
    pump(e, 2.1);
    expect(e.phase, GamePhase.playing);
    expect(e.enemies.any((x) => x.kind == EnemyKind.boss), isTrue);
  });

  test('4. Killing the wave-10 boss wins the campaign', () {
    final e = makeEngine();
    e.startGame();
    e.wave = 10;
    pump(e, 1.5); // intro -> playing (boss wave handled below)
    // Force the boss wave directly.
    e.enemies.clear();
    e.toSpawn = 0;
    e.tick(1 / 60); // waveClear
    pump(e, 1.7); // wave 11 > 10 -> victory
    expect(e.phase, GamePhase.victory);
    expect(e.sfxQueue, contains('win'));
  });

  test('5. Shield absorbs exactly one hit', () {
    final e = makeEngine();
    e.startGame();
    pump(e, 1.5);
    e.shieldT = 12;
    final lives = e.lives;
    // Simulate a hit through the private path via enemy bullet contact.
    e.ebullets.add(Bullet(e.ship, Offset.zero, friendly: false));
    e.tick(1 / 60);
    expect(e.shield, isFalse); // shield consumed
    expect(e.lives, lives); // ship survived
  });

  test('6. Last ship lost -> death animation -> game over', () {
    final e = makeEngine(tuning: TierTuning.cadet);
    e.startGame();
    pump(e, 1.5);
    e.lives = 1;
    e.ebullets.add(Bullet(e.ship, Offset.zero, friendly: false));
    e.tick(1 / 60);
    expect(e.phase, GamePhase.dying);
    pump(e, 1.4);
    expect(e.phase, GamePhase.gameOver);
    expect(e.sfxQueue, contains('lose'));
  });

  test('7. Pause/resume round-trips without losing phase', () {
    final e = makeEngine();
    e.startGame();
    pump(e, 1.5);
    expect(e.phase, GamePhase.playing);
    e.pause();
    expect(e.phase, GamePhase.paused);
    final score = e.score;
    pump(e, 1.0); // tick does nothing while paused
    expect(e.score, score);
    e.resume();
    expect(e.phase, GamePhase.playing);
  });

  test('8. Watchdog repairs every stuck phase timer', () {
    // intro stuck
    var e = makeEngine();
    e.startGame();
    e.debugExpireTimer();
    e.watchdogTick();
    expect(e.phase, GamePhase.playing);
    expect(e.watchdogRepairs, 1);

    // waveClear stuck
    e = makeEngine();
    e.startGame();
    pump(e, 1.5);
    e.toSpawn = 0;
    e.enemies.clear();
    e.tick(1 / 60);
    expect(e.phase, GamePhase.waveClear);
    e.debugExpireTimer();
    e.watchdogTick();
    expect(e.phase, GamePhase.intro);
    expect(e.watchdogRepairs, 1);
    expect(e.lastRepair, isNotEmpty);

    // bossWarn stuck
    e = makeEngine();
    e.startGame();
    e.wave = 4;
    pump(e, 1.5);
    e.toSpawn = 0;
    e.enemies.clear();
    e.tick(1 / 60);
    pump(e, 1.7);
    expect(e.phase, GamePhase.bossWarn);
    e.debugExpireTimer();
    e.watchdogTick();
    expect(e.phase, GamePhase.playing);
    expect(e.enemies.any((x) => x.kind == EnemyKind.boss), isTrue);

    // dying stuck
    e = makeEngine();
    e.startGame();
    pump(e, 1.5);
    e.lives = 0;
    e.ebullets.add(Bullet(e.ship, Offset.zero, friendly: false));
    e.tick(1 / 60);
    expect(e.phase, GamePhase.dying);
    e.debugExpireTimer();
    e.watchdogTick();
    expect(e.phase, GamePhase.gameOver);
  });

  test('9. Score attack ends in victory when the timer expires', () {
    final e = makeEngine(mode: BlastMode.attack);
    e.startGame();
    pump(e, 1.5);
    expect(e.phase, GamePhase.playing);
    e.attackT = 0.05;
    e.tick(1 / 60);
    expect(e.phase, GamePhase.victory);
    expect(e.wonByTimeout, isTrue);
  });

  test('10. Power-up pickup announces with a banner', () {
    final e = makeEngine();
    e.startGame();
    pump(e, 1.5);
    e.powers.add(PowerUp(e.ship, PowerKind.spread));
    e.tick(1 / 60);
    expect(e.powers, isEmpty);
    expect(e.spreadT, greaterThan(0));
    expect(e.banner, 'SPREAD SHOT!');
    expect(e.sfxQueue, contains('powerup'));
  });

  test('11. RETRY from game over restarts the run (no dead end dialog)', () {
    final e = makeEngine();
    e.startGame();
    pump(e, 1.5);
    e.lives = 1;
    e.ebullets.add(Bullet(e.ship, Offset.zero, friendly: false));
    e.tick(1 / 60);
    expect(e.phase, GamePhase.dying);
    pump(e, 1.4);
    expect(e.phase, GamePhase.gameOver);
    e.startGame(); // RETRY tapped on the end dialog
    expect(e.phase, GamePhase.intro);
    expect(e.lives, e.tuning.lives);
    expect(e.score, 0);
    expect(e.wave, 1);
  });

  test('12. Cosmetic clock advances while ready (launch prompt animates)', () {
    final e = makeEngine();
    e.tick(1 / 60);
    expect(e.phase, GamePhase.ready);
    expect(e.starT, greaterThan(0));
  });

  test('Profile JSON round-trips and legacy keys migrate', () {
    expect(StarSettings.decodeProfile(null), StarSettings.defaultPilotName);
    expect(
      StarSettings.decodeProfile(StarSettings.encodeProfile('Nova')),
      'Nova',
    );
    // New list encoding survives a restart with order intact.
    expect(StarSettings.decodeProfile('["Zed"]'), 'Zed');
    // Legacy map encoding migrates.
    expect(StarSettings.decodeProfile('{"pilot":"Nova"}'), 'Nova');
    expect(StarSettings.decodeProfile('not-json{{{'),
        StarSettings.defaultPilotName);
    expect(StarSettings.decodeProfile('{"pilot":"  "}'),
        StarSettings.defaultPilotName);
  });
}
