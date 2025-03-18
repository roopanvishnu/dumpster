import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:garbage1/login_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';

class GeneralPeoplePage extends StatefulWidget {
  final String username;

  const GeneralPeoplePage({Key? key, required this.username}) : super(key: key);

  @override
  State<GeneralPeoplePage> createState() => _GeneralPeoplePageState();
}

class _GeneralPeoplePageState extends State<GeneralPeoplePage> {
  final TextEditingController _problemTitleController = TextEditingController();
  final TextEditingController _problemDescriptionController =
      TextEditingController();
  String _selectedCategory = 'Drainage-Problem';
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoadingTickets = true;

  @override
  void initState() {
    super.initState();
    _loadUserTickets();
  }

  Future<void> _loadUserTickets() async {
    setState(() {
      _isLoadingTickets = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ticketsSnapshot =
            await FirebaseFirestore.instance
                .collection('tickets')
                .where('userId', isEqualTo: user.uid)
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
      }
    } catch (e) {
      setState(() {
        _isLoadingTickets = false;
      });
      _showErrorDialog('Failed to load tickets: $e');
    }
  }

  Future<void> _submitTicket() async {
    final String title = _problemTitleController.text.trim();
    final String description = _problemDescriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('tickets').add({
          'userId': user.uid,
          'userEmail': user.email,
          'title': title,
          'description': description,
          'category': _selectedCategory,
          'status': 'Open',
          'createdAt': FieldValue.serverTimestamp(),
          'userRole': 'General People',
        });

        _problemTitleController.clear();
        _problemDescriptionController.clear();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload tickets after submission
        await _loadUserTickets();
      }
    } catch (e) {
      _showErrorDialog('Failed to submit ticket: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, show dialog
      _showErrorDialog(
        'Location services are disabled. Please enable them to use SOS features.',
      );
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog(
          'Location permissions are denied. Please allow location access to use SOS features.',
        );
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog(
        'Location permissions are permanently denied. Please enable them in settings to use SOS features.',
      );
      return Future.error('Location permissions are permanently denied');
    }

    // When we reach here, permissions are granted and we can get the location
    return await Geolocator.getCurrentPosition();
  }

  // Add this function to _GeneralPeoplePageState class
  Future<void> _sendSOSAlert() async {
    try {
      setState(() {
        _isSubmitting = true;
      });

      // Get current location
      Position position = await _getCurrentLocation();

      // Get current user info
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('You must be logged in to send an SOS alert');
        return;
      }

      // Create SOS document in Firestore
      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'userId': user.uid,
        'userEmail': user.email,
        'username': widget.username,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'status': 'Active',
        'createdAt': FieldValue.serverTimestamp(),
        'address': await _getAddressFromCoordinates(position),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert sent! Officials have been notified.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to send SOS alert: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<Position> _getCurrentLocation() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorDialog(
        'Location services are disabled. Please enable them to send SOS alerts.',
      );
      return Future.error('Location services are disabled');
    }

    // Check for location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog(
          'Location permission denied. Please allow access to send SOS alerts.',
        );
        return Future.error('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog(
        'Location permissions are permanently denied. Please enable them in app settings.',
      );
      return Future.error('Location permissions are permanently denied');
    }

    // Get the current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> _getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}';
      }
      return 'Address unavailable';
    } catch (e) {
      return 'Address unavailable';
    }
  }

  Future<void> _sendSOS() async {
    try {
      setState(() {
        _isSubmitting = true; // Reuse the loading indicator
      });

      // Get current location
      final position = await _determinePosition();

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('User not authenticated');
        return;
      }

      // Create SOS document in Firestore
      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'userId': user.uid,
        'userEmail': user.email,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Active',
        'addressedBy': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS alert sent successfully. Help is on the way!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to send SOS: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
        title: const Text('Home'),
        backgroundColor: Colors.blue,
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
                    colors: [Colors.blue.shade300, Colors.blue.shade600],
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
                        'Role: General People',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Ticket Submission Form
            Row(
              children: const [
                Icon(Icons.create, size: 20),
                SizedBox(width: 8),
                Text(
                  'Submit a New Problem Ticket',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Problem Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items:
                          [
                            'Drainage-Problem',
                            'Sanitation',
                            'Too Much Mosquito',
                            'Garbage-Collection',
                            'Other',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _problemTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Problem Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _problemDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Problem Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitTicket,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon:
                          _isSubmitting
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.send),
                      label: Text(
                        _isSubmitting ? 'Submitting...' : 'Submit Ticket',
                      ),
                    ),
                    // Add this after the submit ticket button in the form Card
                    // Add this after your Submit Ticket button
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _sendSOSAlert,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon:
                            _isSubmitting
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 28,
                                ),
                        label: Text(
                          _isSubmitting ? 'Sending SOS...' : 'SEND SOS ALERT',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                    Icon(Icons.list_alt, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Your Tickets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadUserTickets,
                  tooltip: 'Refresh tickets',
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
                          ],
                        ),
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
                                    ],
                                  ),
                                ),
                                actions: [
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
