import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'data/countries.dart';
import 'data/customers.dart';
import 'models/customer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final String newText = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final int number = int.parse(newText);
    final String formattedText = _formatter.format(number);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

// WIDGET KUSTOM UNTUK TEXT FIELD
class StyledTextField extends StatefulWidget {
  final String label;
  final String hint;
  final bool isNumeric;
  final TextEditingController? controller;
  final String? prefixText;
  final FocusNode? focusNode;

  const StyledTextField({
    super.key,
    required this.label,
    required this.hint,
    this.isNumeric = false,
    this.controller,
    this.prefixText,
    this.focusNode,
  });

  @override
  State<StyledTextField> createState() => _StyledTextFieldState();
}

class _StyledTextFieldState extends State<StyledTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    // Hanya dispose jika node ini dibuat di dalam widget ini
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xFF555555),
              ),
            ),
          ),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FA),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF01aaa3)
                  : Colors.grey.shade300,
              width: _isFocused ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2.0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(
              color: Color(0xFF01aaa3),
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              prefixText: widget.prefixText,
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.normal,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// MODEL DATA
class CartItem {
  final String name;
  final int price;
  double quantity;
  final TextEditingController qtyController;

  CartItem({required this.name, required this.price, this.quantity = 1.0})
    : qtyController = TextEditingController(text: quantity.toString());
}

// ENUM UNTUK DELIVERY OPTION
enum DeliveryOption { drop, deliver }

// ENUM UNTUK METODE PEMBAYARAN
enum PaymentMethod { cash, transfer, qris, card, credit }

// HALAMAN UTAMA
class PosPage extends StatefulWidget {
  const PosPage({super.key});
  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  List<CartItem> cart = [];
  final currencyFormatter = NumberFormat.decimalPattern('id_ID');

  final _customerSearchController = TextEditingController();
  final _hotelNameController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  Map<String, String>? _selectedCountry;

  TimeOfDay? _selectedTime;
  DeliveryOption _deliveryOption = DeliveryOption.drop;
  final _readyTimeController = TextEditingController();
  final _totalItemsController = TextEditingController(text: '0');
  bool _isTotalPcsManual = false;

  List<Map<String, dynamic>> serverServices = [];
  bool isLoading = true;
  String? errorMessage;

  Key _autocompleteKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _totalItemsController.addListener(() {
      if (_totalItemsController.text.isNotEmpty &&
          _totalItemsController.selection.baseOffset != -1) {
        _isTotalPcsManual = true;
      }
    });
    _fetchServices();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        _readyTimeController.text = '$hour:$minute';
      });
    }
  }

  void _updateTotalItems() {
    double total = cart.fold(0.0, (sum, item) => sum + item.quantity);
    _totalItemsController.text = total.toStringAsFixed(
      total.truncateToDouble() == total ? 0 : 1,
    );
  }

  void _fillCustomerData(Customer customer) {
    setState(() {
      _customerSearchController.text = customer.name;
      _hotelNameController.text = customer.lastStay;
      _roomNumberController.text = customer.lastRoomNo;
      _phoneController.text = customer.phone;
      _selectedCountry = {
        'name': customer.country,
        'code': customer.countryCode,
        'flag': customer.countryFlag,
      };
      FocusScope.of(context).unfocus();
    });
  }

  void _showCountryPicker() {
    List<Map<String, String>> filteredCountries = List.from(countries);
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Country'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredCountries = countries.where((country) {
                            final name = country['name']!.toLowerCase();
                            final code = country['code']!.toLowerCase();
                            final query = value.toLowerCase();
                            return name.contains(query) || code.contains(query);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country = filteredCountries[index];
                          return ListTile(
                            leading: Text(
                              country['flag']!,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(country['name']!),
                            subtitle: Text(country['code']!),
                            onTap: () {
                              setState(() {
                                _selectedCountry = country;
                              });
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addItemToCart(Map<String, dynamic> service) {
    setState(() {
      for (var item in cart) {
        if (item.name == service['name']) {
          item.quantity++;
          item.qtyController.text = item.quantity.toStringAsFixed(0);
          if (!_isTotalPcsManual) _updateTotalItems();
          return;
        }
      }
      cart.add(CartItem(name: service['name'], price: service['price']));
      if (!_isTotalPcsManual) _updateTotalItems();
    });
  }

  void _increaseQuantity(CartItem item) {
    setState(() {
      item.quantity++;
      item.qtyController.text = item.quantity.toStringAsFixed(0);
      if (!_isTotalPcsManual) _updateTotalItems();
    });
  }

  void _decreaseQuantity(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
        item.qtyController.text = item.quantity.toStringAsFixed(0);
      } else {
        _removeItem(item);
      }
      if (!_isTotalPcsManual) _updateTotalItems();
    });
  }

  void _removeItem(CartItem item) {
    setState(() {
      item.qtyController.dispose();
      cart.remove(item);
      if (!_isTotalPcsManual) _updateTotalItems();
    });
  }

  void _resetCart() {
    setState(() {
      for (var item in cart) {
        item.qtyController.dispose();
      }
      cart.clear();
      _customerSearchController.clear();
      _hotelNameController.clear();
      _roomNumberController.clear();
      _phoneController.clear();
      _selectedCountry = null;
      _selectedTime = null;
      _readyTimeController.clear();
      _deliveryOption = DeliveryOption.drop;
      _isTotalPcsManual = false;
      _updateTotalItems();
      _autocompleteKey = UniqueKey();
    });
  }

  double _calculateGrandTotal() =>
      cart.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  Future<void> _fetchServices() async {
    final url = Uri.parse('http://10.0.2.2:3000/api/services');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          serverServices = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to load services. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching services: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFA726), Color(0xFFFF9800)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                // Tombol close (X)
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.brown,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Warning',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(1, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 64,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(2, 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String message, VoidCallback? onClose) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.green,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onClose != null) onClose();
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Sukses',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(1, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 64,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(2, 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (onClose != null) onClose();
                        },
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _processOrderWithPayment({
    required double discount,
    required PaymentMethod paymentMethod,
    required double amountPaid,
    required double change,
  }) async {
    final orderData = {
      'customer': {
        'name': _customerSearchController.text,
        'stay': _hotelNameController.text,
        'roomNo': _roomNumberController.text,
        'country': _selectedCountry?['name'] ?? '',
        'phone': '${_selectedCountry?['code'] ?? ''}${_phoneController.text}',
      },
      'items': cart
          .map(
            (item) => {
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
            },
          )
          .toList(),
      'grandTotal': _calculateGrandTotal(),
      'totalItems': _totalItemsController.text,
      'readyTime': _readyTimeController.text,
      'deliveryOption': _deliveryOption.name,
      'payment': {
        'discount': discount,
        'method': paymentMethod.name,
        'amountPaid': amountPaid,
        'change': change,
      },
    };

    final url = Uri.parse('http://10.0.2.2:3000/api/orders');
    final headers = {'Content-Type': 'application/json'};
    final body = json.encode(orderData);

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 201) {
        _showSuccessDialog('Order berhasil diproses!', _resetCart);
      } else {
        throw Exception(
          'Failed to process order. Server responded with ${response.statusCode}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
      );
    }
  }

  // --- DIALOG PEMBAYARAN (SUDAH DIPERBAIKI DENGAN SCROLL) ---
  void showPaymentDialog() {
    final TextEditingController _discountController = TextEditingController(
      text: '0',
    );
    final TextEditingController _amountPaidController = TextEditingController();
    PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
    double grandTotal = _calculateGrandTotal();
    double discount = 0;
    double amountPaid = 0;
    double change = 0;
    double totalAfterDiscount = grandTotal;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void calculateChange() {
              final discountText = _discountController.text.replaceAll('.', '');
              final amountPaidText = _amountPaidController.text.replaceAll(
                '.',
                '',
              );

              discount = double.tryParse(discountText) ?? 0;
              amountPaid = double.tryParse(amountPaidText) ?? 0;
              totalAfterDiscount = (grandTotal - discount).clamp(
                0,
                double.infinity,
              );
              change = (amountPaid - totalAfterDiscount).clamp(
                0,
                double.infinity,
              );
            }

            calculateChange();
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF01aaa3), Color(0xFF018b7d)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.payments,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Payment',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Grand Total (dicoret)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Grand Total (Rp)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rp ${currencyFormatter.format(grandTotal)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                                color: Colors.white70,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Discount
                      _buildModernPaymentInput(
                        'Discount',
                        _discountController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      // Total Setelah Diskon
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total After Discount (Rp)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Center(
                                child: Text(
                                  'Rp ${currencyFormatter.format(totalAfterDiscount)}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Payment Method
                      _buildModernPaymentDropdown(
                        'Payment Method',
                        _selectedPaymentMethod,
                        (val) {
                          setState(() {
                            _selectedPaymentMethod = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      // Amount Paid
                      _buildModernPaymentInput(
                        'Amount Paid',
                        _amountPaidController,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (amountPaid < totalAfterDiscount)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 6,
                          ),
                          child: Text(
                            'Jumlah pembayaran harus sama atau lebih besar dari total.',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      // Change
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Center(
                                child: Text(
                                  'Rp ${currencyFormatter.format(change)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Tombol
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                final discountText = _discountController.text
                                    .replaceAll('.', '');
                                final amountPaidText = _amountPaidController
                                    .text
                                    .replaceAll('.', '');

                                discount = double.tryParse(discountText) ?? 0;
                                amountPaid =
                                    double.tryParse(amountPaidText) ?? 0;

                                double currentTotalAfterDiscount =
                                    (grandTotal - discount).clamp(
                                      0,
                                      double.infinity,
                                    );

                                if (amountPaid < currentTotalAfterDiscount) {
                                  // Panggil setState untuk menampilkan pesan error
                                  setState(() {});
                                  return;
                                }

                                Navigator.of(context).pop();
                                _processOrderWithPayment(
                                  discount: discount,
                                  paymentMethod: _selectedPaymentMethod,
                                  amountPaid: amountPaid,
                                  change:
                                      (amountPaid - currentTotalAfterDiscount)
                                          .clamp(0, double.infinity),
                                );
                              },
                              child: const Text(
                                'Pay',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _validateAndShowPaymentDialog() {
    if (_customerSearchController.text.trim().isEmpty) {
      _showWarningDialog('Nama customer tidak boleh kosong.');
      return;
    }
    if (cart.isEmpty) {
      _showWarningDialog('Pesanan tidak boleh kosong.');
      return;
    }
    showPaymentDialog();
  }

  Widget _buildModernPaymentInput(
    String label,
    TextEditingController controller, {
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: controller,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Enter ${label.toLowerCase()}',
                hintStyle: const TextStyle(color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPaymentDropdown(
    String label,
    PaymentMethod selected,
    ValueChanged<PaymentMethod?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonFormField<PaymentMethod>(
              value: selected,
              items: PaymentMethod.values.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e.name[0].toUpperCase() + e.name.substring(1)),
                );
              }).toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              decoration: const InputDecoration(border: InputBorder.none),
              dropdownColor: Colors.teal[700],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SafeArea(
            child: Row(
              children: [
                Image.asset('assets/logo_sagoon.png', height: 40),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Invoice No.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      'INV-015411',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Autocomplete<Customer>(
                              key: _autocompleteKey,
                              displayStringForOption: (Customer option) =>
                                  option.name,
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<Customer>.empty();
                                    }
                                    return dummyCustomers.where((
                                      Customer customer,
                                    ) {
                                      final query = textEditingValue.text
                                          .toLowerCase();
                                      return customer.name
                                              .toLowerCase()
                                              .contains(query) ||
                                          customer.phone.contains(query);
                                    });
                                  },
                              onSelected: (Customer selection) {
                                _fillCustomerData(selection);
                              },
                              fieldViewBuilder:
                                  (
                                    BuildContext context,
                                    TextEditingController fieldController,
                                    FocusNode fieldFocusNode,
                                    VoidCallback onFieldSubmitted,
                                  ) {
                                    // Sinkronkan setiap perubahan ke _customerSearchController
                                    fieldController.addListener(() {
                                      if (_customerSearchController.text !=
                                          fieldController.text) {
                                        _customerSearchController.text =
                                            fieldController.text;
                                      }
                                    });
                                    return StyledTextField(
                                      label: '',
                                      hint: 'Search by Name or Phone',
                                      controller: fieldController,
                                      focusNode: fieldFocusNode,
                                    );
                                  },
                              optionsViewBuilder:
                                  (
                                    BuildContext context,
                                    AutocompleteOnSelected<Customer> onSelected,
                                    Iterable<Customer> options,
                                  ) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4.0,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 200,
                                            maxWidth: 350,
                                          ),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) {
                                                  final Customer option =
                                                      options.elementAt(index);
                                                  return ListTile(
                                                    title: Text(option.name),
                                                    subtitle: Text(
                                                      'Ph: ${option.countryCode}${option.phone}',
                                                    ),
                                                    onTap: () {
                                                      onSelected(option);
                                                    },
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StyledTextField(
                          label: 'Stay (Hotel)',
                          hint: 'Enter hotel name',
                          controller: _hotelNameController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StyledTextField(
                          label: 'Room No.',
                          hint: 'Room number',
                          isNumeric: true,
                          controller: _roomNumberController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Country',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _showCountryPicker,
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F9FA),
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _selectedCountry == null
                                          ? 'Select Country'
                                          : '${_selectedCountry!['flag']}  ${_selectedCountry!['name']}',
                                      style: TextStyle(
                                        color: _selectedCountry == null
                                            ? Colors.grey.shade500
                                            : Colors.black87,
                                        fontWeight: _selectedCountry == null
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StyledTextField(
                          label: 'Phone (WhatsApp)',
                          hint: '81805754658',
                          isNumeric: true,
                          controller: _phoneController,
                          prefixText: _selectedCountry?['code'],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Order Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: cart.isEmpty
                        ? const Center(
                            child: Text(
                              'Cart is empty',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : SingleChildScrollView(
                            child: DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: 50.0,
                              dataRowMaxHeight: 50.0,
                              columns: const [
                                DataColumn(label: Text('Product')),
                                DataColumn(label: Text('Price'), numeric: true),
                                DataColumn(label: Text('Qty')),
                                DataColumn(
                                  label: Text('Subtotal'),
                                  numeric: true,
                                ),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: cart.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item.name)),
                                    DataCell(
                                      Text(
                                        currencyFormatter.format(item.price),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _decreaseQuantity(item),
                                          ),
                                          SizedBox(
                                            width: 50,
                                            child: TextField(
                                              controller: item.qtyController,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  item.quantity =
                                                      double.tryParse(value) ??
                                                      item.quantity;
                                                });
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 20,
                                              color: Colors.green,
                                            ),
                                            onPressed: () =>
                                                _increaseQuantity(item),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        currencyFormatter.format(
                                          item.price * item.quantity,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_forever,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _removeItem(item),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01aaa3),
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF01aaa3), Color(0xFF018b7d)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Grand Total: Rp ${currencyFormatter.format(_calculateGrandTotal())}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          flex: 2,
                          child: _buildFooterField(
                            label: 'Total Pcs:',
                            icon: Icons.inventory_2_outlined,
                            controller: _totalItemsController,
                            enabled: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 2,
                          child: buildReadyTimeField(
                            controller: _readyTimeController,
                            onTap: () => _selectTime(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery Option:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Radio<DeliveryOption>(
                                    value: DeliveryOption.drop,
                                    groupValue: _deliveryOption,
                                    onChanged: (DeliveryOption? value) {
                                      setState(() {
                                        _deliveryOption = value!;
                                      });
                                    },
                                  ),
                                  const Icon(
                                    Icons.storefront_outlined,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('Drop'),
                                  const SizedBox(width: 12),
                                  Radio<DeliveryOption>(
                                    value: DeliveryOption.deliver,
                                    groupValue: _deliveryOption,
                                    onChanged: (DeliveryOption? value) {
                                      setState(() {
                                        _deliveryOption = value!;
                                      });
                                    },
                                  ),
                                  const Icon(
                                    Icons.local_shipping_outlined,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('Deliver'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _resetCart,
                        icon: const Icon(Icons.refresh),
                        label: const Text('RESET'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _validateAndShowPaymentDialog,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('PROCESS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Garis pemisah vertikal
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 24),
            color: Colors.grey.shade300,
          ),
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage != null
                          ? Center(child: Text('Error: $errorMessage'))
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.0,
                                  ),
                              itemCount: serverServices.length,
                              itemBuilder: (context, index) {
                                final service = serverServices[index];
                                return Card(
                                  elevation: 2,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: InkWell(
                                    onTap: () => _addItemToCart(service),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Text(
                                            service['name'],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Rp ${currencyFormatter.format(service['price'])}',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  _addItemToCart(service),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.teal,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                              child: FittedBox(
                                                child: Text(
                                                  'ADD FOR ${currencyFormatter.format(service['price'])}',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    VoidCallback? onTap,
    bool enabled = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTap,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.teal, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 100,
                          maxWidth: 140,
                        ),
                        child: TextField(
                          controller: controller,
                          enabled: enabled,
                          readOnly: onTap != null,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 16,
                            letterSpacing: 1,
                            fontFamily: 'RobotoMono',
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'HH:mm',
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 0,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          textAlignVertical: TextAlignVertical.center,
                        ),
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.access_time,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReadyTimeField({
    required TextEditingController controller,
    required VoidCallback onTap,
    bool enabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ready Time:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon timer
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
              child: const Icon(
                Icons.timer_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            // Field angka waktu
            Container(
              height: 48,
              width: 100, // Lebar cukup untuk "HH:mm"
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.teal, width: 1.5),
                  right: BorderSide(color: Colors.teal, width: 1.5),
                  bottom: BorderSide(color: Colors.teal, width: 1.5),
                ),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Center(
                  child: Text(
                    controller.text.isEmpty ? 'HH:mm' : controller.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 16,
                      fontFamily: 'RobotoMono', // opsional
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
