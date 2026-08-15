import 'package:flutter/material.dart';

@immutable
class NavModePalette extends ThemeExtension<NavModePalette> {
  const NavModePalette({
    required this.primary,
    required this.dark,
    required this.soft,
  });

  final Color primary;
  final Color dark;
  final Color soft;

  static const pregnancy = NavModePalette(
    primary: Color(0xFFFF4D8D),
    dark: Color(0xFFE93A7A),
    soft: Color(0xFFFFE9F2),
  );

  static const general = NavModePalette(
    primary: Color(0xFF2878FF),
    dark: Color(0xFF1557C8),
    soft: Color(0xFFE7F0FF),
  );

  static NavModePalette of(BuildContext context) {
    return Theme.of(context).extension<NavModePalette>() ?? pregnancy;
  }

  @override
  NavModePalette copyWith({Color? primary, Color? dark, Color? soft}) {
    return NavModePalette(
      primary: primary ?? this.primary,
      dark: dark ?? this.dark,
      soft: soft ?? this.soft,
    );
  }

  @override
  NavModePalette lerp(ThemeExtension<NavModePalette>? other, double t) {
    if (other is! NavModePalette) {
      return this;
    }
    return NavModePalette(
      primary: Color.lerp(primary, other.primary, t)!,
      dark: Color.lerp(dark, other.dark, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
    );
  }
}
