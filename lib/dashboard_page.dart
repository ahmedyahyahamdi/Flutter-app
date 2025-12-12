import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
// IMPORTANT: Ensure you have a 'supabase_config.dart' file 
// that initializes and exposes your Supabase client.
import 'supabase_config.dart'; 
import 'login_page.dart';
import 'chatbot_screen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- Authentication State & Controllers ---
  bool _isLoggedIn = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // --- Existing State Variables ---
  List<Map<String, dynamic>> sensorHistory = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // 🔐 AUTHENTICATION LOGIC 
  // ----------------------------------------------------------------------

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final username = prefs.getString('username');

    setState(() {
      _isLoggedIn = (email != null && email.isNotEmpty) || (username != null && username.isNotEmpty);
    });

    if (_isLoggedIn) {
      await _fetchSensorHistory();
    } else {
      // Stop loading state to show the login form immediately
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      // Use ScaffoldMessenger if the widget is part of a Scaffold
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter both email and password.')),
        );
      }
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
        
      // Supabase login (Assuming username is the email)
      final response = await SupabaseConfig().client.auth.signInWithPassword(
          email: username,
          password: password,
        );

      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        
        setState(() {
          _isLoggedIn = true;
          errorMessage = '';
          isLoading = false;
        });
        await _fetchSensorHistory();
      } else {
        throw Exception('Login failed: Invalid credentials.');
      }

    } catch (e) {
      setState(() {
        errorMessage = 'Login Error: Check credentials or server status.';
        isLoading = false;
      });
    }
  }
  
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    
    await SupabaseConfig().client.auth.signOut();
    
    setState(() {
      _isLoggedIn = false;
      sensorHistory = []; // Clear data
      errorMessage = '';
    });
    
    // If this page was pushed, pop it to go back to the previous screen (e.g., login wrapper)
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  // ----------------------------------------------------------------------
  // 📊 DATA FETCHING & PROCESSING
  // ----------------------------------------------------------------------

  Future<void> _fetchSensorHistory() async {
    if (!_isLoggedIn) return;
    
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final supabaseConfig = SupabaseConfig();
      final response = await supabaseConfig.client
          .from('sensor_readings')
          .select('luminosity, temperature_air, humidity_air, temperature_soil, humidity_soil, timestamp')
          .order('timestamp', ascending: false)
          .limit(100);

      setState(() {
        sensorHistory = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  List<FlSpot> _getChartData(String sensorKey) {
    List<FlSpot> spots = [];
    
    // We process data in reverse order of fetching (oldest to newest for the chart's x-axis)
    final reversedHistory = sensorHistory.reversed.toList();

    for (int i = 0; i < reversedHistory.length; i++) {
      final data = reversedHistory[i];
      final value = data[sensorKey];
      
      if (value != null && value is num) {
        spots.add(FlSpot(i.toDouble(), value.toDouble()));
      }
    }
    
    return spots;
  }

  // ----------------------------------------------------------------------
  // 🎨 UI BUILDER METHODS
  // ----------------------------------------------------------------------

  Widget _buildChart(String title, String sensorKey, Color color, String unit) {
    final chartData = _getChartData(sensorKey);
    
    if (chartData.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: 200,
          child: Center(
            child: Text(
              'No data available for $title',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    
    // Determine min/max Y for the chart scale
    double minY = chartData.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = chartData.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    
    // Add buffer to the min/max
    minY = (minY * 0.95).floorToDouble();
    maxY = (maxY * 1.05).ceilToDouble();
    if (minY < 0) minY = 0; // Prevent negative Y axis if data is non-negative

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: chartData.length.toDouble() - 1,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}$unit',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (chartData.length / 5).floorToDouble() > 0 
                          ? (chartData.length / 5).floorToDouble() 
                          : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          final reversedIndex = sensorHistory.length - 1 - index;
                          
                          if (index >= 0 && index < sensorHistory.length) {
                            final timestamp = sensorHistory[reversedIndex]['timestamp'];
                            if (timestamp != null) {
                              final time = DateTime.parse(timestamp);
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.3))),
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.1),
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

  Widget _buildSummaryCards() {
    if (sensorHistory.isEmpty) return const SizedBox.shrink();

    final latestData = sensorHistory.first;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest Readings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    '💡 Light',
                    latestData['luminosity']?.toString() ?? 'N/A',
                    'lux',
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    '🌡️ Air Temp',
                    latestData['temperature_air']?.toString() ?? 'N/A',
                    '°C',
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    '💧 Air Humidity',
                    latestData['humidity_air']?.toString() ?? 'N/A',
                    '%',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    '🌱 Soil Temp',
                    latestData['temperature_soil']?.toString() ?? 'N/A',
                    '°C',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    '💦 Soil Humidity',
                    latestData['humidity_soil']?.toString() ?? 'N/A',
                    '%',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value $unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Dashboard Login',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Login',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // ----------------------------------------------------------------------
  // 🏠 MAIN BUILD METHOD (Conditional Rendering)
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      // Show the login form if not logged in
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Access'),
          backgroundColor: Colors.blue[700],
        ),
        body: _buildLoginForm(),
      );
    }

    // Show the dashboard content if logged in
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Data Charts'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSensorHistory,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red[800]),
                ),
              ),
            
            const Text(
              'Sensor Data Visualization',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : sensorHistory.isEmpty
                      ? const Center(
                          child: Text(
                            'No historical data available',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildSummaryCards(),
                              _buildChart('Light (Luminosity)', 'luminosity', Colors.amber, 'lux'),
                              _buildChart('Air Temperature', 'temperature_air', Colors.red, '°C'),
                              _buildChart('Air Humidity', 'humidity_air', Colors.blue, '%'),
                              _buildChart('Soil Temperature', 'temperature_soil', Colors.orange, '°C'),
                              _buildChart('Soil Humidity', 'humidity_soil', Colors.green, '%'),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.chat),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen()));
        },
      ),
    );
  }
}
