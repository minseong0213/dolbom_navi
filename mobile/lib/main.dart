import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'theme/nav_mode_palette.dart';

void main() {
  runApp(const PregnantNavApp());
}

class PregnantNavApp extends StatelessWidget {
  const PregnantNavApp({
    super.key,
    this.autoLocateOrigin = true,
  });

  final bool autoLocateOrigin;

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.notoSansKrTextTheme();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '돌봄 내비게이션',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D8D),
          brightness: Brightness.light,
        ),
        textTheme: textTheme,
        primaryTextTheme: textTheme,
        extensions: const [NavModePalette.pregnancy],
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F2F4),
      ),
      home: HomeScreen(autoLocateOrigin: autoLocateOrigin),
    );
  }
}
