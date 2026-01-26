import 'package:flutter/material.dart';

class RideOtpSheet extends StatelessWidget {
  final String otp;
  final String driverName;
  final double driverRating;
  final String? driverPhotoUrl;

  const RideOtpSheet({
    super.key,
    required this.otp,
    required this.driverName,
    required this.driverRating,
    this.driverPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final digits = otp.padLeft(4, '•').substring(0, 4).split('');

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// DRAG HANDLE
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 18),

            /// 🚗 DRIVER HEADER
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      driverPhotoUrl != null ? NetworkImage(driverPhotoUrl!) : null,
                  child: driverPhotoUrl == null
                      ? const Icon(Icons.person, size: 24, color: Colors.grey)
                      : null,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            driverRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _ActionIcon(
                  icon: Icons.chat_bubble_outline,
                  color: Colors.blue.shade600,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _ActionIcon(
                  icon: Icons.phone_outlined,
                  color: Colors.green.shade600,
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 22),

            /// TITLE
            const Text(
              "Share OTP with Driver",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              "Your ride will start after OTP verification",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 22),

            /// 🔐 OTP BOXES (COMPACT — OLA / UBER STYLE)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: digits.map((digit) {
                  return Container(
                    width: 42,   // ✅ smaller
                    height: 50,  // ✅ smaller
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      digit,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 22),

            /// 🔒 INFO
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  "Do not share OTP with anyone else",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔘 ACTION ICON
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
