import 'package:hive/hive.dart';

enum VaultFileType { photo, video, audio, document, other }

class VaultFile extends HiveObject {
  VaultFile({
    required this.id,
    required this.originalName,
    required this.encryptedFileName,
    this.thumbnailFileName,
    required this.mimeType,
    required this.fileType,
    required this.fileSize,
    required this.createdAt,
    required this.modifiedAt,
    this.folderId,
    this.isFavorite = false,
    this.durationMs,
    this.width,
    this.height,
    this.isDeleted = false,
    this.deletedAt,
  });

  String id;
  String originalName;
  String encryptedFileName;
  String? thumbnailFileName;
  String mimeType;
  VaultFileType fileType;
  int fileSize;
  DateTime createdAt;
  DateTime modifiedAt;
  String? folderId;
  bool isFavorite;
  int? durationMs;
  int? width;
  int? height;
  bool isDeleted;
  DateTime? deletedAt;
}

/// Hand-written TypeAdapter — deliberately avoids build_runner/codegen.
/// typeId 0 is reserved for this model; keep IDs stable across releases.
class VaultFileAdapter extends TypeAdapter<VaultFile> {
  @override
  final int typeId = 0;

  @override
  VaultFile read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return VaultFile(
      id: fields[0] as String,
      originalName: fields[1] as String,
      encryptedFileName: fields[2] as String,
      thumbnailFileName: fields[3] as String?,
      mimeType: fields[4] as String,
      fileType: VaultFileType.values[fields[5] as int],
      fileSize: fields[6] as int,
      createdAt: DateTime.parse(fields[7] as String),
      modifiedAt: DateTime.parse(fields[8] as String),
      folderId: fields[9] as String?,
      isFavorite: fields[10] as bool,
      durationMs: fields[11] as int?,
      width: fields[12] as int?,
      height: fields[13] as int?,
      isDeleted: fields[14] as bool? ?? false,
      deletedAt: fields[15] != null ? DateTime.parse(fields[15] as String) : null,
    );
  }

  @override
  void write(BinaryWriter writer, VaultFile obj) {
    writer.writeByte(16);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.originalName);
    writer.writeByte(2);
    writer.write(obj.encryptedFileName);
    writer.writeByte(3);
    writer.write(obj.thumbnailFileName);
    writer.writeByte(4);
    writer.write(obj.mimeType);
    writer.writeByte(5);
    writer.write(obj.fileType.index);
    writer.writeByte(6);
    writer.write(obj.fileSize);
    writer.writeByte(7);
    writer.write(obj.createdAt.toIso8601String());
    writer.writeByte(8);
    writer.write(obj.modifiedAt.toIso8601String());
    writer.writeByte(9);
    writer.write(obj.folderId);
    writer.writeByte(10);
    writer.write(obj.isFavorite);
    writer.writeByte(11);
    writer.write(obj.durationMs);
    writer.writeByte(12);
    writer.write(obj.width);
    writer.writeByte(13);
    writer.write(obj.height);
    writer.writeByte(14);
    writer.write(obj.isDeleted);
    writer.writeByte(15);
    writer.write(obj.deletedAt?.toIso8601String());
  }
}
