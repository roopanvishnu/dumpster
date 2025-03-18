import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MlAnalytics extends StatefulWidget {
  const MlAnalytics({super.key});

  @override
  State<MlAnalytics> createState() => _MlAnalyticsState();
}

class _MlAnalyticsState extends State<MlAnalytics> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _users = [];
  
  // Analytics data
  int _totalTickets = 0;
  int _openTickets = 0;
  int _closedTickets = 0;
  int _inProgressTickets = 0;
  Map<String, int> _categoryDistribution = {};
  Map<String, int> _userComplaintCount = {};
  Map<String, int> _pincodeDistribution = {};
  List<Map<String, dynamic>> _topComplainers = [];
  List<Map<String, dynamic>> _monthlyTickets = [];
  Map<String, double> _resolutionTimeByCategory = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all tickets
      final ticketsSnapshot = await FirebaseFirestore.instance
          .collection('tickets')
          .orderBy('createdAt', descending: true)
          .get();

      final ticketsList = ticketsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
          'createdAt': data['createdAt'] != null 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.now(),
        };
      }).toList();

      // Fetch all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'General People')
          .get();

      final usersList = usersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Process data for analytics
      _processAnalyticsData(ticketsList, usersList);

    } catch (e) {
      _showErrorDialog('Failed to load analytics data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processAnalyticsData(List<Map<String, dynamic>> tickets, List<Map<String, dynamic>> users) {
    _tickets = tickets;
    _users = users;
    
    // Basic counts
    _totalTickets = tickets.length;
    _openTickets = tickets.where((ticket) => ticket['status'] == 'Open').length;
    _closedTickets = tickets.where((ticket) => ticket['status'] == 'Closed').length;
    _inProgressTickets = tickets.where((ticket) => ticket['status'] == 'In Progress').length;
    
    // Category distribution
    _categoryDistribution = {};
    for (var ticket in tickets) {
      String category = ticket['category'] ?? 'Uncategorized';
      _categoryDistribution[category] = (_categoryDistribution[category] ?? 0) + 1;
    }
    
    // User complaint distribution
    _userComplaintCount = {};
    for (var ticket in tickets) {
      String userEmail = ticket['userEmail'] ?? 'Unknown';
      _userComplaintCount[userEmail] = (_userComplaintCount[userEmail] ?? 0) + 1;
    }
    
    // Find top complainers
    _topComplainers = [];
    for (var entry in _userComplaintCount.entries) {
      var userEmail = entry.key;
      var count = entry.value;
      
      var userData = _users.firstWhere(
        (user) => user['email'] == userEmail,
        orElse: () => {'email': userEmail, 'name': 'Unknown', 'address': 'Unknown', 'pincode': 'Unknown'},
      );
      
      _topComplainers.add({
        'email': userEmail,
        'name': userData['name'] ?? 'Unknown',
        'address': userData['address'] ?? 'Unknown',
        'pincode': userData['pincode'] ?? 'Unknown',
        'count': count,
      });
    }
    
    _topComplainers.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    if (_topComplainers.length > 10) {
      _topComplainers = _topComplainers.sublist(0, 10);
    }
    
    // Pincode distribution
    _pincodeDistribution = {};
    for (var complainer in _topComplainers) {
      String pincode = complainer['pincode'] ?? 'Unknown';
      if (pincode != 'Unknown') {
        _pincodeDistribution[pincode] = (_pincodeDistribution[pincode] ?? 0) + 1;
      }
    }
    
    // Monthly ticket data for charts
    Map<String, int> monthlyData = {};
    for (var ticket in tickets) {
      DateTime date = ticket['createdAt'];
      String monthYear = DateFormat('MMM yyyy').format(date);
      monthlyData[monthYear] = (monthlyData[monthYear] ?? 0) + 1;
    }
    
    _monthlyTickets = monthlyData.entries.map((e) => {
      'month': e.key,
      'count': e.value,
    }).toList();
    
    // Sort by date (recent first)
    _monthlyTickets.sort((a, b) {
      DateTime dateA = DateFormat('MMM yyyy').parse(a['month'] as String);
      DateTime dateB = DateFormat('MMM yyyy').parse(b['month'] as String);
      return dateB.compareTo(dateA);
    });
    
    // Calculate average resolution time by category
    Map<String, List<double>> resolutionTimes = {};
    for (var ticket in tickets) {
      if (ticket['status'] == 'Closed' && ticket['resolvedAt'] != null && ticket['createdAt'] != null) {
        String category = ticket['category'] ?? 'Uncategorized';
        
        DateTime createdAt = ticket['createdAt'];
        DateTime resolvedAt = (ticket['resolvedAt'] as Timestamp).toDate();
        
        double durationInHours = resolvedAt.difference(createdAt).inHours.toDouble();
        
        if (!resolutionTimes.containsKey(category)) {
          resolutionTimes[category] = [];
        }
        resolutionTimes[category]!.add(durationInHours);
      }
    }
    
    // Calculate averages
    _resolutionTimeByCategory = {};
    resolutionTimes.forEach((category, times) {
      double sum = times.reduce((a, b) => a + b);
      _resolutionTimeByCategory[category] = sum / times.length;
    });
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ML Analytics Dashboard'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary stats cards
                  _buildSummaryCards(),
                  
                  const SizedBox(height: 24),
                  
                  // Monthly trend chart
                  _buildMonthlyTrendChart(),
                  
                  const SizedBox(height: 24),
                  
                  // Category Distribution
                  _buildCategoryDistribution(),
                  
                  const SizedBox(height: 24),
                  
                  // Resolution time by category
                  _buildResolutionTimeByCategory(),
                  
                  const SizedBox(height: 24),
                  
                  // Top complainers
                  _buildTopComplainers(),
                  
                  const SizedBox(height: 24),
                  
                  // Geographic distribution (pincode)
                  _buildGeographicDistribution(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard(
          title: 'Total Tickets',
          value: _totalTickets.toString(),
          icon: Icons.confirmation_number,
          color: Colors.blue,
        ),
        _buildSummaryCard(
          title: 'Open Tickets',
          value: _openTickets.toString(),
          icon: Icons.pending_actions,
          color: Colors.orange,
        ),
        _buildSummaryCard(
          title: 'Closed Tickets',
          value: _closedTickets.toString(),
          icon: Icons.task_alt,
          color: Colors.green,
        ),
        _buildSummaryCard(
          title: 'In Progress',
          value: _inProgressTickets.toString(),
          icon: Icons.hourglass_bottom,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    // If we don't have at least 2 data points, show a message
    if (_monthlyTickets.length < 2) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Not enough data to display monthly trend chart',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    // Take the most recent 6 months (or all if less than 6)
    final displayData = _monthlyTickets.length > 6 
        ? _monthlyTickets.sublist(0, 6).reversed.toList()
        : _monthlyTickets.reversed.toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Ticket Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (displayData.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${displayData[groupIndex]['month']}: ${displayData[groupIndex]['count']} tickets',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= displayData.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              displayData[value.toInt()]['month'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 5,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: List.generate(
                    displayData.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: (displayData[index]['count'] as int).toDouble(),
                          color: Colors.purple[400],
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5),
                            topRight: Radius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    if (_categoryDistribution.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No category data available',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    // Convert to pie chart data
    List<Map<String, dynamic>> pieData = _categoryDistribution.entries.map((e) => {
      'category': e.key,
      'count': e.value,
    }).toList();
    
    // Sort by count (descending)
    pieData.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // Colors for pie chart sections
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.lime,
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ticket Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: Row(
                children: [
                  // Pie chart
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: List.generate(
                          pieData.length,
                          (index) => PieChartSectionData(
                            value: (pieData[index]['count'] as int).toDouble(),
                            title: '',
                            color: colors[index % colors.length],
                            radius: 100,
                          ),
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  
                  // Legend
                  Expanded(
                    flex: 3,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pieData.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colors[index % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  pieData[index]['category'] as String,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                '${pieData[index]['count']} (${((pieData[index]['count'] / _totalTickets) * 100).toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionTimeByCategory() {
    if (_resolutionTimeByCategory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No resolution time data available',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    // Convert to chart data
    List<Map<String, dynamic>> barData = _resolutionTimeByCategory.entries.map((e) => {
      'category': e.key,
      'hours': e.value,
    }).toList();
    
    // Sort by hours (descending)
    barData.sort((a, b) => (b['hours'] as double).compareTo(a['hours'] as double));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Average Resolution Time by Category (Hours)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: barData.length,
                itemBuilder: (context, index) {
                  final category = barData[index]['category'] as String;
                  final hours = barData[index]['hours'] as double;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: hours / (barData.map((e) => e['hours'] as double).reduce((a, b) => a > b ? a : b) * 1.1),
                                  minHeight: 20,
                                  backgroundColor: Colors.grey[300],
                                  color: hours > 48 ? Colors.red[400] : 
                                         hours > 24 ? Colors.orange[400] : 
                                         Colors.green[400],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${hours.toStringAsFixed(1)} hrs',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopComplainers() {
    if (_topComplainers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No user data available',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Complainers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topComplainers.length,
              itemBuilder: (context, index) {
                final complainer = _topComplainers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple[50],
                      child: Text(
                        '${complainer['count']}',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      complainer['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Email: ${complainer['email']}'),
                        Text('Address: ${complainer['address']}'),
                        Text('Pincode: ${complainer['pincode']}'),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        '${complainer['count']} tickets',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: Colors.purple,
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeographicDistribution() {
    if (_pincodeDistribution.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No geographic data available',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    // Convert to chart data and sort
    List<Map<String, dynamic>> data = _pincodeDistribution.entries.map((e) => {
      'pincode': e.key,
      'count': e.value,
    }).toList();
    
    data.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Geographic Distribution (By Pincode)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final pincode = item['pincode'] as String;
                final count = item['count'] as int;
                
                // Calculate percentage of total
                final percentage = (count / _topComplainers.length) * 100;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pincode: $pincode',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$count users (${percentage.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: count / (data.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b)),
                          minHeight: 15,
                          backgroundColor: Colors.grey[300],
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}