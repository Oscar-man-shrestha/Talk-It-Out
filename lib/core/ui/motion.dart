import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motion tokens and small building blocks shared by every screen, so the
/// app moves the same way everywhere (timeline-style staggers, like GSAP,
/// but with Flutter's own animation engine and no extra dependency).
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);

  /// Entrances: quick start, soft landing.
  static const enter = Curves.easeOutCubic;

  /// Playful pops (likes, badges).
  static const pop = Curves.elasticOut;

  /// Gap between items of a staggered list, and the most any item waits.
  static const stagger = Duration(milliseconds: 45);
  static const maxDelay = Duration(milliseconds: 360);

  /// False when the person asked for less motion, and in widget tests,
  /// where endless ambient animation would never settle.
  static bool ambientAllowed(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return !_isTestBinding;
  }

  /// Whether one-shot entrance animations should play.
  static bool entrancesAllowed(BuildContext context) =>
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  static final bool _isTestBinding = WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');
}

/// Fades and lifts its child into place once, after [index] × stagger.
/// Wrap list items with increasing indexes for a cascading entrance.
class Reveal extends StatefulWidget {
  const Reveal({
    required this.child,
    this.index = 0,
    this.offset = 14,
    super.key,
  });

  final Widget child;
  final int index;

  /// How far (logical pixels) the child rises while appearing.
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    // The stagger is part of the animation (an Interval), not a timer, so
    // it always plays to the end and never leaves a card invisible.
    final wait = Motion.stagger * widget.index;
    final delay = wait > Motion.maxDelay ? Motion.maxDelay : wait;
    final total = delay + Motion.slow;
    _c = AnimationController(vsync: this, duration: total);
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Motion.enter,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (Motion.entrancesAllowed(context)) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Shrinks slightly while pressed and springs back: the tactile feel of a
/// native button. It only animates; [child] still handles the tap.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.scale = 0.97, super.key});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  var _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A number that rolls to its new value (likes, votes, counts).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(this.value, {this.style, super.key});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.medium,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.45),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text('$value', key: ValueKey(value), style: style),
    );
  }
}

/// A light tap on devices that have a haptic engine; nothing elsewhere.
void tapFeedback() => HapticFeedback.selectionClick();
