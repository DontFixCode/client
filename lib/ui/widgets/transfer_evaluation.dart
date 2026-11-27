import 'package:flutter/material.dart';

import '../../data/bus_api.dart';
import '../../models/travel_route.dart';
import 'data_reason.dart';

/// Search evaluations, reroute proposals, and saved journey predictions use
/// the same server probability and slack fields.
class TransferEvaluation extends StatelessWidget {
  const TransferEvaluation({
    super.key,
    required this.transfer,
    this.historical = false,
  });

  final Json transfer;
  final bool historical;

  @override
  Widget build(BuildContext context) {
    final probability = transferProbabilityText(transfer);
    final grade = transferGradeLabel(transfer['slackGrade']);
    final slack = secondsLabel(transfer['slackSeconds']);
    final source = switch (transfer['probabilitySource']) {
      'paired_ecdf' => '두 차량을 함께 관측한 표본',
      'marginal_ecdf' => '두 차량의 도착 오차를 독립으로 보고 계산한 확률',
      _ => null,
    };
    final counts = transfer['probabilitySampleCounts'] as Json?;
    final samples = [
      for (final (key, label) in [
        ('paired', '짝 표본'),
        ('front', '앞 차량'),
        ('next', '다음 차량'),
      ])
        if (counts?[key] case final int count) '$label $count개',
    ];
    final notes = <String>{
      ?source,
      if (samples.isNotEmpty) samples.join(' · '),
      ...(transfer['reasonCodes'] as List? ?? transfer['reason'] as List? ?? [])
          .whereType<String>()
          .where(
            (code) =>
                code != 'transfer_probability_by_marginal_errors' ||
                source == null,
          )
          .map(dataReason),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            historical
                ? '당시 예측: ${probability ?? '확률 확인 불가'}'
                : '환승 성공 가능성 ${probability ?? '확인 불가'}',
            '여유 $slack',
            ?grade,
            if (transfer['slackEstimated'] == true) '예상 시각 기준',
          ].join(' · '),
        ),
        for (final note in notes)
          Text(note, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
