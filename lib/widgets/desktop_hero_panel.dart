import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/mode.dart';
import '../core/responsive.dart';
import '../core/texts.dart';
import 'animated_title.dart';

class DesktopHeroPanel extends StatelessWidget {
  final String lang;
  final Mode mode;

  const DesktopHeroPanel({super.key, required this.lang, required this.mode});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = Responsive.isDesktop(context);
          final verticalFraction = isDesktop ? 0.38 : 0.5;
          final maxImageHeight = (constraints.maxHeight * 0.52).clamp(
            190.0,
            520.0,
          );
          final imageWidth = (maxImageHeight * (9 / 16)).round();
          final imageHeight = maxImageHeight.round();

          return Align(
            alignment: FractionalOffset(0.5, verticalFraction),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedTitle(
                    syncGroup: 'appNameTitle_$lang',
                    text: t(lang, 'appName'),
                    animatedStyle: GoogleFonts.shadowsIntoLight(
                      fontSize: isDesktop ? 42 : 35,
                      letterSpacing: isDesktop ? 0.8 : 0.6,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    finalStyle: GoogleFonts.shadowsIntoLight(
                      fontSize: isDesktop ? 42 : 35,
                      letterSpacing: isDesktop ? 0.8 : 0.6,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [
                        const Shadow(
                          blurRadius: 0,
                          color: Colors.black,
                          offset: Offset(0, 0),
                        ),
                        const Shadow(
                          blurRadius: 2,
                          color: Colors.black,
                          offset: Offset(2, 0),
                        ),
                        const Shadow(
                          blurRadius: 2,
                          color: Colors.black,
                          offset: Offset(-2, 0),
                        ),
                        const Shadow(
                          blurRadius: 2,
                          color: Colors.black,
                          offset: Offset(0, 2),
                        ),
                        const Shadow(
                          blurRadius: 2,
                          color: Colors.black,
                          offset: Offset(0, -2),
                        ),
                        Shadow(
                          blurRadius: 18,
                          color: Colors.white.withValues(alpha: 0.8),
                          offset: const Offset(0, 0),
                        ),
                        Shadow(
                          blurRadius: 32,
                          color: Colors.white.withValues(alpha: 0.6),
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    colors: const [
                      Colors.purpleAccent,
                      Colors.deepPurple,
                      Colors.blueAccent,
                      Colors.pinkAccent,
                    ],
                    typingSpeed: const Duration(milliseconds: 160),
                    colorPause: const Duration(milliseconds: 1200),
                    fadeDuration: const Duration(milliseconds: 1600),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.secondary.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.25),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode == Mode.login
                              ? t(lang, 'leftHeadingLogin')
                              : t(lang, 'leftHeadingRegister'),
                          style: GoogleFonts.poppins(
                            fontSize: isDesktop ? 20 : 16,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t(lang, 'leftSubtitle'),
                          style: GoogleFonts.poppins(
                            fontSize: isDesktop ? 14 : 12,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          mode == Mode.login
                              ? t(lang, 'leftDescriptionLogin')
                              : t(lang, 'leftDescriptionRegister'),
                          style: GoogleFonts.poppins(
                            fontSize: isDesktop ? 13 : 11.5,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _signalChip(
                              icon: Icons.bolt_rounded,
                              label: t(lang, 'leftSignalRealtime'),
                            ),
                            _signalChip(
                              icon: Icons.verified_rounded,
                              label: t(lang, 'leftSignalTrust'),
                            ),
                            _signalChip(
                              icon: Icons.hub_rounded,
                              label: t(lang, 'leftSignalPrecision'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: maxImageHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.06),
                          child: kIsWeb
                              ? const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 56,
                                    color: Colors.white54,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/careersuitup_promo.png',
                                  fit: BoxFit.cover,
                                  cacheWidth: imageWidth,
                                  cacheHeight: imageHeight,
                                  filterQuality: FilterQuality.low,
                                  errorBuilder: (c, e, s) => const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: Colors.white30,
                                    ),
                                  ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _signalChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }
}
