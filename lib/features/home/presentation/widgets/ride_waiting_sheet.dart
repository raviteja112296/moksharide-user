import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class RideWaitingSheet extends StatefulWidget {
  final VoidCallback? onCancel;

  const RideWaitingSheet({super.key, this.onCancel});

  @override
  State<RideWaitingSheet> createState() => _RideWaitingSheetState();
}

class _RideWaitingSheetState extends State<RideWaitingSheet> with TickerProviderStateMixin {
  late AnimationController _spinController;
  late Timer _textTimer;
  
  // 🔄 Dynamic Status Messages
  int _statusIndex = 0;
  final List<String> _statusMessages = [
    "Connecting to drivers...",
    "Checking availability...",
    "Finding the best match...",
    "Almost there..."
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _textTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statusMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _textTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 30, spreadRadius: 5),
        ],
      ),
      // 🔥 FIX: Re-added ScrollView to prevent "Red Screen Overflow" crash
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Drag Handle
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            const SizedBox(height: 30), // Reduced from 40

            // 2. Gradient Spinning Loader
            SizedBox(
              height: 120, // Reduced from 140 to fit better
              width: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // A. The Spinning Gradient Ring
                  AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _spinController.value * 2 * math.pi,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.white,
  Color(0xFF667EEA),  // Deep Blue
  Color(0xFF38EF7D),  // Medium Blue
  Color(0xFF4FACFE),  // Soft Sky Blue
]
,
                              stops: [0.0, 0.4, 0.7, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // B. White Circle Mask
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),

                  // C. The Center Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade50,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_taxi_rounded, 
                      size: 40, 
                      color: Color(0xFF2962FF),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30), // Reduced spacing

            // 3. Dynamic Text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _statusMessages[_statusIndex],
                key: ValueKey<int>(_statusIndex),
                style: const TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w700, 
                  color: Color(0xFF212121),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 10),

            Text(
              "We are contacting drivers near you.",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30), // Reduced spacing

            // 4. Premium Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onCancel ?? () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: const Color(0xFFFFEBEE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  overlayColor: Colors.red.withOpacity(0.2),
                ),
                child: const Text(
                  "CANCEL REQUEST",
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 10), // Safe area buffer
          ],
        ),
      ),
    );
  }
}