import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moksharide_user/features/ride/data/ride_repository.dart';

class RideStatusScreen extends StatefulWidget {
  final String rideId;

  const RideStatusScreen({super.key, required this.rideId});

  @override
  State<RideStatusScreen> createState() => _RideStatusScreenState();
}

class _RideStatusScreenState extends State<RideStatusScreen>
    with SingleTickerProviderStateMixin {

  final RideRepository _rideRepository = RideRepository();

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xfff4f6fb),

      appBar: AppBar(
        title: const Text("Ride Status"),
        centerTitle: true,
        elevation: 0,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ride_requests')
            .doc(widget.rideId)
            .snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? "requested";

          return Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [

                /// STATUS CARD
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {

                    return Transform.scale(
                      scale: status == "requested"
                          ? _scaleAnimation.value
                          : 1,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),

                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(status),
                              _getStatusColor(status).withOpacity(.7)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),

                        child: Column(
                          children: [

                            Icon(
                              _getStatusIcon(status),
                              size: 70,
                              color: Colors.white,
                            ),

                            const SizedBox(height: 15),

                            Text(
                              _getStatusText(status),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                /// RIDE PROGRESS
                _rideProgress(status),

                const SizedBox(height: 30),

                /// RIDE DETAILS
                Container(
                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 10,
                      )
                    ],
                  ),

                  child: Column(
                    children: [

                      _locationRow(
                        "Pickup",
                        data['pickupAddress'] ?? "",
                        Icons.my_location,
                        Colors.green,
                      ),

                      const SizedBox(height: 20),

                      _locationRow(
                        "Drop",
                        data['dropAddress'] ?? "",
                        Icons.location_on,
                        Colors.orange,
                      ),

                      const Divider(height: 35),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Text(
                            "${data['distance'] ?? 0} km",
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey
                            ),
                          ),

                          Text(
                            "₹${data['estimatedPrice'] ?? 0}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),

                const Spacer(),

                /// CANCEL BUTTON
                if (status == "requested")
                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      onPressed: () async {

                        try {

                          await _rideRepository.cancelRide(widget.rideId);

                          Navigator.popUntil(
                              context,
                                  (route) => route.isFirst
                          );

                        } catch (e) {

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Failed to cancel ride")
                            ),
                          );

                        }

                      },

                      child: const Text(
                        "Cancel Ride",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }

  /// STATUS ICON
  IconData _getStatusIcon(String status) {
    switch (status) {
      case "requested":
        return Icons.search;
      case "accepted":
        return Icons.directions_car;
      case "completed":
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  /// STATUS COLOR
  Color _getStatusColor(String status) {
    switch (status) {
      case "requested":
        return Colors.orange;
      case "accepted":
        return Colors.blue;
      case "completed":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// STATUS TEXT
  String _getStatusText(String status) {
    switch (status) {
      case "requested":
        return "Searching drivers near you...";
      case "accepted":
        return "Driver is on the way!";
      case "completed":
        return "Ride completed successfully";
      default:
        return "Ride status";
    }
  }

  /// LOCATION ROW
  Widget _locationRow(
      String title,
      String location,
      IconData icon,
      Color color,
      ) {

    return Row(
      children: [

        Container(
          padding: const EdgeInsets.all(10),

          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            shape: BoxShape.circle,
          ),

          child: Icon(icon, color: color),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(
                title,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13
                ),
              ),

              const SizedBox(height: 4),

              Text(
                location,
                style: const TextStyle(
                    fontWeight: FontWeight.w600
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  /// RIDE PROGRESS BAR
  Widget _rideProgress(String status) {

    int step = 0;

    if (status == "accepted") step = 1;
    if (status == "completed") step = 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        _progressNode("Requested", step >= 0),
        _progressNode("Accepted", step >= 1),
        _progressNode("Completed", step >= 2),

      ],
    );
  }

  Widget _progressNode(String text, bool active) {

    return Column(
      children: [

        AnimatedContainer(
          duration: const Duration(milliseconds: 400),

          width: 16,
          height: 16,

          decoration: BoxDecoration(
            color: active ? Colors.green : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: active ? Colors.black : Colors.grey,
          ),
        )
      ],
    );
  }
}