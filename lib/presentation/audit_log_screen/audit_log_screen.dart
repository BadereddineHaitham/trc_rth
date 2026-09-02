import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../services/supabase_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _svc = SupabaseService.instance;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _selectedAction = 'Tous';
  int _page = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;

  final _actions = [
    'Tous',
    'LOGIN',
    'LOGOUT',
    'CREATE',
    'UPDATE',
    'DELETE',
    'MAINTENANCE',
    'ALERT',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        _searchCtrl.text.isEmpty &&
        _selectedAction == 'Tous') {
      _loadMore();
    }
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 0;
        _hasMore = true;
        _allLogs.clear();
        _filtered.clear();
        _isLoading = true;
      });
    }
    try {
      final data = await _svc.getAuditLogs(limit: _pageSize);
      if (mounted) {
        setState(() {
          _page = 1;
          _allLogs = data;
          _hasMore = data.length >= _pageSize;
          _isLoading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final data = await _svc.getAuditLogsPage(
        limit: _pageSize,
        offset: _page * _pageSize,
      );
      if (mounted) {
        setState(() {
          _page++;
          _allLogs.addAll(data);
          _hasMore = data.length >= _pageSize;
          _isLoadingMore = false;
        });
        _applyFilter();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = _allLogs.where((log) {
        final matchAction = _selectedAction == 'Tous' ||
            (log['action'] as String? ?? '')
                .toUpperCase()
                .contains(_selectedAction);
        if (!matchAction) return false;
        if (query.isEmpty) return true;
        final desc = (log['description'] as String? ?? '').toLowerCase();
        final user = (log['username'] as String? ?? '').toLowerCase();
        final action = (log['action'] as String? ?? '').toLowerCase();
        return desc.contains(query) ||
            user.contains(query) ||
            action.contains(query);
      }).toList();
    });
  }

  Color _colorForAction(String action) {
    switch (action.toUpperCase()) {
      case 'LOGIN':
        return const Color(0xFF2196F3);
      case 'LOGOUT':
        return const Color(0xFF9E9E9E);
      case 'CREATE':
        return const Color(0xFF4CAF50);
      case 'UPDATE':
        return const Color(0xFFFF9800);
      case 'DELETE':
        return const Color(0xFFF44336);
      case 'MAINTENANCE':
        return const Color(0xFF9C27B0);
      case 'ALERT':
        return const Color(0xFFE91E63);
      default:
        return AppTheme.primary;
    }
  }

  IconData _iconForAction(String action) {
    switch (action.toUpperCase()) {
      case 'LOGIN':
        return Icons.login;
      case 'LOGOUT':
        return Icons.logout;
      case 'CREATE':
        return Icons.add_circle_outline;
      case 'UPDATE':
        return Icons.edit_outlined;
      case 'DELETE':
        return Icons.delete_outline;
      case 'MAINTENANCE':
        return Icons.build_outlined;
      case 'ALERT':
        return Icons.notifications_active_outlined;
      default:
        return Icons.history;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'à l\'instant';
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
      if (diff.inDays == 1) return 'hier à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Journal d\'activité',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualiser',
            onPressed: () => _loadLogs(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par utilisateur, action...',
                    hintStyle: GoogleFonts.ibmPlexSans(
                        fontSize: 13, color: AppTheme.mutedText),
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: AppTheme.mutedText),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppTheme.outlineVariantLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppTheme.outlineVariantLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF1A237E), width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundLight,
                  ),
                  style: GoogleFonts.ibmPlexSans(fontSize: 13),
                ),
                const SizedBox(height: 8),
                // Action filter chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _actions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final a = _actions[i];
                      final selected = _selectedAction == a;
                      final color = a == 'Tous'
                          ? const Color(0xFF1A237E)
                          : _colorForAction(a);
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedAction = a);
                          _applyFilter();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? color
                                : color.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? color
                                  : color.withAlpha(80),
                            ),
                          ),
                          child: Text(
                            a,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : color,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Results count
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppTheme.surfaceVariantLight,
            child: Text(
              _isLoading
                  ? 'Chargement...'
                  : '${_filtered.length} entrée${_filtered.length > 1 ? 's' : ''}'
                      '${_hasMore && _searchCtrl.text.isEmpty && _selectedAction == 'Tous' ? ' (scroll pour plus)' : ''}',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: AppTheme.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Log list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history,
                                size: 52, color: AppTheme.mutedText.withAlpha(120)),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune entrée trouvée',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                color: AppTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadLogs(refresh: true),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _filtered.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _filtered.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final log = _filtered[i];
                            final action =
                                (log['action'] as String? ?? '').toUpperCase();
                            final color = _colorForAction(action);
                            final icon = _iconForAction(action);
                            final desc =
                                log['description'] as String? ?? '—';
                            final user =
                                log['username'] as String? ?? '—';
                            final time = _formatDate(
                                log['created_at'] as String?);
                            final isLast = i == _filtered.length - 1;

                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  title: Text(
                                    desc,
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.darkCharcoal,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline,
                                            size: 12, color: AppTheme.mutedText),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            user,
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 11,
                                              color: AppTheme.mutedText,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.access_time,
                                            size: 12, color: AppTheme.mutedText),
                                        const SizedBox(width: 3),
                                        Text(
                                          time,
                                          style: GoogleFonts.ibmPlexSans(
                                            fontSize: 11,
                                            color: AppTheme.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                      border:
                                          Border.all(color: color.withAlpha(80)),
                                    ),
                                    child: Text(
                                      action,
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    indent: 68,
                                    color: AppTheme.outlineVariantLight,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
