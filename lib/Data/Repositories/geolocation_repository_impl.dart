import 'package:geolocator/geolocator.dart';
import '../../Domain/Entities/position.dart' as entity;
import '../../Domain/Repositories/geolocation_repository.dart';

class GeolocationRepositoryImpl implements GeolocationRepository {
  @override
  Future<entity.Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return entity.Position(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}