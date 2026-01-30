import 'package:flutter/material.dart';

class RideWaitingSheet extends StatefulWidget {
  final VoidCallback? onCancel;

  const RideWaitingSheet({super.key, this.onCancel});

  @override
  State<RideWaitingSheet> createState() => _RideWaitingSheetState();
}

class _RideWaitingSheetState extends State<RideWaitingSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24), // Removed vertical padding here
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // 🔥 FIX: Wrapped in SingleChildScrollView to prevent Overflow Error
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            
            // 1. Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            
            const SizedBox(height: 25), // Reduced space

            // 2. 📡 RADAR ANIMATION
            SizedBox(
              height: 100, // Reduced from 120 to fit better
              width: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildRipple(0.0),
                  _buildRipple(0.5),
                  Container(
                    width: 50, // Smaller icon container
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)
                      ]
                    ),
                    child: const Icon(Icons.directions_car, color: Colors.blue, size: 24),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. Text
            const Text(
              "Searching for drivers...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 5),

            Text(
              "We are notifying nearby drivers.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // 4. Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: const LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),

            const SizedBox(height: 20),

            // 5. Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: widget.onCancel ?? () {},
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                label: Text("CANCEL", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14), // Reduced padding
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 20), // Bottom safe area
          ],
        ),
      ),
    );
  }

  Widget _buildRipple(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double value = (_controller.value + delay) % 1.0;
        return Opacity(
          opacity: 1.0 - value,
          child: Transform.scale(
            scale: 1.0 + (value * 1.5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue.withOpacity(0.5),
                  width: 4 * (1.0 - value),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}