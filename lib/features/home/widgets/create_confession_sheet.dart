import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../providers/feed_provider.dart';
import '../providers/tea_feed_provider.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class CreateConfessionSheet extends ConsumerStatefulWidget {
  const CreateConfessionSheet({super.key});

  @override
  ConsumerState<CreateConfessionSheet> createState() =>
      _CreateConfessionSheetState();
}

class _CreateConfessionSheetState
    extends ConsumerState<CreateConfessionSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // spill
  final _headingCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _headingFocus = FocusNode();

  // tea
  final _teaHeadingCtrl = TextEditingController();
  final _teaFocus = FocusNode();

  // voice
  _VoiceState _voice = _VoiceState.idle;
  String? _recPath;
  int _recSecs = 0;
  int _elapsed = 0;
  Timer? _timer;
  List<double> _amps = List.filled(40, 0.04);

  bool get _isSpill => _tabCtrl.index == 0;
  int get _maxSecs => _isSpill ? 30 : 60;

  bool get _hasContent {
    return _headingCtrl.text.trim().isNotEmpty ||
        _bodyCtrl.text.trim().isNotEmpty ||
        _teaHeadingCtrl.text.trim().isNotEmpty ||
        _recPath != null ||
        _voice == _VoiceState.recording;
  }

  bool get _canPost {
    if (_isSpill) return _headingCtrl.text.trim().isNotEmpty;
    return _teaHeadingCtrl.text.trim().isNotEmpty && _recPath != null;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // intercept tab change — show discard dialog if recording/recorded
    _tabCtrl.addListener(_onTabChange);
    for (final c in [_headingCtrl, _bodyCtrl, _teaHeadingCtrl]) {
      c.addListener(() => setState(() {}));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(
          const Duration(milliseconds: 350),
              () => mounted ? _headingFocus.requestFocus() : null);
    });
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChange);
    _tabCtrl.dispose();
    _headingCtrl.dispose();
    _bodyCtrl.dispose();
    _headingFocus.dispose();
    _teaHeadingCtrl.dispose();
    _teaFocus.dispose();
    _timer?.cancel();
    AudioService.instance.stop();
    super.dispose();
  }

  // ── Tab switch guard ──────────────────────────────────────────────────────

  void _onTabChange() {
    if (!_tabCtrl.indexIsChanging) return;
    // If there's a recording (in progress or saved), block and show dialog
    if (_voice != _VoiceState.idle) {
      // Snap back to current index before animation commits
      final previousIndex = _tabCtrl.previousIndex;
      // Show dialog — if confirmed, discard voice and allow switch
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final confirmed = await _showDiscardDialog(
          title: 'Discard recording?',
          body: 'Switching tabs will remove your voice recording.',
          confirmLabel: 'Discard',
        );
        if (confirmed == true) {
          await _discardRec();
          // now actually switch
          _tabCtrl.animateTo(_tabCtrl.index);
        } else {
          // revert to previous tab
          _tabCtrl.animateTo(previousIndex);
        }
      });
    }
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _startRec() async {
    final ok = await AudioService.instance.hasPermission();
    if (!ok) {
      if (mounted) {
        FessSnackbar.show(context, 'Microphone permission needed.',
            type: SnackbarType.error);
      }
      return;
    }
    await AudioService.instance.startRecording();
    setState(() {
      _voice = _VoiceState.recording;
      _elapsed = 0;
      _amps = List.filled(40, 0.04);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _maxSecs) _stopRec();
    });
    AudioService.instance.amplitudeStream.listen((a) {
      if (!mounted || _voice != _VoiceState.recording) return;
      final n = ((a.current + 60) / 60).clamp(0.04, 1.0);
      setState(() => _amps = [..._amps.skip(1), n]);
    });
  }

  Future<void> _stopRec() async {
    _timer?.cancel();
    final path = await AudioService.instance.stopRecording();
    if (path == null || !mounted) {
      setState(() => _voice = _VoiceState.idle);
      return;
    }
    final dur = await AudioService.instance.getFileDurationSeconds(path);
    setState(() {
      _voice = _VoiceState.recorded;
      _recPath = path;
      _recSecs = dur > 0 ? dur : _elapsed;
    });
  }

  Future<void> _discardRec() async {
    _timer?.cancel();
    await AudioService.instance.cancelRecording();
    await AudioService.instance.stop();
    setState(() {
      _voice = _VoiceState.idle;
      _recPath = null;
      _recSecs = 0;
      _elapsed = 0;
      _amps = List.filled(40, 0.04);
    });
  }

  // ── Discard dialog ────────────────────────────────────────────────────────

  Future<bool?> _showDiscardDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111118),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E1E2A), width: 0.8),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontFamily: 'DM Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A26),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF2A2A3A), width: 0.8),
                        ),
                        child: Center(
                          child: Text(
                            'Keep',
                            style: AppTypography.labelMedium.copyWith(
                              fontFamily: 'DM Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.errorLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.errorLight.withOpacity(0.3),
                              width: 0.8),
                        ),
                        child: Center(
                          child: Text(
                            confirmLabel,
                            style: AppTypography.labelMedium.copyWith(
                              fontFamily: 'DM Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.errorLight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Close with discard guard ──────────────────────────────────────────────

  Future<void> _onClose() async {
    if (!_hasContent) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await _showDiscardDialog(
      title: 'Discard post?',
      body: 'Everything you\'ve written will be lost.',
      confirmLabel: 'Discard',
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Post ─────────────────────────────────────────────────────────────────

  Future<void> _post() async {
    if (!_canPost) return;
    HapticFeedback.mediumImpact();
    if (_isSpill) {
      final ok = await ref.read(createPostProvider.notifier).createConfession(
        heading: _headingCtrl.text,
        body: _bodyCtrl.text.isNotEmpty ? _bodyCtrl.text : null,
        voiceNotePath: _recPath,
        voiceDurationSeconds: _recPath != null ? _recSecs : null,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        FessSnackbar.show(context, 'Posted.', type: SnackbarType.success);
      } else {
        FessSnackbar.show(context, 'Failed to post. Try again.',
            type: SnackbarType.error);
      }
    } else {
      final ok = await ref.read(createTeaProvider.notifier).createTea(
        heading: _teaHeadingCtrl.text,
        localAudioPath: _recPath!,
        audioDurationSeconds: _recSecs,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        FessSnackbar.show(context, 'Tea dropped.', type: SnackbarType.success);
      } else {
        FessSnackbar.show(context, 'Failed to post. Try again.',
            type: SnackbarType.error);
      }
    }
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final isPosting =
        ref.watch(createPostProvider) || ref.watch(createTeaProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final avatarUrl = _buildAvatarUrlFromProfile(profile);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF09090F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E2E3A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Top bar: close + tabs + post button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    // close — with discard guard
                    GestureDetector(
                      onTap: _onClose,
                      child: const Icon(LucideIcons.x,
                          size: 20, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 16),
                    // tabs
                    _SheetTabBar(ctrl: _tabCtrl),
                    const Spacer(),
                    // post button
                    _PostBtn(
                      label: _isSpill ? 'Post' : 'Drop',
                      canPost: _canPost,
                      isPosting: isPosting,
                      onPost: _post,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),
              const Divider(
                  height: 0.5, thickness: 0.5, color: Color(0xFF141420)),

              // ── Content
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                child: TabBarView(
                  controller: _tabCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Spill tab
                    _SpillComposer(
                      avatarUrl: avatarUrl,
                      username: profile?['username'] as String? ?? 'anon',
                      headingCtrl: _headingCtrl,
                      bodyCtrl: _bodyCtrl,
                      headingFocus: _headingFocus,
                      voice: _voice,
                      elapsed: _elapsed,
                      recSecs: _recSecs,
                      recPath: _recPath,
                      amps: _amps,
                      onStartRec: _startRec,
                      onStopRec: _stopRec,
                      onDiscardRec: _discardRec,
                    ),
                    // Tea tab
                    _TeaComposer(
                      avatarUrl: avatarUrl,
                      username: profile?['username'] as String? ?? 'anon',
                      headingCtrl: _teaHeadingCtrl,
                      focus: _teaFocus,
                      voice: _voice,
                      elapsed: _elapsed,
                      recSecs: _recSecs,
                      recPath: _recPath,
                      amps: _amps,
                      onStartRec: _startRec,
                      onStopRec: _stopRec,
                      onDiscardRec: _discardRec,
                    ),
                  ],
                ),
              ),

              // ── Bottom hint
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Icon(LucideIcons.globe,
                        size: 15, color: AppColors.hintText),
                    const SizedBox(width: 5),
                    Text(
                      'Everyone can see this',
                      style: AppTypography.bodySmall.copyWith(
                          fontSize: 13, color: AppColors.hintText),
                    ),
                    const Spacer(),
                    if (_isSpill && _bodyCtrl.text.isNotEmpty)
                      Text(
                        '${_bodyCtrl.text.length}/500',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: _bodyCtrl.text.length > 450
                              ? AppColors.errorLight
                              : AppColors.hintText,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FIX: use 'adventurer' style, not 'avataaars'
  String? _buildAvatarUrlFromProfile(Map<String, dynamic>? profile) {
    final raw = profile?['avatarConfig'];
    if (raw == null) return null;
    final config = AvatarConfig.fromMap(raw as Map<String, dynamic>);
    return config.buildUrl(size: 72);
  }
}

enum _VoiceState { idle, recording, recorded }

// SHEET TEA BAR

class _SheetTabBar extends StatelessWidget {
  final TabController ctrl;
  const _SheetTabBar({required this.ctrl});

  @override
  Widget build(BuildContext context) => TabBar(
    controller: ctrl,
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    indicator: const UnderlineTabIndicator(
      borderSide: BorderSide(
        color: AppColors.accentPrimary,
        width: 2,
      ),
      insets: EdgeInsets.symmetric(horizontal: 8),
    ),
    indicatorSize: TabBarIndicatorSize.label,
    dividerColor: Colors.transparent,
    labelStyle: AppTypography.bodyMedium.copyWith(
      fontFamily: 'DM Sans',
      fontWeight: FontWeight.w700,
      fontSize: 15,
    ),
    unselectedLabelStyle: AppTypography.bodyMedium.copyWith(
      fontFamily: 'DM Sans',
      fontWeight: FontWeight.w400,
      fontSize: 15,
    ),
    labelColor: AppColors.textPrimary,
    unselectedLabelColor: AppColors.hintText,
    padding: EdgeInsets.zero,
    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    tabs: const [
      Tab(text: 'Spill'),
      Tab(text: 'Tea'),
    ],
  );
}

// SPILL COMPOSER

class _SpillComposer extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final TextEditingController headingCtrl;
  final TextEditingController bodyCtrl;
  final FocusNode headingFocus;
  final _VoiceState voice;
  final int elapsed;
  final int recSecs;
  final String? recPath;
  final List<double> amps;
  final VoidCallback onStartRec;
  final VoidCallback onStopRec;
  final VoidCallback onDiscardRec;

  const _SpillComposer({
    required this.avatarUrl,
    required this.username,
    required this.headingCtrl,
    required this.bodyCtrl,
    required this.headingFocus,
    required this.voice,
    required this.elapsed,
    required this.recSecs,
    required this.recPath,
    required this.amps,
    required this.onStartRec,
    required this.onStopRec,
    required this.onDiscardRec,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _ComposerAvatar(url: avatarUrl),
              const SizedBox(height: 4),
              Container(
                  width: 1.5, height: 28, color: const Color(0xFF1E1E2A)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FIX: @ before username
                Text(
                  '@$username',
                  style: AppTypography.bodyMedium.copyWith(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: headingCtrl,
                  focusNode: headingFocus,
                  maxLines: null,
                  maxLength: 100,
                  buildCounter: (_, {required currentLength,
                    required isFocused, maxLength}) =>
                  null,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    hintStyle: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.hintText,
                      height: 1.45,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: false,
                  ),
                  cursorColor: AppColors.accentPrimary,
                  cursorWidth: 2,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: bodyCtrl,
                  maxLines: null,
                  maxLength: 500,
                  buildCounter: (_, {required currentLength,
                    required isFocused, maxLength}) =>
                  null,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Spill it Completely..!',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      fontSize: 15,
                      color: AppColors.hintText,
                      height: 1.6,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: false,
                  ),
                  cursorColor: AppColors.accentPrimary,
                  cursorWidth: 2,
                ),
                const SizedBox(height: 14),
                _VoiceSection(
                  optional: true,
                  maxSecs: 30,
                  voice: voice,
                  elapsed: elapsed,
                  recSecs: recSecs,
                  recPath: recPath,
                  amps: amps,
                  onStart: onStartRec,
                  onStop: onStopRec,
                  onDiscard: onDiscardRec,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tea Composer

class _TeaComposer extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final TextEditingController headingCtrl;
  final FocusNode focus;
  final _VoiceState voice;
  final int elapsed;
  final int recSecs;
  final String? recPath;
  final List<double> amps;
  final VoidCallback onStartRec;
  final VoidCallback onStopRec;
  final VoidCallback onDiscardRec;

  const _TeaComposer({
    required this.avatarUrl,
    required this.username,
    required this.headingCtrl,
    required this.focus,
    required this.voice,
    required this.elapsed,
    required this.recSecs,
    required this.recPath,
    required this.amps,
    required this.onStartRec,
    required this.onStopRec,
    required this.onDiscardRec,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _ComposerAvatar(url: avatarUrl),
              const SizedBox(height: 4),
              Container(
                  width: 1.5, height: 28, color: const Color(0xFF1E1E2A)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FIX: @ before username
                Text(
                  '@$username',
                  style: AppTypography.bodyMedium.copyWith(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: headingCtrl,
                  focusNode: focus,
                  maxLines: null,
                  maxLength: 100,
                  buildCounter: (_, {required currentLength,
                    required isFocused, maxLength}) =>
                  null,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'What\'s the tea?',
                    hintStyle: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.hintText,
                      height: 1.45,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: false,
                  ),
                  cursorColor: AppColors.accentPrimary,
                  cursorWidth: 2,
                ),
                const SizedBox(height: 14),
                _VoiceSection(
                  optional: false,
                  maxSecs: 60,
                  voice: voice,
                  elapsed: elapsed,
                  recSecs: recSecs,
                  recPath: recPath,
                  amps: amps,
                  onStart: onStartRec,
                  onStop: onStopRec,
                  onDiscard: onDiscardRec,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Compose avatar

class _ComposerAvatar extends StatelessWidget {
  final String? url;
  const _ComposerAvatar({this.url});

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: AppColors.accentPrimary.withOpacity(0.3),
        width: 1.2,
      ),
    ),
    child: ClipOval(
      child: url != null
          ? CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: const Color(0xFF1A1A28)),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFF1A1A28),
          child: const Icon(LucideIcons.user,
              size: 18, color: AppColors.hintText),
        ),
      )
          : Container(
        color: const Color(0xFF1A1A28),
        child: const Icon(LucideIcons.user,
            size: 18, color: AppColors.hintText),
      ),
    ),
  );
}

// Voice Section

class _VoiceSection extends StatelessWidget {
  final bool optional;
  final int maxSecs;
  final _VoiceState voice;
  final int elapsed;
  final int recSecs;
  final String? recPath;
  final List<double> amps;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  const _VoiceSection({
    required this.optional,
    required this.maxSecs,
    required this.voice,
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
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    child: switch (voice) {
      _VoiceState.idle => _IdleVoice(
        key: const ValueKey('idle'),
        optional: optional,
        maxSecs: maxSecs,
        onStart: onStart,
      ),
      _VoiceState.recording => _RecordingVoice(
        key: const ValueKey('recording'),
        elapsed: elapsed,
        maxSecs: maxSecs,
        amps: amps,
        onStop: onStop,
      ),
      _VoiceState.recorded => _RecordedVoice(
        key: const ValueKey('recorded'),
        recSecs: recSecs,
        path: recPath!,
        onDiscard: onDiscard,
      ),
    },
  );
}

// Idle Voice

class _IdleVoice extends StatelessWidget {
  final bool optional;
  final int maxSecs;
  final VoidCallback onStart;
  const _IdleVoice(
      {super.key,
        required this.optional,
        required this.maxSecs,
        required this.onStart});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.mediumImpact();
      onStart();
    },
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF141420),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF252535), width: 0.8),
          ),
          child: const Icon(LucideIcons.mic,
              size: 16, color: AppColors.accentPrimary),
        ),
        const SizedBox(width: 10),
        Text(
          optional
              ? 'Add a voice note · ${maxSecs}s max'
              : 'Record your voice · ${maxSecs}s max',
          style: AppTypography.bodySmall.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

// RECORDING VOICE

class _RecordingVoice extends StatelessWidget {
  final int elapsed;
  final int maxSecs;
  final List<double> amps;
  final VoidCallback onStop;

  const _RecordingVoice({
    super.key,
    required this.elapsed,
    required this.maxSecs,
    required this.amps,
    required this.onStop,
  });

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final remaining = maxSecs - elapsed;
    final nearEnd = remaining <= 10;

    return Row(
      children: [
        // stop button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onStop();
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.errorLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // waveform
        Expanded(
          child: SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                amps.length,
                    (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 60),
                      height: (amps[i] * 32).clamp(2.5, 32.0),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // timer
        _RecDot(),
        const SizedBox(width: 5),
        Text(
          _fmt(elapsed),
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: nearEnd ? AppColors.errorLight : AppColors.textPrimary,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _RecDot extends StatefulWidget {
  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: AppColors.errorLight),
    ),
  );
}

// RECORD VOICE (SWIPE TO DELETE)

class _RecordedVoice extends StatefulWidget {
  final int recSecs;
  final String path;
  final VoidCallback onDiscard;

  const _RecordedVoice({
    super.key,
    required this.recSecs,
    required this.path,
    required this.onDiscard,
  });

  @override
  State<_RecordedVoice> createState() => _RecordedVoiceState();
}

class _RecordedVoiceState extends State<_RecordedVoice> {
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.recSecs);
    _stateSub = AudioService.instance.playerStateStream.listen((s) {
      if (!mounted) return;
      final playing =
          s.playing && s.processingState != ProcessingState.completed;
      setState(() => _playing = playing);
      if (s.processingState == ProcessingState.completed) {
        setState(() => _position = Duration.zero);
      }
    });
    _posSub = AudioService.instance.positionStream
        .listen((p) { if (mounted) setState(() => _position = p); });
    _durSub = AudioService.instance.durationStream
        .listen((d) { if (mounted && d != null) setState(() => _duration = d); });
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
      if (_position >= _duration && _duration > Duration.zero) {
        await AudioService.instance.seekTo(Duration.zero);
      }
      await AudioService.instance.playLocalFile(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : widget.recSecs * 1000;
    final pct =
    total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;

    return Dismissible(
      key: const ValueKey('rec-voice'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.onDiscard();
      },
      // FIX: visible red background with label
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.errorLight.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.trash2,
                size: 16, color: AppColors.errorLight),
            const SizedBox(width: 6),
            Text(
              'Delete',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.errorLight,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            // play/pause
            GestureDetector(
              onTap: _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _playing
                      ? AppColors.accentPrimary
                      : AppColors.accentPrimary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      _playing ? LucideIcons.pause : LucideIcons.play,
                      key: ValueKey(_playing),
                      size: 14,
                      color: _playing ? Colors.black : AppColors.accentPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // scrubber
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: AppColors.accentPrimary,
                  inactiveTrackColor: const Color(0xFF252535),
                  thumbColor: AppColors.accentPrimary,
                  overlayColor: AppColors.accentPrimary.withOpacity(0.1),
                ),
                child: Slider(
                  value: pct.toDouble(),
                  min: 0,
                  max: 1,
                  onChanged: (v) {
                    if (total == 0) return;
                    AudioService.instance
                        .seekTo(Duration(milliseconds: (v * total).round()));
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_fmt(_position.inSeconds)} / ${_fmt(widget.recSecs)}',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// POST BUTTON

class _PostBtn extends StatefulWidget {
  final String label;
  final bool canPost;
  final bool isPosting;
  final VoidCallback onPost;
  const _PostBtn(
      {required this.label,
        required this.canPost,
        required this.isPosting,
        required this.onPost});

  @override
  State<_PostBtn> createState() => _PostBtnState();
}

class _PostBtnState extends State<_PostBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.canPost && !widget.isPosting;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active
          ? (_) {
        setState(() => _pressed = false);
        widget.onPost();
      }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: active ? 1.0 : 0.35,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: widget.isPosting
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
                  : Text(
                widget.label,
                style: AppTypography.labelMedium.copyWith(
                  fontFamily: 'DM Sans',
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}