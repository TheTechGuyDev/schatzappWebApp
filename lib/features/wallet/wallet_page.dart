import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brand_logo.dart';

/// Wallets tab (Wallet UI image). Placeholder data until the backend phase.
/// Wallet actions are mobile-only: tapping one shows a "mobile app only"
/// notice. The web shows balance and recent transactions.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  static const routePath = '/wallets';

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletAction {
  const _WalletAction(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

const _topActions = [
  _WalletAction(Icons.add, 'Top Up', 'Add money to your wallet'),
  _WalletAction(Icons.schedule, 'History', 'View your transaction history'),
];

const _moreActions = [
  _WalletAction(Icons.arrow_upward, 'Send', 'Send money to a user'),
  _WalletAction(Icons.redeem_outlined, 'Schatz Gift', 'Send gifts to friends'),
  _WalletAction(Icons.credit_card, 'Gift Card', 'Buy or redeem gift cards'),
  _WalletAction(Icons.wifi, 'Data', 'Buy data bundles'),
  _WalletAction(Icons.smartphone, 'Airtime', 'Buy airtime / top up number'),
  _WalletAction(Icons.favorite_border, 'Donation', 'Make a donation'),
];

class _WalletPageState extends State<WalletPage> {
  bool _hidden = false;

  void _onAction(_WalletAction a) {
    showDialog<void>(
      context: context,
      builder: (_) => _MobileOnlyDialog(action: a.title),
    );
  }

  void _openTx(DemoTransaction t) {
    showDialog<void>(
      context: context,
      builder: (_) => _TransactionDialog(tx: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final actions = _ActionsPanel(onTap: _onAction);
    final main = _WalletMain(
      hidden: _hidden,
      onToggleHidden: () => setState(() => _hidden = !_hidden),
      onOpenTx: _openTx,
    );

    if (size == ScreenSize.phone) {
      return Container(
        color: Colors.white,
        child: ListView(
          children: [
            main.header(context),
            main.balance(),
            actions,
            main.transactions(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: size == ScreenSize.desktop ? 370 : 320,
            child: ShellPanel(child: SingleChildScrollView(child: actions)),
          ),
          const SizedBox(width: 12),
          Expanded(child: ShellPanel(child: main)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel({required this.onTap});

  final ValueChanged<_WalletAction> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Wallet Actions',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
          ),
          const SizedBox(height: 16),
          for (final a in _topActions) ...[
            _ActionTile(action: a, onTap: () => onTap(a), boxed: true),
            const SizedBox(height: 14),
          ],
          const Divider(height: 18, color: AppColors.border),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _moreActions.length; i++)
                  _ActionTile(
                    action: _moreActions[i],
                    onTap: () => onTap(_moreActions[i]),
                    divider: i < _moreActions.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.onTap,
    this.boxed = false,
    this.divider = false,
  });

  final _WalletAction action;
  final VoidCallback onTap;
  final bool boxed;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EEF4),
              shape: BoxShape.circle,
            ),
            child: Icon(action.icon, color: AppColors.meta, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.body,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.meta),
                  ),
                ],
              ),
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.meta,
            size: 22,
          ),
        ],
      ),
    );
    return Material(
      color: boxed ? const Color(0xFFF8F7FB) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          children: [
            row,
            if (divider)
              const Padding(
                padding: EdgeInsets.only(left: 70, right: 14),
                child: Divider(height: 1, color: AppColors.border),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main: balance + recent transactions
// ---------------------------------------------------------------------------

class _WalletMain extends StatelessWidget {
  const _WalletMain({
    required this.hidden,
    required this.onToggleHidden,
    required this.onOpenTx,
  });

  final bool hidden;
  final VoidCallback onToggleHidden;
  final ValueChanged<DemoTransaction> onOpenTx;

  Widget header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 20, 6),
    child: Row(
      children: [
        const Text(
          'Wallet',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.heading,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: hidden ? 'Show balance' : 'Hide balance',
          onPressed: onToggleHidden,
          icon: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_rounded,
            color: AppColors.heading,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.accent, AppColors.teal],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Avatar(name: demoCurrentUserName, size: 42),
          ),
        ),
      ],
    ),
  );

  Widget balance() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    child: _BalanceCard(hidden: hidden),
  );

  Widget transactions() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.body,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < demoTransactions.length; i++)
          _TxRow(
            tx: demoTransactions[i],
            hidden: hidden,
            last: i == demoTransactions.length - 1,
            onTap: () => onOpenTx(demoTransactions[i]),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(children: [header(context), balance(), transactions()]);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.hidden});

  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8E4BEA), Color(0xFF7A2BE8), Color(0xFF8B2FF0)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final showArt = c.maxWidth > 420;
          return Stack(
            children: [
              if (showArt)
                const Positioned(
                  right: 50,
                  top: 0,
                  bottom: 0,
                  child: _CardStackArt(),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Balance',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hidden ? 'SFZ ••••••' : demoWalletBalance,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hidden ? '= NGN ••••••' : demoWalletLocal,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fanned stack of frosted cards with the S badge (decorative).
class _CardStackArt extends StatelessWidget {
  const _CardStackArt();

  @override
  Widget build(BuildContext context) {
    Widget card(
      double angle,
      double dx,
      double dy,
      double alpha, {
      bool front = false,
    }) {
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 150,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            ),
            child: front
                ? Stack(
                    children: [
                      Positioned(
                        right: 14,
                        top: 18,
                        child: Container(
                          width: 30,
                          height: 30,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const SMark(size: 22),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: Icon(
                          Icons.contactless_outlined,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 14,
                        child: Container(
                          width: 28,
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      );
    }

    return SizedBox(
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          card(-0.05, 22, -22, 0.35),
          card(0.02, 14, -10, 0.45),
          card(0.12, 6, 2, 0.55),
          card(0.22, -4, 14, 0.75, front: true),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.tx,
    required this.hidden,
    required this.last,
    required this.onTap,
  });

  final DemoTransaction tx;
  final bool hidden;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEDE4FB),
              ),
              child: tx.kind == TxKind.giftcard
                  ? Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.redeem,
                        color: AppColors.accent,
                        size: 24,
                      ),
                    )
                  : Avatar(
                      name: tx.counterparty,
                      color: const Color(0xFF8A6A55),
                      size: 48,
                    ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.heading,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tx.status,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.meta,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hidden ? '••••' : tx.amount,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF17A82E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tx.date,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.meta,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.chevron_right, color: AppColors.heading),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

class _MobileOnlyDialog extends StatelessWidget {
  const _MobileOnlyDialog({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: AppColors.accent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Available on mobile only',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can only access $action from the SchatzApp mobile app.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: AppColors.meta,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionDialog extends StatelessWidget {
  const _TransactionDialog({required this.tx});

  final DemoTransaction tx;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(k, style: const TextStyle(color: AppColors.meta)),
          const Spacer(),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
              ),
            ),
          ),
        ],
      ),
    );
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Transaction Details',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tx.amount,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17A82E),
                ),
              ),
              const SizedBox(height: 14),
              row('Type', tx.title),
              row('Status', tx.status),
              if (tx.kind == TxKind.transfer) row('From', tx.counterparty),
              row('Date', tx.date),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
