import '../models/place.dart';
import '../models/travel_route.dart';

/// UI 체험용 데이터입니다. 실제 노선, 운행 시각, 예측 확률이 아닙니다.
abstract final class DemoData {
  // ponytail: 고정된 환승 제안 한 건으로 UI를 체험해요. 교통 API 연결 시 교체합니다.
  static TravelRoute? fasterTransfer(TravelRoute route) {
    if (route.transfers != 1 ||
        route.transferStop == null ||
        route.id.endsWith('_faster') ||
        route.minutes <= 5) {
      return null;
    }
    final nextBus = route.busNumbers.last == '601' ? '705' : '601';
    return TravelRoute(
      id: '${route.id}_faster',
      origin: route.origin,
      destination: route.destination,
      minutes: route.minutes - 5,
      walkMinutes: route.walkMinutes,
      busNumbers: [route.busNumbers.first, nextBus],
      boardingStop: route.boardingStop,
      arrivalStop: route.arrivalStop,
      transferStop: route.transferStop,
      marginMinutes: 6,
      probability: 92,
      recommended: true,
      waitMinutes: route.waitMinutes,
      reason: '같은 정류장에서 갈아타고 5분 더 일찍 도착해요.',
    );
  }

  static const places = <Place>[
    Place(
      id: 'daejeon_station',
      name: '대전역',
      address: '대전 동구 중앙로 215',
      category: '기차역',
    ),
    Place(
      id: 'arboretum',
      name: '한밭수목원',
      address: '대전 서구 둔산대로 169',
      category: '공원',
    ),
    Place(
      id: 'city_hall',
      name: '대전시청',
      address: '대전 서구 둔산로 100',
      category: '공공기관',
    ),
    Place(
      id: 'chungnam',
      name: '충남대학교',
      address: '대전 유성구 대학로 99',
      category: '대학교',
    ),
    Place(
      id: 'complex',
      name: '대전복합터미널',
      address: '대전 동구 동서대로 1689',
      category: '터미널',
    ),
    Place(
      id: 'expo',
      name: '엑스포과학공원',
      address: '대전 유성구 대덕대로 480',
      category: '공원',
    ),
    Place(
      id: 'yuseong',
      name: '유성온천역',
      address: '대전 유성구 계룡로 97',
      category: '지하철역',
    ),
    Place(
      id: 'seoul',
      name: '서울역',
      address: '서울 용산구 한강대로 405',
      category: '지원 지역 밖',
      supported: false,
    ),
  ];

  static List<TravelRoute> routes(Place origin, Place destination) {
    if (!origin.supported ||
        !destination.supported ||
        origin.id == destination.id) {
      return [];
    }
    return [
      TravelRoute(
        id: 'relaxed',
        origin: origin,
        destination: destination,
        minutes: 38,
        walkMinutes: 6,
        busNumbers: const ['605', '705'],
        boardingStop: '${origin.name} 정류장',
        transferStop: '시청역',
        arrivalStop: '${destination.name} 정류장',
        marginMinutes: 8,
        probability: 94,
        recommended: true,
        reason: '환승 여유가 8분 있어, 서두르지 않고 갈아탈 수 있어요.',
      ),
      TravelRoute(
        id: 'fast',
        origin: origin,
        destination: destination,
        minutes: 32,
        walkMinutes: 8,
        busNumbers: const ['102', '104'],
        boardingStop: '${origin.name} 정류장',
        transferStop: '정부청사역',
        arrivalStop: '${destination.name} 정류장',
        marginMinutes: 3,
        probability: 72,
        reason: '가장 빠르지만 환승 시간이 짧아 서둘러야 해요.',
        waitMinutes: 2,
      ),
      TravelRoute(
        id: 'direct',
        origin: origin,
        destination: destination,
        minutes: 46,
        walkMinutes: 10,
        busNumbers: const ['606'],
        boardingStop: '${origin.name} 정류장',
        arrivalStop: '${destination.name} 정류장',
        reason: '갈아타지 않고, 한 번에 편하게 이동해요.',
        waitMinutes: 6,
      ),
      TravelRoute(
        id: 'unknown',
        origin: origin,
        destination: destination,
        minutes: 41,
        walkMinutes: 7,
        busNumbers: const ['311', '618'],
        boardingStop: '${origin.name} 정류장',
        transferStop: '오룡역',
        arrivalStop: '${destination.name} 정류장',
        marginMinutes: 5,
        reason: '차량 정보가 부족해 환승 확률을 확인할 수 없어요.',
        waitMinutes: 5,
      ),
    ];
  }
}
