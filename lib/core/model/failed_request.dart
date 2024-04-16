import 'package:hive/hive.dart';

part 'failed_request.g.dart';

@HiveType(typeId: 0)
class FailedRequest extends HiveObject {
  @HiveField(0)
  final String apiName;
  @HiveField(1)
  final String sessionID;
  @HiveField(2)
  final double lat;
  @HiveField(3)
  final double long;
  @HiveField(4)
  final String deviceId;
  @HiveField(5)
  final DateTime timestamp;

  FailedRequest({
    required this.apiName,
    required this.sessionID,
    required this.lat,
    required this.long,
    required this.deviceId,
    required this.timestamp,
  });
}
