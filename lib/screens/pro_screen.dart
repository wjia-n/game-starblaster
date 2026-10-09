import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/space_themes.dart';
import '../theme/space_ui.dart';

/// Pro screen: Free-vs-Pro comparison, Pro unlock, tip jar, restore.
/// Graceful when the store products are not configured yet.
class ProScreen extends StatefulWidget {
  final StarAudio audio;
  final StarSettings settings;
  final StarStore store;
  const ProScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  StarStore get _store => widget.store;
  SpaceThemeDef get _t =>
      SpaceThemes.byId(widget.settings.themeId, custom: widget.settings.customTheme);

  @override
  void initState() {
    super.initState();
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
    _store.purchaseError.addListener(_onError);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.powerup();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: SpaceType.body(15, _t)),
        backgroundColor: _t.bgMid,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      widget.audio.win();
      setState(() {});
    }
  }

  void _onError() {
    final err = _store.purchaseError.value;
    if (err == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err, style: SpaceType.body(14, _t)),
        backgroundColor: const Color(0xFF7A2E2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.purchaseError.removeListener(_onError);
    super.dispose();
  }

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
          title: Text('Star Blaster PRO', style: SpaceType.title(20, t)),
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.isPro)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '★ PRO is active — enjoy the full galaxy, pilot!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                  )
                else ...[
                  Text('Free vs Pro',
                      style: SpaceType.display(26, t)),
                  const SizedBox(height: 4),
                  Text('One upgrade. The whole galaxy.',
                      style: SpaceType.body(14, t, color: t.muted)),
                  const SizedBox(height: 14),
                  _compareTable(t),
                  const SizedBox(height: 18),
                  _buyProSection(t, s),
                ],
                const SizedBox(height: 10),
                SectionTitle('Tip Jar', t),
                Text(
                  'Star Blaster is made by one indie pilot. Tips keep the rockets fueled — thank you!',
                  style: SpaceType.body(13, t, color: t.muted),
                ),
                const SizedBox(height: 10),
                _tipJar(t),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () {
                      widget.audio.click();
                      _store.restore();
                    },
                    child: Text('Restore purchases',
                        style: SpaceType.body(14, t,
                            color: t.accent)),
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: _store.purchaseError,
                  builder: (_, err, __) => err == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding:
                              const EdgeInsets.only(top: 8),
                          child: Text(err,
                              textAlign: TextAlign.center,
                              style: SpaceType.body(
                                  13, t,
                                  color: const Color(0xFFE07A5F))),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compareTable(SpaceThemeDef t) {
    final rows = [
      ('All 3 mission modes', true, true),
      ('4 starter paint jobs', true, true),
      ('4 starter ship styles', true, true),
      ('8 more paint jobs', false, true),
      ('4 more ship styles', false, true),
      ('Custom paint creator', false, true),
      ('Ace difficulty tier', false, true),
    ];
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: t.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(
                    width: 64,
                    child: Text('FREE',
                        textAlign: TextAlign.center,
                        style: SpaceType.label(12, t))),
                SizedBox(
                    width: 64,
                    child: Text('PRO',
                        textAlign: TextAlign.center,
                        style: SpaceType.label(12, t,
                            color: t.accent))),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(
                        bottom: BorderSide(
                            color: Colors.white
                                .withValues(alpha: 0.08)))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(rows[i].$1,
                          style: SpaceType.body(14, t))),
                  SizedBox(
                    width: 64,
                    child: Icon(
                      rows[i].$2 ? Icons.check : Icons.close,
                      color: rows[i].$2
                          ? t.accent
                          : t.muted.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Icon(Icons.check,
                        color: t.accent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buyProSection(SpaceThemeDef t, StarSettings s) {
    return ValueListenableBuilder<bool>(
      valueListenable: _store.purchaseInProgress,
      builder: (_, busy, __) {
        final product = _store.proProduct;
        if (!_store.storeReady || product == null) {
          // Honest pre-launch state: products not created in Play Console yet.
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              _store.error ??
                  'Pro unlock will be available after store setup.',
              textAlign: TextAlign.center,
              style:
                  SpaceType.body(14, t, color: t.muted),
            ),
          );
        }
        return Column(
          children: [
            ChunkyButton(
              label: busy
                  ? 'CONTACTING STORE…'
                  : 'UNLOCK PRO · ${product.price}',
              color: const Color(0xFFC9A227),
              bevel: const Color(0xFF7D6518),
              fontSize: 17,
              onTap: busy
                  ? null
                  : () {
                      widget.audio.click();
                      _store.buyPro();
                    },
            ),
            const SizedBox(height: 6),
            Text('One-time purchase · yours forever',
                style:
                    SpaceType.body(12, t, color: t.muted)),
          ],
        );
      },
    );
  }

  Widget _tipJar(SpaceThemeDef t) {
    return ValueListenableBuilder<bool>(
      valueListenable: _store.purchaseInProgress,
      builder: (_, busy, __) {
        if (!_store.storeReady) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _store.error ??
                  'Tip jar opens after store setup.',
              textAlign: TextAlign.center,
              style:
                  SpaceType.body(14, t, color: t.muted),
            ),
          );
        }
        final tips = [
          _store.coffeeProduct,
          _store.chocolateProduct,
        ].whereType<ProductDetails>().toList();
        if (tips.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('Tip jar opens after store setup.',
                textAlign: TextAlign.center,
                style:
                    SpaceType.body(14, t, color: t.muted)),
          );
        }
        return Row(
          children: [
            for (final tip in tips)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: tip == tips.last ? 0 : 10),
                  child: ChunkyButton(
                    label: busy
                        ? '…'
                        : '${tip.id == StarStore.coffeeId ? '☕' : '🍫'} ${tip.price}',
                    color: t.card,
                    bevel: Colors.black54,
                    fontSize: 15,
                    onTap: busy
                        ? null
                        : () {
                            widget.audio.click();
                            _store.buyTip(tip);
                          },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
