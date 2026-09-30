import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'voice_theme.dart';

/// Playing a voice note the school has sent.
///
/// Without this the app fell through to its image branch and drew "Image
/// unavailable" over a perfectly good recording — the parent could see that
/// their child's teacher had sent something and had no way to hear it.
///
/// Deliberately small: a play button, a bar and a length. No scrubbing, no
/// speed control, no waveform. Nothing downloads until the button is pressed,
/// so a thread of notes costs nothing to scroll past on mobile data.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.url,
    this.background,
    this.duration,
    this.theme,
  });

  final String url;

  /// The colour actually behind this player.
  ///
  /// Contrast is worked out from it rather than taken as a flag from the
  /// caller. That flag existed for one build and was wrong immediately: the
  /// parent app's own bubble is a dark blue and the teacher app's is a pale
  /// green, both were passed "this is the sender's bubble", and the teacher's
  /// voice notes came out white on near-white -- a play button you could not
  /// see. A colour cannot be got wrong in that way.
  final Color? background;

  /// The length, when it is already known from the message.
  ///
  /// Saves showing "Voice note" until the file has been fetched: the duration
  /// is stored with the message precisely so a thread can say "0:18" without
  /// every phone downloading every recording to find out.
  final Duration? duration;

  /// Overrides the ambient theme. Rarely needed.
  final VoiceTheme? theme;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();

  Duration _position = Duration.zero;
  Duration? _length;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _length = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      // Back to the start, so pressing play again replays rather than doing
      // nothing — which reads as the note being broken.
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        return;
      }

      Source source;
      if (widget.url.startsWith('http://') || widget.url.startsWith('https://')) {
        source = UrlSource(widget.url);
      } else {
        source = DeviceFileSource(widget.url);
      }
      await _player.play(source);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static String _clock(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Was a hard-coded blue from the parent app. It now comes from whichever
    // app is drawing it, so the teacher app's own accent is used unchanged.
    final t = widget.theme ?? VoiceTheme.of(context);

    // Light content only on a genuinely dark background.
    final onDark =
        (widget.background ?? Theme.of(context).colorScheme.surface)
            .computeLuminance() <
        0.4;
    final ink = onDark ? Colors.white : t.accent;
    final muted = onDark ? Colors.white70 : t.muted;

    if (_failed) {
      // A note that will not play has to say so. Silence is indistinguishable
      // from a note nobody recorded anything into.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 15, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Voice note could not be played',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ),
        ],
      );
    }

    final total = _length ?? widget.duration;
    final progress = (total == null || total.inMilliseconds == 0)
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        width: 210,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: _playing ? 'Pause voice note' : 'Play voice note',
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: onDark ? Colors.white : const Color(0xFF64748B),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: onDark ? const Color(0xFF2563EB) : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomPaint(
                size: const Size(double.infinity, 24),
                painter: _FakeWaveformPainter(
                  progress: progress,
                  activeColor: onDark ? Colors.white : const Color(0xFF64748B),
                  inactiveColor: onDark ? Colors.white.withAlpha(60) : Colors.black.withAlpha(26),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              total == null ? '0:00' : _clock(total),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: onDark ? Colors.white.withAlpha(200) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeWaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _FakeWaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 30;
    final spacing = size.width / barCount;
    
    // A fixed pseudo-random pattern of bar heights
    final heights = [0.3, 0.5, 0.8, 0.6, 0.4, 0.3, 0.5, 0.9, 0.7, 0.4, 0.3, 0.6, 0.8, 1.0, 0.8, 0.5, 0.3, 0.4, 0.7, 0.9, 0.6, 0.4, 0.3, 0.5, 0.8, 0.5, 0.3, 0.4, 0.6, 0.4];

    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + (spacing / 2);
      final isPlayed = (i / barCount) <= progress;
      paint.color = isPlayed ? activeColor : inactiveColor;
      
      final barHeight = size.height * heights[i % heights.length];
      final top = (size.height - barHeight) / 2;
      
      canvas.drawLine(Offset(x, top), Offset(x, top + barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FakeWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.activeColor != activeColor ||
           oldDelegate.inactiveColor != inactiveColor;
  }
}
