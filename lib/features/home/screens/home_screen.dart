// import 'package:flutter/material.dart';
// import '../../../core/constants/app_colors.dart';
// import '../../../core/constants/app_text_styles.dart';
//
// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Row(
//           children: [
//             Image.asset(
//               'assets/images/logo.png',
//               height: 28,
//               errorBuilder: (context, error, stackTrace) {
//                 return Text('Fess', style: AppTextStyles.h3);
//               },
//             ),
//             const SizedBox(width: 8),
//             Text('Fess', style: AppTextStyles.h3),
//           ],
//         ),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.check_circle_outline,
//               size: 64,
//               color: AppColors.accentPrimary,
//             ),
//             const SizedBox(height: 24),
//             Text(
//               'Fess is ready!',
//               style: AppTextStyles.h2,
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'Project wiring complete',
//               style: AppTextStyles.bodyMedium.copyWith(
//                 color: AppColors.textSecondary,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
