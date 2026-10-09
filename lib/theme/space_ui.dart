import 'package:flutter/material.dart';
import 'space_themes.dart';

/// Shared UI atoms for Star Blaster: chunky physical buttons, star backdrop,
/// readable type. Everything is drawn with solid warm colors, bevels and
/// shadows — no neon, no holograms.

class SpaceType {
  static TextStyle display(double size, SpaceThemeDef t, {Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: color ?? t.text,
        shadows: [
          Shadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(0, 3),
              blurRadius: 6),
        ],
      );

  static TextStyle title(double size, SpaceThemeDef t, {Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: color ?? t.text,
      );

  static TextStyle body(double size, SpaceThemeDef t, {Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? t.text,
      );

  static TextStyle label(double size, SpaceThemeDef t, {Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: color ?? t.muted,
      );
}

/// Deep-space backdrop: dark gradient + drifting painted stars.
class StarBackdrop extends StatelessWidget {
  final SpaceThemeDef theme;
  final Widget child;
  const StarBackdrop({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bgDeep, theme.bgMid],
        ),
      ),
      child: CustomPaint(
        painter: _BackdropStars(),
        child: child,
      ),
    );
  }
}

class _BackdropStars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    var seed = 7;
    double rnd() {
      seed = (seed * 16807) % 2147483647;
      return seed / 2147483647;
    }

    for (var i = 0; i < 70; i++) {
      final x = rnd() * size.width;
      final y = rnd() * size.height;
      final r = 0.8 + rnd() * 1.6;
      canvas.drawCircle(
          Offset(x, y), r, paint..color = Colors.white.withValues(alpha: 0.25 + rnd() * 0.4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chunky physical button: solid fill, dark bevel edge, soft drop shadow,
/// satisfying press squash.
class ChunkyButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final Color? bevel;
  final double fontSize;
  final EdgeInsets padding;
  final bool locked;

  const ChunkyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.bevel,
    this.fontSize = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    this.locked = false,
  });

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? const Color(0xFFE4572E);
    final b = widget.bevel ?? const Color(0xFF9C3A1D);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(color: b, width: _pressed ? 2 : 5),
              top: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 2),
              left: BorderSide(color: b.withValues(alpha: 0.6), width: 2),
              right: BorderSide(color: b.withValues(alpha: 0.6), width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                offset: Offset(0, _pressed ? 2 : 6),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.locked) ...[
                const Icon(Icons.lock, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        offset: const Offset(0, 2),
                        blurRadius: 3),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small round icon button with the same chunky treatment.
class ChunkyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final SpaceThemeDef theme;
  final double size;
  const ChunkyIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.theme,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.card,
          shape: BoxShape.circle,
          border: Border.all(color: theme.accent.withValues(alpha: 0.7), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: theme.text, size: size * 0.5),
      ),
    );
  }
}

/// Section heading used across menu / settings / pro screens.
class SectionTitle extends StatelessWidget {
  final String text;
  final SpaceThemeDef theme;
  const SectionTitle(this.text, this.theme, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 20, color: theme.accent),
          const SizedBox(width: 10),
          Text(text, style: SpaceType.label(14, theme)),
        ],
      ),
    );
  }
}

/// PRO lock badge.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A227),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7D6518), width: 1.5),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}
