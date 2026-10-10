import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/space_themes.dart';

/// Persisted settings + stats for Star Blaster. Survives app restarts.
///
/// The pilot profile (display name) is stored as ONE JSON string under
/// [_kProfileJson]. Android's SharedPreferences stores StringLists as an
/// unordered StringSet, so ordered or structured data must never use
/// setStringList — a single JSON string is order-safe by construction.
/// Legacy plain-string keys are migrated once on load, then removed.
class StarSettings extends ChangeNotifier {
  static const _kMusic = 'sb_music_on';
  static const _kSfx = 'sb_sfx_on';
  static const _kVolume = 'sb_volume';
  static const _kProfileJson = 'starblaster_player_names_json';
  static const _kProfileMapLegacy = 'sb_profile_json'; // legacy {"pilot": ...}
  static const _kPilotLegacy = 'sb_pilot_name'; // legacy plain key
  static const _kBestLegacy = 'starblaster_best'; // legacy int from v1 build
  static const _kTheme = 'sb_theme_id';
  static const _kShip = 'sb_ship_style';
  static const _kDifficulty = 'sb_difficulty'; // 0 cadet, 1 pilot, 2 ace
  static const _kMode = 'sb_mode'; // 0 campaign, 1 endless, 2 score attack
  static const _kGames = 'sb_games_played';
  static const _kWins = 'sb_victories';
  static const _kBestPrefix = 'sb_best_';
  static const _kIsPro = 'sb_is_pro';
  static const _kReviewAsked = 'sb_review_asked';
  static const _kCustomPrefix = 'sb_custom_';

  static const defaultPilotName = 'Ace';

  /// Order-safe profile encoding: a single JSON string holding the name
  /// list (one pilot for this single-player game). Never setStringList:
  /// Android backs that with an unordered StringSet, which scrambles slot
  /// order across restarts.
  static String encodeProfile(String pilotName) =>
      jsonEncode([pilotName.trim().isEmpty ? defaultPilotName : pilotName.trim()]);

  static String decodeProfile(String? raw) {
    if (raw == null) return defaultPilotName;
    try {
      final d = jsonDecode(raw);
      if (d is List && d.isNotEmpty) {
        final n = (d.first as String? ?? '').trim();
        if (n.isNotEmpty) return n;
      }
      if (d is Map) {
        // Legacy {"pilot": ...} encoding.
        final n = (d['pilot'] as String? ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    return defaultPilotName;
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String pilotName = defaultPilotName;
  String themeId = 'rocket_red';
  int shipStyle = 0;
  int difficulty = 1; // pilot (normal) default
  int mode = 0; // campaign default
  int gamesPlayed = 0;
  int victories = 0;
  bool isPro = true; // everything unlocked — no Pro version
  bool reviewAsked = false;

  /// Best scores per mode key: cadet / pilot / ace / endless / attack.
  Map<String, int> bestScores = {
    'cadet': 0,
    'pilot': 0,
    'ace': 0,
    'endless': 0,
    'attack': 0,
  };

  /// Custom theme colors (ARGB ints). Defaults mirror Rocket Classic.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'bgDeep': 0xFF141A2E,
    'bgMid': 0xFF1F2740,
    'card': 0xFF2A3352,
    'accent': 0xFFE4572E,
    'accentDark': 0xFF9C3A1D,
    'hull': 0xFFD94F30,
    'hullDark': 0xFF8F2F1B,
    'cockpit': 0xFF8FC3DE,
    'bullet': 0xFFFFD166,
    'enemyA': 0xFF6B8E4E,
    'enemyB': 0xFFB5651D,
    'enemyBoss': 0xFFA31621,
    'text': 0xFFF5EFE0,
    'muted': 0xFF9AA3B8,
  };

  /// Builds the user-designed custom theme from stored colors.
  SpaceThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return SpaceThemeDef(
      id: 'custom',
      name: 'My Creation',
      bgDeep: c('bgDeep'),
      bgMid: c('bgMid'),
      card: c('card'),
      accent: c('accent'),
      accentDark: c('accentDark'),
      hull: c('hull'),
      hullDark: c('hullDark'),
      cockpit: c('cockpit'),
      bullet: c('bullet'),
      enemyA: c('enemyA'),
      enemyB: c('enemyB'),
      enemyBoss: c('enemyBoss'),
      text: c('text'),
      muted: c('muted'),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Pilot profile: prefer the order-safe JSON key; migrate the legacy
    // map key and the legacy plain-string key once, then drop them.
    final profileRaw = p.getString(_kProfileJson);
    if (profileRaw != null) {
      pilotName = decodeProfile(profileRaw);
    } else {
      final legacyMap = p.getString(_kProfileMapLegacy);
      final legacy = legacyMap != null
          ? decodeProfile(legacyMap)
          : (p.getString(_kPilotLegacy) ?? '').trim();
      pilotName = legacy.isEmpty ? defaultPilotName : legacy;
    }
    // Legacy v1 best score -> campaign pilot best.
    final legacyBest = p.getInt(_kBestLegacy);
    themeId = p.getString(_kTheme) ?? 'rocket_red';
    shipStyle = (p.getInt(_kShip) ?? 0).clamp(0, ShipStyles.count() - 1);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 2);
    gamesPlayed = p.getInt(_kGames) ?? 0;
    victories = p.getInt(_kWins) ?? 0;
    isPro = true; // everything unlocked
    reviewAsked = p.getBool(_kReviewAsked) ?? false;
    for (final k in bestScores.keys.toList()) {
      bestScores[k] = p.getInt('$_kBestPrefix$k') ?? 0;
    }
    if (legacyBest != null && legacyBest > (bestScores['pilot'] ?? 0)) {
      bestScores['pilot'] = legacyBest;
    }
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfileJson, encodeProfile(pilotName));
    await p.remove(_kProfileMapLegacy); // legacy map encoding, migrated
    await p.remove(_kPilotLegacy); // legacy key dropped for good
    await p.remove(_kBestLegacy); // migrated into sb_best_pilot
    await p.setString(_kTheme, themeId);
    await p.setInt(_kShip, shipStyle);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kMode, mode);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kWins, victories);
    await p.setBool(_kIsPro, isPro);
    await p.setBool(_kReviewAsked, reviewAsked);
    for (final e in bestScores.entries) {
      await p.setInt('$_kBestPrefix${e.key}', e.value);
    }
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp Pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || SpaceThemes.isProTheme(themeId)) {
      themeId = 'rocket_red';
      changed = true;
    }
    if (ShipStyles.isPro(shipStyle)) {
      shipStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPilotName(String name) async {
    final clean = name.trim();
    pilotName = clean.isEmpty ? defaultPilotName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || SpaceThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setShipStyle(int v) async {
    v = v.clamp(0, ShipStyles.count() - 1);
    if (!isPro && ShipStyles.isPro(v)) return;
    shipStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return; // Ace tier is a Pro feature
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 2);
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setReviewAsked() async {
    reviewAsked = true;
    await _save();
  }

  /// Record a finished game. [modeKey] is one of cadet/pilot/ace/endless/attack.
  Future<void> recordGame({required String modeKey, required int score, required bool won}) async {
    gamesPlayed++;
    if (won) victories++;
    if (score > (bestScores[modeKey] ?? 0)) bestScores[modeKey] = score;
    notifyListeners();
    await _save();
  }

  Future<void> resetStats() async {
    gamesPlayed = 0;
    victories = 0;
    bestScores = {for (final k in bestScores.keys) k: 0};
    notifyListeners();
    await _save();
  }
}
