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
    String phoneNumber = '+919603832514';

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
        color: Color(0xFFF8FAFC), // Soft modern background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),

          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // DRIVER PROFILE
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
                    border: Border.all(
                        color: const Color(0xFF10B981), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: driverPhotoUrl != null
                        ? NetworkImage(driverPhotoUrl!)
                        : null,
                    child: driverPhotoUrl == null
                        ? const Icon(Icons.person,
                            size: 28, color: Color(0xFF94A3B8))
                        : null,
                  ),
                ),

                const SizedBox(width: 16),

                // Name & Car
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 12,
                                    color: Color(0xFFF59E0B)),
                                const SizedBox(width: 4),
                                Text(
                                  driverRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            vehicleModel,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "KA 05 MQ 4521",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.5,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Column(
                  children: [
                    _ActionBtn(
                      icon: Icons.phone,
                      color: const Color(0xFF10B981),
                      onTap: () => makePhoneCall(phoneNumber),
                    ),
                    const SizedBox(height: 8),
                    _ActionBtn(
                      icon: Icons.chat_bubble,
                      color: const Color(0xFF2563EB),
                      onTap: () {},
                    ),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // OTP TITLE
          const Text(
            "Share OTP to Start Ride",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // OTP BOXES
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: digits.map((d) => _OtpBox(digit: d)).toList(),
          ),

          const SizedBox(height: 25),

          // Safety Tip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.security,
                    size: 20, color: Color(0xFF0284C7)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Only share this code once you are inside the vehicle.",
                    style: TextStyle(
                      color: Color(0xFF075985),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String digit;
  const _OtpBox({required this.digit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 50,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFE2E8F0), width: 1.5),
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
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
