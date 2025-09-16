import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../Domain/Entities/position.dart';
import '../../Domain/Usecases/get_location.dart';

abstract class GeolocationEvent extends Equatable {
  const GeolocationEvent();

  @override
  List<Object> get props => [];
}

class FetchLocation extends GeolocationEvent {}

abstract class GeolocationState extends Equatable {
  const GeolocationState();

  @override
  List<Object> get props => [];
}

class GeolocationInitial extends GeolocationState {}

class GeolocationLoading extends GeolocationState {}

class GeolocationLoaded extends GeolocationState {
  final Position position;

  const GeolocationLoaded(this.position);

  @override
  List<Object> get props => [position];
}

class GeolocationError extends GeolocationState {
  final String message;

  const GeolocationError(this.message);

  @override
  List<Object> get props => [message];
}

class GeolocationBloc extends Bloc<GeolocationEvent, GeolocationState> {
  final GetLocation getLocation;

  GeolocationBloc({required this.getLocation}) : super(GeolocationInitial()) {
    on<FetchLocation>((event, emit) async {
      emit(GeolocationLoading());
      try {
        final position = await getLocation();
        emit(GeolocationLoaded(position));
      } catch (e) {
        emit(GeolocationError(e.toString()));
      }
    });
  }
}