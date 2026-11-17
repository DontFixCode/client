import 'dart:async';
import 'dart:convert';

import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/models/travel_route.dart';
import 'package:bus/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _json(Json data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Json _journey(String id, {String status = 'active'}) => {
  'journeyId': id,
  'lifecycleStatus': status,
  'stateVersion': status == 'active' ? 1 : 2,
  'resultVersion': 0,
  'selectionVersion': 1,
};

class _State extends AppState {
  _State({required super.api});

  @override
  Future<void> connectStream() async {}
}

void main() {
  for (final replace in [false, true]) {
    test('종료 전 조회 응답은 ${replace ? '새 이동을 덮지' : '종료된 이동을 복구하지'} 않는다', () async {
      final started = Completer<void>();
      final oldResponse = Completer<http.Response>();
      var reads = 0;
      final state = _State(
        api: BusApi(
          accessToken: () async => 'test-token',
          client: MockClient((request) async {
            if (request.method == 'POST') return _json(_journey('B'));
            if (request.url.path.endsWith('/journeys')) {
              return _json({'items': [], 'nextCursor': null});
            }
            if (++reads == 1) {
              started.complete();
              return oldResponse.future;
            }
            return _json(_journey('A', status: 'completed'));
          }),
        ),
      )..journey = _journey('A');
      addTearDown(state.dispose);

      final restore = state.restoreJourney('A');
      await started.future;
      await state.restoreJourney('A');
      expect(state.journeyId, isNull);
      if (replace) {
        await state.startJourney(
          TravelRoute.fromJson(
            {'candidateId': 'candidate-B'},
            searchId: 'search-B',
            origin: const Place(id: 'origin', name: '출발', address: ''),
            destination: const Place(
              id: 'destination',
              name: '도착',
              address: '',
            ),
          ),
        );
        expect(state.journeyId, 'B');
      }
      oldResponse.complete(_json(_journey('A')));
      await restore;
      expect(state.journeyId, replace ? 'B' : null);
    });
  }

  for (final signOutFirst in [true, false]) {
    test(
      '이전 계정 조회 중 ${signOutFirst ? '로그아웃 후' : '바로'} 로그인해도 새 계정만 복구한다',
      () async {
        final auth = SupabaseClient(
          'http://auth.test',
          'public-anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/logout')) return _json({});
            final email = (jsonDecode(request.body) as Json)['email'] as String;
            final id = email.startsWith('a')
                ? '11111111-1111-4111-8111-111111111111'
                : '22222222-2222-4222-8222-222222222222';
            final payload = base64Url
                .encode(
                  utf8.encode(
                    jsonEncode({
                      'sub': id,
                      'exp':
                          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                    }),
                  ),
                )
                .replaceAll('=', '');
            return _json({
              'access_token': 'e30.$payload.signature',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': id,
                'aud': 'authenticated',
                'email': email,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'user_metadata': {},
                'app_metadata': {},
              },
            });
          }),
        );
        addTearDown(auth.dispose);
        final started = Completer<void>();
        final oldResponse = Completer<http.Response>();
        var aReads = 0;
        final state = AppState(
          auth: auth,
          api: BusApi(
            accessToken: () async => auth.auth.currentSession?.accessToken,
            client: MockClient((request) async {
              if (request.url.path.endsWith('/me')) {
                final name = auth.auth.currentUser!.email!.startsWith('a')
                    ? 'A'
                    : 'B';
                if (name == 'A' && ++aReads == 2) {
                  started.complete();
                  return oldResponse.future;
                }
                return _json({'displayName': name});
              }
              return _json({'items': [], 'nextCursor': null});
            }),
          ),
        );
        addTearDown(state.dispose);
        await state.login('a@example.com', 'test-password');
        state.journey = _journey('A');
        final refresh = state.refreshAccount();
        await started.future;
        if (signOutFirst) await state.signOut();
        await state.login('b@example.com', 'test-password');
        oldResponse.complete(_json({'displayName': 'A'}));
        await refresh;
        expect(state.userName, 'B');
        expect(state.email, 'b@example.com');
        expect(state.journeyId, isNull);
      },
    );
  }
}
