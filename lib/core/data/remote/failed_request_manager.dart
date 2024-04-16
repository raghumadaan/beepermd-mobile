import 'package:hive_flutter/hive_flutter.dart';

import '../../model/failed_request.dart';

class FailedRequestManager {
  static const String boxName = 'failedRequests';

  Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter<FailedRequest>(FailedRequestAdapter());
    await Hive.openBox<FailedRequest>(boxName);
  }

  Future<void> saveRequest(FailedRequest request) async {
    final box = Hive.box<FailedRequest>(boxName);
    await box.add(request);
  }

  Future<List<FailedRequest>> getFailedRequests() async {
    final box = Hive.box<FailedRequest>(boxName);
    return box.values.toList();
  }

  Future<void> removeRequest(FailedRequest request) async {
    final box = Hive.box<FailedRequest>(boxName);
    await box.delete(request.key);
  }

  Future<void> clearAllRequests() async {
    final box = Hive.box<FailedRequest>(boxName);
    await box.clear();
  }
}
