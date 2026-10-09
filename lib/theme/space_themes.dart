import 'package:flutter/material.dart';

/// Theme, ship-style catalog for Star Blaster.
///
/// Art direction: toy-like, cinematic space adventure. Warm physical colors,
/// deep navy starfields, chunky painted ships. NO neon / cyberpunk / hologram
/// aesthetics anywhere — variety comes from hull paint, planet palettes and
/// accent metals.
class SpaceThemeDef {
  final String id;
  final String name;
  final Color bgDeep; // space background
  final Color bgMid; // panel / card surface
  final Color card; // raised card surface
  final Color accent; // primary UI accent (buttons, highlights)
  final Color accentDark; // button bevel shadow
  final Color hull; // player ship hull
  final Color hullDark; // hull shading
  final Color cockpit; // cockpit glass
  final Color bullet; // player bullet color
  final Color enemyA; // light enemy hull
  final Color enemyB; // heavy enemy hull
  final Color enemyBoss; // boss hull
  final Color text;
  final Color muted;

  const SpaceThemeDef({
    required this.id,
    required this.name,
    required this.bgDeep,
    required this.bgMid,
    required this.card,
    required this.accent,
    required this.accentDark,
    required this.hull,
    required this.hullDark,
    required this.cockpit,
    required this.bullet,
    required this.enemyA,
    required this.enemyB,
    required this.enemyBoss,
    required this.text,
    required this.muted,
  });
}

class SpaceThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'rocket_red',
    'dawn_patrol',
    'ocean_abyss',
    'forest_night',
  ];

  static const List<SpaceThemeDef> all = [
    SpaceThemeDef(
      id: 'rocket_red',
      name: 'Rocket Classic',
      bgDeep: Color(0xFF141A2E),
      bgMid: Color(0xFF1F2740),
      card: Color(0xFF2A3352),
      accent: Color(0xFFE4572E),
      accentDark: Color(0xFF9C3A1D),
      hull: Color(0xFFD94F30),
      hullDark: Color(0xFF8F2F1B),
      cockpit: Color(0xFF8FC3DE),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF6B8E4E),
      enemyB: Color(0xFFB5651D),
      enemyBoss: Color(0xFFA31621),
      text: Color(0xFFF5EFE0),
      muted: Color(0xFF9AA3B8),
    ),
    SpaceThemeDef(
      id: 'dawn_patrol',
      name: 'Dawn Patrol',
      bgDeep: Color(0xFF1A1430),
      bgMid: Color(0xFF26204A),
      card: Color(0xFF332B5C),
      accent: Color(0xFFF2A541),
      accentDark: Color(0xFFA66A1F),
      hull: Color(0xFFE8963C),
      hullDark: Color(0xFF9C5F1E),
      cockpit: Color(0xFFA8D5E2),
      bullet: Color(0xFFFFE29A),
      enemyA: Color(0xFF7A8B6F),
      enemyB: Color(0xFF8C5E3C),
      enemyBoss: Color(0xFF7A2E2E),
      text: Color(0xFFFFF3E0),
      muted: Color(0xFFA79BC0),
    ),
    SpaceThemeDef(
      id: 'ocean_abyss',
      name: 'Ocean Abyss',
      bgDeep: Color(0xFF0F1E2A),
      bgMid: Color(0xFF18303F),
      card: Color(0xFF204052),
      accent: Color(0xFF3E92A8),
      accentDark: Color(0xFF245A68),
      hull: Color(0xFF4FA3B8),
      hullDark: Color(0xFF2C6675),
      cockpit: Color(0xFFCFE8EF),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF5E7D6B),
      enemyB: Color(0xFF946B2D),
      enemyBoss: Color(0xFF8C2F39),
      text: Color(0xFFEDF6F7),
      muted: Color(0xFF8FA8B5),
    ),
    SpaceThemeDef(
      id: 'forest_night',
      name: 'Forest Night',
      bgDeep: Color(0xFF121F16),
      bgMid: Color(0xFF1C2F22),
      card: Color(0xFF27402E),
      accent: Color(0xFF7CB350),
      accentDark: Color(0xFF4A7029),
      hull: Color(0xFF6FA34A),
      hullDark: Color(0xFF42662A),
      cockpit: Color(0xFFD7E8C3),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF8B7D4B),
      enemyB: Color(0xFF9C5A2E),
      enemyBoss: Color(0xFF7A3030),
      text: Color(0xFFF0F5E6),
      muted: Color(0xFF93A58C),
    ),
    SpaceThemeDef(
      id: 'solar_flare',
      name: 'Solar Flare',
      bgDeep: Color(0xFF231310),
      bgMid: Color(0xFF332016),
      card: Color(0xFF452C1C),
      accent: Color(0xFFF6B93B),
      accentDark: Color(0xFFA6771F),
      hull: Color(0xFFF0A832),
      hullDark: Color(0xFF9C6A1C),
      cockpit: Color(0xFFFFF0C9),
      bullet: Color(0xFFFFF3B0),
      enemyA: Color(0xFF6E7B4E),
      enemyB: Color(0xFF8A4A2E),
      enemyBoss: Color(0xFF93321F),
      text: Color(0xFFFFF6E3),
      muted: Color(0xFFB89B78),
    ),
    SpaceThemeDef(
      id: 'crimson_fleet',
      name: 'Crimson Fleet',
      bgDeep: Color(0xFF200F16),
      bgMid: Color(0xFF2F1822),
      card: Color(0xFF402230),
      accent: Color(0xFFC9A227),
      accentDark: Color(0xFF7D6518),
      hull: Color(0xFFB03040),
      hullDark: Color(0xFF6E1E28),
      cockpit: Color(0xFFE8D8C0),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF6B7A5E),
      enemyB: Color(0xFF7A5A34),
      enemyBoss: Color(0xFF5E1A24),
      text: Color(0xFFF7EDE4),
      muted: Color(0xFFA98F96),
    ),
    SpaceThemeDef(
      id: 'ice_brigade',
      name: 'Ice Brigade',
      bgDeep: Color(0xFF101A26),
      bgMid: Color(0xFF1A2A3C),
      card: Color(0xFF24394F),
      accent: Color(0xFF7FB8D9),
      accentDark: Color(0xFF4A7591),
      hull: Color(0xFF9CC8E0),
      hullDark: Color(0xFF5A8299),
      cockpit: Color(0xFFF2F9FC),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF6E8A7E),
      enemyB: Color(0xFF8A6E4E),
      enemyBoss: Color(0xFF4E5E7A),
      text: Color(0xFFF0F7FA),
      muted: Color(0xFF8EA3B5),
    ),
    SpaceThemeDef(
      id: 'sandstorm',
      name: 'Sandstorm',
      bgDeep: Color(0xFF211A12),
      bgMid: Color(0xFF2F2718),
      card: Color(0xFF403620),
      accent: Color(0xFFC99B5F),
      accentDark: Color(0xFF7D5E35),
      hull: Color(0xFFC08A4E),
      hullDark: Color(0xFF7A5629),
      cockpit: Color(0xFFF5E6C8),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF7A7A5E),
      enemyB: Color(0xFF8A5E3E),
      enemyBoss: Color(0xFF6E3A2E),
      text: Color(0xFFF8F0DE),
      muted: Color(0xFFA89B7E),
    ),
    SpaceThemeDef(
      id: 'volcano_run',
      name: 'Volcano Run',
      bgDeep: Color(0xFF1E1214),
      bgMid: Color(0xFF2E1C1E),
      card: Color(0xFF402828),
      accent: Color(0xFFE07A3F),
      accentDark: Color(0xFF93491F),
      hull: Color(0xFFC65A34),
      hullDark: Color(0xFF7D371E),
      cockpit: Color(0xFFF5DCC0),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF6E6E5E),
      enemyB: Color(0xFF7D5A3E),
      enemyBoss: Color(0xFF5E1E1E),
      text: Color(0xFFF7EDE2),
      muted: Color(0xFFA8908A),
    ),
    SpaceThemeDef(
      id: 'plum_voyage',
      name: 'Plum Voyage',
      bgDeep: Color(0xFF1E1426),
      bgMid: Color(0xFF2C1F3A),
      card: Color(0xFF3C2B4E),
      accent: Color(0xFFD9A441),
      accentDark: Color(0xFF8A6524),
      hull: Color(0xFF9B6BB0),
      hullDark: Color(0xFF5E3F6E),
      cockpit: Color(0xFFE8D8F0),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF6E8A6E),
      enemyB: Color(0xFF8A7A4E),
      enemyBoss: Color(0xFF5E2E4E),
      text: Color(0xFFF5EDF7),
      muted: Color(0xFFA394B8),
    ),
    SpaceThemeDef(
      id: 'copper_canyon',
      name: 'Copper Canyon',
      bgDeep: Color(0xFF201410),
      bgMid: Color(0xFF2F1F16),
      card: Color(0xFF402C1E),
      accent: Color(0xFFD08A4E),
      accentDark: Color(0xFF82522A),
      hull: Color(0xFFB87333),
      hullDark: Color(0xFF74471E),
      cockpit: Color(0xFFF5E0C0),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF7A7A5E),
      enemyB: Color(0xFF8A6242),
      enemyBoss: Color(0xFF6E3226),
      text: Color(0xFFF8EFE0),
      muted: Color(0xFFAD9682),
    ),
    SpaceThemeDef(
      id: 'arctic_dawn',
      name: 'Arctic Dawn',
      bgDeep: Color(0xFF121820),
      bgMid: Color(0xFF1D2632),
      card: Color(0xFF283646),
      accent: Color(0xFFE8B04B),
      accentDark: Color(0xFF946E26),
      hull: Color(0xFFB8C8D0),
      hullDark: Color(0xFF6E7E88),
      cockpit: Color(0xFF1E2A38),
      bullet: Color(0xFFFFD166),
      enemyA: Color(0xFF6E8A7E),
      enemyB: Color(0xFF8A7A5E),
      enemyBoss: Color(0xFF3E4E5E),
      text: Color(0xFFF2F5F7),
      muted: Color(0xFF93A0AC),
    ),
  ];

  static SpaceThemeDef byId(String id, {SpaceThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) =>
      id != 'custom' && !freeThemeIds.contains(id);
}

/// Ship geometry styles. First 4 are FREE, the rest are PRO.
class ShipStyleDef {
  final String id;
  final String name;
  final bool pro;
  const ShipStyleDef(this.id, this.name, this.pro);
}

class ShipStyles {
  static const List<ShipStyleDef> all = [
    ShipStyleDef('classic', 'Classic Rocket', false),
    ShipStyleDef('dart', 'Star Dart', false),
    ShipStyleDef('bulwark', 'Bulwark', false),
    ShipStyleDef('needle', 'Needle', false),
    ShipStyleDef('falcon', 'Falcon', true),
    ShipStyleDef('mantis', 'Mantis', true),
    ShipStyleDef('titan', 'Titan', true),
    ShipStyleDef('comet', 'Comet', true),
  ];

  static bool isPro(int index) =>
      index < 0 || index >= all.length ? false : all[index].pro;

  static int count() => all.length;
}
