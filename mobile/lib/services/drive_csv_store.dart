import 'drive_csv_store_stub.dart'
    if (dart.library.io) 'drive_csv_store_io.dart' as store;
import 'drive_csv_writer.dart';

Future<DriveCsvWriter> createDriveCsvWriter(String filename) {
  return store.createDriveCsvWriter(filename);
}
