import 'package:hive_flutter/hive_flutter.dart';

import '../../model/failed_request.dart';

class FailedRequestManager {
  static final FailedRequestManager _instance =
      FailedRequestManager._internal();

  factory FailedRequestManager() => _instance;

  FailedRequestManager._internal();

  static const String boxName = 'failedRequests';

  late Box<FailedRequest> _failedReqBox;

  Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter<FailedRequest>(FailedRequestAdapter());
    _failedReqBox = await Hive.openBox<FailedRequest>(boxName);
  }

  Future<void> saveRequest(FailedRequest request) async {
    await _failedReqBox.add(request);
  }

  Future<List<FailedRequest>> getFailedRequests() async {
    return _failedReqBox.values.toList();
  }

  Future<void> removeRequest(FailedRequest request) async {
    await _failedReqBox.delete(request.key);
  }

  Future<void> clearAllRequests() async {
    await _failedReqBox.clear();
  }
}
