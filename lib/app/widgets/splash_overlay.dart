import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Animasi pembuka singkat dengan logo berlatar gelap saat aplikasi dimulai.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  static const Color _splashBg = Color(0xFF1C1F24);

  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _overlayOpacity;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOutCubic),
      ),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.42, curve: Curves.easeOut),
    );
    _overlayOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _finished = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: FadeTransition(
            opacity: _overlayOpacity,
            child: ColoredBox(
              color: _splashBg,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _logoOpacity,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/logo_dark.jpg',
                            width: 176,
                            height: 176,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _titleOpacity,
                      child: const Text(
                        'KleiHon',
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFFF4CA7E),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
