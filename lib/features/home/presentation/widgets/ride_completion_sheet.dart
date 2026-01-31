import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; 
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart'; // 📦 NEW: Import TTS

class RideCompletionSheet extends StatefulWidget {
  final String rideId;
  final double amount;

  const RideCompletionSheet({
    super.key, 
    required this.rideId, 
    required this.amount
  });

  @override
  State<RideCompletionSheet> createState() => _RideCompletionSheetState();
}

class _RideCompletionSheetState extends State<RideCompletionSheet> {
  // 0 = Payment, 1 = Feedback
  int _currentStep = 0; 
  late Razorpay _razorpay;
  final FlutterTts _flutterTts = FlutterTts(); // 🔊 TTS Instance

  @override
  void initState() {
    super.initState();
    
    // 1. Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);

    // 2. 🔊 Play Initial Audio
    _initTtsAndSpeak();
  }

  Future<void> _initTtsAndSpeak() async {
    // Configure TTS settings
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5); // Slower is clearer

    // 🗣️ Speak: "You reached..."
    await _flutterTts.speak("You have reached the destination. Please complete the payment.");
  }

  @override
  void dispose() {
    _razorpay.clear();
    _flutterTts.stop(); // Stop audio if user closes app
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
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
      'key': 'rzp_test_YXemoshVoIu50O', 
      'amount': (widget.amount * 100).toInt(), 
      'name': 'Moksha Ride',
      'description': 'Ride Payment',
      'prefill': {'contact': '9876543210', 'email': 'test@user.com'}
    };
    _razorpay.open(options);
  }

  // 🗣️ Helper to speak "Thank you" and close
  Future<void> _submitFeedback() async {
    // 1. Speak "Thank you"
    await _flutterTts.speak("Thank you for riding with Moksha ride.");
    
    // 2. Wait a moment for audio to start/finish (optional)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.pop(context); // Close sheet
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
                icon: const Icon(Icons.payment, color: Colors.white,),
                label: const Text("Pay with Razorpay", style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Cash Button
            TextButton(
              onPressed: () {
                setState(() => _currentStep = 1); 
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
              // Make sure this image exists or use a NetworkImage
              backgroundImage: AssetImage('assets/images/logo.png'), 
            ),
            const SizedBox(height: 10),
            const Text("Ravi Kumar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            
            RatingBar.builder(
              initialRating: 4,
              minRating: 1,
              direction: Axis.horizontal,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                // Save rating logic
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
                onPressed: _submitFeedback, // 🔥 Calls the Audio + Close logic
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.black,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("SUBMIT", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}