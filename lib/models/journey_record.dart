import 'travel_route.dart';

enum JourneyOutcome {
  success('환승 성공'),
  missed('환승 놓침'),
  unknown('확인 불가');

  const JourneyOutcome(this.label);
  final String label;
}

class JourneyRecord {
  const JourneyRecord({
    required this.id,
    required this.route,
    required this.completedAt,
    required this.outcome,
  });
  final String id;
  final TravelRoute route;
  final DateTime completedAt;
  final JourneyOutcome outcome;
}
