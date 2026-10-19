class SignalModel {
  const SignalModel({
    required this.id,
    required this.pair,
    required this.type,
    required this.entry,
    required this.targets,
    required this.stopLoss,
    required this.exchange,
    required this.timeframe,
    required this.rationale,
    required this.strength,
    required this.isFree,
    required this.status,
    required this.result,
    required this.createdAt,
  });

  final int id;
  final String pair;
  final String type;
  final double entry;
  final String targets;
  final double stopLoss;
  final String exchange;
  final String timeframe;
  final String rationale;
  final int strength;
  final bool isFree;
  final String status;
  final String result;
  final DateTime? createdAt;

  factory SignalModel.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '');
    double? asDouble(Object? value) =>
        value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

    final id = asInt(json['id']);
    final entry = asDouble(json['entry']);
    final stopLoss = asDouble(json['stop_loss']);
    if (id == null ||
        entry == null ||
        stopLoss == null ||
        json['pair'] is! String ||
        json['type'] is! String ||
        json['targets'] is! String) {
      throw const FormatException('Invalid signal row returned by Supabase.');
    }

    return SignalModel(
      id: id,
      pair: json['pair'] as String,
      type: json['type'] as String,
      entry: entry,
      targets: json['targets'] as String,
      stopLoss: stopLoss,
      exchange: json['exchange'] as String? ?? '',
      timeframe: json['timeframe'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      strength: asInt(json['strength']) ?? 0,
      isFree: json['is_free'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      result: json['result'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
