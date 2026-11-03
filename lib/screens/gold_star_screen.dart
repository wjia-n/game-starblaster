import 'package:flutter/material.dart';
import '../services/iap_service.dart';

/// iOS-only Gold Star screen: exactly one purchase button.
/// The game stays fully unlocked; the star is a cosmetic supporter badge.
class GoldStarScreen extends StatefulWidget {
  const GoldStarScreen({super.key});
  @override
  State<GoldStarScreen> createState() => _GoldStarScreenState();
}

class _GoldStarScreenState extends State<GoldStarScreen> {
  final StarStore _store = StarStore();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _store.init().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _store.disposeStore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('\u2b50 Gold Star')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : !_store.storeReady
                  ? Text(
                      _store.error ?? 'Available after store setup',
                      textAlign: TextAlign.center,
                    )
                  : ValueListenableBuilder<bool>(
                      valueListenable: _store.goldStarOwned,
                      builder: (_, owned, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (owned) ...[
                            const Text('\u2b50 Gold Star',
                                style: TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            const Text(
                              'Thank you — you are a Gold Star supporter!',
                              textAlign: TextAlign.center,
                            ),
                          ] else ...[
                            const Text(
                              'Support the game with a Gold Star. '
                              'The game stays fully unlocked.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ValueListenableBuilder<bool>(
                              valueListenable: _store.purchaseInProgress,
                              builder: (_, busy, _) => ElevatedButton(
                                onPressed: busy
                                    ? null
                                    : () {
                                        final prod = _store.starProduct;
                                        if (prod != null) {
                                          _store.buyGoldStar(prod);
                                        }
                                      },
                                child: Text(
                                    '\u2b50 Gold Star${_store.starProduct == null ? '' : ' — ${_store.starProduct!.price}'}'),
                              ),
                            ),
                          ],
                          ValueListenableBuilder<String?>(
                            valueListenable: _store.lastThanks,
                            builder: (_, thanks, _) => thanks == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(thanks,
                                        textAlign: TextAlign.center),
                                  ),
                          ),
                          ValueListenableBuilder<String?>(
                            valueListenable: _store.purchaseError,
                            builder: (_, err, _) => err == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(err,
                                        textAlign: TextAlign.center),
                                  ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
