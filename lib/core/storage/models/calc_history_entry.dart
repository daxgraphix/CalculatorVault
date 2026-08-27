import 'package:hive/hive.dart';

class CalcHistoryEntry extends HiveObject {
  CalcHistoryEntry({
    required this.id,
    required this.expression,
    required this.result,
    required this.createdAt,
  });

  String id;
  String expression;
  String result;
  DateTime createdAt;
}

class CalcHistoryEntryAdapter extends TypeAdapter<CalcHistoryEntry> {
  @override
  final int typeId = 2;

  @override
  CalcHistoryEntry read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return CalcHistoryEntry(
      id: fields[0] as String,
      expression: fields[1] as String,
      result: fields[2] as String,
      createdAt: DateTime.parse(fields[3] as String),
    );
  }

  @override
  void write(BinaryWriter writer, CalcHistoryEntry obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.expression);
    writer.writeByte(2);
    writer.write(obj.result);
    writer.writeByte(3);
    writer.write(obj.createdAt.toIso8601String());
  }
}
