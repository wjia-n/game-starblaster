import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/space_themes.dart';
import '../theme/space_ui.dart';

/// Custom paint creator (PRO): pick every color of your own theme.
class CustomThemeScreen extends StatefulWidget {
  final StarAudio audio;
  final StarSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const _labels = {
    'bgDeep': 'Deep space',
    'bgMid': 'Panel',
    'card': 'Card',
    'accent': 'Accent',
    'accentDark': 'Accent shade',
    'hull': 'Ship hull',
    'hullDark': 'Hull shade',
    'cockpit': 'Cockpit glass',
    'bullet': 'Bullets',
    'enemyA': 'Light enemies',
    'enemyB': 'Heavy enemies',
    'enemyBoss': 'Boss',
    'text': 'Text',
    'muted': 'Muted text',
  };

  static const _swatches = [
    0xFFE4572E,
    0xFFF2A541,
    0xFFFFD166,
    0xFF7CB350,
    0xFF3E92A8,
    0xFF7FB8D9,
    0xFF9B6BB0,
    0xFFB03040,
    0xFFC9A227,
    0xFFB87333,
    0xFFF5EFE0,
    0xFF8FC3DE,
    0xFF141A2E,
    0xFF1F2740,
    0xFF6B8E4E,
    0xFFB5651D,
  ];

  SpaceThemeDef get _t => SpaceThemes.byId('custom',
      custom: widget.settings.customTheme);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return StarBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: t.text),
          title:
              Text('Custom paint', style: SpaceType.title(20, t)),
          actions: [
            TextButton(
              onPressed: () {
                widget.audio.click();
                s.resetCustomColors();
              },
              child: Text('Reset',
                  style: SpaceType.body(14, t,
                      color: t.accent)),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => ListView(
            padding: const EdgeInsets.all(22),
            children: [
              // Live preview ship.
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: t.bgDeep,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          t.accent.withValues(alpha: 0.5)),
                ),
                child: CustomPaint(
                  painter: _PreviewPainter(theme: t),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ChunkyButton(
                  label: s.themeId == 'custom'
                      ? '✓  USING THIS PAINT'
                      : 'USE THIS PAINT',
                  color: t.accent,
                  bevel: t.accentDark,
                  fontSize: 16,
                  onTap: () {
                    widget.audio.click();
                    s.setTheme('custom');
                  },
                ),
              ),
              for (final key in _labels.keys)
                _ColorRow(
                  label: _labels[key]!,
                  value: Color(s.customColors[key]!),
                  theme: t,
                  onPick: (c) {
                    widget.audio.click();
                    s.setCustomColor(key, c.toARGB32());
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final Color value;
  final SpaceThemeDef theme;
  final ValueChanged<Color> onPick;
  const _ColorRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: value,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white30, width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: SpaceType.body(15, theme)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _CustomThemeScreenState._swatches)
                GestureDetector(
                  onTap: () => onPick(Color(c)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: value.toARGB32() == c
                            ? Colors.white
                            : Colors.black45,
                        width:
                            value.toARGB32() == c ? 3 : 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final SpaceThemeDef theme;
  _PreviewPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()..color = theme.hull;
    final dp = Paint()..color = theme.hullDark;
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 30)
          ..lineTo(c.dx - 17, c.dy + 14)
          ..lineTo(c.dx, c.dy + 7)
          ..lineTo(c.dx + 17, c.dy + 14)
          ..close(),
        dp);
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 26)
          ..lineTo(c.dx - 14, c.dy + 12)
          ..lineTo(c.dx, c.dy + 6)
          ..lineTo(c.dx + 14, c.dy + 12)
          ..close(),
        p);
    canvas.drawCircle(c + const Offset(0, -7), 6,
        Paint()..color = theme.cockpit);
    // Enemy sample.
    canvas.drawCircle(c + const Offset(-70, 10), 14,
        Paint()..color = theme.enemyA);
    canvas.drawCircle(c + const Offset(70, -8), 18,
        Paint()..color = theme.enemyB);
    // Bullet sample.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c + const Offset(0, -52),
                width: 6,
                height: 18),
            const Radius.circular(3)),
        Paint()..color = theme.bullet);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
