import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'drive_csv_writer.dart';

Future<DriveCsvWriter> createDriveCsvWriter(String filename) async {
  final documents = await getApplicationDocumentsDirectory();
  final directory =
      Directory('${documents.path}${Platform.pathSeparator}drive_data');
  await directory.create(recursive: true);
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  return _IoDriveCsvWriter(file.path, file.openWrite());
}

class _IoDriveCsvWriter implements DriveCsvWriter {
  _IoDriveCsvWriter(this.path, this._sink);

  @override
  final String path;

  final IOSink _sink;

  @override
  void write(String value) => _sink.write(value);

  @override
  Future<void> close() => _sink.close();
}
