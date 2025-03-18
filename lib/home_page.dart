import 'package:flutter/material.dart';
import 'general_people_page.dart';
import 'corporation_page.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String role;

  const HomePage({Key? key, required this.username, required this.role})
    : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    // Route to the appropriate page based on user role
    if (widget.role == "Corporation Official") {
      return CorporationPage(username: widget.username);
    } else {
      return GeneralPeoplePage(username: widget.username);
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class HomePage extends StatefulWidget {
//   final String username;
//   final String role;

//   const HomePage({Key? key, required this.username, required this.role})
//     : super(key: key);

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   final TextEditingController _problemTitleController = TextEditingController();
//   final TextEditingController _problemDescriptionController =
//       TextEditingController();
//   String _selectedCategory = 'Drainage-Problem';
//   bool _isSubmitting = false;
//   List<Map<String, dynamic>> _tickets = [];
//   bool _isLoadingTickets = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserTickets();
//   }

//   Future<void> _loadUserTickets() async {
//     setState(() {
//       _isLoadingTickets = true;
//     });

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         Query query = FirebaseFirestore.instance.collection('tickets');

//         if (widget.role == "Corporation Official") {
//           query = query.where('userRole', isEqualTo: 'General People');
//         } else {
//           query = query.where('userId', isEqualTo: user.uid);
//         }

//         final ticketsSnapshot = await query.orderBy('createdAt', descending: true).get();

//         final tickets = ticketsSnapshot.docs.map((doc) {
//           final data = doc.data() as Map<String, dynamic>?; // Ensure proper type casting
//           return {
//             'id': doc.id,
//             ...?data, // Use null-aware spread to prevent null issues
//             'createdAt': data?['createdAt'] != null
//                 ? (data!['createdAt'] as Timestamp).toDate()
//                 : DateTime.now(), // Fallback if 'createdAt' is missing
//           };
//         }).toList();

//         setState(() {
//           _tickets = tickets;
//           _isLoadingTickets = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _isLoadingTickets = false;
//       });
//       _showErrorDialog('Failed to load tickets: $e');
//     }
//   }

//   Future<void> _updateTicketStatus(String ticketId) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('tickets')
//           .doc(ticketId)
//           .update({'status': 'Closed'});

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Ticket status updated to Closed'),
//             backgroundColor: Colors.green,
//           ),
//         );
//         _loadUserTickets(); // Refresh tickets after update
//       }
//     } catch (e) {
//       _showErrorDialog('Failed to update ticket status: $e');
//     }
//   }

//   Future<void> _submitTicket() async {
//     final String title = _problemTitleController.text.trim();
//     final String description = _problemDescriptionController.text.trim();

//     if (title.isEmpty || description.isEmpty) {
//       _showErrorDialog('Please fill in all fields');
//       return;
//     }

//     setState(() {
//       _isSubmitting = true;
//     });

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         await FirebaseFirestore.instance.collection('tickets').add({
//           'userId': user.uid,
//           'userEmail': user.email,
//           'title': title,
//           'description': description,
//           'category': _selectedCategory,
//           'status': 'Open',
//           'createdAt': FieldValue.serverTimestamp(),
//           'userRole': widget.role,
//         });

//         _problemTitleController.clear();
//         _problemDescriptionController.clear();

//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Ticket submitted successfully'),
//             backgroundColor: Colors.green,
//           ),
//         );

//         // Reload tickets after submission
//         await _loadUserTickets();
//       }
//     } catch (e) {
//       _showErrorDialog('Failed to submit ticket: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isSubmitting = false;
//         });
//       }
//     }
//   }

//   Future<void> _showErrorDialog(String message) async {
//     if (!mounted) return;
//     await showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Error'),
//           content: Text(message),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('OK'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _signOut() async {
//     try {
//       await FirebaseAuth.instance.signOut();
//       if (!mounted) return;
//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       _showErrorDialog('Error signing out: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final bool isOfficialRole = widget.role == 'Corporation Official';
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(isOfficialRole ? 'Ticket Management' : 'Home'),
//         backgroundColor: isOfficialRole ? Colors.indigo : Colors.blue,
//         actions: [
//           IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Welcome Card
//             Card(
//               elevation: 4,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(16.0),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16),
//                   gradient: LinearGradient(
//                     colors: isOfficialRole 
//                       ? [Colors.indigo.shade300, Colors.indigo.shade600]
//                       : [Colors.blue.shade300, Colors.blue.shade600],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Welcome, ${widget.username}',
//                       style: const TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Text(
//                         'Role: ${widget.role}',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
            
//             const SizedBox(height: 24),
            
//             // Ticket Submission Form - Only for General People
//             if (!isOfficialRole) ...[
//               Row(
//                 children: const [
//                   Icon(Icons.create, size: 20),
//                   SizedBox(width: 8),
//                   Text(
//                     'Submit a New Problem Ticket',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               Card(
//                 elevation: 4,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       DropdownButtonFormField<String>(
//                         value: _selectedCategory,
//                         decoration: const InputDecoration(
//                           labelText: 'Problem Category',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.category),
//                         ),
//                         items:
//                             [
//                               'Drainage-Problem',
//                               'Sanitation',
//                               'Too Much Mosquito',
//                               'Garbage-Collection',
//                               'Other',
//                             ].map((String value) {
//                               return DropdownMenuItem<String>(
//                                 value: value,
//                                 child: Text(value),
//                               );
//                             }).toList(),
//                         onChanged: (String? newValue) {
//                           if (newValue != null) {
//                             setState(() {
//                               _selectedCategory = newValue;
//                             });
//                           }
//                         },
//                       ),
//                       const SizedBox(height: 16),
//                       TextFormField(
//                         controller: _problemTitleController,
//                         decoration: const InputDecoration(
//                           labelText: 'Problem Title',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.title),
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       TextFormField(
//                         controller: _problemDescriptionController,
//                         decoration: const InputDecoration(
//                           labelText: 'Problem Description',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.description),
//                           alignLabelWithHint: true,
//                         ),
//                         maxLines: 5,
//                       ),
//                       const SizedBox(height: 16),
//                       ElevatedButton.icon(
//                         onPressed: _isSubmitting ? null : _submitTicket,
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(16),
//                           ),
//                         ),
//                         icon: _isSubmitting
//                             ? const SizedBox(
//                                 width: 20,
//                                 height: 20,
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                   color: Colors.white,
//                                 ),
//                               )
//                             : const Icon(Icons.send),
//                         label: Text(_isSubmitting ? 'Submitting...' : 'Submit Ticket'),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
            
//             // Tickets List Section
//             const SizedBox(height: 24),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Icon(
//                       isOfficialRole ? Icons.admin_panel_settings : Icons.list_alt,
//                       size: 20,
//                       color: isOfficialRole ? Colors.indigo : Colors.blue,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       isOfficialRole ? 'Citizen Tickets' : 'Your Tickets',
//                       style: TextStyle(
//                         fontSize: 18, 
//                         fontWeight: FontWeight.bold,
//                         color: isOfficialRole ? Colors.indigo : Colors.blue,
//                       ),
//                     ),
//                   ],
//                 ),
//                 // Refresh button
//                 IconButton(
//                   icon: const Icon(Icons.refresh),
//                   onPressed: _loadUserTickets,
//                   tooltip: 'Refresh tickets',
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
            
//             // Tickets list
//             _isLoadingTickets
//                 ? const Center(
//                     child: Padding(
//                       padding: EdgeInsets.all(32.0),
//                       child: CircularProgressIndicator(),
//                     ))
//                 : _tickets.isEmpty
//                 ? Card(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Container(
//                       padding: const EdgeInsets.all(24.0),
//                       width: double.infinity,
//                       child: Column(
//                         children: [
//                           Icon(
//                             Icons.inbox_outlined,
//                             size: 48,
//                             color: Colors.grey[400],
//                           ),
//                           const SizedBox(height: 16),
//                           Text(
//                             'No tickets found',
//                             style: TextStyle(
//                               fontSize: 16,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   )
//                 : ListView.builder(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     itemCount: _tickets.length,
//                     itemBuilder: (context, index) {
//                       final ticket = _tickets[index];
                      
//                       // Determine status color
//                       Color statusColor;
//                       IconData statusIcon;
                      
//                       switch(ticket['status']) {
//                         case 'Open':
//                           statusColor = Colors.orange;
//                           statusIcon = Icons.report_problem_outlined;
//                           break;
//                         case 'In Progress':
//                           statusColor = Colors.blue;
//                           statusIcon = Icons.pending_outlined;
//                           break;
//                         case 'Closed':
//                           statusColor = Colors.green;
//                           statusIcon = Icons.check_circle_outline;
//                           break;
//                         default:
//                           statusColor = Colors.grey;
//                           statusIcon = Icons.help_outline;
//                       }
                      
//                       return Card(
//                         margin: const EdgeInsets.only(bottom: 12),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           side: BorderSide(
//                             color: statusColor.withOpacity(0.5),
//                             width: 1,
//                           ),
//                         ),
//                         child: ListTile(
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 8,
//                           ),
//                           leading: CircleAvatar(
//                             backgroundColor: statusColor.withOpacity(0.2),
//                             child: Icon(statusIcon, color: statusColor),
//                           ),
//                           title: Text(
//                             ticket['title'],
//                             style: const TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                           subtitle: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const SizedBox(height: 4),
//                               Row(
//                                 children: [
//                                   const Icon(Icons.category, size: 14, color: Colors.grey),
//                                   const SizedBox(width: 4),
//                                   Text('${ticket['category']}', style: const TextStyle(fontSize: 13)),
//                                 ],
//                               ),
//                               const SizedBox(height: 2),
//                               Row(
//                                 children: [
//                                   Icon(statusIcon, size: 14, color: statusColor),
//                                   const SizedBox(width: 4),
//                                   Text(
//                                     'Status: ${ticket['status']}',
//                                     style: TextStyle(
//                                       color: statusColor,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 13,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 2),
//                               Row(
//                                 children: [
//                                   const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
//                                   const SizedBox(width: 4),
//                                   Text(
//                                     'Created: ${ticket['createdAt'].toString().split('.')[0]}',
//                                     style: const TextStyle(fontSize: 12),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                           trailing:
//                               isOfficialRole &&
//                                       ticket['status'] == 'Open'
//                                   ? ElevatedButton.icon(
//                                       onPressed: () => _updateTicketStatus(ticket['id']),
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: Colors.green,
//                                         foregroundColor: Colors.white,
//                                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius: BorderRadius.circular(8),
//                                         ),
//                                       ),
//                                       icon: const Icon(Icons.check, size: 16),
//                                       label: const Text('Close'),
//                                     )
//                                   : null,
//                           onTap: () {
//                             showDialog(
//                               context: context,
//                               builder: (context) {
//                                 return AlertDialog(
//                                   title: Row(
//                                     children: [
//                                       Icon(statusIcon, color: statusColor, size: 24),
//                                       const SizedBox(width: 8),
//                                       Expanded(child: Text(ticket['title'])),
//                                     ],
//                                   ),
//                                   content: SingleChildScrollView(
//                                     child: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         Container(
//                                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                                           decoration: BoxDecoration(
//                                             color: Colors.grey[200],
//                                             borderRadius: BorderRadius.circular(20),
//                                           ),
//                                           child: Text('Category: ${ticket['category']}'),
//                                         ),
//                                         const SizedBox(height: 8),
//                                         Container(
//                                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                                           decoration: BoxDecoration(
//                                             color: statusColor.withOpacity(0.2),
//                                             borderRadius: BorderRadius.circular(20),
//                                           ),
//                                           child: Text(
//                                             'Status: ${ticket['status']}',
//                                             style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
//                                           ),
//                                         ),
//                                         const SizedBox(height: 16),
//                                         const Text(
//                                           'Description:',
//                                           style: TextStyle(
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 8),
//                                         Container(
//                                           padding: const EdgeInsets.all(12),
//                                           decoration: BoxDecoration(
//                                             color: Colors.grey[100],
//                                             borderRadius: BorderRadius.circular(8),
//                                           ),
//                                           child: Text(ticket['description']),
//                                         ),
//                                         if (ticket['userEmail'] != null) ...[
//                                           const SizedBox(height: 16),
//                                           Text('Submitted by: ${ticket['userEmail']}',
//                                             style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
//                                           ),
//                                         ],
//                                       ],
//                                     ),
//                                   ),
//                                   actions: [
//                                     if (isOfficialRole &&
//                                         ticket['status'] == 'Open')
//                                       TextButton.icon(
//                                         onPressed: () {
//                                           _updateTicketStatus(ticket['id']);
//                                           Navigator.of(context).pop();
//                                         },
//                                         icon: const Icon(Icons.check_circle, color: Colors.green),
//                                         label: const Text('Close Ticket', style: TextStyle(color: Colors.green)),
//                                       ),
//                                     TextButton.icon(
//                                       onPressed: () => Navigator.of(context).pop(),
//                                       icon: const Icon(Icons.close),
//                                       label: const Text('Dismiss'),
//                                     ),
//                                   ],
//                                 );
//                               },
//                             );
//                           },
//                         ),
//                       );
//                     },
//                   ),
//           ],
//         ),
//       ),
//     );
//   }
// }