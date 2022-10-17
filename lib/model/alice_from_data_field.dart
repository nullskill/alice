class AliceFormDataField {
  final String name;
  final String value;

  AliceFormDataField(this.name, this.value);

  @override
  String toString() => '{"$name": "$value"}';
}
