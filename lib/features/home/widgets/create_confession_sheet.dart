import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../providers/feed_provider.dart';
import '../providers/tea_feed_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kBg       = Color(0xFF07070F); // matches AppColors.backgroundMain
const _kSurface  = Color(0xFF0F0F1A);
const _kBorder   = Color(0xFF1C1C2A);
const _kLine     = Color(0xFF141420);

const _kSpillHints = [
  'What are you not saying out loud?',
  'Say it. No one knows it\'s you.',
  'Something on your mind?',
];

const _spillMaxSecs = 30;
const _teaMaxSecs   = 60;

// ─────────────────────────────────────────────────────────────────────────────
// Root sheet
// ─────────────────────────────────────────────────────────────────────────────

class CreateConfessionSheet extends ConsumerStatefulWidget {
  const CreateConfessionSheet({super.key});

  @override
  ConsumerState<CreateConfessionSheet> createState() =>
      _CreateConfessionSheetState();
}

class _CreateConfessionSheetState extends ConsumerState<CreateConfessionSheet>
    with SingleTickerProviderStateMixin {

  bool _expanded = false;

  late final PageController _pageCtrl;
  int _tabIndex = 0;

  // Spill
  final _spillHeadingCtrl = TextEditingController();
  final _spillBodyCtrl    = TextEditingController();
  final _spillFocus       = FocusNode();
  late final String _spillHint;

  // Tea
  final _teaHeadingCtrl = TextEditingController();
  final _teaFocus       = FocusNode();

  // Voice — shared across both tabs
  _VoiceState  _voiceState = _VoiceState.idle;
  String?      _recPath;
  int          _recSecs  = 0;
  int          _elapsed  = 0;
  Timer?       _recTimer;
  // 30 bar amplitudes
  final List<double> _amps = List.filled(30, 0.08);

  bool get _isSpill  => _tabIndex == 0;
  int  get _maxSecs  => _isSpill ? _spillMaxSecs : _teaMaxSecs;

  bool get _canPost {
    if (_isSpill) return _spillHeadingCtrl.text.trim().isNotEmpty;
    return _teaHeadingCtrl.text.trim().isNotEmpty && _recPath != null;
  }

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _spillHint = _kSpillHints[Random().nextInt(_kSpillHints.length)];
    _pageCtrl  = PageController();
    _spillHeadingCtrl.addListener(() => setState(() {}));
    _spillBodyCtrl.addListener(() => setState(() {}));
    _teaHeadingCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(380.ms, () {
        if (mounted) _spillFocus.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _spillHeadingCtrl.dispose();
    _spillBodyCtrl.dispose();
    _spillFocus.dispose();
    _teaHeadingCtrl.dispose();
    _teaFocus.dispose();
    _recTimer?.cancel();
    AudioService.instance.stop();
    super.dispose();
  }

  // ── tab ───────────────────────────────────────────────────────────────────

  void _switchTab(int i) {
    if (i == _tabIndex) return;
    HapticFeedback.selectionClick();
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  // ── recording ─────────────────────────────────────────────────────────────

  Future<void> _startRec() async {
    final ok = await AudioService.instance.hasPermission();
    if (!ok && mounted) {
      FessSnackbar.show(context, 'Microphone permission required.',
          type: SnackbarType.error);
      return;
    }
    await AudioService.instance.startRecording();
    setState(() {
      _voiceState = _VoiceState.recording;
      _elapsed = 0;
      for (int i = 0; i < _amps.length; i++) _amps[i] = 0.08;
    });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _maxSecs) _stopRec();
    });
    AudioService.instance.amplitudeStream.listen((a) {
      if (!mounted || _voiceState != _VoiceState.recording) return;
      final norm = ((a.current + 60) / 60).clamp(0.06, 1.0);
      setState(() {
        _amps.removeAt(0);
        _amps.add(norm);
      });
    });
  }

  Future<void> _stopRec() async {
    _recTimer?.cancel();
    final path = await AudioService.instance.stopRecording();
    if (!mounted) return;
    if (path == null) { setState(() => _voiceState = _VoiceState.idle); return; }
    final dur = await AudioService.instance.getFileDurationSeconds(path);
    setState(() {
      _voiceState = _VoiceState.recorded;
      _recPath    = path;
      _recSecs    = dur > 0 ? dur : _elapsed;
    });
  }

  Future<void> _discardRec() async {
    _recTimer?.cancel();
    await AudioService.instance.cancelRecording();
    await AudioService.instance.stop();
    setState(() {
      _voiceState = _VoiceState.idle;
      _recPath    = null;
      _recSecs    = 0;
      _elapsed    = 0;
      for (int i = 0; i < _amps.length; i++) _amps[i] = 0.08;
    });
  }

  // ── post ──────────────────────────────────────────────────────────────────

  Future<void> _post() async {
    if (!_canPost) return;
    HapticFeedback.mediumImpact();
    bool ok;
    if (_isSpill) {
      ok = await ref.read(createPostProvider.notifier).createConfession(
        heading: _spillHeadingCtrl.text,
        body: _spillBodyCtrl.text.isNotEmpty ? _spillBodyCtrl.text : null,
        voiceNotePath: _recPath,
        voiceDurationSeconds: _recPath != null ? _recSecs : null,
      );
    } else {
      ok = await ref.read(createTeaProvider.notifier).createTea(
        heading: _teaHeadingCtrl.text,
        localAudioPath: _recPath!,
        audioDurationSeconds: _recSecs,
      );
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      FessSnackbar.show(
        context,
        _isSpill ? 'Posted.' : 'Tea dropped.',
        type: SnackbarType.success,
      );
    } else {
      FessSnackbar.show(context, 'Failed. Try again.',
          type: SnackbarType.error);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPosting = ref.watch(createPostProvider) ||
        ref.watch(createTeaProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      height: _expanded ? screenH : null,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            mainAxisSize: _expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _DragHandle(),
              _SheetHeader(
                expanded: _expanded,
                onClose:  () => Navigator.of(context).pop(),
                onExpand: () => setState(() => _expanded = !_expanded),
              ),
              _TabRow(index: _tabIndex, onTap: _switchTab),
              Container(height: 0.5, color: _kLine, margin:
              const EdgeInsets.only(top: 6)),
              Flexible(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _tabIndex = i);
                  },
                  children: [
                    // ── Spill tab ──────────────────────────────────────────
                    _SpillTab(
                      headingCtrl: _spillHeadingCtrl,
                      bodyCtrl:    _spillBodyCtrl,
                      focus:       _spillFocus,
                      hint:        _spillHint,
                      expanded:    _expanded,
                      voiceState:  _voiceState,
                      elapsed:     _elapsed,
                      recSecs:     _recSecs,
                      recPath:     _recPath,
                      amps:        List.unmodifiable(_amps),
                      onStart:     _startRec,
                      onStop:      _stopRec,
                      onDiscard:   _discardRec,
                    ),
                    // ── Tea tab ────────────────────────────────────────────
                    _TeaTab(
                      headingCtrl: _teaHeadingCtrl,
                      focus:       _teaFocus,
                      voiceState:  _voiceState,
                      elapsed:     _elapsed,
                      recSecs:     _recSecs,
                      recPath:     _recPath,
                      amps:        List.unmodifiable(_amps),
                      onStart:     _startRec,
                      onStop:      _stopRec,
                      onDiscard:   _discardRec,
                    ),
                  ],
                ),
              ),
              // ── Footer ───────────────────────────────────────────────────
              Container(height: 0.5, color: _kLine),
              _PostBar(
                isSpill:   _isSpill,
                bodyLen:   _spillBodyCtrl.text.length,
                canPost:   _canPost,
                isPosting: isPosting,
                onPost:    _post,
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(
        begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}

enum _VoiceState { idle, recording, recorded }

// ─────────────────────────────────────────────────────────────────────────────
// Sheet chrome
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      width: 34, height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback onClose;
  final VoidCallback onExpand;
  const _SheetHeader({
    required this.expanded, required this.onClose, required this.onExpand});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
    child: Row(children: [
      Text('New Post',
          style: AppTypography.labelLarge.copyWith(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, letterSpacing: -0.2)),
      const Spacer(),
      _ChromeBtn(
          icon: expanded ? LucideIcons.minimize2 : LucideIcons.maximize2,
          onTap: onExpand),
      const SizedBox(width: 4),
      _ChromeBtn(icon: LucideIcons.x, onTap: onClose),
    ]),
  );
}

