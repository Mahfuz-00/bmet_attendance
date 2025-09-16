import '../Entities/position.dart';

abstract class GeolocationRepository {
  Future<Position> getCurrentPosition();
}