/// Business-level lines printed on every receipt, read from `app_config`.
///
/// `stores.phone` is the customer's number, not ours — the business phone
/// lives in `app_config` under `receipt.phone`, and an optional custom
/// footer under `receipt.footer`. Both are omitted from the paper when unset.
class ReceiptConfig {
  final String? phone;
  final String? footer;

  const ReceiptConfig({this.phone, this.footer});

  static const ReceiptConfig empty = ReceiptConfig();

  static const String phoneKey = 'receipt.phone';
  static const String footerKey = 'receipt.footer';

  factory ReceiptConfig.fromRows(List<Map<String, dynamic>> rows) {
    String? pick(String key) {
      for (final r in rows) {
        if (r['key'] == key) {
          final v = (r['value'] ?? '').toString().trim();
          return v.isEmpty ? null : v;
        }
      }
      return null;
    }

    return ReceiptConfig(phone: pick(phoneKey), footer: pick(footerKey));
  }
}
