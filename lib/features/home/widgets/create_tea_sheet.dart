// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:lucide_icons/lucide_icons.dart';
// import 'package:record/record.dart';
// import '../../../core/constants/app_colors.dart';
// import '../../../core/constants/app_typography.dart';
// import '../../../core/services/audio_service.dart';
// import '../../../core/widgets/fess_snackbar.dart';
// import '../providers/tea_feed_provider.dart';
//
// const int _maxSeconds = 60;
//
// class CreateTeaSheet extends ConsumerStatefulWidget {
//   const CreateTeaSheet({super.key});
//
//   @override
//   ConsumerState<CreateTeaSheet> createState() => _CreateTeaSheetState();
// }
//
// class _CreateTeaSheetState extends ConsumerState<CreateTeaSheet>
//     with SingleTickerProviderStateMixin {
//   final TextEditingController _heading = TextEditingController();
//   final FocusNode _headingFocus = FocusNode();
//
//   _RecordingState _recordState = _RecordingState.idle;
//   String? _recordedPath;
//   int _recordedSeconds = 0;
//   int _elapsedSeconds = 0;
//   Timer? _timer;
//   List<double> _amplitudes = List.filled(30, 0.1);
//
//   bool get _canPost =>
//       _heading.text.trim().isNotEmpty &&
//           _recordedPath != null &&
//           _recordedSeconds > 0;
//
//   @override
//   void initState() {
//     super.initState();
//     _heading.addListener(() => setState(() {}));
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Future.delayed(const Duration(milliseconds: 350), () {
//         if (mounted) _headingFocus.requestFocus();
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _heading.dispose();
//     _headingFocus.dispose();
//     _timer?.cancel();
//     AudioService.instance.stopPlayback();
//     super.dispose();
//   }
//
// // Recording Controls
//
//   Future<void> _startRecording() async {
//     final hasPermission = await AudioService.instance.hasPermission();
//     if (!hasPermission) {
//       if (!mounted) return;
//       FessSnackbar.show(
//         context,
//         'Microphone permission is required.',
//         type: SnackbarType.error,
//       );
//       return;
//     }
//
//     await AudioService.instance.startRecording();
//     setState(() {
//       _recordState = _RecordingState.recording;
//       _elapsedSeconds = 0;
//       _amplitudes = List.filled(30, 0.1);
//     });
//
//     _timer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (!mounted) return;
//       setState(() => _elapsedSeconds++);
//       if (_elapsedSeconds >= _maxSeconds) _stopRecording();
//     });
//
//     // live amplitude
//     AudioService.instance.amplitudeStream.listen((amp) {
//       if (!mounted) return;
//       final normalized =
//       ((amp.current + 60) / 60).clamp(0.05, 1.0);
//       setState(() {
//         _amplitudes = [..._amplitudes.skip(1), normalized];
//       });
//     });
//   }
//
//   Future<void> _stopRecording() async {
//     _timer?.cancel();
//     final path = await AudioService.instance.stopRecording();
//     if (path == null) {
//       setState(() => _recordState = _RecordingState.idle);
//       return;
//     }
//     final dur =
//     await AudioService.instance.getLocalFileDurationSeconds(path);
//     setState(() {
//       _recordState = _RecordingState.recorded;
//       _recordedPath = path;
//       _recordedSeconds = dur > 0 ? dur : _elapsedSeconds;
//     });
//   }
//
//   Future<void> _discardRecording() async {
//     await AudioService.instance.cancelRecording();
//     await AudioService.instance.stopPlayback();
//     setState(() {
//       _recordState = _RecordingState.idle;
//       _recordedPath = null;
//       _recordedSeconds = 0;
//       _elapsedSeconds = 0;
//       _amplitudes = List.filled(30, 0.1);
//     });
//   }
//
//   // Post
//
//   Future<void> _post() async {
//     if (!_canPost) return;
//     HapticFeedback.mediumImpact();
//
//     final success = await ref.read(createTeaProvider.notifier).createTea(
//       heading: _heading.text,
//       localAudioPath: _recordedPath!,
//       audioDurationSeconds: _recordedSeconds,
//     );
//
//     if (!mounted) return;
//
//     if (success) {
//       Navigator.of(context).pop();
//       FessSnackbar.show(context, 'Tea spilled. ☕', type: SnackbarType.success);
//     } else {
//       FessSnackbar.show(
//         context,
//         'Failed to post. Try again.',
//         type: SnackbarType.error,
//       );
//     }
//   }
//
//   String _fmt(int s) {
//     final m = (s ~/ 60).toString().padLeft(2, '0');
//     final sec = (s % 60).toString().padLeft(2, '0');
//     return '$m:$sec';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isPosting = ref.watch(createTeaProvider);
//     final bottomInset = MediaQuery.of(context).viewInsets.bottom;
//
//     return Container(
//       decoration: const BoxDecoration(
//         color: Color(0xFF0F0F0F),
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: SafeArea(
//         child: Padding(
//           padding: EdgeInsets.only(bottom: bottomInset),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _Handle(),
//               _SheetHeader(onClose: () => Navigator.of(context).pop()),
//               _TypeRow(),
//               const SizedBox(height: 4),
//               _HeadingField(
//                 controller: _heading,
//                 focusNode: _headingFocus,
//               ),
//               const SizedBox(height: 16),
//               _RecorderSection(
//                 recordState: _recordState,
//                 elapsedSeconds: _elapsedSeconds,
//                 recordedSeconds: _recordedSeconds,
//                 recordedPath: _recordedPath,
//                 amplitudes: _amplitudes,
//                 onStart: _startRecording,
//                 onStop: _stopRecording,
//                 onDiscard: _discardRecording,
//                 fmt: _fmt,
//               ),
//               const SizedBox(height: 8),
//               _TeaBottomBar(
//                 canPost: _canPost,
//                 isPosting: isPosting,
//                 onPost: _post,
//               ),
//             ],
//           ),
//         ),
//       ),
//     ).animate().slideY(
//       begin: 0.05,
//       end: 0,
//       duration: 300.ms,
//       curve: Curves.easeOutCubic,
//     );
//   }
// }
//
// enum _RecordingState { idle, recording, recorded }
//
// // Sub Widgets
//
// class _Handle extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(top: 12, bottom: 4),
//       child: Container(
//         width: 36,
//         height: 4,
//         decoration: BoxDecoration(
//           color: const Color(0xFF3A3A3A),
//           borderRadius: BorderRadius.circular(2),
//         ),
//       ),
//     );
//   }
// }
//
// class _SheetHeader extends StatelessWidget {
//   final VoidCallback onClose;
//   const _SheetHeader({required this.onClose});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
//       child: Row(
//         children: [
//           Text(
//             'Drop Tea ☕',
//             style: AppTypography.h4.copyWith(
//               fontSize: 16,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           const Spacer(),
//           GestureDetector(
//             onTap: onClose,
//             child: Container(
//               width: 32,
//               height: 32,
//               decoration: const BoxDecoration(
//                 color: Color(0xFF1E1E1E),
//                 shape: BoxShape.circle,
//               ),
//               child: const Center(
//                 child: Icon(LucideIcons.x, size: 16,
//                     color: AppColors.textSecondary),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _TypeRow extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//       child: Row(
//         children: [
//           _Pill(label: 'Spill', isSelected: false, onTap: () {}),
//           const SizedBox(width: 8),
//           _Pill(label: 'Tea  ☕', isSelected: true, onTap: () {}),
//         ],
//       ),
//     );
//   }
// }
//
// class _Pill extends StatelessWidget {
//   final String label;
//   final bool isSelected;
//   final VoidCallback onTap;
//
//   const _Pill({
//     required this.label,
//     required this.isSelected,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
//         decoration: BoxDecoration(
//           color: isSelected
//               ? AppColors.accentPrimary.withOpacity(0.12)
//               : Colors.transparent,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(
//             color: isSelected
//                 ? AppColors.accentPrimary.withOpacity(0.5)
//                 : const Color(0xFF2A2A2A),
//             width: 0.8,
//           ),
//         ),
//         child: Text(
//           label,
//           style: AppTypography.bodySmall.copyWith(
//             fontSize: 13,
//             fontWeight: FontWeight.w600,
//             color: isSelected
//                 ? AppColors.accentPrimary
//                 : AppColors.textSecondary,
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _HeadingField extends StatelessWidget {
//   final TextEditingController controller;
//   final FocusNode focusNode;
//
//   const _HeadingField({
//     required this.controller,
//     required this.focusNode,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: Stack(
//         alignment: Alignment.centerRight,
//         children: [
//           TextField(
//             controller: controller,
//             focusNode: focusNode,
//             maxLength: 100,
//             maxLines: 2,
//             minLines: 1,
//             buildCounter: (_, {required currentLength,
//               required isFocused,
//               maxLength}) => null,
//             style: AppTypography.bodyMedium.copyWith(
//               fontFamily: 'DM Sans',
//               fontSize: 17,
//               fontWeight: FontWeight.w600,
//               color: AppColors.textPrimary,
//               height: 1.4,
//             ),
//             decoration: InputDecoration(
//               hintText: 'What\'s the tea?',
//               hintStyle: AppTypography.bodyMedium.copyWith(
//                 fontFamily: 'DM Sans',
//                 fontSize: 17,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.hintText,
//                 height: 1.4,
//               ),
//               border: InputBorder.none,
//               enabledBorder: InputBorder.none,
//               focusedBorder: InputBorder.none,
//               contentPadding: const EdgeInsets.only(right: 52, bottom: 4),
//               filled: false,
//             ),
//             textInputAction: TextInputAction.done,
//           ),
//           Text(
//             '${controller.text.length}/100',
//             style: AppTypography.bodySmall.copyWith(
//               fontSize: 11,
//               color: controller.text.length > 85
//                   ? AppColors.errorLight.withOpacity(0.8)
//                   : AppColors.hintText,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _RecorderSection extends StatelessWidget {
//   final _RecordingState recordState;
//   final int elapsedSeconds;
//   final int recordedSeconds;
//   final String? recordedPath;
//   final List<double> amplitudes;
//   final VoidCallback onStart;
//   final VoidCallback onStop;
//   final VoidCallback onDiscard;
//   final String Function(int) fmt;
//
//   const _RecorderSection({
//     required this.recordState,
//     required this.elapsedSeconds,
//     required this.recordedSeconds,
//     required this.recordedPath,
//     required this.amplitudes,
//     required this.onStart,
//     required this.onStop,
//     required this.onDiscard,
//     required this.fmt,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: AnimatedSwitcher(
//         duration: const Duration(milliseconds: 250),
//         child: switch (recordState) {
//           _RecordingState.idle => _IdleRecorder(onStart: onStart),
//           _RecordingState.recording => _ActiveRecorder(
//             elapsed: elapsedSeconds,
//             amplitudes: amplitudes,
//             onStop: onStop,
//             fmt: fmt,
//           ),
//           _RecordingState.recorded => _RecordedPreview(
//             durationSeconds: recordedSeconds,
//             audioPath: recordedPath!,
//             onDiscard: onDiscard,
//           ),
//         },
//       ),
//     );
//   }
// }
//
// class _IdleRecorder extends StatelessWidget {
//   final VoidCallback onStart;
//   const _IdleRecorder({required this.onStart});
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () {
//         HapticFeedback.mediumImpact();
//         onStart();
//       },
//       child: Container(
//         key: const ValueKey('idle'),
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 24),
//         decoration: BoxDecoration(
//           color: const Color(0xFF0F0F1A),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: AppColors.accentSecondary.withOpacity(0.3),
//             width: 0.8,
//           ),
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 52,
//               height: 52,
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
//                 ),
//                 shape: BoxShape.circle,
//                 boxShadow: [
//                   BoxShadow(
//                     color: const Color(0xFF7C4DFF).withOpacity(0.3),
//                     blurRadius: 16,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: const Center(
//                 child: Icon(LucideIcons.mic, size: 22, color: Colors.white),
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'Tap to record',
//               style: AppTypography.bodySmall.copyWith(
//                 fontSize: 13,
//                 color: AppColors.textSecondary,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               'Max 60 seconds',
//               style: AppTypography.bodySmall.copyWith(
//                 fontSize: 11,
//                 color: AppColors.hintText,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _ActiveRecorder extends StatelessWidget {
//   final int elapsed;
//   final List<double> amplitudes;
//   final VoidCallback onStop;
//   final String Function(int) fmt;
//
//   const _ActiveRecorder({
//     required this.elapsed,
//     required this.amplitudes,
//     required this.onStop,
//     required this.fmt,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final remaining = _maxSeconds - elapsed;
//     final isNearEnd = remaining <= 10;
//
//     return Container(
//       key: const ValueKey('recording'),
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0F0F1A),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: AppColors.errorLight.withOpacity(0.4),
//           width: 0.8,
//         ),
//       ),
//       child: Column(
//         children: [
//           // live waveform
//           SizedBox(
//             height: 40,
//             child: Row(
//               children: List.generate(amplitudes.length, (i) {
//                 return Expanded(
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 1),
//                     child: Center(
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 80),
//                         width: double.infinity,
//                         height: (amplitudes[i] * 36).clamp(3.0, 36.0),
//                         decoration: BoxDecoration(
//                           color: AppColors.errorLight.withOpacity(0.7),
//                           borderRadius: BorderRadius.circular(2),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }),
//             ),
//           ),
//           const SizedBox(height: 12),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               // elapsed + REC dot
//               Row(
//                 children: [
//                   Container(
//                     width: 7,
//                     height: 7,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: AppColors.errorLight,
//                     ),
//                   )
//                       .animate(onPlay: (c) => c.repeat())
//                       .fadeOut(duration: 600.ms)
//                       .fadeIn(duration: 600.ms),
//                   const SizedBox(width: 6),
//                   Text(
//                     fmt(elapsed),
//                     style: AppTypography.bodySmall.copyWith(
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                       color: AppColors.textPrimary,
//                     ),
//                   ),
//                 ],
//               ),
//               // remaining
//               Text(
//                 '-${fmt(remaining)}',
//                 style: AppTypography.bodySmall.copyWith(
//                   fontSize: 12,
//                   color: isNearEnd
//                       ? AppColors.errorLight
//                       : AppColors.textSecondary,
//                   fontWeight:
//                   isNearEnd ? FontWeight.w600 : FontWeight.w400,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 14),
//           // stop button
//           GestureDetector(
//             onTap: () {
//               HapticFeedback.mediumImpact();
//               onStop();
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 28, vertical: 10),
//               decoration: BoxDecoration(
//                 color: AppColors.errorLight.withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(
//                     color: AppColors.errorLight.withOpacity(0.4),
//                     width: 0.8),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     width: 10,
//                     height: 10,
//                     decoration: BoxDecoration(
//                       color: AppColors.errorLight,
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     'Stop',
//                     style: AppTypography.bodySmall.copyWith(
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                       color: AppColors.errorLight,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _RecordedPreview extends StatefulWidget {
//   final int durationSeconds;
//   final String audioPath;
//   final VoidCallback onDiscard;
//
//   const _RecordedPreview({
//     required this.durationSeconds,
//     required this.audioPath,
//     required this.onDiscard,
//   });
//
//   @override
//   State<_RecordedPreview> createState() => _RecordedPreviewState();
// }
//
// class _RecordedPreviewState extends State<_RecordedPreview> {
//   bool _isPlaying = false;
//
//   String _fmt(int s) {
//     final m = (s ~/ 60).toString().padLeft(2, '0');
//     final sec = (s % 60).toString().padLeft(2, '0');
//     return '$m:$sec';
//   }
//
//   Future<void> _toggle() async {
//     HapticFeedback.selectionClick();
//     if (_isPlaying) {
//       await AudioService.instance.pausePlayback();
//       setState(() => _isPlaying = false);
//     } else {
//       await AudioService.instance.playLocalFile(widget.audioPath);
//       setState(() => _isPlaying = true);
//       AudioService.instance.playerStateStream.firstWhere(
//             (s) => s.processingState == ProcessingState.completed,
//       ).then((_) {
//         if (mounted) setState(() => _isPlaying = false);
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       key: const ValueKey('recorded'),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0F0F1A),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: AppColors.accentPrimary.withOpacity(0.3),
//           width: 0.8,
//         ),
//       ),
//       child: Row(
//         children: [
//           // play preview
//           GestureDetector(
//             onTap: _toggle,
//             child: Container(
//               width: 42,
//               height: 42,
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
//                 ),
//                 shape: BoxShape.circle,
//               ),
//               child: Center(
//                 child: Icon(
//                   _isPlaying ? LucideIcons.pause : LucideIcons.play,
//                   size: 18,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Voice note ready',
//                   style: AppTypography.bodySmall.copyWith(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//                 Text(
//                   _fmt(widget.durationSeconds),
//                   style: AppTypography.bodySmall.copyWith(
//                     fontSize: 11,
//                     color: AppColors.textSecondary,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // discard
//           GestureDetector(
//             onTap: () {
//               HapticFeedback.selectionClick();
//               widget.onDiscard();
//             },
//             child: Container(
//               width: 32,
//               height: 32,
//               decoration: const BoxDecoration(
//                 color: Color(0xFF1E1E1E),
//                 shape: BoxShape.circle,
//               ),
//               child: const Center(
//                 child: Icon(LucideIcons.trash2,
//                     size: 14, color: AppColors.textSecondary),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _TeaBottomBar extends StatelessWidget {
//   final bool canPost;
//   final bool isPosting;
//   final VoidCallback onPost;
//
//   const _TeaBottomBar({
//     required this.canPost,
//     required this.isPosting,
//     required this.onPost,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(height: 0.5, color: const Color(0xFF1E1E1E)),
//         Padding(
//           padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
//           child: Row(
//             children: [
//               Text(
//                 'Voice note · max 60s',
//                 style: AppTypography.bodySmall.copyWith(
//                   fontSize: 11,
//                   color: AppColors.hintText,
//                 ),
//               ),
//               const Spacer(),
//               GestureDetector(
//                 onTap: (canPost && !isPosting) ? onPost : null,
//                 child: AnimatedOpacity(
//                   duration: const Duration(milliseconds: 200),
//                   opacity: canPost ? 1.0 : 0.35,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 22, vertical: 10),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
//                       ),
//                       borderRadius: BorderRadius.circular(22),
//                     ),
//                     child: isPosting
//                         ? const SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                         : Text(
//                       'Drop Tea',
//                       style: AppTypography.labelMedium.copyWith(
//                         color: Colors.white,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }