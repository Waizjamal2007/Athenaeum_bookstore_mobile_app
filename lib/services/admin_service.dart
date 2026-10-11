import 'api_service.dart';

class AdminService {
  static Future<void> manageUser(
      String uid,
      String action, {
        String? name,
        String? address,
        String? paymentMethod,
      }) async {
    await ApiService.post('manageUser', {
      'uid': uid,
      'action': action,
      if (name != null) 'name': name,
      if (address != null) 'shippingAddress': address,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    });
  }

  static Future<Map<String, dynamic>> announce(
      String title,
      String body,
      ) =>
      ApiService.post('sendAnnouncement', {
        'title': title.trim(),
        'body': body.trim(),
      });

  static Future<Map<String, dynamic>> updateOrderStatus(
      String id,
      String status,
      ) =>
      ApiService.post('updateOrderStatus', {
        'orderId': id,
        'status': status,
      });

  static Future<Map<String, dynamic>> retryNotifications() =>
      ApiService.post('retryNotifications', {});
}