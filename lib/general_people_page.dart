import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:garbage1/login_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'theme.dart';

class GeneralPeoplePage extends StatefulWidget {
  final String username;

  const GeneralPeoplePage({Key? key, required this.username}) : super(key: key);

  @override
  State<GeneralPeoplePage> createState() => _GeneralPeoplePageState();
}

class _GeneralPeoplePageState extends State<GeneralPeoplePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = ticketCategories.first;
  String _ticketFilter = 'All';
  bool _isSubmitting = false;
  bool _isSendingSOS = false;
  int _tab = 0;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ticketStream;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Single equality filter, sorted on the client -> no composite index needed.
    _ticketStream =
        FirebaseFirestore.instance
            .collection('tickets')
            .where('userId', isEqualTo: _user?.uid)
            .snapshots();
    _profileFuture =
        FirebaseFirestore.instance.collection('users').doc(_user?.uid).get();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _submitTicket() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('tickets').add({
        'userId': user.uid,
        'userEmail': user.email,
        'username': widget.username,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'status': 'Open',
        'createdAt': FieldValue.serverTimestamp(),
        'userRole': 'General People',
      });
      _titleController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _snack('Your report has been submitted', AppColors.closed);
      setState(() => _tab = 2);
    } catch (e) {
      _showErrorDialog('Failed to submit report: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmAndSendSOS() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: const Icon(
              Icons.emergency_share,
              color: AppColors.danger,
              size: 36,
            ),
            title: const Text('Send emergency alert?'),
            content: const Text(
              'Your live location will be shared with corporation officials so they can respond immediately.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send SOS'),
              ),
            ],
          ),
    );
    if (ok == true) await _sendSOSAlert();
  }

  Future<void> _sendSOSAlert() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSendingSOS = true);
    try {
      final position = await _getCurrentLocation();
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
      _snack(
        'Emergency alert sent. Officials have been notified.',
        AppColors.danger,
      );
    } catch (e) {
      _showErrorDialog('Failed to send SOS alert: $e');
    } finally {
      if (mounted) setState(() => _isSendingSOS = false);
    }
  }

  Future<Position> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are disabled. Please enable them.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw 'Location permission denied.';
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission is permanently denied. Enable it in Settings.';
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<String> _getAddressFromCoordinates(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return [
          p.street,
          p.subLocality,
          p.locality,
          p.postalCode,
          p.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
      }
    } catch (_) {}
    return 'Address unavailable';
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: AppColors.danger),
            title: const Text('Something went wrong'),
            content: Text(message, textAlign: TextAlign.center),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _startReport(String category) {
    setState(() {
      _selectedCategory = category;
      _tab = 1;
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ticketStream,
      builder: (context, snap) {
        final tickets =
            snap.hasData
                ? docsNewestFirst(snap.data!)
                : <Map<String, dynamic>>[];
        final loading = snap.connectionState == ConnectionState.waiting;

        final pages = [
          _buildHome(tickets, loading),
          _buildReport(),
          _buildTickets(tickets, loading, snap.error),
          _buildProfile(tickets),
        ];

        return Scaffold(
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                _tab == 0
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
            child: IndexedStack(index: _tab, children: pages),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Report',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'My Reports',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _firstName {
    final n = widget.username.trim();
    if (n.contains('@')) return n.split('@').first;
    return n.split(' ').first;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ----- Home ---------------------------------------------------------------

  Widget _buildHome(List<Map<String, dynamic>> tickets, bool loading) {
    int count(String s) => tickets.where((t) => t['status'] == s).length;
    final topInset = MediaQuery.of(context).padding.top;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _firstName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _tab = 3),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        _firstName.isEmpty ? '?' : _firstName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _headerStat('${tickets.length}', 'Reported'),
                    _headerDivider(),
                    _headerStat(
                      '${count('Open') + count('In Progress')}',
                      'Pending',
                    ),
                    _headerDivider(),
                    _headerStat('${count('Closed')}', 'Resolved'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSOSCard(),
              const SizedBox(height: 24),
              const SectionHeader(
                'Report an issue',
                subtitle: 'Pick a category to get started',
              ),
              GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.0,
                children: [
                  for (final c in ticketCategories)
                    _categoryTile(c, () => _startReport(c)),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(
                'Recent reports',
                trailing:
                    tickets.isEmpty
                        ? null
                        : TextButton(
                          onPressed: () => setState(() => _tab = 2),
                          child: const Text('View all'),
                        ),
              ),
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (tickets.isEmpty)
                const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No reports yet',
                  message:
                      'Issues you report will appear here so you can track their progress.',
                )
              else
                ...tickets
                    .take(3)
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TicketTile(
                          ticket: t,
                          onTap: () => showTicketDetails(context, t),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerStat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _headerDivider() => Container(
    width: 1,
    height: 32,
    color: Colors.white.withValues(alpha: 0.2),
  );

  Widget _buildSOSCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isSendingSOS ? null : _confirmAndSendSOS,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child:
                      _isSendingSOS
                          ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(
                            Icons.sos_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSendingSOS ? 'Sending alert…' : 'Emergency SOS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Share your location with officials instantly',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(String category, VoidCallback onTap) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIcon(category),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                categoryLabel(category),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Report -------------------------------------------------------------

  Widget _buildReport() {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an issue')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Describe the problem clearly so officials can act quickly.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in ticketCategories)
                    ChoiceChip(
                      avatar: Icon(
                        categoryIcon(c),
                        size: 18,
                        color:
                            _selectedCategory == c
                                ? Colors.white
                                : AppColors.primary,
                      ),
                      label: Text(categoryLabel(c)),
                      selected: _selectedCategory == c,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color:
                            _selectedCategory == c
                                ? Colors.white
                                : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = c),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Overflowing bin near bus stop',
                  prefixIcon: Icon(Icons.title),
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Please add a short title'
                            : null,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Where is it, how long has it been there, etc.',
                  alignLabelWithHint: true,
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().length < 10)
                            ? 'Please describe the issue (min 10 characters)'
                            : null,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitTicket,
                icon:
                    _isSubmitting
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Submitting…' : 'Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Tickets ------------------------------------------------------------

  Widget _buildTickets(
    List<Map<String, dynamic>> tickets,
    bool loading,
    Object? error,
  ) {
    const filters = ['All', 'Open', 'In Progress', 'Closed'];
    final visible =
        _ticketFilter == 'All'
            ? tickets
            : tickets.where((t) => t['status'] == _ticketFilter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        f == 'All'
                            ? 'All (${tickets.length})'
                            : '$f (${tickets.where((t) => t['status'] == f).length})',
                      ),
                      selected: _ticketFilter == f,
                      onSelected: (_) => setState(() => _ticketFilter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child:
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: EmptyState(
                        icon: Icons.cloud_off,
                        title: 'Could not load reports',
                        message: '$error',
                      ),
                    )
                    : visible.isEmpty
                    ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Nothing here',
                        message: 'No reports match this filter.',
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder:
                          (_, i) => TicketTile(
                            ticket: visible[i],
                            onTap: () => showTicketDetails(context, visible[i]),
                          ),
                    ),
          ),
        ],
      ),
    );
  }

  // ----- Profile ------------------------------------------------------------

  Widget _buildProfile(List<Map<String, dynamic>> tickets) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _profileFuture,
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          final name = (data['name'] ?? widget.username) as String;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user?.email ?? '',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Citizen',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Column(
                  children: [
                    _profileRow(
                      Icons.home_outlined,
                      'Address',
                      (data['address'] as String?)?.isNotEmpty == true
                          ? data['address']
                          : 'Not provided',
                    ),
                    const Divider(height: 1, indent: 56),
                    _profileRow(
                      Icons.pin_drop_outlined,
                      'Pincode',
                      (data['pincode'] as String?)?.isNotEmpty == true
                          ? data['pincode']
                          : 'Not provided',
                    ),
                    const Divider(height: 1, indent: 56),
                    _profileRow(
                      Icons.receipt_long_outlined,
                      'Reports submitted',
                      '${tickets.length}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, color: AppColors.textSecondary),
    title: Text(
      label,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    ),
    subtitle: Text(
      value,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );
}
