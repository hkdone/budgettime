import '../domain/reconciliation_match.dart';

/// Logique de rapprochement prévisionnel ↔ opération réelle (inbox ou saisie).
class ReconciliationService {
  static const int defaultDaysBefore = 30;
  static const int defaultDaysAfter = 7;

  /// Tolérance fine pour montants fixes (loyer, abonnement…).
  static const double _fixedMinTolerance = 0.05;
  static const double _fixedPercentTolerance = 0.01;

  /// Tolérance large pour enveloppes variables (courses hebdo…).
  static const double _variableMinTolerance = 30.0;
  static const double _variablePercentTolerance = 0.25;

  /// Prévision issue d'une récurrence ou fréquence variable → enveloppe souple.
  bool isVariableProjected(Map<String, dynamic> projected) {
    final recurrenceId = projected['recurrence'];
    if (recurrenceId != null && recurrenceId.toString().isNotEmpty) {
      return true;
    }

    final expandRec = projected['expand']?['recurrence'];
    if (expandRec is Map) {
      final freq = expandRec['frequency'] as String?;
      if (freq == 'weekly' || freq == 'biweekly') return true;
    }

    return false;
  }

  /// Tolérance maximale acceptée pour rapprocher [projectedAmount].
  double toleranceFor(Map<String, dynamic> projected, double projectedAmount) {
    if (isVariableProjected(projected)) {
      final percentTol = projectedAmount * _variablePercentTolerance;
      return percentTol > _variableMinTolerance
          ? percentTol
          : _variableMinTolerance;
    }

    final percentTol = projectedAmount * _fixedPercentTolerance;
    return percentTol > _fixedMinTolerance ? percentTol : _fixedMinTolerance;
  }

  bool amountsMatch(
    double projectedAmount,
    double actualAmount,
    Map<String, dynamic> projected,
  ) {
    final diff = (projectedAmount - actualAmount).abs();
    return diff <= toleranceFor(projected, projectedAmount);
  }

  /// Filtre et classe les candidats par pertinence (meilleur en premier).
  List<ReconciliationMatch> rankMatches({
    required List<Map<String, dynamic>> candidates,
    required double actualAmount,
    required DateTime actualDate,
  }) {
    final matches = <ReconciliationMatch>[];

    for (final projected in candidates) {
      final projectedAmount = (projected['amount'] as num).abs().toDouble();
      if (!amountsMatch(projectedAmount, actualAmount, projected)) continue;

      final projectedDate = DateTime.parse(projected['date'] as String).toLocal();
      final daysDelta = actualDate.difference(projectedDate).inDays.abs();
      final amountDelta = projectedAmount - actualAmount;
      final variable = isVariableProjected(projected);

      final tolerance = toleranceFor(projected, projectedAmount);
      final amountScore = tolerance > 0
          ? (1 - (amountDelta.abs() / tolerance)).clamp(0.0, 1.0)
          : (amountDelta.abs() < 0.01 ? 1.0 : 0.0);

      final maxDays = defaultDaysBefore + defaultDaysAfter;
      final dateScore = maxDays > 0
          ? (1 - (daysDelta / maxDays)).clamp(0.0, 1.0)
          : 1.0;

      var score = amountScore * 0.55 + dateScore * 0.45;
      if (variable) score += 0.05;
      if (projected['recurrence'] != null &&
          projected['recurrence'].toString().isNotEmpty) {
        score += 0.1;
      }

      matches.add(
        ReconciliationMatch(
          transaction: projected,
          score: score,
          amountDelta: amountDelta,
          daysDelta: daysDelta,
          isVariableEnvelope: variable,
        ),
      );
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }
}
