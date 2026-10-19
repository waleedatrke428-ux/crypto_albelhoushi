import 'package:flutter/foundation.dart';

import '../models/signal_model.dart';
import '../services/supabase_service.dart';

class SignalProvider extends ChangeNotifier {
  bool isLoading = false;
  List<SignalModel> signals = [];

  Future<void> loadSignals() async {
    isLoading = true;
    notifyListeners();

    final rows = await AppSupabase.fetchSignals();
    signals = rows.map(SignalModel.fromJson).toList();

    isLoading = false;
    notifyListeners();
  }
}
