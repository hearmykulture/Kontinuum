// lib/services/sfx.dart
import 'dart:typed_data';
import 'package:flutter/widgets.dart'; // WidgetsBinding
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:soundpool/soundpool.dart';

/// Minimal, lazy SFX manager for short overlapping sounds.
/// - No platform calls at import time (prevents startup hangs)
/// - Creates Soundpool on first use
/// - Can warm up after first frame
/// - Supports stacking (maxStreams > 1)
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  Soundpool? _pool; // lazily created
  int? _chimeId; // assets/audio/complete_chime.wav
  int? _levelUpId; // assets/audio/levelup.wav
  bool _loading = false;

  /// Optionally call this from a screen's initState:
  /// WidgetsBinding.instance.addPostFrameCallback((_) => Sfx.instance.warmup());
  void scheduleWarmup() {
    WidgetsBinding.instance.addPostFrameCallback((_) => warmup());
  }

  Future<void> _ensurePool() async {
    if (_pool != null) return;
    // Make sure bindings exist before touching platform channels.
    WidgetsFlutterBinding.ensureInitialized();
    _pool = Soundpool.fromOptions(
      options: const SoundpoolOptions(
        streamType: StreamType.music,
        maxStreams: 8, // allow overlapping plays
      ),
    );
  }

  /// Preload both sounds so first play is instant (safe to call many times).
  Future<void> warmup() async {
    if (_loading) return;
    if (_chimeId != null && _levelUpId != null) return;
    _loading = true;
    try {
      await _ensurePool();

      final futures = <Future<void>>[];

      if (_chimeId == null) {
        futures.add(_loadToPool('assets/audio/complete_chime.wav')
            .then((id) => _chimeId = id));
      }
      if (_levelUpId == null) {
        futures.add(_loadToPool('assets/audio/levelup.wav')
            .then((id) => _levelUpId = id));
      }

      await Future.wait(futures);
    } catch (_) {
      // Swallow — audio should never break startup.
    } finally {
      _loading = false;
    }
  }

  /// Fire-and-forget play. If not preloaded, we lazy-load on first play.
  void playComplete({double volume = 1.0}) {
    _play(_chimeId, 'assets/audio/complete_chime.wav', (id) => _chimeId = id,
        volume);
  }

  void playLevelUp({double volume = 1.0}) {
    _play(_levelUpId, 'assets/audio/levelup.wav', (id) => _levelUpId = id,
        volume);
  }

  // ---------- internals ----------
  Future<int> _loadToPool(String asset) async {
    final ByteData data = await rootBundle.load(asset);
    return _pool!.load(data);
  }

  void _play(
    int? cachedId,
    String asset,
    void Function(int) cacheSetter,
    double volume,
  ) async {
    try {
      await _ensurePool();

      int soundId = cachedId ??
          await _loadToPool(asset).then((id) {
            cacheSetter(id);
            return id;
          });

      final streamId = await _pool!.play(soundId);
      if (volume != 1.0) {
        await _pool!.setVolume(
          streamId: streamId,
          volume: volume.clamp(0.0, 1.0),
        );
      }
    } catch (_) {
      // swallow
    }
  }
}
