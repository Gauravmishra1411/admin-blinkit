import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_init_service.dart';

class OverviewView extends StatelessWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111C43)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await DatabaseInitService().initializeDatabase();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Database Schema Initialized Successfully!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error initializing database: $e')),
                  );
                }
              },
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('Initialize DB Schema'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Metric Cards Row
        Row(
          children: [
            Expanded(child: _buildMetricCard('Total Revenue', '\$12,450', '+15% from yesterday', Icons.attach_money, const Color(0xFF4CA1AF))),
            const SizedBox(width: 20),
            Expanded(child: _buildMetricCard('Active Orders', '142', '+5% from yesterday', Icons.shopping_bag_outlined, Colors.orange)),
            const SizedBox(width: 20),
            Expanded(child: _buildMetricCard('Total Vendors', '84', '+2 new today', Icons.storefront, Colors.indigo)),
            const SizedBox(width: 20),
            Expanded(child: _buildMetricCard('Total Users', '4,210', '+120 this week', Icons.group_outlined, Colors.teal)),
          ],
        ),
        const SizedBox(height: 30),
        // Chart Placeholders
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Revenue Analytics',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111C43),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Last 7 Days',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Expanded(
                        child: RevenueLineChart(),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top Vendors',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111C43),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: 5,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.store, color: Colors.blueGrey),
                                ),
                                title: Text(
                                  'Vendor ${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('${150 - (index * 20)} orders today'),
                                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.black54, fontSize: 14)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111C43))),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.arrow_upward, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text(subtitle, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class RevenueLineChart extends StatelessWidget {
  const RevenueLineChart({super.key});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}k',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 6,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3),
              FlSpot(1, 1.5),
              FlSpot(2, 5),
              FlSpot(3, 3.1),
              FlSpot(4, 4),
              FlSpot(5, 3.5),
              FlSpot(6, 4.2),
            ],
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
            ),
            barWidth: 5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2193b0).withOpacity(0.2),
                  const Color(0xFF6dd5ed).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

