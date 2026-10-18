double? nullableDoubleFromJson(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

Map<String, dynamic> flagsFromJson(Object? value) {
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}
