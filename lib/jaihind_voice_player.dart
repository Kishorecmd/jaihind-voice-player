/// Playing a voice note.
///
/// Split out of jaihind_voice so an app that only listens does not depend on
/// the recorder. record_android declares RECORD_AUDIO in its own manifest and
/// that merges into whatever depends on it, so the driver app -- which only
/// ever receives voice notes -- would have asked drivers for a microphone it
/// never uses.
library;

export 'src/voice_format.dart';
export 'src/voice_note_player.dart';
export 'src/voice_theme.dart';
export 'src/waveform.dart';
