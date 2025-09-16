import '../Entities/position.dart';
import '../Repositories/geolocation_repository.dart';

class GetLocation {
  final GeolocationRepository repository;

  GetLocation(this.repository);

  Future<Position> call() async {
    return repository.getCurrentPosition();
  }
}