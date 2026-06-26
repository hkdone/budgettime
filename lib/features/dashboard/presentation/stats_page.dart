import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'stats_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/app_theme.dart';
import '../../categories/domain/category.dart';
import '../../members/presentation/member_controller.dart';
import '../../categories/presentation/category_controller.dart';
import 'widgets/statistics_widgets.dart';

class StatsPage extends ConsumerStatefulWidget {
  final String? initialAccountId;

  const StatsPage({super.key, this.initialAccountId});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  String _viewMode = 'projected';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Réinitialise le filtre compte (sinon un filtre précédent persiste via Riverpod)
      ref
          .read(statsControllerProvider.notifier)
          .setFilterAccount(widget.initialAccountId);
    });
  }

  List<int> get _yearOptions {
    final current = DateTime.now().year;
    return [for (var y = current - 5; y <= current; y++) y];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsControllerProvider);
    final membersAsync = ref.watch(memberControllerProvider);
    final categoriesAsync = ref.watch(categoryControllerProvider);
    final customCategories = categoriesAsync.maybeWhen(
      data: (cats) => cats.where((c) => !c.isSystem).toList(),
      orElse: () => <Category>[],
    );

    return state.isLoading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
            appBar: AppBar(
              title: const Text('Analyse'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/stats-trend'),
                  icon: const Icon(Icons.show_chart),
                  tooltip: 'Tendances historiques',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButton<int>(
                    value: _yearOptions.contains(state.selectedYear)
                        ? state.selectedYear
                        : _yearOptions.last,
                    onChanged: (y) {
                      if (y != null) {
                        ref.read(statsControllerProvider.notifier).changeYear(y);
                      }
                    },
                    items: _yearOptions
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                  ),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(statsControllerProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilters(state),
                    _buildGlobalSummary(state),
                    if (state.visibleStatsByAccount.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('Aucune donnée pour cette période')),
                      )
                    else
                      ...state.visibleStatsByAccount.entries.map((entry) {
                        return _buildAccountSection(
                          state: state,
                          accountId: entry.key,
                          stats: entry.value,
                          membersAsync: membersAsync,
                          customCategories: customCategories,
                        );
                      }),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: BottomAppBar(
              height: 70,
              child: Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'real',
                      label: Text('Réel'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: 'projected',
                      label: Text('Prévisionnel'),
                      icon: Icon(Icons.event_available),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (val) {
                    setState(() => _viewMode = val.first);
                  },
                ),
              ),
            ),
          );
  }

  Widget _buildFilters(StatsState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.periodLabel(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SegmentedButton<StatsGranularity>(
            segments: const [
              ButtonSegment(value: StatsGranularity.year, label: Text('Année')),
              ButtonSegment(
                value: StatsGranularity.quarter,
                label: Text('Trimestre'),
              ),
              ButtonSegment(value: StatsGranularity.month, label: Text('Mois')),
            ],
            selected: {state.granularity},
            onSelectionChanged: (val) {
              ref
                  .read(statsControllerProvider.notifier)
                  .changeGranularity(val.first);
            },
          ),
          if (state.granularity == StatsGranularity.month) ...[
            const SizedBox(height: 8),
            DropdownButton<int>(
              isExpanded: true,
              value: state.selectedMonth,
              items: List.generate(12, (i) {
                final m = i + 1;
                return DropdownMenuItem(value: m, child: Text('Mois $m'));
              }),
              onChanged: (m) {
                if (m != null) {
                  ref.read(statsControllerProvider.notifier).changeMonth(m);
                }
              },
            ),
          ],
          if (state.granularity == StatsGranularity.quarter) ...[
            const SizedBox(height: 8),
            DropdownButton<int>(
              isExpanded: true,
              value: state.selectedQuarter,
              items: const [
                DropdownMenuItem(value: 1, child: Text('T1 (Jan–Mar)')),
                DropdownMenuItem(value: 2, child: Text('T2 (Avr–Juin)')),
                DropdownMenuItem(value: 3, child: Text('T3 (Juil–Sep)')),
                DropdownMenuItem(value: 4, child: Text('T4 (Oct–Déc)')),
              ],
              onChanged: (q) {
                if (q != null) {
                  ref.read(statsControllerProvider.notifier).changeQuarter(q);
                }
              },
            ),
          ],
          if (state.filterAccountId != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    state.accountNames[state.filterAccountId] ?? 'Compte filtré',
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    ref
                        .read(statsControllerProvider.notifier)
                        .setFilterAccount(null);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlobalSummary(StatsState state) {
    double totalRealIncome = 0;
    double totalRealExpense = 0;
    double totalProjectedIncome = 0;
    double totalProjectedExpense = 0;

    for (final stats in state.visibleStatsByAccount.values) {
      double sumSafe(Map<String, double> map) => map.entries
          .where((e) => e.key != 'transfer')
          .fold(0.0, (a, b) => a + b.value);

      totalRealIncome += sumSafe(stats.realIncomeByCategory);
      totalRealExpense += sumSafe(stats.realExpenseByCategory);
      totalProjectedIncome += sumSafe(stats.projectedIncomeByCategory);
      totalProjectedExpense += sumSafe(stats.projectedExpenseByCategory);
    }

    final realBalance = totalRealIncome - totalRealExpense;
    final projectedBalance = totalProjectedIncome - totalProjectedExpense;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Bilan — ${state.periodLabel()}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem(
                    'Réel',
                    realBalance,
                    totalRealIncome,
                    totalRealExpense,
                    AppColors.textSecondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _buildBalanceItem(
                    'Prévisionnel',
                    projectedBalance,
                    totalProjectedIncome,
                    totalProjectedExpense,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(
    String label,
    double balance,
    double income,
    double expense,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          formatCurrency(balance),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: balance >= 0 ? Colors.black : Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_upward, size: 12, color: Colors.green),
            Text(formatCurrency(income), style: const TextStyle(fontSize: 11, color: Colors.green)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_downward, size: 12, color: Colors.red),
            Text(formatCurrency(expense), style: const TextStyle(fontSize: 11, color: Colors.red)),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSection({
    required StatsState state,
    required String accountId,
    required AccountStats stats,
    required AsyncValue membersAsync,
    required List<Category> customCategories,
  }) {
    final accountName = state.accountNames[accountId] ?? 'Compte';
    final isReal = _viewMode == 'real';
    final lookup = {...state.categoryNames, ...state.memberNames};

    Widget dualOrSingle({
      required Map<String, double> realData,
      required Map<String, double> projectedData,
      required Color color,
      required String sectionTitle,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(sectionTitle),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      child: GenericBreakdownPieChart(
                        data: realData,
                        nameLookup: lookup,
                        baseColor: color,
                        title: 'Réel',
                      ),
                    ),
                    Expanded(
                      child: GenericBreakdownPieChart(
                        data: projectedData,
                        nameLookup: lookup,
                        baseColor: color,
                        title: 'Prévisionnel',
                      ),
                    ),
                  ],
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: GenericBreakdownPieChart(
                    data: isReal ? realData : projectedData,
                    nameLookup: lookup,
                    baseColor: color,
                    title: isReal ? 'Réel' : 'Prévisionnel',
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    Widget memberChart({
      required Map<String, double> realData,
      required Map<String, double> projectedData,
      required String title,
      required Color color,
    }) {
      final data = isReal ? realData : projectedData;
      final total = data.values.fold(0.0, (a, b) => a + b);
      return membersAsync.maybeWhen(
        data: (members) {
          final memberStats = data.entries
              .map(
                (e) => MemberStats(
                  memberId: e.key,
                  amount: e.value,
                  percentage: total > 0 ? (e.value / total) * 100 : 0,
                ),
              )
              .toList()
            ..sort((a, b) => b.amount.compareTo(a.amount));
          return MemberPieChart(
            stats: memberStats,
            members: members,
            totalAmount: total,
            title: '$title (${isReal ? 'Réel' : 'Prévisionnel'})',
          );
        },
        orElse: () => GenericBreakdownPieChart(
          data: data,
          nameLookup: state.memberNames,
          baseColor: color,
          title: title,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(Icons.account_balance, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                accountName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        dualOrSingle(
          realData: _withoutTransfer(stats.realExpenseByCategory),
          projectedData: _withoutTransfer(stats.projectedExpenseByCategory),
          color: AppColors.chartExpense,
          sectionTitle: 'Dépenses par catégorie',
        ),
        dualOrSingle(
          realData: _withoutTransfer(stats.realIncomeByCategory),
          projectedData: _withoutTransfer(stats.projectedIncomeByCategory),
          color: AppColors.chartIncome,
          sectionTitle: 'Revenus par catégorie',
        ),
        _sectionTitle('Revenus par membre'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: memberChart(
              realData: stats.realIncomeByMember,
              projectedData: stats.projectedIncomeByMember,
              title: 'Revenus par membre',
              color: AppColors.chartIncome,
            ),
          ),
        ),
        _sectionTitle('Dépenses par membre'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: memberChart(
              realData: stats.realExpenseByMember,
              projectedData: stats.projectedExpenseByMember,
              title: 'Dépenses par membre',
              color: AppColors.chartMemberExpense,
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Map<String, double> _withoutTransfer(Map<String, double> data) {
    return Map.fromEntries(data.entries.where((e) => e.key != 'transfer'));
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
