import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

abstract final class LocationService {
  static Future<bool> requestPermissions() async {
    final when = await Permission.location.request();
    if (!when.isGranted) return false;

    final always = await Permission.locationAlways.request();
    return always.isGranted;
  }

  static Future<bool> hasPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  static Future<Position> currentPosition() async {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }
}
