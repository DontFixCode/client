import 'place.dart';

String transferProbabilityLabel(int? probability) => switch (probability) {
  null => '확인 불가',
  < 20 => '매우 낮음',
  < 40 => '낮음',
  < 60 => '보통',
  < 80 => '높음',
  _ => '매우 높음',
};

class TravelRoute {
  const TravelRoute({
    required this.id,
    required this.origin,
    required this.destination,
    required this.minutes,
    required this.walkMinutes,
    required this.busNumbers,
    required this.boardingStop,
    required this.arrivalStop,
    required this.reason,
    this.transferStop,
    this.marginMinutes,
    this.probability,
    this.recommended = false,
    this.waitMinutes = 4,
  });
  final String id;
  final Place origin;
  final Place destination;
  final int minutes;
  final int walkMinutes;
  final List<String> busNumbers;
  final String boardingStop;
  final String arrivalStop;
  final String? transferStop;
  final int? marginMinutes;
  final int? probability;
  final bool recommended;
  final String reason;
  final int waitMinutes;
  int get transfers => busNumbers.length - 1;
  String get probabilityLabel => transferProbabilityLabel(probability);
}
