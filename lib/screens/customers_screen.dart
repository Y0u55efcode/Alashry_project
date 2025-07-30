import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/customer.dart';

class CustomersScreen extends StatefulWidget {
  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();

  // متغيرات البحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('العملاء'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'عميل جديد'),
            Tab(text: 'العملاء القدامى'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewCustomerTab(),
          _buildOldCustomersTab(),
        ],
      ),
    );
  }

  Widget _buildNewCustomerTab() {
    return NewCustomerForm(firebaseService: _firebaseService);
  }

  Widget _buildOldCustomersTab() {
    return Column(
      children: [
        // شريط البحث
        Container(
          padding: EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'البحث في العملاء',
              hintText: 'ابحث بالاسم أو المبلغ أو التاريخ أو الهاتف أو الملاحظات...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),
        // قائمة العملاء
        Expanded(
          child: StreamBuilder<List<Customer>>(
            stream: _firebaseService.getCustomers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('حدث خطأ في تحميل البيانات'),
                      Text('${snapshot.error}'),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              List<Customer> customers = snapshot.data!;

              // فلترة العملاء بناءً على البحث
              List<Customer> filteredCustomers = customers.where((customer) {
                if (_searchQuery.isEmpty) return true;

                return customer.name.toLowerCase().contains(_searchQuery) ||
                    customer.phoneNumber.toLowerCase().contains(_searchQuery) || // Search by phone number
                    customer.notes.toLowerCase().contains(_searchQuery) ||       // Search by notes
                    customer.invoiceAmount.toString().contains(_searchQuery) ||
                    customer.paidAmount.toString().contains(_searchQuery) ||
                    customer.remainingAmount.toString().contains(_searchQuery) ||
                    DateFormat('dd/MM/yyyy').format(customer.date).contains(_searchQuery);
              }).toList();

              // ترتيب النتائج
              if (_searchQuery.isNotEmpty) {
                filteredCustomers.sort((a, b) {
                  bool aStartsWithQuery = a.name.toLowerCase().startsWith(_searchQuery);
                  bool bStartsWithQuery = b.name.toLowerCase().startsWith(_searchQuery);

                  if (aStartsWithQuery && !bStartsWithQuery) return -1;
                  if (!aStartsWithQuery && bStartsWithQuery) return 1;
                  return b.createdAt.compareTo(a.createdAt);
                });
              }

              if (filteredCustomers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'لا يوجد عملاء مسجلين'
                            : 'لم يتم العثور على عملاء يطابقون البحث',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          'جرب البحث بكلمات أخرى',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredCustomers.length,
                itemBuilder: (context, index) {
                  Customer customer = filteredCustomers[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    elevation: 2,
                    child: ExpansionTile(
                      title: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                          children: _highlightSearchText(customer.name, _searchQuery),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(color: Colors.grey[700]),
                                  children: _highlightSearchText(
                                    DateFormat('dd/MM/yyyy').format(customer.date),
                                    _searchQuery,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Icon(
                                customer.remainingAmount > 0 ? Icons.warning : Icons.check_circle,
                                size: 16,
                                color: customer.remainingAmount > 0 ? Colors.orange : Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                customer.remainingAmount > 0 ? 'متبقي' : 'مسدد',
                                style: TextStyle(
                                  color: customer.remainingAmount > 0 ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('اسم العميل: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(color: Colors.black),
                                        children: _highlightSearchText(customer.name, _searchQuery),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.phone, size: 18, color: Colors.blue), // Phone icon
                                  SizedBox(width: 8),
                                  Text('رقم الهاتف: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(color: Colors.black),
                                        children: _highlightSearchText(customer.phoneNumber, _searchQuery),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              if (customer.notes.isNotEmpty) // Display notes only if not empty
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.note, size: 18, color: Colors.blue), // Notes icon
                                    SizedBox(width: 8),
                                    Text('ملاحظات: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(color: Colors.black),
                                          children: _highlightSearchText(customer.notes, _searchQuery),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('التاريخ: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(color: Colors.black),
                                      children: _highlightSearchText(
                                        DateFormat('dd/MM/yyyy').format(customer.date),
                                        _searchQuery,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('مبلغ الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(color: Colors.black, fontSize: 16),
                                            children: _highlightSearchText(
                                              '${customer.invoiceAmount.toStringAsFixed(2)} جنيه',
                                              _searchQuery,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('المبلغ المدفوع:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                                            children: _highlightSearchText(
                                              '${customer.paidAmount.toStringAsFixed(2)} جنيه',
                                              _searchQuery,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('المبلغ المتبقي:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: customer.remainingAmount > 0 ? Colors.red : Colors.green,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            children: _highlightSearchText(
                                              '${customer.remainingAmount.toStringAsFixed(2)} جنيه',
                                              _searchQuery,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (customer.remainingAmount > 0)
                                    ElevatedButton.icon(
                                      onPressed: () => _showPaymentDialog(customer),
                                      icon: Icon(Icons.payment, size: 18),
                                      label: Text('دفع مبلغ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showEditCustomerDialog(customer),
                                    icon: Icon(Icons.edit, size: 18),
                                    label: Text('تعديل'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showDeleteConfirmation(customer),
                                    icon: Icon(Icons.delete, size: 18),
                                    label: Text('حذف'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // دالة لتمييز النص المطابق للبحث
  List<TextSpan> _highlightSearchText(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    List<TextSpan> spans = [];
    String lowerText = text.toLowerCase();
    String lowerQuery = query.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      // إضافة النص قبل المطابقة
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // إضافة النص المطابق مع التمييز
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: Colors.yellow[300],
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // إضافة باقي النص
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  void _showPaymentDialog(Customer customer) {
    final _paymentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('دفع مبلغ للعميل ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المبلغ المتبقي: ${customer.remainingAmount.toStringAsFixed(2)} جنيه',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            SizedBox(height: 16),
            TextFormField(
              controller: _paymentController,
              decoration: InputDecoration(
                labelText: 'المبلغ المراد دفعه',
                border: OutlineInputBorder(),
                suffixText: 'جنيه',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              double? paymentAmount = double.tryParse(_paymentController.text);
              if (paymentAmount != null && paymentAmount > 0 && paymentAmount <= customer.remainingAmount) {
                double newPaidAmount = customer.paidAmount + paymentAmount;
                double newRemainingAmount = customer.remainingAmount - paymentAmount;

                await _firebaseService.updateCustomerPayment(
                  customer.id,
                  newPaidAmount,
                  newRemainingAmount,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم تسجيل الدفعة بنجاح')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('يرجى إدخال مبلغ صحيح لا يتجاوز المبلغ المتبقي'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('تأكيد الدفع'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(Customer customer) {
    final _nameController = TextEditingController(text: customer.name);
    final _phoneNumberController = TextEditingController(text: customer.phoneNumber); // Init with existing
    final _notesController = TextEditingController(text: customer.notes);             // Init with existing
    final _invoiceAmountController = TextEditingController(text: customer.invoiceAmount.toString());
    final _paidAmountController = TextEditingController(text: customer.paidAmount.toString());
    DateTime _selectedDate = customer.date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('تعديل بيانات العميل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم العميل',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _phoneNumberController, // Phone number field
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _notesController, // Notes field
                  decoration: InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Text('التاريخ: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                    Spacer(),
                    TextButton(
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      child: Text('تغيير'),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _invoiceAmountController,
                  decoration: InputDecoration(
                    labelText: 'مبلغ الفاتورة',
                    border: OutlineInputBorder(),
                    suffixText: 'جنيه',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _paidAmountController,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    border: OutlineInputBorder(),
                    suffixText: 'جنيه',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                double? invoiceAmount = double.tryParse(_invoiceAmountController.text);
                double? paidAmount = double.tryParse(_paidAmountController.text);

                if (invoiceAmount != null && paidAmount != null &&
                    invoiceAmount > 0 && paidAmount >= 0 && paidAmount <= invoiceAmount) {

                  Customer updatedCustomer = customer.copyWith(
                    name: _nameController.text,
                    phoneNumber: _phoneNumberController.text, // Save phone number
                    notes: _notesController.text,             // Save notes
                    date: _selectedDate,
                    invoiceAmount: invoiceAmount,
                    paidAmount: paidAmount,
                    remainingAmount: invoiceAmount - paidAmount,
                  );

                  await _firebaseService.updateCustomer(customer.id, updatedCustomer);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تحديث بيانات العميل بنجاح')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('يرجى إدخال بيانات صحيحة'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('حفظ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف العميل "${customer.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firebaseService.deleteCustomer(customer.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم حذف العميل بنجاح')),
              );
            },
            child: Text('حذف'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class NewCustomerForm extends StatefulWidget {
  final FirebaseService firebaseService;

  NewCustomerForm({required this.firebaseService});

  @override
  _NewCustomerFormState createState() => _NewCustomerFormState();
}

class _NewCustomerFormState extends State<NewCustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneNumberController = TextEditingController(); // New controller
  final _notesController = TextEditingController();       // New controller
  final _invoiceAmountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  double _remainingAmount = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _invoiceAmountController.addListener(_calculateRemaining);
    _paidAmountController.addListener(_calculateRemaining);
  }

  void _calculateRemaining() {
    double invoiceAmount = double.tryParse(_invoiceAmountController.text) ?? 0.0;
    double paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
    setState(() {
      _remainingAmount = invoiceAmount - paidAmount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إضافة عميل جديد',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'اسم العميل',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال اسم العميل';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _phoneNumberController, // Phone number field
              decoration: InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _notesController, // Notes field
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('التاريخ: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: Text('تغيير التاريخ'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _invoiceAmountController,
              decoration: InputDecoration(
                labelText: 'مبلغ الفاتورة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt),
                suffixText: 'جنيه',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال مبلغ الفاتورة';
                }
                double? amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'يرجى إدخال مبلغ صحيح';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _paidAmountController,
              decoration: InputDecoration(
                labelText: 'الدفعة المقدمة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
                suffixText: 'جنيه',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال الدفعة المقدمة';
                }
                double? paidAmount = double.tryParse(value);
                double? invoiceAmount = double.tryParse(_invoiceAmountController.text);
                if (paidAmount == null || paidAmount < 0) {
                  return 'يرجى إدخال مبلغ صحيح';
                }
                if (invoiceAmount != null && paidAmount > invoiceAmount) {
                  return 'الدفعة المقدمة لا يمكن أن تتجاوز مبلغ الفاتورة';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _remainingAmount > 0 ? Colors.orange[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _remainingAmount > 0 ? Colors.orange : Colors.green,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('مبلغ الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${double.tryParse(_invoiceAmountController.text)?.toStringAsFixed(2) ?? '0.00'} جنيه'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الدفعة المقدمة:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${double.tryParse(_paidAmountController.text)?.toStringAsFixed(2) ?? '0.00'} جنيه',
                          style: TextStyle(color: Colors.green)),
                    ],
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المبلغ المتبقي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${_remainingAmount.toStringAsFixed(2)} جنيه',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _remainingAmount > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveCustomer,
              child: _isLoading
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('جاري الحفظ...', style: TextStyle(fontSize: 18)),
                ],
              )
                  : Text('حفظ العميل', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCustomer() async {
    print('تم الضغط على زر حفظ العميل'); // Debug print

    if (!_formKey.currentState!.validate()) {
      print('فشل في التحقق من صحة البيانات'); // Debug print
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('بدء عملية الحفظ...'); // Debug print

      double invoiceAmount = double.parse(_invoiceAmountController.text);
      double paidAmount = double.parse(_paidAmountController.text);
      double remainingAmount = invoiceAmount - paidAmount;

      print('البيانات: الاسم=${_nameController.text}, الهاتف=${_phoneNumberController.text}, الملاحظات=${_notesController.text}, مبلغ الفاتورة=$invoiceAmount, المدفوع=$paidAmount, المتبقي=$remainingAmount'); // Debug print

      Customer customer = Customer(
        id: '',
        name: _nameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(), // Save phone number
        notes: _notesController.text.trim(),             // Save notes
        date: _selectedDate,
        invoiceAmount: invoiceAmount,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        createdAt: DateTime.now(),
      );

      print('تم إنشاء كائن العميل، بدء الحفظ في Firebase...'); // Debug print

      await widget.firebaseService.addCustomer(customer);

      print('تم حفظ العميل بنجاح في Firebase'); // Debug print

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ العميل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _nameController.clear();
        _phoneNumberController.clear(); // Clear new field
        _notesController.clear();       // Clear new field
        _invoiceAmountController.clear();
        _paidAmountController.clear();
        setState(() {
          _selectedDate = DateTime.now();
          _remainingAmount = 0.0;
        });
      }
    } catch (e, stackTrace) {
      print('خطأ في حفظ العميل: $e'); // Debug print
      print('Stack trace: $stackTrace'); // Debug print

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حفظ العميل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose(); // Dispose new controller
    _notesController.dispose();       // Dispose new controller
    _invoiceAmountController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }
}
