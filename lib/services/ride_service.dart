class RideService {
  final String id;
  final String name;
  final String image;
  double distanceKm;
  int durationMin;
  double price;

  RideService({
    required this.id,
    required this.name,
    required this.image,
    required this.distanceKm,
    required this.durationMin,
    required this.price,
  });
}
