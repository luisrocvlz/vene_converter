import 'package:workmanager/workmanager.dart';
import '../services/rates_service.dart';

const String kRefreshTaskName = 'vene-rates-refresh';
const String kRefreshTaskUnique = 'vene-rates-refresh-unique';

@pragma('vm:entry-point')
void rangeCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final snap = await RatesService.fetchAll();
      await RatesService.syncHistory();
      await RatesService.pushToWidget(snap);
      return true;
    } catch (_) {
      return false;
    }
  });
}
