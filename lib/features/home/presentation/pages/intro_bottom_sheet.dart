import 'package:flutter/material.dart';

class IntroBottomSheet extends StatefulWidget {
  final ScrollController scrollController;

  const IntroBottomSheet({super.key, required this.scrollController});

  @override
  State<IntroBottomSheet> createState() => _IntroBottomSheetState();
}

class _IntroBottomSheetState extends State<IntroBottomSheet> {
  // 🔄 State for the Banner Carousel
  int _currentBannerIndex = 0;
  final PageController _pageController = PageController(viewportFraction: 0.9);

  // 🎁 Mock Data for Promotional Banners
  final List<Map<String, dynamic>> _promos = [
    {
      "title": "Welcome to MokshaRide!",
      "subtitle": "Get 50% off on your first Auto ride.",
      "color1": const Color(0xFF2962FF),
      "color2": const Color(0xFF1565C0),
      "icon": Icons.local_activity,
    },
    {
      "title": "Safety First 🛡️",
      "subtitle": "All our drivers are KYC verified.",
      "color1": const Color(0xFF00C853),
      "color2": const Color(0xFF2E7D32),
      "icon": Icons.security,
    },
    {
      "title": "Refer & Earn",
      "subtitle": "Invite friends and get ₹50 wallet cash.",
      "color1": const Color(0xFFFF8F00),
      "color2": const Color(0xFFEF6C00),
      "icon": Icons.card_giftcard,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), 
            blurRadius: 15, 
            offset: const Offset(0, -5)
          )
        ],
      ),
      child: ListView(
        controller: widget.scrollController, // 👈 Required for DraggableScrollableSheet
        padding: const EdgeInsets.only(top: 10, bottom: 40),
        children: [
          // 1. DRAG HANDLE
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // 2. HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome to Moksha Ride 🛺",
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Affordable transportation for Chintamani.",
                  style: TextStyle(color: theme.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // 3. SWIPEABLE PROMO BANNERS 🎁
          SizedBox(
            height: 130,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentBannerIndex = index),
              itemCount: _promos.length,
              itemBuilder: (context, index) {
                final promo = _promos[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [promo['color1'], promo['color2']],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              promo['title'],
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              promo['subtitle'],
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Icon(promo['icon'], size: 40, color: Colors.white.withOpacity(0.8)),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Dots Indicator for Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _promos.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentBannerIndex == index ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentBannerIndex == index ? theme.primary : theme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // 4. RIDE SERVICES SECTION 🛺
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Our Services",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.onSurface),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildServiceIcon("Auto", 'assets/images/auto.png', theme),
              _buildServiceIcon("Cab", 'assets/images/car.png', theme),
              _buildServiceIcon("Bike", 'assets/images/bike.jpg', theme),
            ],
          ),

          const SizedBox(height: 30),
          const Divider(indent: 20, endIndent: 20),
          const SizedBox(height: 15),

          // 5. CONTACT & TRUST SECTION 📞
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Need Help?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.onSurface),
                ),
                const SizedBox(height: 12),
                
                // Contact Card
Container(
  decoration: BoxDecoration(
    color: theme.surfaceContainerHighest.withOpacity(0.5),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      )
    ],
  ),
  child: Column(
    children: [

      /// SUPPORT
      ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.primary.withOpacity(0.1),
          child: Icon(Icons.support_agent, color: theme.primary),
        ),
        title: const Text("24/7 Customer Support"),
        subtitle: const Text("+91 98765 43210"),
        trailing: IconButton(
          icon: const Icon(Icons.call),
          color: Colors.green,
          onPressed: () {
            // launch call
          },
        ),
      ),

      Divider(height: 1, indent: 70),

      /// EMAIL SUPPORT
      ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.primary.withOpacity(0.1),
          child: Icon(Icons.email_outlined, color: theme.primary),
        ),
        title: const Text("Email Support"),
        subtitle: const Text("support@ambaniyatri.com"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // open email
        },
      ),

      Divider(height: 1, indent: 70),

      /// ABOUT APP
      ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.primary.withOpacity(0.1),
          child: Icon(Icons.info_outline, color: theme.primary),
        ),
        title: const Text("About Moksha ride"),
        subtitle: const Text("Version 1.0.0"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // navigate to about page
        },
      ),

      Divider(height: 1, indent: 70),

      /// PRIVACY POLICY
      ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.primary.withOpacity(0.1),
          child: Icon(Icons.privacy_tip_outlined, color: theme.primary),
        ),
        title: const Text("Privacy Policy"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // open privacy policy
        },
      ),

      Divider(height: 1, indent: 70),

      /// TERMS & CONDITIONS
      ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.primary.withOpacity(0.1),
          child: Icon(Icons.description_outlined, color: theme.primary),
        ),
        title: const Text("Terms & Conditions"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // open terms
        },
      ),

      Divider(height: 1, indent: 70),

      /// EMERGENCY CONTACT
      ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.1),
          child: const Icon(Icons.emergency, color: Colors.red),
        ),
        title: const Text("Emergency Help"),
        subtitle: const Text("Quick assistance during ride"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // emergency action
        },
      ),

      const SizedBox(height: 10),
    ],
  ),
)

              ],
            ),
          ),
          
          const SizedBox(height: 100), // Buffer for floating action buttons
        ],
      ),
    );
  }

  // 🎨 Helper for Service Icons (Theme Aware)
  Widget _buildServiceIcon(String name, String assetPath, ColorScheme theme) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.surfaceContainerHighest, // Adapts to Dark/Light mode
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Image.asset(
            assetPath,
            errorBuilder: (c, o, s) => Icon(Icons.directions_car, size: 35, color: theme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(fontWeight: FontWeight.w600, color: theme.onSurface, fontSize: 14),
        ),
      ],
    );
  }
}