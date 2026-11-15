import '../data/bus_api.dart';
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
    this.searchId,
    this.legs = const [],
    this.evaluation = const {},
    this.startable = true,
    this.blockedReason,
    this.startMode,
    this.expiresAt,
    this.reasonCodes = const [],
    this.estimated = false,
  });
  final String id;
  final Place origin;
  final Place destination;
  final int? minutes;
  final int? walkMinutes;
  final List<String> busNumbers;
  final String boardingStop;
  final String arrivalStop;
  final String? transferStop;
  final int? marginMinutes;
  final int? probability;
  final bool recommended;
  final String reason;
  final int? waitMinutes;
  final String? searchId, blockedReason, startMode;
  final List<Json> legs;
  final Json evaluation;
  final bool startable;
  final DateTime? expiresAt;
  final List<String> reasonCodes;
  final bool estimated;
  bool get isLive => searchId != null;
  String get minutesLabel => minutes == null ? '시간 확인 불가' : '$minutes분';
  String get walkLabel => walkMinutes == null ? '도보 확인 불가' : '도보 $walkMinutes분';
  List<Json> get busLegs => legs.where((l) => l['kind'] == 'bus').toList();
  List<Json> get transferEvaluations =>
      (evaluation['transfers'] as List? ?? []).cast<Json>();
  factory TravelRoute.fromJson(
    Json json, {
    required String searchId,
    required Place origin,
    required Place destination,
    String? recommendedId,
    DateTime? expiresAt,
  }) {
    final legs = (json['legs'] as List? ?? []).cast<Json>();
    final buses = legs.where((l) => l['kind'] == 'bus').toList();
    final ev = json['evaluation'] as Json? ?? {};
    final transfers = (ev['transfers'] as List? ?? []).cast<Json>();
    final seconds = ev['expectedTotalSeconds'] ?? ev['nominalTotalSeconds'];
    final estimated =
        json['estimated'] == true ||
        buses.any(
          (leg) => [
            'boardEta',
            'alightEta',
          ].any((side) => leg[side]?['etaSource'] == 'headway_estimate'),
        );
    final reasons = <String>{
      ...List<String>.from(ev['reasonCodes'] ?? []),
      ...List<String>.from(json['startLimitReasons'] ?? []),
      ...List<String>.from(json['rankingReasonCodes'] ?? []),
      for (final leg in buses) ...List<String>.from(leg['reasonCodes'] ?? []),
    }.toList();
    return TravelRoute(
      id: json['candidateId'] as String,
      searchId: searchId,
      origin: origin,
      destination: destination,
      minutes: minutesFromSeconds(seconds),
      walkMinutes: minutesFromSeconds(ev['walkingSeconds']),
      waitMinutes: minutesFromSeconds(
        (ev['firstBoarding'] as Json?)?['waitSeconds'],
      ),
      busNumbers: buses
          .map((l) => (l['route']?['routeNo'] ?? '노선 미확인').toString())
          .toList(),
      boardingStop: buses.isEmpty
          ? '정류소 미확인'
          : buses.first['board']?['name'] as String? ?? '정류소 미확인',
      arrivalStop: buses.isEmpty
          ? '정류소 미확인'
          : buses.last['alight']?['name'] as String? ?? '정류소 미확인',
      transferStop: buses.length < 2
          ? null
          : buses.first['alight']?['name'] as String?,
      probability: transfers.length == 1
          ? probabilityPercent(transfers.first['probability'])
          : null,
      marginMinutes: transfers.length == 1
          ? minutesFromSeconds(transfers.first['slackSeconds'])
          : null,
      recommended: json['candidateId'] == recommendedId,
      startable: json['startable'] as bool? ?? true,
      blockedReason: json['startBlockedReason'] as String?,
      startMode: json['startMode'] as String?,
      expiresAt: expiresAt,
      legs: legs,
      evaluation: ev,
      reasonCodes: reasons,
      estimated: estimated,
      reason: json['startable'] == false
          ? '지금 시작할 수 없는 경로입니다. 새로 검색해 주세요.'
          : estimated
          ? '아직 출발하지 않은 차량의 배차간격으로 예상한 경로예요. 실제 도착시각과 다를 수 있어요.'
          : json['startMode'] == 'data_limited'
          ? '자료가 부족해 시간·확률이 일부 확인되지 않았습니다.'
          : json['candidateId'] == recommendedId
          ? '서버 평가 기준 추천 경로입니다.'
          : '서버에서 계산한 경로입니다.',
    );
  }
  int get transfers => busNumbers.length - 1;
  String get probabilityLabel => transferProbabilityLabel(probability);
}

int? minutesFromSeconds(dynamic seconds) =>
    seconds is num ? (seconds / 60).ceil() : null;
int? probabilityPercent(dynamic value) =>
    value is num ? (value * 100).round().clamp(0, 100) : null;
