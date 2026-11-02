import 'package:flutter/widgets.dart';

import '../data/demo_data.dart';
import '../models/journey_record.dart';
import '../models/place.dart';
import '../models/travel_route.dart';

/// 프론트엔드 시연 상태. 앱을 종료하면 초기화되며 서버에 저장하지 않습니다.
class AppState extends ChangeNotifier {
  Place origin = DemoData.places.first;
  Place? destination;
  String? userName;
  String? email;
  bool alertsEnabled = true;
  final Set<String> _favoriteIds = {'arboretum', 'chungnam'};
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
      (guideStep == 2 || guideStep == 3) && boardingMatchesRoute
      ? DemoData.fasterTransfer(activeRoute!)
      : null;
  bool get isLoggedIn => userName != null;
  List<Place> get favoritePlaces =>
      DemoData.places.where((p) => _favoriteIds.contains(p.id)).toList();
  List<JourneyRecord> get history => List.unmodifiable(_history);
  List<TravelRoute> get routeOptions =>
      destination == null ? [] : DemoData.routes(origin, destination!);
  bool isFavorite(Place place) => _favoriteIds.contains(place.id);
  void setOrigin(Place place) {
    origin = place;
    notifyListeners();
  }

  void setDestination(Place place) {
    destination = place;
    notifyListeners();
  }

  void swapPlaces() {
    if (destination == null) return;
    final previous = origin;
    origin = destination!;
    destination = previous;
    notifyListeners();
  }

  void toggleFavorite(Place place) {
    if (!_favoriteIds.remove(place.id)) _favoriteIds.add(place.id);
    notifyListeners();
  }

  void signIn({required String name, required String email}) {
    userName = name;
    this.email = email;
    notifyListeners();
  }

  void updateProfile({required String name}) {
    userName = name;
    notifyListeners();
  }

  void signOut() {
    userName = null;
    email = null;
    notifyListeners();
  }

  void deleteAccount() {
    userName = null;
    email = null;
    _history.clear();
    _favoriteIds.clear();
    activeRoute = null;
    guideStep = 0;
    remainingStops = 0;
    transferSuggestionSeen = false;
    _clearBoardingInfo();
    notifyListeners();
  }

  void setAlertsEnabled(bool enabled) {
    alertsEnabled = enabled;
    notifyListeners();
  }

  void startJourney(TravelRoute route) {
    activeRoute = route;
    guideStep = 0;
    remainingStops = 0;
    transferSuggestionSeen = false;
    _clearBoardingInfo();
    notifyListeners();
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
    notifyListeners();
  }

  void passDemoStop() {
    if ((guideStep != 2 && guideStep != 4) ||
        !boardingMatchesRoute ||
        remainingStops <= 0) {
      return;
    }
    remainingStops--;
    notifyListeners();
  }

  void markTransferSuggestionSeen() {
    transferSuggestionSeen = true;
    notifyListeners();
  }

  void acceptFasterTransfer() {
    final alternative = fasterTransfer;
    if (alternative == null) return;
    activeRoute = alternative;
    transferSuggestionSeen = true;
    notifyListeners();
  }

  void setBoardingInfo({
    required String bus,
    required String direction,
    required bool uncertain,
  }) {
    confirmedBus = uncertain ? null : bus;
    confirmedDirection = uncertain ? null : direction;
    boardingUncertain = uncertain;
    notifyListeners();
  }

  void _clearBoardingInfo() {
    confirmedBus = null;
    confirmedDirection = null;
    boardingUncertain = false;
  }

  void advanceJourney() => setGuideStep(guideStep + 1);
  void cancelJourney() {
    activeRoute = null;
    guideStep = 0;
    remainingStops = 0;
    transferSuggestionSeen = false;
    _clearBoardingInfo();
    notifyListeners();
  }

  void finishJourney(JourneyOutcome outcome) {
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
    notifyListeners();
  }

  void deleteRecord(String id) {
    _history.removeWhere((record) => record.id == id);
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
