import 'package:flutter/material.dart';
import '../core/texts.dart';
import '../core/mode.dart';

class AuthButtonsWidget extends StatelessWidget {
  final Mode mode;
  final Function(Mode) onModeChange;
  final String lang;

  const AuthButtonsWidget({
    super.key,
    required this.mode,
    required this.onModeChange,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _AnimatedAuthButton(
                  label: t(lang, "login"),
                  selected: mode == Mode.login,
                  onTap: () => onModeChange(Mode.login),
                  activeGradient: const [
                    Colors.purpleAccent,
                    Colors.deepPurple,
                  ],
                  inactiveTextColor: onSurface,
                ),
              ),
              Expanded(
                child: _AnimatedAuthButton(
                  label: t(lang, "register"),
                  selected: mode == Mode.register,
                  onTap: () => onModeChange(Mode.register),
                  activeGradient: const [Colors.blueAccent, Colors.purple],
                  inactiveTextColor: onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedAuthButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final List<Color> activeGradient;
  final Color inactiveTextColor;

  const _AnimatedAuthButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.activeGradient,
    required this.inactiveTextColor,
  });

  @override
  State<_AnimatedAuthButton> createState() => _AnimatedAuthButtonState();
}

class _AnimatedAuthButtonState extends State<_AnimatedAuthButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.98 : (_isHovering ? 1.02 : 1.0);
    final isActive = widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() {
        _isHovering = false;
        _isPressed = false;
      }),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: scale),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        builder: (context, animatedScale, child) {
          return Transform.scale(scale: animatedScale, child: child);
        },
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.activeGradient,
                    )
                  : null,
              color: isActive ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: widget.activeGradient.last.withValues(
                          alpha: 0.45,
                        ),
                        blurRadius: _isHovering ? 16 : 10,
                        spreadRadius: _isHovering ? 1.2 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isActive ? Colors.white : widget.inactiveTextColor,
                ),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