class _ChromeBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ChromeBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: SizedBox(
        width: 36, height: 36,
        child: Center(
            child: Icon(icon, size: 15, color: AppColors.textSecondary))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs
// ─────────────────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _TabRow({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: Row(children: [
      _TabChip(label: 'Spill', active: index == 0, onTap: () => onTap(0)),
      const SizedBox(width: 8),
      _TabChip(label: 'Tea',   active: index == 1, onTap: () => onTap(1)),
    ]),
  );
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? AppColors.accentPrimary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: active
                ? AppColors.accentPrimary.withOpacity(0.40)
                : const Color(0xFF222230),
            width: 0.8),
      ),
      child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppTypography.bodySmall.copyWith(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active
                  ? AppColors.accentPrimary
                  : AppColors.textSecondary),
          child: Text(label)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Spill tab
// ─────────────────────────────────────────────────────────────────────────────

class _SpillTab extends StatelessWidget {
  final TextEditingController headingCtrl;
  final TextEditingController bodyCtrl;
  final FocusNode focus;
  final String hint;
  final bool expanded;
  final _VoiceState voiceState;
  final int elapsed;
  final int recSecs;
  final String? recPath;
  final List<double> amps;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  const _SpillTab({
    required this.headingCtrl,
    required this.bodyCtrl,
    required this.focus,
    required this.hint,
    required this.expanded,
    required this.voiceState,
    required this.elapsed,
    required this.recSecs,
    required this.recPath,
    required this.amps,
    required this.onStart,
    required this.onStop,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    physics: const BouncingScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // heading field
        TextField(
          controller: headingCtrl,
          focusNode: focus,
          maxLength: 100,
          maxLines: null,
          buildCounter: (_, {required currentLength,
            required isFocused, maxLength}) => null,
          style: AppTypography.bodyMedium.copyWith(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary, height: 1.4),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMedium.copyWith(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.hintText, height: 1.4),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        // char counter for heading
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedOpacity(
            opacity: headingCtrl.text.length > 80 ? 1.0 : 0.0,
            duration: 200.ms,
            child: Text('${headingCtrl.text.length}/100',
                style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: headingCtrl.text.length > 90
                        ? AppColors.errorLight
                        : AppColors.hintText)),
          ),
        ),
        _Thin(),
        // body field
        TextField(
          controller: bodyCtrl,
          maxLength: 500,
          maxLines: null,
          minLines: expanded ? 5 : 2,
          buildCounter: (_, {required currentLength,
            required isFocused, maxLength}) => null,
          style: AppTypography.bodySmall.copyWith(
              fontSize: 14.5, color: AppColors.textSecondary, height: 1.65),
          decoration: InputDecoration(
            hintText: 'More detail... (optional)',
            hintStyle: AppTypography.bodySmall.copyWith(
                fontSize: 14.5, color: AppColors.hintText, height: 1.65),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 16),
        // ── voice widget always present ───────────────────────────────────
        VoiceWidget(
          optional: true,
          maxSecs: _spillMaxSecs,
          voiceState: voiceState,
          elapsed: elapsed,
          recSecs: recSecs,
          recPath: recPath,
          amps: amps,
          onStart: onStart,
          onStop: onStop,
          onDiscard: onDiscard,
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tea tab
// ─────────────────────────────────────────────────────────────────────────────

class _TeaTab extends StatelessWidget {
  final TextEditingController headingCtrl;
  final FocusNode focus;
  final _VoiceState voiceState;
  final int elapsed;
  final int recSecs;
  final String? recPath;
  final List<double> amps;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  const _TeaTab({
    required this.headingCtrl,
    required this.focus,
    required this.voiceState,
    required this.elapsed,
    required this.recSecs,
    required this.recPath,
    required this.amps,
    required this.onStart,
    required this.onStop,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    physics: const BouncingScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // heading
        TextField(
          controller: headingCtrl,
          focusNode: focus,
          maxLength: 100,
          maxLines: null,
          buildCounter: (_, {required currentLength,
            required isFocused, maxLength}) => null,
          style: AppTypography.bodyMedium.copyWith(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary, height: 1.4),
          decoration: InputDecoration(
            hintText: "What's the tea?",
            hintStyle: AppTypography.bodyMedium.copyWith(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.hintText, height: 1.4),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedOpacity(
            opacity: headingCtrl.text.length > 80 ? 1.0 : 0.0,
            duration: 200.ms,
            child: Text('${headingCtrl.text.length}/100',
                style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: headingCtrl.text.length > 90
                        ? AppColors.errorLight
                        : AppColors.hintText)),
          ),
        ),
        _Thin(),
        const SizedBox(height: 12),
        // voice widget — required for Tea
        VoiceWidget(
          optional: false,
          maxSecs: _teaMaxSecs,
          voiceState: voiceState,
          elapsed: elapsed,
          recSecs: recSecs,
          recPath: recPath,
          amps: amps,
          onStart: onStart,
          onStop: onStop,
          onDiscard: onDiscard,
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice widget — Spotify-grade player UX
// Public so confession_card.dart can reuse it for playback
// ─────────────────────────────────────────────────────────────────────────────

class VoiceWidget extends StatelessWidget {
  final bool optional;
  final int maxSecs;
  final _VoiceState voiceState;
  final int elapsed;
  final int recSecs;
  final String? recPath;
  final List<double> amps;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  const VoiceWidget({
    super.key,
    required this.optional,
    required this.maxSecs,
    required this.voiceState,
    required this.elapsed,
    required this.recSecs,
    required this.recPath,
    required this.amps,
    required this.onStart,
    required this.onStop,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 240),
    transitionBuilder: (child, anim) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child),
    ),
    child: switch (voiceState) {
      _VoiceState.idle      => _VoiceIdle(
          key: const ValueKey('v-idle'),
          optional: optional,
          maxSecs: maxSecs,
          onStart: onStart),
      _VoiceState.recording => _VoiceRecording(
          key: const ValueKey('v-rec'),
          elapsed: elapsed,
          maxSecs: maxSecs,
          amps: amps,
          onStop: onStop),
      _VoiceState.recorded  => _VoiceRecorded(
          key: const ValueKey('v-done'),
          recSecs: recSecs,
          path: recPath!,
          onDiscard: onDiscard),
    },
  );
}

// ── Idle ──────────────────────────────────────────────────────────────────────

class _VoiceIdle extends StatefulWidget {
  final bool optional;
  final int maxSecs;
  final VoidCallback onStart;
  const _VoiceIdle({super.key, required this.optional,
    required this.maxSecs, required this.onStart});

  @override
  State<_VoiceIdle> createState() => _VoiceIdleState();
}

class _VoiceIdleState extends State<_VoiceIdle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: 100.ms, lowerBound: 0, upperBound: 1);
  }
  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _press.forward(),
    onTapUp: (_) {
      _press.reverse();
      HapticFeedback.mediumImpact();
      widget.onStart();
    },
    onTapCancel: () => _press.reverse(),
    child: AnimatedBuilder(
      animation: _press,
      builder: (_, child) => Transform.scale(
          scale: 1.0 - (_press.value * 0.03),
          child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child: Icon(LucideIcons.mic, size: 16,
                      color: AppColors.accentPrimary)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    widget.optional
                        ? 'Add voice note'
                        : 'Record voice note',
                    style: AppTypography.bodySmall.copyWith(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                    widget.optional
                        ? 'Optional  ·  max ${widget.maxSecs}s'
                        : 'Required  ·  max ${widget.maxSecs}s',
                    style: AppTypography.bodySmall.copyWith(
                        fontSize: 11.5, color: AppColors.hintText)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Recording ─────────────────────────────────────────────────────────────────

class _VoiceRecording extends StatelessWidget {
  final int elapsed;
  final int maxSecs;
  final List<double> amps;
  final VoidCallback onStop;

  const _VoiceRecording({super.key,
    required this.elapsed, required this.maxSecs,
    required this.amps, required this.onStop});

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final pct      = (elapsed / maxSecs).clamp(0.0, 1.0);
    final nearEnd  = (maxSecs - elapsed) <= 10;
    final accentC  = nearEnd ? AppColors.errorLight : AppColors.accentPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: accentC.withOpacity(0.22), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top row: timer + stop
          Row(children: [
            _Blinker(),
            const SizedBox(width: 8),
            Text(_fmt(elapsed),
                style: AppTypography.labelLarge.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFeatures: [const FontFeature.tabularFigures()])),
            const Spacer(),
            AnimatedDefaultTextStyle(
              duration: 200.ms,
              style: AppTypography.bodySmall.copyWith(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: nearEnd ? AppColors.errorLight : AppColors.textSecondary),
              child: Text('-${_fmt(maxSecs - elapsed)}'),
            ),
            const SizedBox(width: 16),
            _StopBtn(onStop: onStop),
          ]),
          const SizedBox(height: 12),
          // waveform
          SizedBox(
            height: 32,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(amps.length, (i) {
                final h = (amps[i] * 28).clamp(3.0, 28.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.2),
                    child: AnimatedContainer(
                      duration: 60.ms,
                      height: h,
                      decoration: BoxDecoration(
                        color: accentC.withOpacity(
                            0.35 + 0.45 * amps[i]),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          // progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 2,
              backgroundColor: const Color(0xFF1E1E2C),
              valueColor: AlwaysStoppedAnimation<Color>(accentC),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blinker extends StatefulWidget {
  @override
  State<_Blinker> createState() => _BlinkerState();
}
class _BlinkerState extends State<_Blinker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: 800.ms)
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(
      width: 7, height: 7,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: AppColors.errorLight),
    ),
  );
}

class _StopBtn extends StatelessWidget {
  final VoidCallback onStop;
  const _StopBtn({required this.onStop});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.mediumImpact(); onStop(); },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: AppColors.errorLight.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.errorLight.withOpacity(0.25), width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 7),
        Text('Stop', style: AppTypography.bodySmall.copyWith(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.errorLight)),
      ]),
    ),
  );
}

// ── Recorded — Spotify-style player ──────────────────────────────────────────

class _VoiceRecorded extends StatefulWidget {
  final int recSecs;
  final String path;
  final VoidCallback onDiscard;
  const _VoiceRecorded({super.key,
    required this.recSecs, required this.path, required this.onDiscard});

  @override
  State<_VoiceRecorded> createState() => _VoiceRecordedState();
}

class _VoiceRecordedState extends State<_VoiceRecorded> {
  bool     _playing  = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>?    _posSub;
  StreamSubscription<Duration?>?   _durSub;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.recSecs);
    _stateSub = AudioService.instance.playerStateStream.listen((s) {
      if (!mounted) return;
      final p = s.playing &&
          s.processingState != ProcessingState.completed;
      setState(() => _playing = p);
      if (s.processingState == ProcessingState.completed) {
        setState(() => _position = Duration.zero);
      }
    });
    _posSub = AudioService.instance.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = AudioService.instance.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    if (_playing) {
      await AudioService.instance.pause();
    } else {
      if (_duration > Duration.zero &&
          _position >= _duration - const Duration(milliseconds: 300)) {
        await AudioService.instance.seekTo(Duration.zero);
      }
      await AudioService.instance.playLocalFile(widget.path);
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Dismissible(
      key: const ValueKey('v-recorded'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (_) => widget.onDiscard(),
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.errorLight.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(LucideIcons.trash2, size: 17,
            color: AppColors.errorLight),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.accentPrimary.withOpacity(0.20), width: 0.8),
        ),
        child: Column(children: [
          Row(children: [
            // play/pause circle — Spotify style
            GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.accentPrimary,
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: 140.ms,
                  child: Icon(
                      _playing ? LucideIcons.pause : LucideIcons.play,
                      key: ValueKey(_playing),
                      size: 15, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // times
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voice note',
                    style: AppTypography.bodySmall.copyWith(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Row(children: [
                  Text(_fmt(_position),
                      style: AppTypography.bodySmall.copyWith(
                          fontSize: 11.5, color: AppColors.accentPrimary,
                          fontFeatures: [const FontFeature.tabularFigures()])),
                  Text(' / ${_fmt(Duration(seconds: widget.recSecs))}',
                      style: AppTypography.bodySmall.copyWith(
                          fontSize: 11.5, color: AppColors.hintText,
                          fontFeatures: [const FontFeature.tabularFigures()])),
                ]),
              ],
            ),
            const Spacer(),
            // swipe hint
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(LucideIcons.chevronLeft,
                    size: 12, color: AppColors.hintText),
                const SizedBox(height: 2),
                Text('swipe to\nremove',
                    textAlign: TextAlign.right,
                    style: AppTypography.bodySmall.copyWith(
                        fontSize: 9.5, color: AppColors.hintText,
                        height: 1.3)),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          // Scrubber
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5.5),
              overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 16),
              activeTrackColor: AppColors.accentPrimary,
              inactiveTrackColor: const Color(0xFF1E1E2C),
              thumbColor: AppColors.accentPrimary,
              overlayColor: AppColors.accentPrimary.withOpacity(0.12),
            ),
            child: Slider(
              value: pct,
              min: 0, max: 1,
              onChanged: (v) {
                if (_duration.inMilliseconds == 0) return;
                AudioService.instance.seekTo(Duration(
                    milliseconds:
                    (v * _duration.inMilliseconds).round()));
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post bar
// ─────────────────────────────────────────────────────────────────────────────

class _PostBar extends StatelessWidget {
  final bool isSpill;
  final int bodyLen;
  final bool canPost;
  final bool isPosting;
  final VoidCallback onPost;
  const _PostBar({
    required this.isSpill, required this.bodyLen,
    required this.canPost, required this.isPosting,
    required this.onPost});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
    child: Row(children: [
      AnimatedSwitcher(
        duration: 200.ms,
        child: isSpill && bodyLen > 0
            ? Text('$bodyLen / 500',
            key: const ValueKey('c'),
            style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: bodyLen > 450
                    ? AppColors.errorLight
                    : AppColors.hintText))
            : Text(
            isSpill
                ? 'Voice note  ·  optional'
                : 'Voice note  ·  required',
            key: const ValueKey('h'),
            style: AppTypography.bodySmall.copyWith(
                fontSize: 11, color: AppColors.hintText)),
      ),
      const Spacer(),
      _PostButton(
          label: isSpill ? 'Post' : 'Drop tea',
          canPost: canPost,
          isPosting: isPosting,
          onPost: onPost),
    ]),
  );
}

class _PostButton extends StatefulWidget {
  final String label;
  final bool canPost;
  final bool isPosting;
  final VoidCallback onPost;
  const _PostButton({required this.label, required this.canPost,
    required this.isPosting, required this.onPost});

  @override
  State<_PostButton> createState() => _PostButtonState();
}

class _PostButtonState extends State<_PostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.canPost && !widget.isPosting;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) {
        setState(() => _pressed = false);
        widget.onPost();
      } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        duration: 180.ms,
        opacity: active ? 1.0 : 0.28,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: 100.ms,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: widget.isPosting
                ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
                : Text(widget.label,
                style: AppTypography.labelLarge.copyWith(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.black, letterSpacing: 0.1)),
          ),
        ),
      ),
    );
  }
}

// Helpers

class _Thin extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 0.5, color: _kLine,
      margin: const EdgeInsets.symmetric(vertical: 10));
}