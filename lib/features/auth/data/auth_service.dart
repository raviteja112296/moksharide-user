import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Signs in with Google and returns the Firebase User
  /// 
  /// Throws [FirebaseAuthException] or [GoogleSignInException] on failure
  Future<User> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      // ignore: avoid_print
      print('Google user: $googleUser');

      if (googleUser == null) {
        // User cancelled the sign-in
        throw FirebaseAuthException(
          code: 'sign_in_cancelled',
          message: 'Google sign-in was cancelled',
        );
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('Access Token: ${googleAuth.accessToken}');
      print('ID Token: ${googleAuth.idToken}');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Failed to sign in with Google',
        );
      }

      return user;
    } on FirebaseAuthException catch (e) {
      // Re-throw Firebase auth exceptions
      rethrow;
    } catch (e) {
      // Handle any other exceptions
      throw FirebaseAuthException(
        code: 'sign_in_failed',
        message: 'Failed to sign in with Google: ${e.toString()}',
      );
      
    }
    
  }
  
  /// Signs out the current user
  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _firebaseAuth.signOut(),
      ]);
    } catch (e) {
      throw FirebaseAuthException(
        code: 'sign_out_failed',
        message: 'Failed to sign out: ${e.toString()}',
      );
    }
  }

  /// Returns the current Firebase User
  User? get currentUser => _firebaseAuth.currentUser;

  /// Returns a stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}


