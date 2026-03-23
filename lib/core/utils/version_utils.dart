/// Compare two semver strings. Returns true if [remote] > [local].
bool isNewerVersion(String remote, String local) {
  final rParts = remote.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final lParts = local.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  for (int i = 0; i < rParts.length && i < lParts.length; i++) {
    if (rParts[i] > lParts[i]) return true;
    if (rParts[i] < lParts[i]) return false;
  }
  return rParts.length > lParts.length;
}
