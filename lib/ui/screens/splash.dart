import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../widgets.dart';

/// Animated logo for a moment, then the app.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.next});
  final Widget next;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _done
          ? widget.next
          : Scaffold(
              key: const ValueKey('splash'),
              body: AuroraBackground(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) {
                      final t = Curves.easeOutBack.transform(_c.value.clamp(0, 1));
                      return Opacity(
                        opacity: _c.value.clamp(0, 1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(scale: 0.6 + 0.4 * t, child: const AlphaLogo(size: 96)),
                            const SizedBox(height: 22),
                            ShaderMask(
                              shaderCallback: (r) => AlphaColors.aurora.createShader(r, textDirection: TextDirection.rtl),
                              child: const Text('Alpha', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                            ),
                            const SizedBox(height: 6),
                            const Text('مصنع التطبيقات المتكاملة', style: TextStyle(color: AlphaColors.muted, fontSize: 15)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
