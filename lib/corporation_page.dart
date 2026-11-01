import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:garbage1/login_page.dart';
import 'package:garbage1/ml_analytics.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';

class CorporationPage extends StatefulWidget {
  final String username;

  const CorporationPage({Key? key, required this.username}) : super(key: key);

  @override
  State<CorporationPage> createState() => _CorporationPageState();
}

class _CorporationPageState extends State<CorporationPage> {
  final _notifications = FlutterLocalNotificationsPlugin();
  final _searchController = TextEditingController();
  StreamSubscription? _sosSub;
  bool _sosInitialLoad = true;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ticketStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sosStream;

  int _tab = 0;
  int _analyticsVersion = 0; // bump to reload analytics on each visit
  String _ticketFilter = 'All';
  String _search = '';
  bool _showResolvedSOS = false;

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    // No where+orderBy combos: everything is filtered/sorted client-side so
    // the fresh Firestore database needs no composite indexes.
    _ticketStream = db.collection('tickets').snapshots();
    _sosStream = db.collection('sos_alerts').snapshots();
    _initNotifications();
    _listenForNewSOS();
  }

  @override
  void dispose() {
    _sosSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<void> _initNotifications() async {
    try {
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (_) {
          if (mounted) setState(() => _tab = 2);
        },
      );
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        FirebaseMessaging.onMessage.listen((m) {
          _showLocalNotification(
            m.notification?.title ?? 'Emergency Alert',
            m.notification?.body ?? 'A new SOS alert has been received!',
          );
        });
      }
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'sos_channel_id',
            'SOS Alerts',
            channelDescription: 'Emergency SOS alerts from citizens',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }

  void _listenForNewSOS() {
    _sosSub = FirebaseFirestore.instance
        .collection('sos_alerts')
        .where('status', isEqualTo: 'Active')
        .snapshots()
        .listen((snapshot) {
          // Skip the first snapshot: those alerts already existed.
          if (_sosInitialLoad) {
            _sosInitialLoad = false;
            return;
          }
          final added = snapshot.docChanges.where(
            (c) => c.type == DocumentChangeType.added,
          );
          if (added.isEmpty || !mounted) return;
          _showLocalNotification(
            'Emergency SOS alert',
            'A citizen has requested emergency assistance.',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 8),
              content: const Text('New emergency SOS alert received'),
              action: SnackBarAction(
                label: 'VIEW',
                textColor: Colors.white,
                onPressed: () => setState(() => _tab = 2),
              ),
            ),
          );
        });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _setTicketStatus(String id, String status) async {
    try {
      await FirebaseFirestore.instance.collection('tickets').doc(id).update({
        'status': status,
        'updatedBy': FirebaseAuth.instance.currentUser?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('Ticket marked as $status', statusColor(status));
    } catch (e) {
      _showErrorDialog('Failed to update ticket: $e');
    }
  }

  Future<void> _resolveSOS(String id) async {
    try {
      await FirebaseFirestore.instance.collection('sos_alerts').doc(id).update({
        'status': 'Resolved',
        'resolvedBy': FirebaseAuth.instance.currentUser?.email,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      _snack('SOS alert marked as resolved', AppColors.closed);
    } catch (e) {
      _showErrorDialog('Failed to update SOS alert: $e');
    }
  }

  Future<void> _openMap(dynamic lat, dynamic lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showErrorDialog('Could not open the map');
    }
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
    if (!mounted) return;
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

  void _openTicket(Map<String, dynamic> t) {
    final status = t['status'] ?? 'Open';
    showTicketDetails(
      context,
      t,
      actions:
          (ctx) => [
            const Text(
              'Update status',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (status != 'In Progress')
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.inProgress,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setTicketStatus(t['id'], 'In Progress');
                      },
                      icon: const Icon(Icons.engineering_outlined),
                      label: Text(status == 'Closed' ? 'Reopen' : 'Start work'),
                    ),
                  ),
                if (status != 'In Progress' && status != 'Closed')
                  const SizedBox(width: 10),
                if (status != 'Closed')
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.closed,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setTicketStatus(t['id'], 'Closed');
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Resolve'),
                    ),
                  ),
              ],
            ),
          ],
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ticketStream,
      builder: (context, tSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _sosStream,
          builder: (context, sSnap) {
            final tickets =
                tSnap.hasData
                    ? docsNewestFirst(tSnap.data!)
                    : <Map<String, dynamic>>[];
            final sos =
                sSnap.hasData
                    ? docsNewestFirst(sSnap.data!)
                    : <Map<String, dynamic>>[];
            final loading = !tSnap.hasData || !sSnap.hasData;
            final activeSOS = sos.where((a) => a['status'] == 'Active').length;

            final pages = [
              _buildOverview(tickets, sos, loading, tSnap.error),
              _buildTickets(tickets, loading),
              _buildSOS(sos, loading),
              MlAnalytics(key: ValueKey(_analyticsVersion)),
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
                  onDestinationSelected:
                      (i) => setState(() {
                        if (i == 3 && _tab != 3) _analyticsVersion++;
                        _tab = i;
                      }),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: tickets.any(
                          (t) => t['status'] == 'Open',
                        ),
                        label: Text(
                          '${tickets.where((t) => t['status'] == 'Open').length}',
                        ),
                        backgroundColor: AppColors.open,
                        child: const Icon(Icons.assignment_outlined),
                      ),
                      selectedIcon: const Icon(Icons.assignment),
                      label: 'Tickets',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: activeSOS > 0,
                        label: Text('$activeSOS'),
                        child: const Icon(Icons.sos_outlined),
                      ),
                      selectedIcon: const Icon(Icons.sos),
                      label: 'SOS',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights),
                      label: 'Analytics',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ----- Overview -----------------------------------------------------------

  Widget _buildOverview(
    List<Map<String, dynamic>> tickets,
    List<Map<String, dynamic>> sos,
    bool loading,
    Object? error,
  ) {
    int count(String s) => tickets.where((t) => t['status'] == s).length;
    final open = count('Open');
    final progress = count('In Progress');
    final closed = count('Closed');
    final total = tickets.length;
    final rate = total == 0 ? 0.0 : closed / total;
    final activeSOS = sos.where((a) => a['status'] == 'Active').toList();
    final topInset = MediaQuery.of(context).padding.top;

    final byCategory = <String, int>{
      for (final c in ticketCategories)
        c: tickets.where((t) => t['category'] == c).length,
    };
    final maxCat = byCategory.values.fold<int>(1, (a, b) => b > a ? b : a);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(20, topInset + 18, 12, 24),
          color: AppColors.navy,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Corporation Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle, color: Colors.white),
                onSelected: (v) {
                  if (v == 'logout') _signOut();
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          FirebaseAuth.instance.currentUser?.email ??
                              widget.username,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 18),
                            SizedBox(width: 10),
                            Text('Sign out'),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Could not load data',
                  message: '$error',
                ),
                const SizedBox(height: 16),
              ],

              // Active SOS banner
              if (activeSOS.isNotEmpty) ...[
                Material(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _tab = 2),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${activeSOS.length} active emergency ${activeSOS.length == 1 ? 'alert' : 'alerts'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Latest ${timeAgo(activeSOS.first['createdAt'])} · tap to respond',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
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
                const SizedBox(height: 20),
              ],

              const SectionHeader('Ticket summary'),
              GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.1,
                children: [
                  StatCard(
                    label: 'Total tickets',
                    value: loading ? '–' : '$total',
                    icon: Icons.assignment_outlined,
                    color: AppColors.primary,
                    onTap: () => _jumpToTickets('All'),
                  ),
                  StatCard(
                    label: 'Open',
                    value: loading ? '–' : '$open',
                    icon: Icons.inbox_outlined,
                    color: AppColors.open,
                    onTap: () => _jumpToTickets('Open'),
                  ),
                  StatCard(
                    label: 'In progress',
                    value: loading ? '–' : '$progress',
                    icon: Icons.engineering_outlined,
                    color: AppColors.inProgress,
                    onTap: () => _jumpToTickets('In Progress'),
                  ),
                  StatCard(
                    label: 'Resolved',
                    value: loading ? '–' : '$closed',
                    icon: Icons.task_alt,
                    color: AppColors.closed,
                    onTap: () => _jumpToTickets('Closed'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Resolution rate
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Resolution rate',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            '${(rate * 100).round()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.closed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: rate,
                          minHeight: 10,
                          backgroundColor: AppColors.border,
                          color: AppColors.closed,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$closed of $total tickets resolved',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const SectionHeader(
                'Issues by category',
                subtitle: 'Where citizens need help most',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final e in byCategory.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Icon(
                                categoryIcon(e.key),
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 136,
                                child: Text(
                                  categoryLabel(e.key),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: e.value / maxCat,
                                    minHeight: 8,
                                    backgroundColor: AppColors.background,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${e.value}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SectionHeader(
                'Needs attention',
                subtitle: 'Most recent open tickets',
                trailing: TextButton(
                  onPressed: () => _jumpToTickets('Open'),
                  child: const Text('View all'),
                ),
              ),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (open == 0)
                const EmptyState(
                  icon: Icons.task_alt,
                  title: 'All caught up',
                  message: 'There are no open tickets right now.',
                )
              else
                ...tickets
                    .where((t) => t['status'] == 'Open')
                    .take(4)
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TicketTile(
                          ticket: t,
                          showReporter: true,
                          onTap: () => _openTicket(t),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  void _jumpToTickets(String filter) {
    setState(() {
      _ticketFilter = filter;
      _tab = 1;
    });
  }

  // ----- Tickets ------------------------------------------------------------

  Widget _buildTickets(List<Map<String, dynamic>> tickets, bool loading) {
    const filters = ['All', 'Open', 'In Progress', 'Closed'];
    final q = _search.toLowerCase();
    final visible =
        tickets.where((t) {
          if (_ticketFilter != 'All' && t['status'] != _ticketFilter) {
            return false;
          }
          if (q.isEmpty) return true;
          return [
            t['title'],
            t['description'],
            t['userEmail'],
            t['category'],
          ].any((f) => (f ?? '').toString().toLowerCase().contains(q));
        }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Citizen tickets')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search title, reporter, category…',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon:
                    _search.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
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
                    : visible.isEmpty
                    ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'No tickets found',
                        message: 'Try a different filter or search term.',
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder:
                          (_, i) => TicketTile(
                            ticket: visible[i],
                            showReporter: true,
                            onTap: () => _openTicket(visible[i]),
                          ),
                    ),
          ),
        ],
      ),
    );
  }

  // ----- SOS ----------------------------------------------------------------

  Widget _buildSOS(List<Map<String, dynamic>> sos, bool loading) {
    final active = sos.where((a) => a['status'] == 'Active').toList();
    final resolved = sos.where((a) => a['status'] != 'Active').toList();
    final visible = _showResolvedSOS ? resolved : active;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency alerts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text('Active (${active.length})'),
                    icon: const Icon(Icons.warning_amber_rounded),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Resolved (${resolved.length})'),
                    icon: const Icon(Icons.task_alt),
                  ),
                ],
                selected: {_showResolvedSOS},
                onSelectionChanged:
                    (s) => setState(() => _showResolvedSOS = s.first),
              ),
            ),
          ),
          Expanded(
            child:
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : visible.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: EmptyState(
                        icon:
                            _showResolvedSOS
                                ? Icons.history
                                : Icons.verified_user_outlined,
                        title:
                            _showResolvedSOS
                                ? 'No resolved alerts'
                                : 'No active emergencies',
                        message:
                            _showResolvedSOS
                                ? 'Resolved alerts will be listed here.'
                                : 'You will be notified as soon as a citizen sends an SOS.',
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _sosCard(visible[i]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _sosCard(Map<String, dynamic> a) {
    final isActive = a['status'] == 'Active';
    final color = isActive ? AppColors.danger : AppColors.closed;
    final lat = a['latitude'];
    final lng = a['longitude'];
    final hasLoc = lat is num && lng is num;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: isActive ? 0.5 : 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.emergency : Icons.task_alt,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['username'] ?? a['userEmail'] ?? 'Unknown citizen',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        timeAgo(a['createdAt'] ?? a['timestamp']),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(isActive ? 'Active' : 'Resolved'),
              ],
            ),
            const SizedBox(height: 14),
            _sosInfo(
              Icons.place_outlined,
              (a['address'] as String?) ??
                  (hasLoc
                      ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                      : 'Location unavailable'),
            ),
            if (a['userEmail'] != null)
              _sosInfo(Icons.mail_outline, a['userEmail']),
            _sosInfo(
              Icons.schedule,
              'Received ${formatDate(a['createdAt'] ?? a['timestamp'])}',
            ),
            if (!isActive && a['resolvedAt'] != null)
              _sosInfo(
                Icons.verified_outlined,
                'Resolved ${formatDate(a['resolvedAt'])}${a['resolvedBy'] != null ? ' by ${a['resolvedBy']}' : ''}',
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: hasLoc ? () => _openMap(lat, lng) : null,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open map'),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.closed,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => _resolveSOS(a['id']),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Resolve'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sosInfo(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}
