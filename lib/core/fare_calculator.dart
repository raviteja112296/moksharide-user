class FareCalculator {
  static const double baseFare = 40.0;
  static const double perKmRate = 12.0;

  static double calculateFare(double distanceKm) {
    return baseFare + (distanceKm * perKmRate);
  }
}
