class AliceFormDataFile {
  final String? fileName;
  final String contentType;
  final int length;

  AliceFormDataFile(this.fileName, this.contentType, this.length);

  @override
  String toString() => '{fileName: $fileName, contentType: $contentType, length: $length}';
}
