import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const StarBlasterApp());

class StarBlasterApp extends StatelessWidget {
  const StarBlasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.neonArcade,
      title: 'Star Blaster',
      tagline: 'Dodge the swarm, blast the bosses, own the galaxy!',
      emoji: '🚀',
      slug: 'starblaster',
      howToPlay:
          '• Drag your ship to move — it fires automatically.\n• Blast every alien in the wave to advance.\n• Grab power-ups: Spread shot, Shield, Rapid fire.\n• A boss warps in every 5 waves. Beat the wave-10 boss to win!\n• You have 3 lives. Good hunting, pilot.',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => StarBlasterScreen(players: players, callbacks: cb),
    );
  }
}
