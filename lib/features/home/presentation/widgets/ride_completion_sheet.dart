import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // Add this package for stars
import 'package:razorpay_flutter/razorpay_flutter.dart'; // Add for payments

class RideCompletionSheet extends StatefulWidget {
  final String rideId;
  final double amount;

  const RideCompletionSheet({
    Key? key, 
    required this.rideId, 
    required this.amount
  }) : super(key: key);

  @override
  State<RideCompletionSheet> createState() => _RideCompletionSheetState();
}

class _RideCompletionSheetState extends State<RideCompletionSheet> {
  // 0 = Payment, 1 = Feedback, 2 = Done
  int _currentStep = 0; 
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Payment Successful -> Move to Feedback
    setState(() {
      _currentStep = 1; 
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Successful!"), backgroundColor: Colors.green)
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}"), backgroundColor: Colors.red)
    );
  }

  void _startRazorpay() {
    var options = {
      'key': 'YOUR_RAZORPAY_KEY_HERE', // Replace with your Test Key
      'amount': (widget.amount * 100).toInt(), // Amount in paise
      'name': 'Moksha Ride',
      'description': 'Ride Payment',
      'prefill': {'contact': '9876543210', 'email': 'test@user.com'}
    };
    _razorpay.open(options);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          
          /// 💰 STEP 1: PAYMENT UI
          if (_currentStep == 0) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            const Text("Ride Completed!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Total Fare: ₹${widget.amount}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blue)),
            const SizedBox(height: 20),
            
            // Pay Online Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startRazorpay,
                icon: const Icon(Icons.payment),
                label: const Text("Pay with Razorpay"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Cash Button (Skip Payment logic for now)
            TextButton(
              onPressed: () {
                setState(() => _currentStep = 1); // Skip to feedback
              },
              child: const Text("Paid by Cash"),
            ),
          ],

          /// ⭐ STEP 2: FEEDBACK UI
          if (_currentStep == 1) ...[
            const Text("Rate your Driver", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage('assets/images/logo.png'), // Or network image
            ),
            const SizedBox(height: 10),
            const Text("Ravi Kumar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            
            // Star Rating (Requires flutter_rating_bar package)
            RatingBar.builder(
              initialRating: 4,
              minRating: 1,
              direction: Axis.horizontal,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                // Save rating logic here
              },
            ),
            const SizedBox(height: 20),
            
            TextField(
              decoration: InputDecoration(
                hintText: "Write a review (optional)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Close the sheet and go back to home map
                  Navigator.pop(context); 
                  // Reset UI state in HomePage if needed
                },
                child: const Text("SUBMIT"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}