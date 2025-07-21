extension StringExtension on String {
  String or(String? value) {
    return isEmpty ? (value ?? '') : this;
  }
}
