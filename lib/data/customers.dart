// lib/data/customers.dart
import '../models/customer.dart';

final List<Customer> dummyCustomers = [
  Customer(
    id: 1,
    name: 'Budi Santoso',
    phone: '81234567890',
    country: 'Indonesia',
    countryCode: '+62',
    countryFlag: '🇮🇩',
    lastStay: 'Grand Hyatt',
    lastRoomNo: '101',
  ),
  Customer(
    id: 2,
    name: 'Ayu Lestari',
    phone: '85678901234',
    country: 'Indonesia',
    countryCode: '+62',
    countryFlag: '🇮🇩',
    lastStay: 'The Ritz-Carlton',
    lastRoomNo: '205',
  ),
  Customer(
    id: 3,
    name: 'John Smith',
    phone: '412345678',
    country: 'Australia',
    countryCode: '+61',
    countryFlag: '🇦🇺',
    lastStay: 'Four Seasons',
    lastRoomNo: '302',
  ),
];
