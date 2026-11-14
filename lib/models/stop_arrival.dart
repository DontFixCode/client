class StopArrival {
  const StopArrival({
    required this.routeNo,
    this.remainingSeconds,
    this.stopsAway,
  });
  final String routeNo;
  final int? remainingSeconds;
  final int? stopsAway;

  factory StopArrival.fromJson(Map<String, dynamic> json) {
    final route = json['route'] as Map<String, dynamic>?;
    return StopArrival(
      routeNo: route?['routeNo'] as String? ?? '-',
      remainingSeconds: json['remainingSeconds'] as int?,
      stopsAway: json['stopsAway'] as int?,
    );
  }

  String get minutesText {
    final seconds = remainingSeconds;
    if (seconds == null) return '-';
    return '${(seconds / 60).ceil()}분';
  }

  String get stopsAwayText {
    final count = stopsAway;
    if (count == null) return '';
    return '$count정거장 전';
  }
}
