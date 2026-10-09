# Star Blaster — RULES

The authoritative source of truth for gameplay. If the implementation
conflicts with this document, fix the implementation.

## 1. Objective

Pilot your rocket, dodge the alien swarm, and blast every enemy. In
Campaign mode, survive all 10 waves and destroy the wave-10 boss to win.
In Endless mode, survive as long as possible. In Score Attack, score as
much as possible in 150 seconds.

## 2. Setup

- Portrait orientation, touch only.
- The ship starts parked at the bottom-center of the starfield.
- Campaign difficulty select: Cadet (4 ships), Pilot (3 ships),
  Ace (2 ships, Pro only).
- Endless uses Pilot tuning; Score Attack uses Cadet tuning + a 150s timer.
- The pilot picks a paint job (theme), a ship style, and a callsign.

## 3. Turn order

Real-time (no turns). Each frame the engine advances: spawn → move →
collide → score. The ship fires automatically; the player only steers.

## 4. Legal moves

- Drag anywhere on the starfield: the ship chases the drag target.
- The ship is clamped to the lower 65% of the screen and 24px margins.
- Pause / resume / restart / quit at any time (pause menu).
- RETRY / FLY AGAIN on the end dialog restarts the run immediately — the
  engine accepts `startGame` from `ready`, `gameOver` and `victory` phases,
  so a finished run never needs a trip back to the menu.
- Collect falling power-ups by flying into them.

## 5. Illegal moves

- The ship cannot leave the play area (clamped, never an error).
- Input is ignored during `ready`, `dying`, `gameOver`, `victory`, `paused`.
- No input can skip a wave intro, boss warning, or death animation.

## 6. Captures

- A player bullet destroys an enemy when it enters the enemy's hit radius
  (boss: 46px, others: 22px). Multi-HP enemies (tank 3, gunner 2, boss N)
  lose 1 HP per hit.
- An enemy bullet destroys nothing — it damages the ship on contact.
- An enemy ramming the ship destroys the enemy AND damages the ship.

## 7. Special rules

- Power-ups: Spread Shot (10s triple fire), Shield (12s, absorbs one hit),
  Rapid Fire (10s), +1 Ship (max 5 ships). Drop chance 13% per non-boss
  kill; +1 Ship is the rare 2% slice of that.
- Combo: kills within 2.5s of each other chain a combo; each chained kill
  adds combo × 5 bonus points. Taking a hit resets the combo.
- Shield absorbs exactly one hit, then breaks (with 1s invulnerability).
- After any hit: 2s invulnerability (ship blinks).
- Boss waves (Campaign waves 5 and 10): a 2s warning siren, then the
  Void Mauler warps in. Boss kill pays 500 + slow-motion + screen shake.
- Score Attack: the 150s timer runs only during live combat; at 0 the run
  ends in victory ("TIME UP!").

## 8. Scoring

- Dart 10 · Weaver 15 · Gunner 20 · Tank 30 · Boss 500.
- Wave-clear bonus: 100 × wave number. Boss-down bonus: 500.
- Combo bonus: +combo × 5 per chained kill (combo ≥ 2).
- Every point is announced with a floating "+N" popup — no silent scoring.

## 9. Winning conditions

- Campaign: destroy the wave-10 boss → VICTORY ("GALAXY SAVED!").
- Score Attack: survive until the timer ends → VICTORY ("TIME UP!").
- Endless: there is no victory; the run ends only in defeat.

## 10. Draw conditions

None — every run ends in victory or defeat.

## 11. AI strategy

Enemy behaviors (deterministic per seeded RNG):
- Dart: dives straight down.
- Weaver: sine-wave descent.
- Tank: slow descent, fires aimed shots every ~2.2s.
- Gunner: strafes across the upper third, fires 3-round aimed bursts.
- Boss: hovers across the top, fires aimed shots + radial bullet rings.
- Speed, fire rate, HP, and spawn counts scale with wave number and
  difficulty tier (Cadet 0.8× / Pilot 1.0× / Ace 1.25× enemy speed).

## 12. Edge cases

- Wave with zero live enemies and zero pending spawns → wave-clear phase
  (engine-owned; watchdog repairs if the timer ever stalls).
- Ship hit at 0 ships → death animation (1.3s) → GAME OVER.
- App backgrounded mid-run → engine pauses; music pauses and resumes.
- Store products not configured → Pro screen shows an honest
  "available after store setup" state; no fake buy buttons.
- Corrupt/missing settings → defaults (never a crash).

## 13. Test cases

1. Launch from ready → intro (1.4s banner) → playing.
2. Kill every enemy of a wave → wave-clear banner + bonus popup →
   next wave intro.
3. Campaign wave 5 → boss warning siren → boss spawns → boss HP bar shown.
4. Campaign wave-10 boss killed → victory.
5. Ship hit with shield → shield breaks, ship survives, 1s invuln.
6. Ship hit at 1 ship left → death animation → game over.
7. Pause during boss fight → resume returns to the boss fight intact.
8. Watchdog: expire any phase timer artificially → engine self-repairs to
   the correct next phase (no stuck state).
9. Score Attack: timer hits 0 mid-combat → victory with timeout headline.
10. Power-up pickup → banner + effect timer shown in the status strip.
