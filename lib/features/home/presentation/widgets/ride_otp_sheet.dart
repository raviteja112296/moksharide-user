import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RideOtpSheet extends StatelessWidget {
  final String otp;
  final String driverName;
  final double driverRating;
  final String? driverPhotoUrl;
  final String vehicleModel; 
  final String vehicleNumber; 

  const RideOtpSheet({
    super.key,
    required this.otp,
    required this.driverName,
    required this.driverRating,
    this.driverPhotoUrl,
    this.vehicleModel = "White Swift", 
    this.vehicleNumber = "KA 05 MQ 4521", 
  });

  @override
  Widget build(BuildContext context) {
    final digits = otp.padLeft(4, '0').split(''); 
      String phoneNumber='+919603832514';
// 📞 Function to launch Phone Dialer
  Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint("Could not launch dialer");
    }
  }
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          )
        ],
      ),
      // 🔥 FIX: Wrapped in SingleChildScrollView to prevent overflow
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. DRAG HANDLE
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20), // Reduced spacing slightly

            // 2. DRIVER & VEHICLE PROFILE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green.shade400, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: driverPhotoUrl != null ? NetworkImage(driverPhotoUrl!) : null,
                      child: driverPhotoUrl == null 
                          ? const Icon(Icons.person, size: 28, color: Colors.grey) 
                          : null,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Name & Car Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, size: 12, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    driverRating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              vehicleModel,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicleNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),

                  // Call/Chat Actions
                  Column(
                    children: [
                      _ActionBtn(icon: Icons.phone, color: Colors.green, onTap: () {makePhoneCall(phoneNumber);}),
                      const SizedBox(height: 8),
                      _ActionBtn(icon: Icons.chat_bubble, color: Colors.blue, onTap: () {}),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // 3. OTP SECTION
            const Text(
              "Share OTP to Start Ride",
              style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            
            const SizedBox(height: 16),
            
            // Large OTP Digits
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: digits.map((d) => _OtpBox(digit: d)).toList(),
            ),
            
            const SizedBox(height: 25),
            
            // 4. Safety Tip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Only share this code once you are inside the vehicle.",
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20), 
          ],
        ),
      ),
    );
  }
}

// ✨ Helper for OTP Digit Box
class _OtpBox extends StatelessWidget {
  final String digit;
  const _OtpBox({required this.digit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 50, // Reduced width slightly
      height: 60, // Reduced height slightly
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 28, 
          fontWeight: FontWeight.bold, 
          color: Colors.black87,
        ),
      ),
    );
  }
}

// ✨ Helper for Circular Action Buttons
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}