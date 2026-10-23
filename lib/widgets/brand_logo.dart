import 'package:flutter/material.dart';
import 'package:hue_quito/theme/theme.dart';

enum HueQuitoLogoVariant {
  horizontal, // Primary horizontal logo
  stacked,    // Stacked logo (symbol on top, wordmark below)
  symbol,     // Just the olla de barro + pin
  appIcon,    // Squircle app icon
}

class HueQuitoLogo extends StatelessWidget {
  final double? height;
  final double? width;
  final HueQuitoLogoVariant variant;
  final bool? isDark;
  final BoxFit fit;
  final Alignment alignment;

  const HueQuitoLogo({
    super.key,
    this.height = 36,
    this.width,
    this.variant = HueQuitoLogoVariant.horizontal,
    this.isDark,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.centerLeft,
  });

  const HueQuitoLogo.stacked({
    super.key,
    this.height = 90,
    this.width,
    this.isDark,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  }) : variant = HueQuitoLogoVariant.stacked;

  const HueQuitoLogo.symbol({
    super.key,
    this.height = 40,
    this.width,
    this.isDark,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  }) : variant = HueQuitoLogoVariant.symbol;

  const HueQuitoLogo.appIcon({
    super.key,
    this.height = 80,
    this.width,
    this.isDark,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  }) : variant = HueQuitoLogoVariant.appIcon;

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

    String assetPath;
    switch (variant) {
      case HueQuitoLogoVariant.stacked:
        assetPath = 'assets/images/logo_stacked.png';
        break;
      case HueQuitoLogoVariant.symbol:
        assetPath = 'assets/images/logo_symbol.png';
        break;
      case HueQuitoLogoVariant.appIcon:
        assetPath = 'assets/images/app_icon.png';
        break;
      case HueQuitoLogoVariant.horizontal:
        assetPath = effectiveDark
            ? 'assets/images/logo_dark.png'
            : 'assets/images/logo_primary.png';
        break;
    }

    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) {
        // High quality programmatic fallback in case asset fails
        return _buildFallback(effectiveDark);
      },
    );
  }

  Widget _buildFallback(bool dark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.location_on,
          size: (height ?? 36) * 0.9,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: (height ?? 36) * 0.65,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(
                text: 'Hue',
                style: TextStyle(
                  color: dark ? Colors.white : AppTheme.deepEarthBrown,
                ),
              ),
              const TextSpan(
                text: 'Quito',
                style: TextStyle(color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
