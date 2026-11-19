import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/bus_api.dart';
import '../../../models/place.dart';
import '../../widgets/api_action.dart';

import '../../../data/demo_data.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/demo_notice.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_pill.dart';

class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key, required this.isOrigin});
  final bool isOrigin;

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false;
  String? _error;
  List<Place> _results = [];

  void _search(String value) {
    final state = AppScope.of(context);
    final generation = ++_generation;
    _debounce?.cancel();
    setState(() {
      _query = value;
      _error = null;
      _results = [];
      _loading = !state.demoMode && value.trim().isNotEmpty;
    });
    if (state.demoMode || value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final places = await state.searchPlaces(value.trim());
        if (mounted && generation == _generation) {
          setState(() => _results = places);
        }
      } catch (error) {
        if (mounted && generation == _generation) {
          setState(() {
            _error = switch (error) {
              ApiException(code: 'PLACES_NOT_CONFIGURED') =>
                '장소 검색 서비스가 아직 준비되지 않았어요. 나중에 다시 시도해 주세요.',
              ApiException(code: 'PLACES_UNAVAILABLE') =>
                '장소 검색에 일시적으로 연결할 수 없어요. 잠시 후 다시 시도해 주세요.',
              _ => error.toString(),
            };
          });
        }
      } finally {
        if (mounted && generation == _generation) {
          setState(() => _loading = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final query = _query.replaceAll(' ', '').toLowerCase();
    final places = state.demoMode
        ? DemoData.places
              .where(
                (place) => '${place.name}${place.address}'
                    .replaceAll(' ', '')
                    .toLowerCase()
                    .contains(query),
              )
              .toList()
        : _results;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isOrigin ? '출발지 찾기' : '도착지 찾기')),
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '장소 이름이나 주소를 입력하세요',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '검색어 지우기',
                                onPressed: () {
                                  _controller.clear();
                                  _search('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  if (widget.isOrigin)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: state.busy
                              ? null
                              : () async {
                                  if (state.demoMode) {
                                    Navigator.pop(
                                      context,
                                      DemoData.places.first,
                                    );
                                    return;
                                  }
                                  Place? place;
                                  if (await apiAction(context, () async {
                                        place = await state.currentLocation();
                                      }) &&
                                      context.mounted) {
                                    Navigator.pop(context, place);
                                  }
                                },
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            state.demoMode
                                ? '현재 위치 사용 · 체험 위치: 대전역'
                                : '현재 위치 사용',
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _loading
                                ? '검색 중…'
                                : _error != null
                                ? '장소 검색'
                                : _query.isEmpty
                                ? (state.demoMode ? '대전의 주요 장소' : '장소 이름·주소 검색')
                                : '검색 결과 ${places.length}개',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(state.demoMode ? '장소 검색 체험' : '서버 검색'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (_loading || _error != null || places.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: '장소 검색을 사용할 수 없어요',
                        message: _error!,
                        action: TextButton(
                          onPressed: () => _search(_query),
                          child: const Text('다시 시도'),
                        ),
                      )
                    : EmptyState(
                        icon: Icons.search_off_rounded,
                        title: _query.isEmpty && !state.demoMode
                            ? '검색할 장소를 입력해 주세요'
                            : '일치하는 장소가 없어요',
                        message: state.demoMode
                            ? '대전역, 한밭수목원 등\n체험 장소의 이름이나 주소로 검색해 주세요.'
                            : _query.isEmpty
                            ? '장소 이름이나 주소로 출발지·도착지를 찾아보세요.'
                            : '다른 장소 이름이나 주소로 검색해 보세요.',
                      ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverList.separated(
                  itemCount: places.length,
                  separatorBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(),
                  ),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          place.supported
                              ? Icons.location_on_outlined
                              : Icons.location_off_outlined,
                          color: AppColors.primary,
                          size: 21,
                        ),
                      ),
                      title: Text(
                        place.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        '${place.category}\n${place.address}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.pop(context, place),
                      trailing: IconButton(
                        tooltip: state.isFavorite(place)
                            ? '${place.name} 즐겨찾기 해제'
                            : '${place.name} 즐겨찾기 추가',
                        onPressed: () => state.toggleFavorite(place),
                        icon: Icon(
                          state.isFavorite(place)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: state.isFavorite(place)
                              ? AppColors.amber
                              : AppColors.muted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: DemoNotice(
                  message: state.demoMode
                      ? '등록된 체험 장소 안에서 검색할 수 있어요'
                      : '저장한 장소는 현재 앱 실행 중에만 유지돼요',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
