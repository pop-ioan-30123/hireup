import 'package:flutter/material.dart';

class LampTransitionOverlay extends StatelessWidget {
  final bool lampVisible;
  final AnimationController lampController;
  final AnimationController glowController;
  final Animation<double> overlayOpacity;
  final Animation<double> lampFade;
  final Animation<double> ropeOffset;
  final Animation<double> glowRadius;

  const LampTransitionOverlay({
    super.key,
    required this.lampVisible,
    required this.lampController,
    required this.glowController,
    required this.overlayOpacity,
    required this.lampFade,
    required this.ropeOffset,
    required this.glowRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (!lampVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([lampController, glowController]),
          builder: (context, child) {
            final lightBg = ThemeData.light().scaffoldBackgroundColor;
            final darkBg = ThemeData.dark().scaffoldBackgroundColor;
            final blended = Color.lerp(lightBg, darkBg, lampController.value)!;
            return Container(
              color: blended.withValues(alpha: overlayOpacity.value),
            );
          },
        ),
        Positioned(
          top: 20 + ropeOffset.value,
          right: 20,
          child: Opacity(
            opacity: lampFade.value,
            child: AnimatedBuilder(
              animation: glowController,
              builder: (context, child) {
                final glow = glowRadius.value;
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.yellow[200],
                    shape: BoxShape.circle,
                    boxShadow: glow > 0
                        ? [
                            BoxShadow(
                              color: Colors.yellow.withValues(alpha: 0.9),
                              blurRadius: glow,
                              spreadRadius: glow / 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
