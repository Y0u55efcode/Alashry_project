import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';
import '../models/product.dart';
import '../models/invoice.dart';

class InvoicesScreen extends StatefulWidget {
  @override
  _InvoicesScreenState createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();
  final PdfService _pdfService = PdfService();

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
        title: Text('الفواتير'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'فاتورة جديدة'),
            Tab(text: 'الفواتير القديمة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewInvoiceTab(),
          _buildOldInvoicesTab(),
        ],
      ),
    );
  }

  Widget _buildNewInvoiceTab() {
    return NewInvoiceForm(
      firebaseService: _firebaseService,
      pdfService: _pdfService,
    );
  }

  Widget _buildOldInvoicesTab() {
    return Column(
      children: [
        // شريط البحث
        Container(
          padding: EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'البحث في الفواتير',
              hintText: 'ابحث بالعميل أو التاريخ أو البضائع أو المبلغ...',
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
        // قائمة الفواتير
        Expanded(
          child: StreamBuilder<List<Invoice>>(
            stream: _firebaseService.getInvoices(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              List<Invoice> invoices = snapshot.data!;

              // فلترة الفواتير بناءً على البحث
              List<Invoice> filteredInvoices = invoices.where((invoice) {
                if (_searchQuery.isEmpty) return true;

                // البحث في اسم العميل
                if (invoice.customerName.toLowerCase().contains(_searchQuery)) {
                  return true;
                }

                // البحث في التاريخ
                String dateString = DateFormat('dd/MM/yyyy').format(invoice.date);
                if (dateString.contains(_searchQuery)) {
                  return true;
                }

                // البحث في المبلغ الإجمالي
                if (invoice.totalAmount.toString().contains(_searchQuery)) {
                  return true;
                }

                // البحث في أسماء البضائع
                for (var item in invoice.items) {
                  if (item.productName.toLowerCase().contains(_searchQuery) ||
                      item.productType.toLowerCase().contains(_searchQuery) ||
                      item.quantity.toString().contains(_searchQuery) ||
                      item.price.toString().contains(_searchQuery)) {
                    return true;
                  }
                }

                return false;
              }).toList();

              // ترتيب النتائج - الفواتير التي تبدأ بنص البحث أولاً
              if (_searchQuery.isNotEmpty) {
                filteredInvoices.sort((a, b) {
                  bool aStartsWithQuery = a.customerName.toLowerCase().startsWith(_searchQuery);
                  bool bStartsWithQuery = b.customerName.toLowerCase().startsWith(_searchQuery);

                  if (aStartsWithQuery && !bStartsWithQuery) return -1;
                  if (!aStartsWithQuery && bStartsWithQuery) return 1;

                  // ترتيب حسب التاريخ (الأحدث أولاً)
                  return b.date.compareTo(a.date);
                });
              } else {
                // ترتيب حسب التاريخ (الأحدث أولاً) عند عدم وجود بحث
                filteredInvoices.sort((a, b) => b.date.compareTo(a.date));
              }

              if (filteredInvoices.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.receipt_long_outlined : Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'لا توجد فواتير مسجلة'
                            : 'لم يتم العثور على فواتير تطابق البحث',
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
                itemCount: filteredInvoices.length,
                itemBuilder: (context, index) {
                  Invoice invoice = filteredInvoices[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    elevation: 2,
                    child: ExpansionTile(
                      title: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: 'فاتورة '),
                            ..._highlightSearchText(invoice.customerName, _searchQuery),
                          ],
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
                                    DateFormat('dd/MM/yyyy').format(invoice.date),
                                    _searchQuery,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(color: Colors.grey[700]),
                                  children: _highlightSearchText(
                                    '${invoice.totalAmount.toStringAsFixed(2)} جنيه',
                                    _searchQuery,
                                  ),
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
                                  Text('العميل: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(color: Colors.black),
                                        children: _highlightSearchText(invoice.customerName, _searchQuery),
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
                                        DateFormat('dd/MM/yyyy').format(invoice.date),
                                        _searchQuery,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.inventory, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('البضائع:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              SizedBox(height: 8),
                              ...invoice.items.map((item) => Padding(
                                padding: EdgeInsets.only(left: 26.0, bottom: 4.0),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: Colors.black87),
                                    children: _highlightSearchText(
                                      '• ${item.productName} (${item.productType}) - الكمية: ${item.quantity} - السعر: ${item.price.toStringAsFixed(2)} - الإجمالي: ${item.total.toStringAsFixed(2)}',
                                      _searchQuery,
                                    ),
                                  ),
                                ),
                              )),
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calculate, size: 18, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('الإجمالي الكلي: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: Colors.blue[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        children: _highlightSearchText(
                                          '${invoice.totalAmount.toStringAsFixed(2)} جنيه',
                                          _searchQuery,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _pdfService.generateInvoicePdf(invoice),
                                    icon: Icon(Icons.print, size: 18),
                                    label: Text('طباعة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showEditInvoicePage(invoice),
                                    icon: Icon(Icons.edit, size: 18),
                                    label: Text('تعديل'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showDeleteInvoiceConfirmation(invoice),
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

  void _showEditInvoicePage(Invoice invoice) {
    print('Attempting to show EditInvoicePage for invoice ID: ${invoice.id}');
    print('Invoice details: Customer: ${invoice.customerName}, Date: ${invoice.date}, Items count: ${invoice.items.length}');
    for (var item in invoice.items) {
      print('  Item: ${item.productName}, Qty: ${item.quantity}, Price: ${item.price}, ProductId: ${item.productId}');
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to take full height if needed
      builder: (context) {
        print('Building EditInvoicePage for invoice ID: ${invoice.id}');
        return EditInvoicePage( // Changed to EditInvoicePage
          invoice: invoice,
          firebaseService: _firebaseService,
        );
      },
    );
  }

  void _showDeleteInvoiceConfirmation(Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذه الفاتورة؟\n\nالعميل: ${invoice.customerName}\nالتاريخ: ${DateFormat('dd/MM/yyyy').format(invoice.date)}\nالمبلغ: ${invoice.totalAmount.toStringAsFixed(2)} جنيه'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Revert product quantities when deleting invoice
              for (var item in invoice.items) {
                Product? product = await _firebaseService.getProductById(item.productId);
                if (product != null) {
                  await _firebaseService.updateProductQuantity(
                      product.id, product.quantity + item.quantity);
                }
              }
              await _firebaseService.deleteInvoice(invoice.id);
              Navigator.pop(context);
              // Check if mounted before showing SnackBar
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم حذف الفاتورة بنجاح واستعادة المخزون')),
                );
              }
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

class NewInvoiceForm extends StatefulWidget {
  final FirebaseService firebaseService;
  final PdfService pdfService;

  NewInvoiceForm({required this.firebaseService, required this.pdfService});

  @override
  _NewInvoiceFormState createState() => _NewInvoiceFormState();
}

class _NewInvoiceFormState extends State<NewInvoiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<InvoiceItem> _invoiceItems = [];
  double _totalAmount = 0.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _customerNameController,
              decoration: InputDecoration(
                labelText: 'اسم العميل',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال اسم العميل';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            Row(
              children: [
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
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showAddItemDialog,
              child: Text('إضافة بضاعة للفاتورة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Column(
                children: [
                  if (_invoiceItems.isNotEmpty) ...[
                    Text('البضائع المضافة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _invoiceItems.length,
                        itemBuilder: (context, index) {
                          InvoiceItem item = _invoiceItems[index];
                          return Card(
                            child: ListTile(
                              title: Text('${item.productName} - ${item.productType}'),
                              subtitle: Text('الكمية: ${item.quantity} - السعر: ${item.price.toStringAsFixed(2)} - الإجمالي: ${item.total.toStringAsFixed(2)}'),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _invoiceItems.removeAt(index);
                                    _calculateTotal();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Text('الإجمالي الكلي: ${_totalAmount.toStringAsFixed(2)} جنيه',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _invoiceItems.isNotEmpty ? _saveInvoice : null,
                      child: Text('حفظ وطباعة الفاتورة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Center(
                        child: Text('لم يتم إضافة أي بضائع بعد',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        firebaseService: widget.firebaseService,
        onItemAdded: (item) {
          setState(() {
            _invoiceItems.add(item);
            _calculateTotal();
          });
        },
      ),
    );
  }

  void _calculateTotal() {
    _totalAmount = _invoiceItems.fold(0.0, (sum, item) => sum + item.total);
  }

  void _saveInvoice() async {
    if (_formKey.currentState!.validate() && _invoiceItems.isNotEmpty) {
      Invoice invoice = Invoice(
        id: '',
        customerName: _customerNameController.text,
        date: _selectedDate,
        items: _invoiceItems,
        totalAmount: _totalAmount,
      );

      // Save to Firebase
      await widget.firebaseService.addInvoice(invoice);

      // Update product quantities
      for (InvoiceItem item in _invoiceItems) {
        Product? product = await widget.firebaseService.getProductById(item.productId);
        if (product != null) {
          await widget.firebaseService.updateProductQuantity(
              product.id, product.quantity - item.quantity);
        }
      }

      // Generate PDF
      await widget.pdfService.generateInvoicePdf(invoice);

      // Check if mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الفاتورة وطباعتها بنجاح')),
        );
      }

      // Clear form
      _customerNameController.clear();
      setState(() {
        _invoiceItems.clear();
        _totalAmount = 0.0;
        _selectedDate = DateTime.now();
      });
    }
  }
}

class AddItemDialog extends StatefulWidget {
  final FirebaseService firebaseService;
  final Function(InvoiceItem) onItemAdded;

  AddItemDialog({required this.firebaseService, required this.onItemAdded});

  @override
  _AddItemDialogState createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _productNameController = TextEditingController();
  List<Product> _availableProducts = [];
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      // Get products once instead of using stream for autocomplete
      final products = await widget.firebaseService.getProducts().first;
      setState(() {
        _availableProducts = products.where((product) => product.quantity > 0).toList();
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingProducts = false;
      });
      print('Error loading products: $e');
    }
  }

  List<Product> _filterProducts(String query) {
    if (query.isEmpty) {
      return _availableProducts;
    }
    return _availableProducts.where((product) {
      return product.name.toLowerCase().contains(query.toLowerCase()) ||
          product.type.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إضافة بضاعة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingProducts)
              CircularProgressIndicator()
            else if (_availableProducts.isEmpty)
              Text('لا توجد بضائع متاحة في المخزون')
            else
              Column(
                children: [
                  // Autocomplete widget for product selection
                  Autocomplete<Product>(
                    displayStringForOption: (Product product) =>
                    '${product.name} - ${product.type}',
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      return _filterProducts(textEditingValue.text);
                    },
                    onSelected: (Product selectedProduct) {
                      setState(() {
                        _selectedProduct = selectedProduct;
                        _productNameController.text = '${selectedProduct.name} - ${selectedProduct.type}';
                      });
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                      // Use our own controller to maintain state
                      if (_productNameController.text.isNotEmpty &&
                          textEditingController.text != _productNameController.text) {
                        textEditingController.text = _productNameController.text;
                      }

                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'اكتب اسم البضاعة',
                          hintText: 'ابدأ بكتابة اسم البضاعة...',
                          border: OutlineInputBorder(),
                          suffixIcon: _selectedProduct != null
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          // Clear selection if user modifies the text
                          if (_selectedProduct != null &&
                              value != '${_selectedProduct!.name} - ${_selectedProduct!.type}') {
                            setState(() {
                              _selectedProduct = null;
                            });
                          }
                        },
                        validator: (value) {
                          if (_selectedProduct == null) {
                            return 'يرجى اختيار بضاعة من القائمة';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (BuildContext context,
                        AutocompleteOnSelected<Product> onSelected,
                        Iterable<Product> options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 200,
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Product product = options.elementAt(index);
                                return ListTile(
                                  title: Text('${product.name} - ${product.type}'),
                                  subtitle: Text('متوفر: ${product.quantity} - السعر: ${product.price.toStringAsFixed(2)} جنيه'),
                                  onTap: () {
                                    onSelected(product);
                                  },
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'الكمية',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال الكمية';
                      }
                      int? quantity = int.tryParse(value);
                      if (quantity == null || quantity <= 0) {
                        return 'يرجى إدخال كمية صحيحة';
                      }
                      if (_selectedProduct != null && quantity > _selectedProduct!.quantity) {
                        return 'الكمية تتجاوز المتوفر (${_selectedProduct!.quantity})';
                      }
                      return null;
                    },
                  ),
                  if (_selectedProduct != null) ...[
                    SizedBox(height: 16),
                    _buildProductDetails(),
                  ],
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء'),
        ),
        TextButton(
          onPressed: _addItem,
          child: Text('إضافة'),
        ),
      ],
    );
  }

  Widget _buildProductDetails() {
    if (_selectedProduct == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تفاصيل البضاعة:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('الاسم: ${_selectedProduct!.name}'),
          Text('النوع: ${_selectedProduct!.type}'),
          Text('السعر: ${_selectedProduct!.price.toStringAsFixed(2)} جنيه'),
          Text('المتوفر: ${_selectedProduct!.quantity} قطعة'),
        ],
      ),
    );
  }

  void _addItem() {
    if (_selectedProduct == null) {
      _showError('يرجى اختيار بضاعة');
      return;
    }

    if (_quantityController.text.isEmpty) {
      _showError('يرجى إدخال الكمية');
      return;
    }

    int? quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showError('يرجى إدخال كمية صحيحة');
      return;
    }

    if (quantity > _selectedProduct!.quantity) {
      _showError('الكمية تتجاوز المتوفر (${_selectedProduct!.quantity})');
      return;
    }

    InvoiceItem item = InvoiceItem(
      productId: _selectedProduct!.id,
      productName: _selectedProduct!.name,
      productType: _selectedProduct!.type,
      quantity: quantity,
      price: _selectedProduct!.price,
      total: quantity * _selectedProduct!.price,
    );

    widget.onItemAdded(item);
    Navigator.pop(context);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _productNameController.dispose();
    super.dispose();
  }
}

// New EditInvoicePage widget
class EditInvoicePage extends StatefulWidget {
  final Invoice invoice;
  final FirebaseService firebaseService;

  EditInvoicePage({required this.invoice, required this.firebaseService});

  @override
  _EditInvoicePageState createState() => _EditInvoicePageState();
}

class _EditInvoicePageState extends State<EditInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late DateTime _selectedDate;
  late List<InvoiceItem> _invoiceItems;
  late double _totalAmount;
  bool _hasInitError = false;
  String _initErrorMessage = '';

  @override
  void initState() {
    super.initState();
    try {
      print('EditInvoicePage initState: Starting initialization for invoice ID: ${widget.invoice.id}');
      _customerNameController = TextEditingController(text: widget.invoice.customerName);
      _selectedDate = widget.invoice.date;
      // Deep copy the list of invoice items to allow independent modification
      _invoiceItems = widget.invoice.items.map((item) => InvoiceItem(
        productId: item.productId,
        productName: item.productName,
        productType: item.productType,
        quantity: item.quantity,
        price: item.price,
        total: item.total,
      )).toList();
      _calculateTotal();
      print('EditInvoicePage initState: Initialization finished successfully.');
    } catch (e, stack) {
      print('EditInvoicePage initState: Error during initialization: $e');
      print('EditInvoicePage initState: Stack trace: $stack');
      setState(() {
        _hasInitError = true;
        _initErrorMessage = 'حدث خطأ أثناء تهيئة بيانات الفاتورة: $e';
      });
    }
  }

  void _calculateTotal() {
    _totalAmount = _invoiceItems.fold(0.0, (sum, item) => sum + item.total);
    print('EditInvoicePage: Total amount calculated: $_totalAmount');
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        firebaseService: widget.firebaseService,
        onItemAdded: (item) {
          setState(() {
            _invoiceItems.add(item);
            _calculateTotal();
          });
        },
      ),
    );
  }

  void _showEditItemDialog(InvoiceItem itemToEdit, int index) {
    showDialog(
      context: context,
      builder: (context) => EditInvoiceItemDialog(
        initialItem: itemToEdit,
        firebaseService: widget.firebaseService,
        onItemEdited: (updatedItem) {
          setState(() {
            _invoiceItems[index] = updatedItem;
            _calculateTotal();
          });
        },
        onItemDeleted: () {
          setState(() {
            _invoiceItems.removeAt(index);
            _calculateTotal();
          });
        },
      ),
    );
  }

  Future<void> _saveChanges() async {
    // Add this check and SnackBar for validation failure
    if (!_formKey.currentState!.validate()) {
      print('EditInvoicePage: Form validation failed.');
      // Check if mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى ملء جميع الحقول المطلوبة بشكل صحيح.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Also check if there are any items in the invoice
    if (_invoiceItems.isEmpty) {
      print('EditInvoicePage: No items in invoice. Validation failed.');
      // Check if mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن حفظ فاتورة فارغة. يرجى إضافة بضائع.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      print('EditInvoicePage: Saving changes for invoice ID: ${widget.invoice.id}');
      // Get the current state of the invoice from Firebase to compare
      Invoice? currentInvoiceInDb = await widget.firebaseService.getInvoiceById(widget.invoice.id);
      if (currentInvoiceInDb == null) {
        // Check if mounted before showing SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: الفاتورة الأصلية غير موجودة في قاعدة البيانات.')),
          );
        }
        // Ensure pop happens after SnackBar if mounted
        if (mounted) Navigator.pop(context); // Close the dialog
        return;
      }

      print('EditInvoicePage: Original invoice fetched from DB. Items count: ${currentInvoiceInDb.items.length}');
      Map<String, int> oldQuantities = {};
      for (var item in currentInvoiceInDb.items) {
        oldQuantities[item.productId] = item.quantity;
        print('  Old item: ProductId: ${item.productId}, Quantity: ${item.quantity}');
      }

      Map<String, int> newQuantities = {};
      for (var item in _invoiceItems) {
        newQuantities[item.productId] = item.quantity;
        print('  New item: ProductId: ${item.productId}, Quantity: ${item.quantity}');
      }

      print('EditInvoicePage: Old quantities map: $oldQuantities');
      print('EditInvoicePage: New quantities map: $newQuantities');

      // Calculate net changes for each product
      Set<String> allProductIds = oldQuantities.keys.toSet().union(newQuantities.keys.toSet());
      print('EditInvoicePage: All product IDs involved in change calculation: $allProductIds');

      for (String productId in allProductIds) {
        int oldQty = oldQuantities[productId] ?? 0;
        int newQty = newQuantities[productId] ?? 0;
        int quantityChange = oldQty - newQty; // Positive if quantity decreased (add to stock), negative if increased (remove from stock)
        print('  Processing Product ID: $productId. Old Qty in old invoice: $oldQty, New Qty in new invoice: $newQty, Calculated change for stock: $quantityChange');

        if (quantityChange != 0) {
          Product? product = await widget.firebaseService.getProductById(productId);
          if (product != null) {
            print('    Found product in DB: ${product.name} (ID: ${product.id}). Current stock in DB: ${product.quantity}');
            int updatedStock = product.quantity + quantityChange;
            print('    Attempting to update product ${product.name} (ID: ${product.id}) stock from ${product.quantity} to $updatedStock.');
            await widget.firebaseService.updateProductQuantity(
                product.id, updatedStock);
            print('    Product ${product.name} quantity updated successfully to $updatedStock.');
          } else {
            print('    EditInvoicePage: CRITICAL WARNING: Product with ID $productId not found in Firebase when attempting to update its quantity. This item might have been deleted from products collection. Skipping stock update for this product.');
            // Consider adding a SnackBar here if this is a critical error for the user
            // if (mounted) {
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     SnackBar(content: Text('تحذير: لم يتم العثور على بعض البضائع في المخزون لتحديث الكمية.'), backgroundColor: Colors.orange),
            //   );
            // }
          }
        } else {
          print('  Product ID: $productId has no quantity change (oldQty: $oldQty, newQty: $newQty). Skipping stock update.');
        }
      }

      print('EditInvoicePage: All product quantities adjustments attempted.');

      // Update the invoice in Firebase
      Invoice updatedInvoice = Invoice(
        id: widget.invoice.id,
        customerName: _customerNameController.text,
        date: _selectedDate,
        items: _invoiceItems,
        totalAmount: _totalAmount,
      );

      print('EditInvoicePage: Attempting to update invoice ${widget.invoice.id} in Firebase with new data.');
      await widget.firebaseService.updateInvoice(widget.invoice.id, updatedInvoice);
      print('EditInvoicePage: Invoice updated successfully in Firebase.');

      // Check if mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الفاتورة بنجاح')),
        );
      }

      // Ensure pop happens after SnackBar if mounted
      if (mounted) Navigator.pop(context); // Close the modal sheet
      print('EditInvoicePage: Changes saved successfully and page popped.');
    } catch (e, stack) {
      print('EditInvoicePage: Error during saving changes: $e');
      print('EditInvoicePage: Stack trace during save: $stack');
      // Check if mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حفظ التعديلات: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    print('EditInvoicePage: Disposed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('EditInvoicePage build method called. _hasInitError: $_hasInitError');
    if (_hasInitError) {
      return Scaffold(
        appBar: AppBar(
          title: Text('خطأ'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 60),
                SizedBox(height: 20),
                Text(
                  _initErrorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.red[700]),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close the modal sheet
                  },
                  child: Text('إغلاق'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      print('EditInvoicePage build: Customer Name: ${_customerNameController.text}');
      print('EditInvoicePage build: Selected Date: $_selectedDate');
      print('EditInvoicePage build: Invoice Items Count: ${_invoiceItems.length}');
      print('EditInvoicePage build: Total Amount: $_totalAmount');

      return Scaffold(
        appBar: AppBar(
          title: Text('تعديل الفاتورة'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveChanges,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _customerNameController,
                  decoration: InputDecoration(
                    labelText: 'اسم العميل',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال اسم العميل';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
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
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _showAddItemDialog,
                  child: Text('إضافة بضاعة للفاتورة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                SizedBox(height: 16),
                Text('البضائع المضافة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                if (_invoiceItems.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _invoiceItems.length,
                    itemBuilder: (context, index) {
                      InvoiceItem item = _invoiceItems[index];
                      return Card(
                        child: ListTile(
                          title: Text('${item.productName} - ${item.productType}'),
                          subtitle: Text('الكمية: ${item.quantity} - السعر: ${item.price.toStringAsFixed(2)} - الإجمالي: ${item.total.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue), // Changed to edit icon
                                onPressed: () {
                                  _showEditItemDialog(item, index); // Call edit dialog
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red), // Keep delete option
                                onPressed: () {
                                  setState(() {
                                    _invoiceItems.removeAt(index);
                                    _calculateTotal();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('لم يتم إضافة أي بضائع بعد',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ),
                  ),
                SizedBox(height: 16),
                Text('الإجمالي الكلي: ${_totalAmount.toStringAsFixed(2)} جنيه',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveChanges,
                  child: Text('حفظ التعديلات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e, stack) {
      print('EditInvoicePage build: Error during widget build: $e');
      print('EditInvoicePage build: Stack trace: $stack');
      return Scaffold(
        appBar: AppBar(
          title: Text('خطأ في العرض'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 60),
                SizedBox(height: 20),
                Text(
                  'حدث خطأ غير متوقع أثناء عرض صفحة التعديل: $e. يرجى التحقق من وحدة التحكم للمزيد من التفاصيل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.red[700]),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close the modal sheet
                  },
                  child: Text('إغلاق'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// New EditInvoiceItemDialog widget
class EditInvoiceItemDialog extends StatefulWidget {
  final InvoiceItem initialItem;
  final FirebaseService firebaseService;
  final Function(InvoiceItem) onItemEdited;
  final VoidCallback onItemDeleted; // Callback for explicit delete from dialog

  EditInvoiceItemDialog({
    required this.initialItem,
    required this.firebaseService,
    required this.onItemEdited,
    required this.onItemDeleted,
  });

  @override
  _EditInvoiceItemDialogState createState() => _EditInvoiceItemDialogState();
}

class _EditInvoiceItemDialogState extends State<EditInvoiceItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  Product? _currentProductStock; // To hold the actual stock from DB
  bool _isLoadingStock = true; // New state to manage loading

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.initialItem.quantity.toString());
    _priceController = TextEditingController(text: widget.initialItem.price.toStringAsFixed(2));
    _fetchProductStock();
  }

  Future<void> _fetchProductStock() async {
    setState(() {
      _isLoadingStock = true; // Start loading
    });
    try {
      print('EditInvoiceItemDialog: Attempting to fetch product stock for Product ID: ${widget.initialItem.productId}');
      // Add a check for empty productId
      if (widget.initialItem.productId.isEmpty) {
        print('EditInvoiceItemDialog: Product ID is empty. Cannot fetch stock details.');
        if (mounted) {
          setState(() {
            _isLoadingStock = false;
          });
          _showError('خطأ: معرف البضاعة (ID) فارغ. لا يمكن جلب تفاصيل المخزون.');
        }
        return;
      }

      Product? product = await widget.firebaseService.getProductById(widget.initialItem.productId);
      if (mounted) {
        setState(() {
          _currentProductStock = product;
          _isLoadingStock = false; // End loading
        });
        if (product == null) {
          print('EditInvoiceItemDialog: Product with ID ${widget.initialItem.productId} NOT FOUND in Firebase.');
          // Removed SnackBar here to avoid potential issues if dialog is popped quickly
          // _showError('تحذير: لم يتم العثور على البضاعة الأصلية في المخزون.');
        } else {
          print('EditInvoiceItemDialog: Fetched product stock: ${product.name}, Quantity: ${product.quantity} for Product ID: ${product.id}');
        }
      }
    } catch (e, stack) {
      print('EditInvoiceItemDialog: Error fetching product stock for ${widget.initialItem.productName} (ID: ${widget.initialItem.productId}): $e');
      print('EditInvoiceItemDialog: Stack trace: $stack');
      if (mounted) {
        setState(() {
          _isLoadingStock = false; // End loading even on error
        });
        _showError('فشل جلب تفاصيل المخزون: $e. يرجى التحقق من اتصالك بالإنترنت وقواعد Firebase.');
      }
    }
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      int newQuantity = int.parse(_quantityController.text);
      double newPrice = double.parse(_priceController.text);
      // Calculate total for the updated item
      double newTotal = newQuantity * newPrice;

      InvoiceItem updatedItem = InvoiceItem(
        productId: widget.initialItem.productId,
        productName: widget.initialItem.productName,
        productType: widget.initialItem.productType,
        quantity: newQuantity,
        price: newPrice,
        total: newTotal,
      );

      widget.onItemEdited(updatedItem);
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تعديل بضاعة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اسم البضاعة: ${widget.initialItem.productName}', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('النوع: ${widget.initialItem.productType}'),
              SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'الكمية',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الكمية';
                  }
                  int? quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'يرجى إدخال كمية صحيحة';
                  }
                  if (_isLoadingStock) {
                    return 'جاري التحقق من المخزون... يرجى الانتظار.';
                  }
                  if (_currentProductStock == null) {
                    return 'لا يمكن التحقق من المخزون. البضاعة غير موجودة.';
                  }
                  // Stock check: new quantity must be <= (current stock in DB + original quantity in this invoice item)
                  int availableForThisEdit = _currentProductStock!.quantity + widget.initialItem.quantity;
                  if (quantity > availableForThisEdit) {
                    return 'الكمية تتجاوز المتوفر (${_currentProductStock!.quantity} + ${widget.initialItem.quantity} = $availableForThisEdit)';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'السعر',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال السعر';
                  }
                  double? price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'يرجى إدخال سعر صحيح';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              if (_isLoadingStock)
                Center(child: CircularProgressIndicator())
              else if (_currentProductStock != null)
                Text('المتوفر في المخزون: ${_currentProductStock!.quantity} قطعة',
                  style: TextStyle(color: Colors.grey[700]),
                )
              else
                Text('لم يتم العثور على تفاصيل المخزون لهذه البضاعة.',
                  style: TextStyle(color: Colors.red[700]),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            widget.onItemDeleted(); // Call the delete callback
            Navigator.pop(context); // Close the dialog
          },
          child: Text('حذف البضاعة', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: _saveItem,
          child: Text('حفظ التعديلات'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
      ],
    );
  }
}
