import 'dart:async';
import 'dart:convert';

import 'package:bus/data/bus_api.dart';
import 'package:bus/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

http.Response _json(Json data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
);

Json _journey({required bool changed}) => {
  'journeyId': 'journey',
  'lifecycleStatus': 'active',
  'stateVersion': changed ? 4 : 1,
  'resultVersion': changed ? 2 : 1,
  'selectionVersion': changed ? 2 : 1,
  'movementState': changed ? 'transferring' : 'walking',
  'selectedRoute': {
    'candidateId': changed ? 'new-route' : 'old-route',
    'searchId': 'search',
    'selectionVersion': changed ? 2 : 1,
    'origin': {'lat': 36.3504, 'lon': 127.3845, 'name': '시청'},
    'destination': {'lat': 36.3324, 'lon': 127.4342, 'name': '대전역'},
    'legs': [
      {'legIndex': 0, 'kind': 'walk'},
      {
        'legIndex': 1,
        'kind': 'bus',
        'route': {'id': '605000', 'routeNo': '605'},
        'board': {'name': '시청'},
        'alight': {'name': '환승 정류소'},
      },
      {'legIndex': 2, 'kind': 'walk'},
      {
        'legIndex': 3,
        'kind': 'bus',
        'route': {
          'id': changed ? '612000' : '710000',
          'routeNo': changed ? '612' : '710',
        },
        'board': {'name': '환승 정류소'},
        'alight': {'name': '대전역'},
      },
      {'legIndex': 4, 'kind': 'walk'},
    ],
  },
  'currentProgress': {
    'legIndex': changed ? 2 : 0,
    'nextBusLegIndex': changed ? 3 : 1,
    'boarded': null,
    'completedBusLegs': changed ? [1] : [],
  },
  'guidance': {'baseStateVersion': changed ? 4 : 1},
  'guidanceStatus': 'current',
  'proposedRoute': null,
  'transferResults': [
    {
      'snapshotKey': 'selection-1-transfer-1',
      'selectionVersion': 1,
      'transferIndex': 1,
    },
    if (changed)
      {
        'snapshotKey': 'selection-2-transfer-1',
        'selectionVersion': 2,
        'transferIndex': 1,
      },
  ],
};

class _Socket implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  late final _Sink output = _Sink(() => incoming.close());
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  WebSocketSink get sink => output;
  @override
  Future<void> get ready => Future.value();
  @override
  int? get closeCode => null;
  void emit(Json message) => incoming.add(jsonEncode(message));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  _Sink(this.onClose);
  final Future<void> Function() onClose;
  @override
  void add(dynamic data) {}
  @override
  Future<void> close([int? code, String? reason]) async => unawaited(onClose());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends BusApi {
  _Api(Future<http.Response> Function(http.Request) handler)
    : super(
        client: MockClient(handler),
        baseUrl: 'https://test',
        accessToken: () async => 'test-token',
      );
  final sockets = <_Socket>[];
  @override
  WebSocketChannel connect(String journeyId) {
    final socket = _Socket();
    sockets.add(socket);
    return socket;
  }
}

void main() {
  test('선택 버전만 바뀐 스트림은 상세를 한 번 조회해 경로·진행·환승 결과를 함께 갱신한다', () async {
    final detailResponse = Completer<http.Response>();
    var reads = 0;
    final api = _Api((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/journeys/journey');
      reads++;
      return reads == 1
          ? _json(_journey(changed: false))
          : detailResponse.future;
    });
    final state = AppState(api: api);
    addTearDown(state.dispose);
    await state.restoreJourney('journey');
    expect(state.activeRoute!.id, 'old-route');
    expect(reads, 1);

    final mixedStates = <String>[];
    state.addListener(() {
      if (state.activeRoute?.id == 'old-route' &&
          state.progress['nextBusLegIndex'] == 3) {
        mixedStates.add('이전 경로에 새 진행 상태가 표시됨');
      }
    });
    final detail = _journey(changed: true);
    final message = {...detail, 'type': 'journey_state'}
      ..remove('selectedRoute')
      ..remove('transferResults');
    final socket = api.sockets.single;
    socket.emit(message);
    await Future<void>.delayed(Duration.zero);
    expect(reads, 2, reason: '새 selectionVersion은 상세 GET이 필요함');
    expect(mixedStates, isEmpty);

    socket.emit(message);
    await Future<void>.delayed(Duration.zero);
    expect(reads, 2, reason: '같은 선택 버전의 수신은 진행 중인 조회를 중복하지 않음');

    detailResponse.complete(_json(detail));
    await Future<void>.delayed(Duration.zero);
    expect(state.activeRoute!.id, 'new-route');
    expect(state.activeRoute!.busNumbers, ['605', '612']);
    expect(state.journey!['selectionVersion'], 2);
    expect(state.progress['nextBusLegIndex'], 3);
    expect(state.journey!['transferResults'], detail['transferResults']);
    expect(reads, 2);
    expect(mixedStates, isEmpty);
  });
}
