import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/utils/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      final route = user != null ? AppRoutes.home : AppRoutes.signIn;

      Navigator.pushReplacementNamed(context, route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AnimatedGradientBackground(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _AnimatedHeading(),
                  SizedBox(height: 16),
                  _Tagline(),
                  SizedBox(height: 48),
                  _AnimatedLogo(),
                ],
              ),
            ),
            const _LoadingFooter(),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                         ANIMATED GRADIENT BACKGROUND                        */
/* -------------------------------------------------------------------------- */

class _AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  const _AnimatedGradientBackground({required this.child});

  @override
  State<_AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<_AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF6366F1),
                    const Color(0xFF8B5CF6), _controller.value)!,
                Color.lerp(const Color(0xFF8B5CF6),
                    const Color(0xFFEC4899), _controller.value)!,
                Color.lerp(const Color(0xFFEC4899),
                    const Color(0xFFF59E0B), _controller.value)!,
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               HEADING TEXT                                 */
/* -------------------------------------------------------------------------- */

class _AnimatedHeading extends StatefulWidget {
  const _AnimatedHeading();

  @override
  State<_AnimatedHeading> createState() => _AnimatedHeadingState();
}

class _AnimatedHeadingState extends State<_AnimatedHeading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: Text(
          'Welcome to AmbaniYatri',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 4),
                    blurRadius: 20,
                    color: Colors.black.withOpacity(0.35),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   TAGLINE                                  */
/* -------------------------------------------------------------------------- */

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Your trusted ride partner',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 16,
        letterSpacing: 0.8,
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               LOGO ANIMATION                               */
/* -------------------------------------------------------------------------- */

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
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
    return FadeTransition(
      opacity: _controller,
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutBack,
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                              LOADING FOOTER                                */
/* -------------------------------------------------------------------------- */

class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Column(
        children: const [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Preparing your experience...',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
