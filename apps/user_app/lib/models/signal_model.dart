import 'dart:convert';

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
    final id = _integer(json['id']);
    final entry = _number(json['entry']);
    final stopLoss = _number(json['stop_loss']);
    final pair = json['pair'];
    final type = json['type'];
    final targets = json['targets'];
    if (id == null ||
        entry == null ||
        stopLoss == null ||
        pair is! String ||
        type is! String ||
        targets is! String) {
      throw const FormatException('Invalid signal row returned by Supabase.');
    }

    return SignalModel(
      id: id,
      pair: pair,
      type: type,
      entry: entry,
      targets: targets,
      stopLoss: stopLoss,
      exchange: json['exchange'] as String? ?? '',
      timeframe: json['timeframe'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      strength: _integer(json['strength']) ?? 0,
      isFree: json['is_free'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      result: json['result'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<String> get targetLevels {
    final raw = targets.trim();
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((value) => value.toString()).toList();
      if (decoded is Map) {
        return decoded.values.map((value) => value.toString()).toList();
      }
    } on FormatException {
      return raw
          .split(RegExp(r'[,;|]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    return raw
        .split(RegExp(r'[,;|]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }
}
