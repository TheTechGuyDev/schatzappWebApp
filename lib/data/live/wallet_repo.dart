import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../demo_data.dart';

/// The signed-in user's wallet, read-only, from the same tables as the phone
/// (wallets, wallet_transactions) and the same fx-rate function. Every money
/// action stays on the phone.
class WalletRepo extends ChangeNotifier {
  WalletRepo._();
  static final WalletRepo instance = WalletRepo._();

  SupabaseClient get _sb => Supabase.instance.client;
  String? get _me => _sb.auth.currentUser?.id;

  bool loading = true;
  String? error;

  /// False when the user has not set up a wallet on the phone yet.
  bool hasWallet = false;
  double schatzBalance = 0;
  String currency = '';
  double? localEquivalent;
  List<DemoTransaction> transactions = [];

  RealtimeChannel? _channel;
  Timer? _debounce;
  String? _startedFor;

  Future<void> start() async {
    final me = _me;
    if (me == null || _startedFor == me) return;
    _startedFor = me;
    await refresh();
    _channel = _sb
        .channel('web-wallet-$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (_) => _schedule(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'wallet_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (_) => _schedule(),
        )
        .subscribe();
  }

  Future<void> stop() async {
    _startedFor = null;
    _debounce?.cancel();
    await _channel?.unsubscribe();
    _channel = null;
    transactions = [];
    hasWallet = false;
    loading = true;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), refresh);
  }

  Future<void> refresh() async {
    final me = _me;
    if (me == null) return;
    try {
      final w = await _sb
          .from('wallets')
          .select('schatz_balance, balance, currency')
          .eq('user_id', me)
          .maybeSingle();
      hasWallet = w != null;
      schatzBalance = (w?['schatz_balance'] as num?)?.toDouble() ?? 0;
      currency = '${w?['currency'] ?? ''}';

      final rows = await _sb
          .from('wallet_transactions')
          .select(
            'id, reference, type, status, amount, currency, fee_amount, '
            'balance_after, provider, metadata, created_at',
          )
          .eq('user_id', me)
          .order('created_at', ascending: false)
          .limit(10);
      transactions = await _toTransactions(
        List<Map<String, dynamic>>.from(rows),
      );
      loading = false;
      error = null;
      notifyListeners();
      if (hasWallet && currency.isNotEmpty) _loadRate();
    } catch (_) {
      loading = false;
      error = 'Could not load your wallet. Check your connection.';
      notifyListeners();
    }
  }

  /// SCHATZ is priced in euro cents (same as computeLocalEquivalent).
  Future<void> _loadRate() async {
    try {
      final r = await _sb.functions.invoke(
        'fx-rate?from=EUR&to=$currency',
        method: HttpMethod.get,
      );
      dynamic d = r.data;
      if (d is String) d = jsonDecode(d);
      if (d is Map && d['success'] == true && d['rate'] != null) {
        final rate = double.tryParse('${d['rate']}') ?? 0;
        if (rate > 0) {
          localEquivalent = schatzBalance / 100 * rate;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------------------

  static String label(String t) => switch (t) {
    'send_money_out' => 'Money Sent',
    'send_money_in' => 'Money Received',
    'airtime_purchase' || 'airtime' => 'Airtime',
    'data_purchase' || 'data' => 'Data',
    'giftcard_purchase' => 'Gift Card',
    'giftcard_received' => 'Gift Card Received',
    'topup' => 'Wallet Top Up',
    _ => t.replaceAll('_', ' '),
  };

  static bool incoming(String t) =>
      t == 'send_money_in' || t == 'giftcard_received' || t == 'topup';

  static IconData iconFor(String t) {
    if (t.startsWith('airtime')) return Icons.phone_android_rounded;
    if (t.startsWith('data')) return Icons.wifi_rounded;
    if (t.startsWith('giftcard')) return Icons.redeem_rounded;
    if (t == 'topup') return Icons.account_balance_wallet_rounded;
    return Icons.swap_horiz_rounded;
  }

  static String money(double v) {
    final fixed = v.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$whole.${parts[1]}';
  }

  static String _when(DateTime? d) {
    if (d == null) return '';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year} · '
        '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  Map<String, dynamic> _meta(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return {};
  }

  Future<List<DemoTransaction>> _toTransactions(
    List<Map<String, dynamic>> rows,
  ) async {
    final me = _me!;
    // Names and photos of the people money went to or came from.
    final ids = <String>{};
    for (final r in rows) {
      final m = _meta(r['metadata']);
      final t = '${r['type']}';
      final id =
          '${m[t == 'send_money_out' ? 'recipientUserId' : 'senderUserId'] ?? ''}';
      if (id.isNotEmpty) ids.add(id);
    }
    final names = <String, String>{};
    final photos = <String, String>{};
    if (ids.isNotEmpty) {
      try {
        final saved = await _sb
            .from('contacts')
            .select('contact_user_id, saved_name')
            .eq('owner_id', me)
            .inFilter('contact_user_id', ids.toList());
        for (final c in saved) {
          final n = '${c['saved_name'] ?? ''}'.trim();
          if (n.isNotEmpty) names['${c['contact_user_id']}'] = n;
        }
        final p = await _sb
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', ids.toList());
        for (final x in p) {
          final id = '${x['id']}';
          names.putIfAbsent(id, () => '${x['full_name'] ?? ''}'.trim());
          if ((x['avatar_url'] ?? '') != '') photos[id] = x['avatar_url'];
        }
      } catch (_) {}
    }

    return [
      for (final r in rows)
        () {
          final t = '${r['type'] ?? ''}';
          final m = _meta(r['metadata']);
          final inc = incoming(t);
          final transfer = t == 'send_money_in' || t == 'send_money_out';
          final amt = (r['amount'] as num?)?.toDouble() ?? 0;
          final cur = '${r['currency'] ?? ''}';
          final unit = transfer ? 'SFZ' : cur;
          final other =
              '${m[t == 'send_money_out' ? 'recipientUserId' : 'senderUserId'] ?? ''}';
          final otherName = names[other] ?? '';
          String sub = '';
          if (transfer && otherName.isNotEmpty) {
            sub = '${t == 'send_money_out' ? 'To' : 'From'} $otherName';
          } else if (t == 'giftcard_purchase') {
            sub = '${m['productName'] ?? ''}';
          } else if (t.startsWith('airtime') || t.startsWith('data')) {
            sub = [
              '${m['operatorName'] ?? ''}',
              '${m['recipientPhone'] ?? ''}',
            ].where((e) => e.isNotEmpty).join(' ');
          }
          final created = DateTime.tryParse('${r['created_at'] ?? ''}')
              ?.toLocal();
          final fee = (r['fee_amount'] as num?)?.toDouble() ?? 0;
          final after = (r['balance_after'] as num?)?.toDouble();
          return DemoTransaction(
            id: '${r['id']}',
            title: label(t),
            status: '${r['status'] ?? ''}',
            date: _when(created),
            amount: '${inc ? '+' : '-'}$unit ${money(amt)}',
            kind: t.startsWith('giftcard') ? TxKind.giftcard : TxKind.transfer,
            counterparty: otherName,
            incoming: inc,
            subtitle: sub,
            avatarUrl: photos[other],
            icon: transfer ? null : iconFor(t),
            details: [
              if (otherName.isNotEmpty)
                (t == 'send_money_out' ? 'To' : 'From', otherName),
              if (sub.isNotEmpty && !transfer) ('Details', sub),
              if (fee > 0) ('Fee', '$unit ${money(fee)}'),
              if (after != null) ('Balance after', '$unit ${money(after)}'),
              if ('${r['reference'] ?? ''}'.isNotEmpty)
                ('Reference', '${r['reference']}'),
            ],
          );
        }(),
    ];
  }
}
