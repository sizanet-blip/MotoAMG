String formatNavigationDuration(int totalSeconds) {
  if (totalSeconds <= 0) {
    return '—';
  }
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) {
    return '${hours} h ${minutes} min';
  }
  if (minutes > 0) {
    return '$minutes min';
  }
  return '$totalSeconds s';
}
