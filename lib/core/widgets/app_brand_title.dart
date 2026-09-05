import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_amg/core/constants/app_constants.dart';

/// Marca compacta para AppBars: icono + nombre.
class AppBrandTitle extends StatelessWidget {
  const AppBrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.plusJakartaSans(
      fontSize: Theme.of(context).textTheme.titleLarge?.fontSize ?? 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            AppConstants.appIconAsset,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppConstants.appName,
              style: titleStyle,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ],
    );
  }
}
