import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:garbage1/login_page.dart';
import 'package:garbage1/ml_analytics.dart';
import 'package:url_launcher/url_launcher.dart';

class CorporationPage extends StatefulWidget {
  final String username;

  const CorporationPage({Key? key, required this.username}) : super(key: key);

  @override
  State<CorporationPage> createState() => _CorporationPageState();
}

class _CorporationPageState extends State<CorporationPage> {
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoadingTickets = true;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> _sosAlerts = [];
  bool _isLoadingSOS = false;

  @override
  void initState() {
    super.initState();
    _loadCitizenTickets();
    _initNotifications();
    _loadSOSAlerts();
    _listenForSOSAlerts();
    _loadSOSAlerts();
    _setupSOSListener();
  }

  void _setupSOSListener() {
    FirebaseFirestore.instance
        .collection('sos_alerts')
        .where('status', isEqualTo: 'Active')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              // A new SOS alert was added
              if (mounted) {
                // Show a local notification (you would implement this)
                _showSOSNotification();
                // Refresh the list
                _loadSOSAlerts();
              }
            }
          }
        });
  }

  void _showSOSNotification() {
    // Simple notification within the app
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ EMERGENCY: New SOS alert received!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _initNotifications() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification taps
        _loadSOSAlerts();
      },
    );

    // Initialize Firebase Messaging
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Show notification when app is in foreground
        _showLocalNotification(
          message.notification?.title ?? 'Emergency Alert',
          message.notification?.body ?? 'A new SOS alert has been received!',
        );

        // Refresh SOS alerts
        _loadSOSAlerts();
      });
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'sos_channel_id',
          'SOS Alerts',
          channelDescription: 'This channel is used for SOS alerts',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          sound: RawResourceAndroidNotificationSound('alarm'),
          playSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> _loadSOSAlerts() async {
    setState(() {
      _isLoadingSOS = true;
    });

    try {
      final sosSnapshot =
          await FirebaseFirestore.instance
              .collection('sos_alerts')
              .orderBy('createdAt', descending: true)
              .get();

      final alerts =
          sosSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return {
              'id': doc.id,
              ...?data,
              'createdAt':
                  data?['createdAt'] != null
                      ? (data!['createdAt'] as Timestamp).toDate()
                      : DateTime.now(),
            };
          }).toList();

      setState(() {
        _sosAlerts = alerts;
        _isLoadingSOS = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSOS = false;
      });
      _showErrorDialog('Failed to load SOS alerts: $e');
    }
  }

  Future<void> _updateSOSStatus(String sosId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('sos_alerts')
          .doc(sosId)
          .update({
            'status': newStatus,
            'resolvedBy': FirebaseAuth.instance.currentUser?.email,
            'resolvedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SOS alert marked as $newStatus'),
            backgroundColor: Colors.green,
          ),
        );

        // Immediately refresh the SOS alerts list
        await _loadSOSAlerts();
      }
    } catch (e) {
      _showErrorDialog('Failed to update SOS status: $e');
    }
  }

  void _openMapLocation(double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorDialog('Could not open the map');
    }
  }

  void _listenForSOSAlerts() {
    FirebaseFirestore.instance
        .collection('sos_alerts')
        .where('status', isEqualTo: 'Active')
        .snapshots()
        .listen((snapshot) {
          // This will be called whenever a new SOS alert is added
          if (snapshot.docChanges.isNotEmpty) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                _showLocalNotification(
                  'Emergency SOS Alert!',
                  'A citizen has requested emergency assistance.',
                );
                _loadSOSAlerts();
                break;
              }
            }
          }
        });
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _showErrorDialog('Could not open the map');
    }
  }

  Future<void> _resolveSOSAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection('sos_alerts')
          .doc(alertId)
          .update({
            'status': 'Resolved',
            'addressedBy': FirebaseAuth.instance.currentUser?.email,
            'resolvedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS alert marked as resolved'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSOSAlerts();
      }
    } catch (e) {
      _showErrorDialog('Failed to update SOS alert: $e');
    }
  }

  Future<void> _loadCitizenTickets() async {
    setState(() {
      _isLoadingTickets = true;
    });

    try {
      final ticketsSnapshot =
          await FirebaseFirestore.instance
              .collection('tickets')
              .where('userRole', isEqualTo: 'General People')
              .orderBy('createdAt', descending: true)
              .get();

      final tickets =
          ticketsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return {
              'id': doc.id,
              ...?data,
              'createdAt':
                  data?['createdAt'] != null
                      ? (data!['createdAt'] as Timestamp).toDate()
                      : DateTime.now(),
            };
          }).toList();

      setState(() {
        _tickets = tickets;
        _isLoadingTickets = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTickets = false;
      });
      _showErrorDialog('Failed to load tickets: $e');
    }
  }

  Future<void> _updateTicketStatus(String ticketId) async {
    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(ticketId)
          .update({'status': 'Closed'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket status updated to Closed'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCitizenTickets(); // Refresh tickets after update
      }
    } catch (e) {
      _showErrorDialog('Failed to update ticket status: $e');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
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

  void _signOut() async {
  try {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    
    // Instead of using a named route, use MaterialPageRoute with the LoginPage
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // This removes all previous routes from the stack
    );
  } catch (e) {
    _showErrorDialog('Error signing out: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Management'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade300, Colors.indigo.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${widget.username}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    // Add this as a new section after the tickets list in CorporationPage
                    // SOS Alerts Section
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 24,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Emergency SOS Alerts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        // Refresh button
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadSOSAlerts,
                          tooltip: 'Refresh SOS alerts',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SOS alerts list
                    _isLoadingSOS
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(color: Colors.red),
                          ),
                        )
                        : _sosAlerts.isEmpty
                        ? Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24.0),
                            width: double.infinity,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 48,
                                  color: Colors.green[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No active SOS alerts',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : // Replace your current SOS alerts ListView.builder with this updated version
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sosAlerts.length,
                          itemBuilder: (context, index) {
                            final alert = _sosAlerts[index];
                            final timestamp =
                                alert['createdAt']; // Changed from timestamp to createdAt
                            final bool isActive = alert['status'] == 'Active';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // Change background color based on status
                              color:
                                  isActive
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        isActive
                                            ? Colors.red.shade100
                                            : Colors.green.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    isActive
                                        ? Icons.emergency
                                        : Icons.check_circle,
                                    color: isActive ? Colors.red : Colors.green,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      isActive
                                          ? 'Emergency SOS'
                                          : 'Resolved SOS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isActive
                                                ? Colors.red
                                                : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isActive) // Only show URGENT tag if active
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'URGENT',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    if (alert['userEmail'] != null)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'From: ${alert['userEmail']}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Received: ${timestamp.toString().split('.')[0]}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (alert['resolvedAt'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Resolved: ${(alert['resolvedAt'] as Timestamp).toDate().toString().split('.')[0]}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Location: ${alert['latitude'].toStringAsFixed(6)}, ${alert['longitude'].toStringAsFixed(6)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Only show action buttons if active
                                    if (isActive)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  () => _openMapLocation(
                                                    alert['latitude'],
                                                    alert['longitude'],
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              icon: const Icon(
                                                Icons.map,
                                                size: 16,
                                              ),
                                              label: const Text('View Map'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  () => _updateSOSStatus(
                                                    alert['id'],
                                                    'Resolved',
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              icon: const Icon(
                                                Icons.check,
                                                size: 16,
                                              ),
                                              label: const Text('Resolve'),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed:
                                            () => _openMapLocation(
                                              alert['latitude'],
                                              alert['longitude'],
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        icon: const Icon(Icons.map, size: 16),
                                        label: const Text('View Location'),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Role: Corporation Official',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tickets List Section
             const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 20,
                      color: Colors.indigo,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Citizen Tickets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // ML Analytics Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MlAnalytics(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.analytics, size: 16),
                      label: const Text('ML Analytics'),
                    ),
                    const SizedBox(width: 8),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadCitizenTickets,
                      tooltip: 'Refresh tickets',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tickets list
            _isLoadingTickets
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
                : _tickets.isEmpty
                ? Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    width: double.infinity,
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tickets found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];

                    // Determine status color
                    Color statusColor;
                    IconData statusIcon;

                    switch (ticket['status']) {
                      case 'Open':
                        statusColor = Colors.orange;
                        statusIcon = Icons.report_problem_outlined;
                        break;
                      case 'In Progress':
                        statusColor = Colors.blue;
                        statusIcon = Icons.pending_outlined;
                        break;
                      case 'Closed':
                        statusColor = Colors.green;
                        statusIcon = Icons.check_circle_outline;
                        break;
                      default:
                        statusColor = Colors.grey;
                        statusIcon = Icons.help_outline;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: statusColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        title: Text(
                          ticket['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.category,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${ticket['category']}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Status: ${ticket['status']}',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Created: ${ticket['createdAt'].toString().split('.')[0]}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            if (ticket['userEmail'] != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'User: ${ticket['userEmail']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing:
                            ticket['status'] == 'Open'
                                ? ElevatedButton.icon(
                                  onPressed:
                                      () => _updateTicketStatus(ticket['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Close'),
                                )
                                : null,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(
                                      statusIcon,
                                      color: statusColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(ticket['title'])),
                                  ],
                                ),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'Category: ${ticket['category']}',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'Status: ${ticket['status']}',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Description:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(ticket['description']),
                                      ),
                                      if (ticket['userEmail'] != null) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          'Submitted by: ${ticket['userEmail']}',
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                actions: [
                                  if (ticket['status'] == 'Open')
                                    TextButton.icon(
                                      onPressed: () {
                                        _updateTicketStatus(ticket['id']);
                                        Navigator.of(context).pop();
                                      },
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      label: const Text(
                                        'Close Ticket',
                                        style: TextStyle(color: Colors.green),
                                      ),
                                    ),
                                  TextButton.icon(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Dismiss'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
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
