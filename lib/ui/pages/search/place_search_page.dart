import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final query = _query.replaceAll(' ', '').toLowerCase();
    final places = DemoData.places
        .where(
          (place) => '${place.name}${place.address}'
              .replaceAll(' ', '')
              .toLowerCase()
              .contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.isOrigin ? '출발지 찾기' : '도착지 찾기')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
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
                            setState(() => _query = '');
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
                    onPressed: () =>
                        Navigator.pop(context, DemoData.places.first),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('현재 위치 사용 · 체험 위치: 대전역'),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    _query.isEmpty ? '대전의 주요 장소' : '검색 결과 ${places.length}개',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  const StatusPill('장소 검색 체험'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: places.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: '일치하는 장소가 없어요',
                      message: '대전역, 한밭수목원 등\n체험 장소의 이름이나 주소로 검색해 주세요.',
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: DemoNotice(message: '등록된 체험 장소 안에서 검색할 수 있어요'),
            ),
          ],
        ),
      ),
    );
  }
}
