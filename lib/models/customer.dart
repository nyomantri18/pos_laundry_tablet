// lib/models/customer.dart
class Customer {
  final int id;
  final String name;
  final String phone;
  final String country;
  final String countryCode;
  final String countryFlag;
  final String lastStay;
  final String lastRoomNo;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.country,
    required this.countryCode,
    required this.countryFlag,
    required this.lastStay,
    required this.lastRoomNo,
  });
}
