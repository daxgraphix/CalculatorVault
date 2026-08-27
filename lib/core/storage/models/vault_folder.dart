import 'package:hive/hive.dart';

class VaultFolder extends HiveObject {
  VaultFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.modifiedAt,
  });

  String id;
  String name;
  String? parentId;
  DateTime createdAt;
  DateTime modifiedAt;
}

class VaultFolderAdapter extends TypeAdapter<VaultFolder> {
  @override
  final int typeId = 1;

  @override
  VaultFolder read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return VaultFolder(
      id: fields[0] as String,
      name: fields[1] as String,
      parentId: fields[2] as String?,
      createdAt: DateTime.parse(fields[3] as String),
      modifiedAt: DateTime.parse(fields[4] as String),
    );
  }

  @override
  void write(BinaryWriter writer, VaultFolder obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.parentId);
    writer.writeByte(3);
    writer.write(obj.createdAt.toIso8601String());
    writer.writeByte(4);
    writer.write(obj.modifiedAt.toIso8601String());
  }
}
