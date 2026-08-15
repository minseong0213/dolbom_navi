abstract class DriveCsvWriter {
  String get path;

  void write(String value);

  Future<void> close();
}
