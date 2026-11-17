import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/backend_config.dart';
import '../data/bus_api.dart';

import 'package:flutter/widgets.dart';

import '../data/demo_data.dart';
import '../models/journey_record.dart';
import '../models/place.dart';
import '../models/travel_route.dart';

/// 서버 이동 상태를 기준으로 동기화합니다. 체험 모드는 명시적으로 선택합니다.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({this.demoMode = BackendConfig.demo, this.auth, BusApi? api}) {
    this.api =
        api ??
        BusApi(
          accessToken: () async {
            if (accountDeleted) return null;
            final session = auth?.auth.currentSession;
            if (session != null && session.isExpired) {
              await auth!.auth.refreshSession();
            }
            return auth?.auth.currentSession?.accessToken;
          },
        );
    this.api.onAccountDeleted = _accountDeleted;
    if (!demoMode) {
      origin = const Place(id: 'unset', name: '출발지를 선택해 주세요', address: '');
    }
  }
  final bool demoMode;
  // Supabase는 복원·토큰 갱신을 담당하고 FastAPI에는 사용자 access token만 전달합니다.
  final SupabaseClient? auth;
  late final BusApi api;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<dynamic>? _socketSubscription;
  StreamSubscription<Position>? _positionSubscription;
  WebSocketChannel? _socket;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _observingLifecycle = false;
  bool busy = false;
  bool passwordRecovery = false;
  bool accountDeleted = false;
  bool streamConnected = false;
  String? syncError, streamError, locationError;
  bool locatingOrigin = false;
  bool _originLocationAttempted = false;
  String? originLocationError;
  Json? journey;
  List<Json> serverHistory = [];
  String? historyCursor;
  Json? searchResult;
  bool searchLoading = false;
  String? searchError;
  int _searchGeneration = 0;
  int? _refreshingSession;
  String? _sessionUserId;
  int _sessionGeneration = 0;
  int _journeyGeneration = 0;
  Json? _pendingEvent;
  String? _pendingEventKey;
  String? _pendingEventJourneyId;
  bool get hasPendingEvent => _pendingEvent != null;
  String? get pendingEventJourneyId => _pendingEventJourneyId;
  bool get authConfigured => auth != null;
  bool get hasServerSession =>
      !accountDeleted && auth?.auth.currentSession != null;
  String? get journeyId => journey?['journeyId'] as String?;
  Json get progress => journey?['currentProgress'] as Json? ?? {};
  Json? get guidance {
    final data = journey?['guidance'] as Json?;
    return data?['baseStateVersion'] == journey?['stateVersion'] ? data : null;
  }

  Future<void> initialize() async {
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    if (demoMode || auth == null) return;
    _authSubscription = auth!.auth.onAuthStateChange.listen(
      (event) {
        if (event.event == AuthChangeEvent.signedOut) {
          _clearSession();
        } else if (event.event == AuthChangeEvent.passwordRecovery) {
          passwordRecovery = true;
          _notify();
        } else if ((event.event == AuthChangeEvent.signedIn ||
                event.event == AuthChangeEvent.initialSession) &&
            event.session != null) {
          unawaited(refreshAccount());
        } else if (event.event == AuthChangeEvent.tokenRefreshed &&
            journeyId != null) {
          unawaited(connectStream());
        }
      },
      onError: (Object error) {
        syncError = '인증 연결을 확인해 주세요.';
        _notify();
      },
    );
    if (hasServerSession) await refreshAccount();
  }

  void _notify() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Future<T> perform<T>(Future<T> Function() action) async {
    if (busy) throw const ApiException('BUSY', '이전 요청을 처리 중이에요.');
    busy = true;
    _notify();
    try {
      return await action();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> login(String email, String password) async {
    if (demoMode) {
      signIn(name: email.split('@').first, email: email);
      return;
    }
    if (auth == null) {
      throw const ApiException(
        'AUTH_NOT_CONFIGURED',
        '서버 연결 설정이 필요해요. 실행 설정을 확인해 주세요.',
      );
    }
    await auth!.auth.signInWithPassword(email: email, password: password);
    accountDeleted = false;
    await refreshAccount();
  }

  Future<bool> signup(String name, String email, String password) async {
    if (demoMode) {
      signIn(name: name, email: email);
      return true;
    }
    if (auth == null) {
      throw const ApiException('AUTH_NOT_CONFIGURED', '서버 연결 설정이 필요해요.');
    }
    final result = await auth!.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
      emailRedirectTo: BackendConfig.authRedirect.isEmpty
          ? null
          : BackendConfig.authRedirect,
    );
    if (result.session == null) return false;
    accountDeleted = false;
    await api.request('PATCH', '/me', body: {'displayName': name});
    await refreshAccount();
    return true;
  }

  Future<void> resetPassword(String email) async {
    if (demoMode) return;
    if (auth == null) {
      throw const ApiException('AUTH_NOT_CONFIGURED', '서버 연결 설정이 필요해요.');
    }
    await auth!.auth.resetPasswordForEmail(
      email,
      redirectTo: BackendConfig.authRedirect.isEmpty
          ? null
          : BackendConfig.authRedirect,
    );
  }

  Future<void> changeRecoveredPassword(String password) async {
    if (auth == null || !passwordRecovery) {
      throw const ApiException('RECOVERY_REQUIRED', '재설정 이메일의 링크로 다시 접속해 주세요.');
    }
    await auth!.auth.updateUser(UserAttributes(password: password));
    passwordRecovery = false;
    _notify();
    await refreshAccount();
  }

  Future<void> refreshAccount() async {
    if (demoMode || !hasServerSession) return;
    final userId = auth!.auth.currentUser!.id;
    if (_sessionUserId != null && _sessionUserId != userId) _clearSession();
    _sessionUserId = userId;
    final generation = _sessionGeneration;
    if (_refreshingSession == generation) return;
    _refreshingSession = generation;
    syncError = null;
    _notify();
    try {
      final profile = await api.request('GET', '/me');
      if (auth!.auth.currentUser?.id != userId ||
          _disposed ||
          generation != _sessionGeneration) {
        return;
      }
      email = auth!.auth.currentUser?.email;
      userName =
          profile['displayName'] as String? ??
          auth!.auth.currentUser?.userMetadata?['display_name'] as String? ??
          email?.split('@').first ??
          '여행자';
      try {
        await loadHistory();
      } catch (error) {
        syncError = error.toString();
      }
      if (generation != _sessionGeneration) return;
      final active = await api.request(
        'GET',
        '/journeys',
        query: {'status': 'active'},
      );
      if (auth!.auth.currentUser?.id != userId ||
          _disposed ||
          generation != _sessionGeneration) {
        return;
      }
      final items = active['items'] as List;
      if (items.isNotEmpty) {
        await restoreJourney(items.first['journeyId'] as String);
      }
    } catch (error) {
      if (generation == _sessionGeneration) syncError = error.toString();
    } finally {
      if (_refreshingSession == generation) _refreshingSession = null;
      _notify();
    }
  }

  Future<List<Place>> searchPlaces(String query) async {
    if (demoMode) {
      return DemoData.places
          .where(
            (p) => '${p.name}${p.address}'
                .replaceAll(' ', '')
                .contains(query.replaceAll(' ', '')),
          )
          .toList();
    }
    final result = await api.request(
      'GET',
      '/places/search',
      query: {'q': query},
    );
    return (result['items'] as List)
        .map((p) => Place.fromJson(p as Json))
        .toList();
  }

  Future<void> searchRoutes() async {
    if (demoMode) return;
    final generation = ++_searchGeneration;
    searchLoading = true;
    searchError = null;
    searchResult = null;
    _notify();
    try {
      if (!origin.hasCoordinates || destination?.hasCoordinates != true) {
        throw const ApiException(
          'COORDINATES_REQUIRED',
          '출발지와 도착지를 GPS·장소 검색·좌표 입력으로 지정해 주세요.',
        );
      }
      if (origin.latitude == destination!.latitude &&
          origin.longitude == destination!.longitude) {
        throw const ApiException(
          'SAME_PLACE',
          '출발지와 도착지가 같아요. 다른 장소를 선택해 주세요.',
        );
      }
      var result = await api.request(
        'POST',
        '/route-searches',
        body: {'origin': origin.toJson(), 'destination': destination!.toJson()},
      );
      final id = result['searchId'] as String;
      // ponytail: 60초 동안 조회한 뒤 수동 재조회를 제공합니다. 장기 검색은 워커 완료 알림으로 교체할 수 있습니다.
      for (
        var i = 0;
        i < 60 && generation == _searchGeneration && !_disposed;
        i++
      ) {
        result = await api.request('GET', '/route-searches/$id');
        if (generation != _searchGeneration || _disposed) return;
        searchResult = result;
        if (result['status'] != 'processing') break;
        _notify();
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } catch (error) {
      if (generation == _searchGeneration) searchError = error.toString();
    } finally {
      if (generation == _searchGeneration) {
        searchLoading = false;
        _notify();
      }
    }
  }

  void stopSearchPolling() {
    _searchGeneration++;
    searchLoading = false;
  }

  Future<void> refreshSearch() async {
    final id = searchResult?['searchId'];
    if (id == null) return searchRoutes();
    final generation = ++_searchGeneration;
    searchLoading = true;
    searchError = null;
    _notify();
    try {
      final result = await api.request('GET', '/route-searches/$id');
      if (generation == _searchGeneration) searchResult = result;
    } catch (error) {
      if (generation == _searchGeneration) searchError = error.toString();
    } finally {
      if (generation == _searchGeneration) {
        searchLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadHistory({bool more = false}) async {
    if (demoMode) return;
    final generation = _sessionGeneration;
    final result = await api.request(
      'GET',
      '/journeys',
      query: {if (more && historyCursor != null) 'cursor': historyCursor!},
    );
    if (_disposed || generation != _sessionGeneration) return;
    serverHistory = [
      ...(more ? serverHistory : <Json>[]),
      ...(result['items'] as List).cast<Json>(),
    ];
    historyCursor = result['nextCursor'] as String?;
    _notify();
  }

  Future<void> restoreJourney(String id) async {
    final generation = _sessionGeneration;
    final journeyGeneration = _journeyGeneration;
    final data = await api.request('GET', '/journeys/$id');
    if (_disposed ||
        generation != _sessionGeneration ||
        journeyGeneration != _journeyGeneration) {
      return;
    }
    _applyJourney(data);
    if (journeyId == id) await connectStream();
  }

  void _applyJourney(Json data, {bool refreshTransferResults = false}) {
    if (_disposed) return;
    final current = journey;
    if (current != null && current['journeyId'] == data['journeyId']) {
      final sv = data['stateVersion'] as int;
      final oldSv = current['stateVersion'] as int;
      if (sv < oldSv ||
          (sv == oldSv &&
              (data['resultVersion'] as int) <
                  (current['resultVersion'] as int))) {
        // 결과 저장은 버전을 올리지 않습니다. 더 최신 안내를 유지하면서 결과만 반영합니다.
        if (refreshTransferResults &&
            data['selectionVersion'] == current['selectionVersion'] &&
            data['transferResults'] is List) {
          journey = {...current, 'transferResults': data['transferResults']};
          _notify();
        }
        return;
      }
    }
    if (current?['journeyId'] != data['journeyId'] ||
        data['lifecycleStatus'] != 'active') {
      _journeyGeneration++;
    }
    journey = {
      ...?(current?['journeyId'] == data['journeyId'] ? current : null),
      ...data,
    };
    if (journey!['lifecycleStatus'] != 'active') {
      journey = null;
      activeRoute = null;
      _stopStream();
      _stopLocation();
      unawaited(
        loadHistory().catchError((Object e) {
          syncError = e.toString();
          _notify();
        }),
      );
    } else if (journey!['selectedRoute'] case final Json selected) {
      activeRoute = TravelRoute.fromJson(
        selected,
        searchId: selected['searchId'] as String,
        origin: Place.fromJson(selected['origin'] as Json),
        destination: Place.fromJson(selected['destination'] as Json),
      );
    }
    _notify();
  }

  Future<void> connectStream() async {
    final id = journeyId;
    if (id == null || demoMode || _disposed) return;
    _stopStream();
    final socket = api.connect(id);
    _socket = socket;
    _socketSubscription = socket.stream.listen(
      (dynamic raw) {
        if (_socket != socket || journeyId != id || _disposed) return;
        try {
          final data = jsonDecode(raw as String) as Json;
          if (data['type'] != 'journey_state' &&
              data['type'] != 'journey_ended') {
            return;
          }
          if (data['journeyId'] != id) return;
          streamConnected = true;
          streamError = null;
          _applyJourney(data);
        } catch (_) {
          streamError = '안내 응답 형식을 확인할 수 없어요.';
          _notify();
        }
      },
      onError: (Object error) {
        _streamLost(socket);
      },
      onDone: () {
        _streamLost(socket);
      },
    );
    try {
      await socket.ready.timeout(const Duration(seconds: 10));
      final token = await api.accessToken();
      if (_socket != socket || journeyId != id || token == null) return;
      socket.sink.add(jsonEncode({'type': 'auth', 'accessToken': token}));
    } catch (_) {
      _streamLost(socket);
    }
  }

  void _streamLost(WebSocketChannel socket) {
    if (_socket != socket || _disposed || journeyId == null) return;
    streamConnected = false;
    if (socket.closeCode == 4403) {
      _accountDeleted();
      return;
    }
    if (socket.closeCode == 4404) {
      streamError = '이동을 찾을 수 없어요. 서버 상태를 다시 확인해 주세요.';
      _reconnectTimer?.cancel();
      _notify();
      return;
    }
    streamError = socket.closeCode == 4401
        ? '로그인 확인이 필요해요.'
        : '연결이 끊겼어요. 서버의 이동은 유지되며 재연결합니다.';
    _notify();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (journeyId == null || _disposed) return;
      try {
        if (socket.closeCode == 4401 && auth != null) {
          await auth!.auth.refreshSession();
        }
        await restoreJourney(journeyId!);
      } catch (_) {
        if (!_disposed) _streamLost(socket);
      }
    });
  }

  void _stopStream() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final socket = _socket;
    _socket = null;
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    unawaited(socket?.sink.close());
    streamConnected = false;
  }

  Future<void> sendJourneyEvent(String type, Json payload) async {
    if (journeyId == null) return;
    await _sendEvent(
      journeyId!,
      journey!['stateVersion'] as int,
      type,
      payload,
    );
  }

  Future<Json> submitTransferResult(
    Json journeyData,
    Json transfer, {
    required String result,
    bool? usedPlanned,
  }) async {
    final previous = transfer['result'] as Json?;
    return _sendEvent(
      journeyData['journeyId'] as String,
      journeyData['stateVersion'] as int,
      previous == null ? 'transfer_result' : 'correction',
      {
        if (previous == null) ...{
          'snapshotKey': transfer['snapshotKey'],
          'selectionVersion': transfer['selectionVersion'],
          'transferIndex': transfer['transferIndex'],
        } else
          'supersedesEventId': previous['eventId'],
        'result': result,
        if (usedPlanned != null)
          'actualConnection': {'usedPlanned': usedPlanned},
      },
    );
  }

  Future<Json> _sendEvent(
    String id,
    int version,
    String type,
    Json payload,
  ) async {
    if (_pendingEvent != null) {
      throw const ApiException('EVENT_PENDING', '이전 이동 확인을 먼저 재전송해 주세요.');
    }
    _pendingEvent = {
      'eventType': type,
      'stateVersion': version,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    };
    _pendingEventKey = BusApi.eventKey();
    _pendingEventJourneyId = id;
    return _submitPendingEvent();
  }

  void _clearPendingEvent() {
    _pendingEvent = null;
    _pendingEventKey = null;
    _pendingEventJourneyId = null;
  }

  Future<Json> _submitPendingEvent() async {
    final id = _pendingEventJourneyId!;
    final generation = _sessionGeneration;
    try {
      await api.request(
        'POST',
        '/journeys/$id/events',
        body: _pendingEvent,
        idempotencyKey: _pendingEventKey,
      );
      // 동일 키 재전송은 응답 유실에도 이벤트를 중복 저장하지 않습니다.
      final data = await api.request('GET', '/journeys/$id');
      if (_disposed || generation != _sessionGeneration) {
        throw const ApiException('SESSION_CHANGED', '로그인 상태가 변경되었어요.');
      }
      _clearPendingEvent();
      if (journeyId == id) _applyJourney(data, refreshTransferResults: true);
      _notify();
      return data;
    } on ApiException catch (error) {
      if (generation == _sessionGeneration &&
          error.status >= 400 &&
          error.status < 500) {
        _clearPendingEvent();
        if (error.status == 409 && journeyId == id) {
          try {
            await restoreJourney(id);
          } catch (_) {
            /* 다음 재조회에서 복구 */
          }
        }
      }
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<Json?> retryPendingEvent() async {
    if (_pendingEvent == null) return null;
    return _submitPendingEvent();
  }

  Future<void> deleteJourneyRecord(String id) async {
    if (_pendingEventJourneyId == id) {
      throw const ApiException('EVENT_PENDING', '전송 중인 환승 결과를 먼저 확인해 주세요.');
    }
    final generation = _sessionGeneration;
    try {
      await api.request('DELETE', '/journeys/$id');
    } on ApiException catch (error) {
      // 삭제 응답을 놓친 뒤 다시 요청하면 이미 삭제된 기록은 404입니다.
      if (error.status != 404 || error.code != 'NOT_FOUND') rethrow;
    }
    if (_disposed || generation != _sessionGeneration) return;
    serverHistory.removeWhere((item) => item['journeyId'] == id);
    if (journeyId == id) {
      _journeyGeneration++;
      journey = null;
      activeRoute = null;
      _stopStream();
      _stopLocation();
    }
    // 기록 삭제와 함께 원본 검색이 정리될 수 있어 캐시도 비웁니다.
    stopSearchPolling();
    searchResult = null;
    searchError = null;
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (demoMode || _disposed) return;
    if (state == AppLifecycleState.resumed && journeyId != null) {
      unawaited(
        restoreJourney(journeyId!).catchError((Object e) {
          syncError = e.toString();
          _notify();
        }),
      );
    }
  }

  Future<void> locateOrigin({bool retry = false}) async {
    if (demoMode ||
        origin.id != 'unset' ||
        locatingOrigin ||
        (_originLocationAttempted && !retry)) {
      return;
    }
    _originLocationAttempted = true;
    locatingOrigin = true;
    originLocationError = null;
    final initialOrigin = origin;
    final session = _sessionGeneration;
    _notify();
    try {
      final place = await currentLocation(shareWithJourney: false);
      if (!_disposed &&
          session == _sessionGeneration &&
          identical(origin, initialOrigin)) {
        origin = place;
      }
    } catch (error) {
      if (!_disposed &&
          session == _sessionGeneration &&
          identical(origin, initialOrigin)) {
        originLocationError = error is ApiException
            ? error.message
            : '현재 위치를 찾지 못했어요. 출발지를 직접 선택해 주세요.';
      }
    } finally {
      locatingOrigin = false;
      _notify();
    }
  }

  Future<Place> currentLocation({bool shareWithJourney = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException('LOCATION_OFF', '기기의 위치 서비스를 켜 주세요.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'LOCATION_DENIED',
        '위치 권한이 필요해요. 기기 설정에서 허용하거나 좌표를 직접 입력해 주세요.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    if (shareWithJourney && journeyId != null) await _sendPosition(position);
    return Place(
      id: 'gps',
      name: '현재 위치',
      address: 'GPS로 확인한 위치',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> startLocationSharing() async {
    await currentLocation();
    if (journeyId == null) return;
    _stopLocation();
    locationError = null;
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          ),
        ).listen(
          (p) {
            unawaited(
              _sendPosition(p).catchError((Object e) {
                locationError = e.toString();
                _notify();
              }),
            );
          },
          onError: (Object e) {
            locationError = '위치 수신이 중단되었어요. 이동은 유지됩니다.';
            _notify();
          },
        );
    _notify();
  }

  Future<void> _sendPosition(Position p) async {
    final id = journeyId;
    if (id == null) return;
    await api.request(
      'PUT',
      '/journeys/$id/location',
      body: {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'observedAt': p.timestamp.toUtc().toIso8601String(),
        'accuracyM': p.accuracy,
      },
    );
  }

  void _stopLocation() {
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
  }

  void _clearSession() {
    _sessionGeneration++;
    _journeyGeneration++;
    _sessionUserId = null;
    _stopStream();
    _stopLocation();
    stopSearchPolling();
    journey = null;
    activeRoute = null;
    userName = null;
    email = null;
    serverHistory = [];
    historyCursor = null;
    searchResult = null;
    _clearPendingEvent();
    syncError = null;
    streamError = null;
    locationError = null;
    searchError = null;
    passwordRecovery = false;
    if (!demoMode) {
      origin = const Place(id: 'unset', name: '출발지를 선택해 주세요', address: '');
      destination = null;
      originLocationError = null;
      _originLocationAttempted = false;
    }
    _favorites.clear();
    _favoriteIds.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchGeneration++;
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    _stopStream();
    _stopLocation();
    api.close();
    super.dispose();
  }

  Place origin = DemoData.places.first;
  Place? destination;
  String? userName;
  String? email;
  bool alertsEnabled = true;
  final Set<String> _favoriteIds = {'arboretum', 'chungnam'};
  final Map<String, Place> _favorites = {};
  final List<JourneyRecord> _history = [];
  TravelRoute? activeRoute;
  int guideStep = 0;
  String? confirmedBus;
  String? confirmedDirection;
  bool boardingUncertain = false;
  int remainingStops = 0;
  bool transferSuggestionSeen = false;
  bool get boardingMatchesRoute {
    final route = activeRoute;
    if (route == null || boardingUncertain) return false;
    if ((guideStep == 2 || guideStep == 4) &&
        (confirmedBus == null || confirmedDirection == null)) {
      return false;
    }
    final connecting = guideStep == 4;
    return (confirmedBus == null ||
            confirmedBus ==
                (connecting
                    ? route.busNumbers.last
                    : route.busNumbers.first)) &&
        (confirmedDirection == null ||
            confirmedDirection ==
                (connecting
                    ? route.arrivalStop
                    : route.transferStop ?? route.arrivalStop));
  }

  TravelRoute? get fasterTransfer =>
      demoMode && (guideStep == 2 || guideStep == 3) && boardingMatchesRoute
      ? DemoData.fasterTransfer(activeRoute!)
      : null;
  bool get isLoggedIn => userName != null;
  List<Place> get favoritePlaces => demoMode
      ? DemoData.places.where((p) => _favoriteIds.contains(p.id)).toList()
      : _favorites.values.toList();
  List<JourneyRecord> get history => List.unmodifiable(_history);
  List<TravelRoute> get routeOptions => destination == null
      ? []
      : demoMode
      ? DemoData.routes(origin, destination!)
      : (searchResult?['candidates'] as List? ?? [])
            .map(
              (c) => TravelRoute.fromJson(
                c as Json,
                searchId: searchResult!['searchId'] as String,
                origin: Place.fromJson(searchResult!['origin'] as Json),
                destination: Place.fromJson(
                  searchResult!['destination'] as Json,
                ),
                recommendedId:
                    searchResult!['recommendedCandidateId'] as String?,
                expiresAt: DateTime.tryParse(
                  searchResult!['expiresAt'] as String? ?? '',
                ),
              ),
            )
            .toList();
  bool isFavorite(Place place) => demoMode
      ? _favoriteIds.contains(place.id)
      : _favorites.containsKey(place.id);
  void setOrigin(Place place) {
    origin = place;
    _notify();
  }

  void setDestination(Place place) {
    destination = place;
    _notify();
  }

  void swapPlaces() {
    if (destination == null) return;
    final previous = origin;
    origin = destination!;
    destination = previous;
    _notify();
  }

  void toggleFavorite(Place place) {
    if (demoMode) {
      if (!_favoriteIds.remove(place.id)) _favoriteIds.add(place.id);
    } else {
      if (_favorites.remove(place.id) == null) _favorites[place.id] = place;
    }
    _notify();
  }

  void signIn({required String name, required String email}) {
    assert(demoMode);
    userName = name;
    this.email = email;
    _notify();
  }

  Future<void> updateProfile({required String name}) async {
    if (!demoMode) {
      await api.request('PATCH', '/me', body: {'displayName': name});
    }
    userName = name;
    _notify();
  }

  Future<void> signOut() async {
    if (!demoMode) {
      await auth?.auth.signOut(scope: SignOutScope.local);
      _clearSession();
      return;
    }
    userName = null;
    email = null;
    _notify();
  }

  void _accountDeleted() {
    if (_disposed || accountDeleted) return;
    accountDeleted = true;
    _clearSession();
    // SDK는 로컬 세션부터 지웁니다. Auth 차단/네트워크 실패로 탈퇴 완료를 되돌리지 않습니다.
    final signOut = auth?.auth.signOut(scope: SignOutScope.local);
    if (signOut != null) unawaited(signOut.catchError((Object _) {}));
  }

  Future<void> deleteAccount() async {
    if (!demoMode) {
      final generation = _sessionGeneration;
      await api.request('DELETE', '/me');
      if (_disposed || generation != _sessionGeneration) return;
      // 202의 authBlockStatus=pending도 탈퇴 접수 완료입니다.
      _accountDeleted();
      return;
    }
    userName = null;
    email = null;
    _history.clear();
    _favoriteIds.clear();
    activeRoute = null;
    guideStep = 0;
    remainingStops = 0;
    transferSuggestionSeen = false;
    _clearBoardingInfo();
    _notify();
  }

  void setAlertsEnabled(bool enabled) {
    alertsEnabled = enabled;
    _notify();
  }

  Future<void> startJourney(TravelRoute route) async {
    if (!demoMode) {
      if (_pendingEvent != null) {
        throw const ApiException('EVENT_PENDING', '먼저 전송 중인 이동 확인을 완료해 주세요.');
      }
      if (journeyId != null) {
        throw const ApiException(
          'ACTIVE_JOURNEY_EXISTS',
          '진행 중인 이동을 먼저 종료해 주세요.',
        );
      }
      final generation = _sessionGeneration;
      try {
        final data = await api.request(
          'POST',
          '/journeys',
          body: {'searchId': route.searchId, 'candidateId': route.id},
        );
        if (_disposed || generation != _sessionGeneration) return;
        _applyJourney(data);
        await connectStream();
      } on ApiException catch (error) {
        if (error.code == 'ACTIVE_JOURNEY_EXISTS') await refreshAccount();
        rethrow;
      }
      return;
    }
    activeRoute = route;
    guideStep = 0;
    remainingStops = 0;
    transferSuggestionSeen = false;
    _clearBoardingInfo();
    _notify();
  }

  void setGuideStep(int step) {
    final next = step.clamp(0, 6);
    if (next != guideStep) {
      // ponytail: 정류장 수는 수동 체험용입니다. 위치·노선 API 연결 시 교체합니다.
      remainingStops = next == 2 || next == 4 ? 2 : 0;
    }
    if ((guideStep == 2 && next > 2) || (guideStep == 4 && next > 4)) {
      _clearBoardingInfo();
    }
    guideStep = next;
    _notify();
  }

  void passDemoStop() {
    if ((guideStep != 2 && guideStep != 4) ||
        !boardingMatchesRoute ||
        remainingStops <= 0) {
      return;
    }
    remainingStops--;
    _notify();
  }

  void markTransferSuggestionSeen() {
    transferSuggestionSeen = true;
    _notify();
  }

  void acceptFasterTransfer() {
    final alternative = fasterTransfer;
    if (alternative == null) return;
    activeRoute = alternative;
    transferSuggestionSeen = true;
    _notify();
  }

  void setBoardingInfo({
    required String bus,
    required String direction,
    required bool uncertain,
  }) {
    confirmedBus = uncertain ? null : bus;
    confirmedDirection = uncertain ? null : direction;
    boardingUncertain = uncertain;
    _notify();
  }

  void _clearBoardingInfo() {
    confirmedBus = null;
    confirmedDirection = null;
    boardingUncertain = false;
  }

  void advanceJourney() => setGuideStep(guideStep + 1);
  Future<void> cancelJourney() async {
    if (!demoMode) {
      await sendJourneyEvent('cancelled', {'reason': 'user_requested'});
      return;
    }
    activeRoute = null;
    guideStep = 0;
    remainingStops = 0;
    transferSuggestionSeen = false;
    _clearBoardingInfo();
    _notify();
  }

  Future<void> finishJourney(JourneyOutcome outcome) async {
    if (!demoMode) {
      await sendJourneyEvent('completed', {});
      return;
    }
    final route = activeRoute;
    if (route == null) return;
    final now = DateTime.now();
    _history.insert(
      0,
      JourneyRecord(
        id: now.microsecondsSinceEpoch.toString(),
        route: route,
        completedAt: now,
        outcome: outcome,
      ),
    );
    activeRoute = null;
    guideStep = 0;
    remainingStops = 0;
    transferSuggestionSeen = false;
    _clearBoardingInfo();
    _notify();
  }

  void deleteRecord(String id) {
    _history.removeWhere((record) => record.id == id);
    _notify();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
