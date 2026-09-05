/// Reading a voice note's numbers.
///
/// The half of the shared voice rules that a LISTENER needs: how long it is,
/// and what shape it was. The other half -- the recording limits, the loudness
/// maths, the slide-to-cancel distance -- lives with the recorder, because an
/// app that only plays notes back has no use for it and should not carry a
/// microphone dependency to get it.
class VoiceFormat {
  /// How many bars a stored waveform holds.
  static const int waveformBars = 40;

  /// "0:07", and "1:05" rather than "1:5".
  static String clock(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$m:$s';
  }

  /// Reads the compact waveform stored with a message: two digits per bar.
  ///
  /// Anything malformed gives an empty list, and the player then draws its
  /// neutral pattern rather than throwing. A note recorded before waveforms
  /// existed, or by another app, simply has no shape -- and drawing a made-up
  /// one would be claiming to know what somebody's voice looked like.
  static List<double> decodeWaveform(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty || text.length.isOdd) return const [];

    final out = <double>[];
    for (var i = 0; i < text.length; i += 2) {
      final n = int.tryParse(text.substring(i, i + 2));
      if (n == null) return const [];
      out.add((n / 99).clamp(0.0, 1.0));
    }

    return out;
  }
}
