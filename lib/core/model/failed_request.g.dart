// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'failed_request.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FailedRequestAdapter extends TypeAdapter<FailedRequest> {
  @override
  final int typeId = 0;

  @override
  FailedRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FailedRequest(
      apiName: fields[0] as String,
      sessionID: fields[1] as String,
      lat: fields[2] as double,
      long: fields[3] as double,
      deviceId: fields[4] as String,
      timestamp: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FailedRequest obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.apiName)
      ..writeByte(1)
      ..write(obj.sessionID)
      ..writeByte(2)
      ..write(obj.lat)
      ..writeByte(3)
      ..write(obj.long)
      ..writeByte(4)
      ..write(obj.deviceId)
      ..writeByte(5)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailedRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
