import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/app_routes.dart';
import '../../../data/bus_api.dart';
import '../../../models/travel_route.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kakao_place_map.dart';
import '../../widgets/kakao_route_map.dart';
import '../../widgets/route_map_data.dart';
import '../../widgets/route_swipe_card.dart';
import 'route_detail_page.dart';

class RoutePreviewPage extends StatefulWidget {
  const RoutePreviewPage({
    super.key,
    required this.routes,
    required this.initialIndex,
  });
  final List<TravelRoute> routes;
  final int initialIndex;

  @override
  State<RoutePreviewPage> createState() => _RoutePreviewPageState();
}

class _RoutePreviewPageState extends State<RoutePreviewPage> {
  late int _page = widget.initialIndex;
  late final _pages = PageController(
    viewportFraction: 0.88,
    initialPage: widget.initialIndex,
  );

  final _stops = <String, Map<BusPattern, List<Json>>>{};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loadStops(widget.routes[_page]);
  }

  Future<void> _loadStops(TravelRoute route) async {
    if (!KakaoPlaceMap.available || _stops.containsKey(route.id)) return;
    final patterns = RouteMapData.fromLegs(route.legs).missingPatterns;
    if (patterns.isEmpty) return;
    _stops[route.id] = {};
    final api = AppScope.of(context).api;
    final result = <BusPattern, List<Json>>{};
    for (final pattern in patterns) {
      final id = Uri.encodeComponent(pattern.routeId);
      final key = Uri.encodeComponent(pattern.patternKey);
      try {
        final data = await api.request(
          'GET',
          '/routes/$id/patterns/$key/stops',
        );
        final items = data['items'];
        if (items is List) {
          result[pattern] = items.whereType<Json>().toList();
        }
      } on ApiException {
        continue;
      }
    }
    if (!mounted) return;
    setState(() => _stops[route.id] = result);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Widget _map(TravelRoute route, double bottomInset) {
    final data = RouteMapData.fromLegs(
      route.legs,
      origin: route.origin,
      destination: route.destination,
      patternStops: _stops[route.id] ?? const {},
    );
    const fallback = KakaoMapUnavailable();
    if (!KakaoPlaceMap.available) return fallback;
    return KakaoRouteMap(
      key: ValueKey(data.fingerprint),
      data: data,
      fallback: fallback,
      bottomInset: bottomInset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final routes = widget.routes;
    final route = routes[_page];
    final bottom = MediaQuery.of(context).padding.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${route.origin.name} → ${route.destination.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _map(route, 340 + bottom)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16 + bottom + 290 + 8,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_page + 1} / ${routes.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16 + bottom,
              height: 290,
              child: PageView.builder(
                controller: _pages,
                itemCount: routes.length,
                onPageChanged: (index) {
                  setState(() => _page = index);
                  _loadStops(routes[index]);
                },
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: RouteSwipeCard(
                    route: routes[index],
                    startKey: index == _page
                        ? const ValueKey('startJourneyButton')
                        : null,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.routeDetail,
                      arguments: routes[index],
                    ),
                    onStart:
                        state.busy ||
                            (routes[index].isLive && !routes[index].startable)
                        ? null
                        : () => startRoute(context, routes[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
