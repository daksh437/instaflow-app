import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/stats_model.dart';

/// Follower growth chart with filters
class FollowerGrowthChart extends StatefulWidget {
  final List<FollowerGrowthData> growthData;
  final int selectedDays;

  const FollowerGrowthChart({
    super.key,
    required this.growthData,
    this.selectedDays = 7,
  });

  @override
  State<FollowerGrowthChart> createState() => _FollowerGrowthChartState();
}

class _FollowerGrowthChartState extends State<FollowerGrowthChart> {
  int _selectedFilter = 2; // Default to 7 days (index 2)
  final List<int> _filterDays = [1, 7, 30];

  @override
  void initState() {
    super.initState();
    _selectedFilter = _filterDays.indexOf(widget.selectedDays);
    if (_selectedFilter == -1) _selectedFilter = 2;
  }

  List<FollowerGrowthData> get _filteredData {
    final days = _filterDays[_selectedFilter];
    if (widget.growthData.isEmpty) return [];
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return widget.growthData
        .where((data) => data.date.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredData;
    if (filtered.isEmpty) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text('No growth data available'),
        ),
      );
    }

    final maxValue = filtered.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    final minValue = filtered.map((e) => e.count).reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    final chartMax = maxValue + (range * 0.1).round();
    final chartMin = minValue - (range * 0.1).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Followers Growth',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Row(
                children: List.generate(_filterDays.length, (index) {
                  final isSelected = _selectedFilter == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = index),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7B2CBF)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        index == 0
                            ? 'Today'
                            : '${_filterDays[index]}d',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (chartMax - chartMin) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: (Colors.grey[200] ?? Colors.grey),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            _formatNumber(value.toInt()),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= filtered.length) return const SizedBox();
                        final index = value.toInt().clamp(0, filtered.length - 1);
                        final date = filtered[index].date;
                        final label = _selectedFilter == 0
                            ? '${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                            : '${date.day}/${date.month}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: filtered.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF7B2CBF),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF7B2CBF).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: chartMin.toDouble(),
                maxY: chartMax.toDouble(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

