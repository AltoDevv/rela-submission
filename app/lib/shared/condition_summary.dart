import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'rubric.dart';
import 'theme.dart';

/// Level per kunjungan untuk satu domain (`null` = tidak disebut). Hanya kunjungan terkonfirmasi.
List<int?> levelSeries(List<Visit> visits, String key) => [
  for (final v in visits)
    if (v.finalResult != null) (v.finalResult![key] as Map?)?['level'] as int?,
];

String _dm(DateTime d) => '${d.toLocal().day}/${d.toLocal().month}';

/// Ringkasan tren yang dipakai keluarga dan relawan. Data selalu disaring dan diurutkan di sini.
class ConditionSummary extends StatefulWidget {
  const ConditionSummary({super.key, required this.visits});

  final List<Visit> visits;

  @override
  State<ConditionSummary> createState() => _ConditionSummaryState();
}

class _ConditionSummaryState extends State<ConditionSummary> {
  String _domain = rubricDomains.first.key;

  @override
  Widget build(BuildContext context) {
    final visits =
        widget.visits
            .where((v) => v.confirmedAt != null && v.finalResult != null)
            .toList()
          ..sort((a, b) => a.visitedAt.compareTo(b.visitedAt));
    final domain = rubricDomains.firstWhere((d) => d.key == _domain);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Text(
          'RINGKASAN KONDISI',
          style: TextStyle(
            color: RelaColors.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('kategori'),
          initialValue: _domain,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Kategori'),
          items: [
            for (final d in rubricDomains)
              DropdownMenuItem(value: d.key, child: Text(d.name)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _domain = v);
          },
        ),
        if (visits.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Grafik tersedia setelah ada kunjungan yang disimpan relawan.',
            ),
          )
        else ...[
          DomainChart(
            domain: domain,
            levels: levelSeries(visits, domain.key),
            visits: visits,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Garis turun menunjukkan kondisi memburuk. Titik kosong berarti tidak disebut. Bukan diagnosis medis.',
              style: TextStyle(fontSize: 12, color: RelaColors.muted),
            ),
          ),
        ],
      ],
    );
  }
}

/// Grafik satu kategori (Figma "Nafsu Makan — Grafik"): sumbu Y berlabel tingkat, dari terbaik di atas sampai
/// "Tidak disebut" di bawah, jadi garis turun saat kondisi memburuk. `null` = titik kosong di y = −1.
class DomainChart extends StatelessWidget {
  const DomainChart({
    super.key,
    required this.domain,
    required this.levels,
    required this.visits,
  });

  final RubricDomain domain;
  final List<int?> levels;
  final List<Visit> visits;

  @override
  Widget build(BuildContext context) {
    final line = [
      for (final (i, l) in levels.indexed)
        l == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), 3.0 - l),
    ];
    final empty = [
      for (final (i, l) in levels.indexed)
        if (l == null) FlSpot(i.toDouble(), -1),
    ];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              domain.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Pemantauan berkala',
              style: TextStyle(color: RelaColors.muted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                duration: const Duration(
                  milliseconds: 400,
                ), // grafik bergeser halus saat kunjungan baru masuk
                LineChartData(
                  minX: 0,
                  maxX: (levels.length - 1).clamp(1, 1 << 20).toDouble(),
                  minY: -1,
                  maxY: 3,
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                      dashArray: const [3, 5],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 100,
                        getTitlesWidget: (value, meta) => Text(
                          value < 0
                              ? 'Tidak disebut'
                              : domain.labels[3 - value.toInt()],
                          style: TextStyle(
                            fontSize: 12,
                            color: value >= 2
                                ? RelaColors.ink
                                : RelaColors.muted,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          return i < visits.length
                              ? Text(
                                  _dm(visits[i].visitedAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: RelaColors.muted,
                                  ),
                                )
                              : const SizedBox();
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: line,
                      color: RelaColors.primary,
                      barWidth: 3,
                    ),
                    LineChartBarData(
                      spots: empty,
                      barWidth: 0,
                      color: Colors.transparent,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: Colors.grey,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
