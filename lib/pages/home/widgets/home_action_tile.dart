import 'package:flutter/material.dart';

import 'meteor_border_painter.dart';

class HomeActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool hovered;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final Color foregroundColor;
  final Color meteorColor;
  final Animation<double> rotationAnimation;

  const HomeActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.hovered,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.foregroundColor,
    required this.meteorColor,
    required this.rotationAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => onHoverEnter(),
      onExit: (_) => onHoverExit(),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        scale: hovered ? 1.03 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.98),
                  scheme.secondary.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: hovered ? 0.82 : 0.48),
                width: hovered ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: hovered ? 0.32 : 0.2),
                  blurRadius: hovered ? 22 : 14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: rotationAnimation,
                      builder: (context, child) => CustomPaint(
                        painter: MeteorBorderPainter(
                          progress: rotationAnimation.value,
                          color: meteorColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(icon, color: foregroundColor, size: 52),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foregroundColor.withValues(alpha: 0.86),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
