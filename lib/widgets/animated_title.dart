import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:math' as math;
import 'dart:async';

class AnimatedTitle extends StatefulWidget {
  final String text;
  final TextStyle animatedStyle;
  final TextStyle finalStyle;
  final List<Color> colors;
  final Duration typingSpeed;
  final Duration colorPause;
  final Duration fadeDuration;
  final String? syncGroup;

  const AnimatedTitle({
    super.key,
    required this.text,
    required this.animatedStyle,
    required this.finalStyle,
    required this.colors,
    required this.typingSpeed,
    required this.colorPause,
    required this.fadeDuration,
    this.syncGroup,
  });

  @override
  State<AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<AnimatedTitle>
    with SingleTickerProviderStateMixin {
  static final Map<String, DateTime> _groupStartTimes = <String, DateTime>{};

  bool _showFinal = false;
  late AnimationController _tickerController;
  late DateTime _startTime;
  late DateTime _finalPhaseStart;
  Timer? _phaseSwitchTimer;

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _startTime = widget.syncGroup == null
        ? DateTime.now()
        : _groupStartTimes.putIfAbsent(widget.syncGroup!, () => DateTime.now());

    final totalMs = widget.text.length * widget.typingSpeed.inMilliseconds +
        widget.colorPause.inMilliseconds;
    _finalPhaseStart = _startTime.add(Duration(milliseconds: totalMs));

    _schedulePhaseSwitch();
  }

  @override
  void didUpdateWidget(covariant AnimatedTitle oldWidget) {
    super.didUpdateWidget(oldWidget);

    final groupChanged = oldWidget.syncGroup != widget.syncGroup;
    final textChanged = oldWidget.text != widget.text;

    if (groupChanged || textChanged) {
      _startTime = widget.syncGroup == null
          ? DateTime.now()
          : _groupStartTimes.putIfAbsent(widget.syncGroup!, () => DateTime.now());

      final totalMs = widget.text.length * widget.typingSpeed.inMilliseconds +
          widget.colorPause.inMilliseconds;
      _finalPhaseStart = _startTime.add(Duration(milliseconds: totalMs));
      _schedulePhaseSwitch();
    }
  }

  void _schedulePhaseSwitch() {
    _phaseSwitchTimer?.cancel();

    final remaining = _finalPhaseStart.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      if (!_showFinal) {
        setState(() => _showFinal = true);
      }
      return;
    }

    if (_showFinal) {
      setState(() => _showFinal = false);
    }

    _phaseSwitchTimer = Timer(remaining, () {
      if (!mounted) return;
      setState(() => _showFinal = true);
    });
  }

  double _currentGlowBlur() {
    const minBlur = 18.0;
    const maxBlur = 36.0;
    const cycleMs = 1800.0;

    final elapsedMs = DateTime.now().difference(_finalPhaseStart).inMilliseconds;
    final normalized = ((elapsedMs % cycleMs) / cycleMs).clamp(0.0, 1.0);
    final pulse = (math.sin((2 * math.pi * normalized) - (math.pi / 2)) + 1) / 2;
    return minBlur + (maxBlur - minBlur) * pulse;
  }

  @override
  void dispose() {
    _phaseSwitchTimer?.cancel();
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showFinal) {
      return AnimatedOpacity(
        opacity: 1,
        duration: widget.fadeDuration,
        child: AnimatedBuilder(
          animation: _tickerController,
          builder: (context, child) {
            final animatedBlur = _currentGlowBlur();
            final baseShadows = widget.finalStyle.shadows ?? const <Shadow>[];
            final newShadows = baseShadows.map((s) {
              if (s.blurRadius >= 18) {
                return Shadow(
                  blurRadius: animatedBlur,
                  color: s.color,
                  offset: s.offset,
                );
              }
              return s;
            }).toList();

            return Text(
              widget.text,
              style: widget.finalStyle.copyWith(shadows: newShadows),
              textAlign: TextAlign.center,
            );
          },
        ),
      );
    }

    return AnimatedTextKit(
      animatedTexts: [
        TypewriterAnimatedText(
          widget.text,
          textStyle: widget.animatedStyle,
          speed: widget.typingSpeed,
        ),
        ColorizeAnimatedText(
          widget.text,
          textStyle: widget.animatedStyle,
          colors: widget.colors,
        ),
      ],
      isRepeatingAnimation: false,
      displayFullTextOnTap: true,
      pause: widget.colorPause,
    );
  }
}
