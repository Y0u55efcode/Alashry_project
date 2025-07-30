import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> with TickerProviderStateMixin {
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
        title: Text('البضائع'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'تسجيل جديد'),
            Tab(text: 'البضائع المسجلة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddProductTab(),
          _buildProductsListTab(),
        ],
      ),
    );
  }

  Widget _buildAddProductTab() {
    return AddProductForm(firebaseService: _firebaseService);
  }

  Widget _buildProductsListTab() {
    return Column(
      children: [
        // شريط البحث
        Container(
          padding: EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'البحث في البضائع',
              hintText: 'ابحث بالاسم أو النوع أو الملاحظات...',
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
        // قائمة البضائع
        Expanded(
          child: StreamBuilder<List<Product>>(
            stream: _firebaseService.getProducts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              List<Product> products = snapshot.data!;

              // فلترة البضائع بناءً على البحث
              List<Product> filteredProducts = products.where((product) {
                if (_searchQuery.isEmpty) return true;

                return product.name.toLowerCase().contains(_searchQuery) ||
                    product.type.toLowerCase().contains(_searchQuery) ||
                    product.notes.toLowerCase().contains(_searchQuery) ||
                    product.quantity.toString().contains(_searchQuery) ||
                    product.price.toString().contains(_searchQuery);
              }).toList();

              // ترتيب النتائج - البضائع التي تبدأ بنص البحث أولاً
              if (_searchQuery.isNotEmpty) {
                filteredProducts.sort((a, b) {
                  bool aStartsWithQuery = a.name.toLowerCase().startsWith(_searchQuery) ||
                      a.type.toLowerCase().startsWith(_searchQuery);
                  bool bStartsWithQuery = b.name.toLowerCase().startsWith(_searchQuery) ||
                      b.type.toLowerCase().startsWith(_searchQuery);

                  if (aStartsWithQuery && !bStartsWithQuery) return -1;
                  if (!aStartsWithQuery && bStartsWithQuery) return 1;
                  return a.name.compareTo(b.name);
                });
              }

              if (filteredProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'لا توجد بضائع مسجلة'
                            : 'لم يتم العثور على بضائع تطابق البحث',
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
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  Product product = filteredProducts[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    elevation: 2,
                    child: ExpansionTile(
                      title: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.black, fontSize: 16),
                          children: _highlightSearchText(
                            '${product.name} - ${product.type}',
                            _searchQuery,
                          ),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text('الكمية: ${product.quantity}'),
                              SizedBox(width: 16),
                              Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text('السعر: ${product.price.toStringAsFixed(2)} جنيه'),
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
                              if (product.notes.isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(color: Colors.black87),
                                          children: [
                                            TextSpan(
                                              text: 'الملاحظات: ',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            ..._highlightSearchText(product.notes, _searchQuery),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                  SizedBox(width: 8),
                                  Text(
                                    'تاريخ الإضافة: ${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showEditProductDialog(product),
                                    icon: Icon(Icons.edit, size: 18),
                                    label: Text('تعديل'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showDeleteConfirmation(product),
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

  void _showEditProductDialog(Product product) {
    final _nameController = TextEditingController(text: product.name);
    final _typeController = TextEditingController(text: product.type);
    final _quantityController = TextEditingController(text: product.quantity.toString());
    final _priceController = TextEditingController(text: product.price.toString());
    final _notesController = TextEditingController(text: product.notes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل البضاعة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الصنف',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _typeController,
                decoration: InputDecoration(
                  labelText: 'النوع',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'العدد',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'السعر',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
              Product updatedProduct = Product(
                id: product.id,
                name: _nameController.text,
                type: _typeController.text,
                quantity: int.tryParse(_quantityController.text) ?? product.quantity,
                price: double.tryParse(_priceController.text) ?? product.price,
                notes: _notesController.text,
                createdAt: product.createdAt,
              );
              await _firebaseService.updateProduct(product.id, updatedProduct);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم تحديث البضاعة بنجاح')),
              );
            },
            child: Text('حفظ'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذه البضاعة؟\n\n${product.name} - ${product.type}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firebaseService.deleteProduct(product.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم حذف البضاعة بنجاح')),
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

class AddProductForm extends StatefulWidget {
  final FirebaseService firebaseService;

  AddProductForm({required this.firebaseService});

  @override
  _AddProductFormState createState() => _AddProductFormState();
}

class _AddProductFormState extends State<AddProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  List<Product> _allProducts = [];
  List<String> _nameSuggestions = [];
  List<String> _typeSuggestions = [];
  bool _showNameSuggestions = false;
  bool _showTypeSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _nameController.addListener(_onNameChanged);
    _typeController.addListener(_onTypeChanged);
  }

  void _loadProducts() {
    widget.firebaseService.getProducts().listen((products) {
      setState(() {
        _allProducts = products;
      });
    });
  }

  void _onNameChanged() {
    String query = _nameController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _showNameSuggestions = false;
        _nameSuggestions = [];
      });
      return;
    }

    Set<String> suggestions = {};
    for (Product product in _allProducts) {
      if (product.name.toLowerCase().contains(query)) {
        suggestions.add(product.name);
      }
    }

    setState(() {
      _nameSuggestions = suggestions.take(5).toList();
      _showNameSuggestions = _nameSuggestions.isNotEmpty;
    });
  }

  void _onTypeChanged() {
    String query = _typeController.text.toLowerCase();
    String selectedName = _nameController.text;

    if (query.isEmpty) {
      setState(() {
        _showTypeSuggestions = false;
        _typeSuggestions = [];
      });
      return;
    }

    Set<String> suggestions = {};
    for (Product product in _allProducts) {
      if (product.name == selectedName && product.type.toLowerCase().contains(query)) {
        suggestions.add(product.type);
      }
    }

    setState(() {
      _typeSuggestions = suggestions.take(5).toList();
      _showTypeSuggestions = _typeSuggestions.isNotEmpty;
    });
  }

  void _selectNameSuggestion(String name) {
    _nameController.text = name;
    setState(() {
      _showNameSuggestions = false;
    });
    // Auto-fill price from existing product if available
    Product? existingProduct = _allProducts.firstWhere(
          (product) => product.name == name,
      orElse: () => Product(id: '', name: '', type: '', quantity: 0, price: 0, notes: '', createdAt: DateTime.now()),
    );
    if (existingProduct.id.isNotEmpty) {
      _priceController.text = existingProduct.price.toString();
    }
  }

  void _selectTypeSuggestion(String type) {
    _typeController.text = type;
    setState(() {
      _showTypeSuggestions = false;
    });
    // Auto-fill price from existing product
    String selectedName = _nameController.text;
    Product? existingProduct = _allProducts.firstWhere(
          (product) => product.name == selectedName && product.type == type,
      orElse: () => Product(id: '', name: '', type: '', quantity: 0, price: 0, notes: '', createdAt: DateTime.now()),
    );
    if (existingProduct.id.isNotEmpty) {
      _priceController.text = existingProduct.price.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // إخفاء لوحة المفاتيح عند النقر خارج الحقول
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Name field with suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم الصنف',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال اسم الصنف';
                      }
                      return null;
                    },
                  ),
                  if (_showNameSuggestions)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: _nameSuggestions.map((suggestion) {
                          return ListTile(
                            dense: true,
                            title: Text(suggestion),
                            onTap: () => _selectNameSuggestion(suggestion),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16),
              // Type field with suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _typeController,
                    decoration: InputDecoration(
                      labelText: 'النوع',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.category),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال النوع';
                      }
                      return null;
                    },
                  ),
                  if (_showTypeSuggestions)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: _typeSuggestions.map((suggestion) {
                          return ListTile(
                            dense: true,
                            title: Text(suggestion),
                            onTap: () => _selectTypeSuggestion(suggestion),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'العدد',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال العدد';
                  }
                  if (int.tryParse(value) == null) {
                    return 'يرجى إدخال رقم صحيح';
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
                  suffixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال السعر';
                  }
                  if (double.tryParse(value) == null) {
                    return 'يرجى إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addOrUpdateProduct,
                child: Text('إضافة البضاعة'),
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
  }

  void _addOrUpdateProduct() async {
    if (_formKey.currentState!.validate()) {
      String name = _nameController.text;
      String type = _typeController.text;
      int newQuantity = int.parse(_quantityController.text);
      double price = double.parse(_priceController.text);
      String notes = _notesController.text;

      // Check if product with same name and type already exists
      Product? existingProduct = _allProducts.firstWhere(
            (product) => product.name == name && product.type == type,
        orElse: () => Product(id: '', name: '', type: '', quantity: 0, price: 0, notes: '', createdAt: DateTime.now()),
      );

      if (existingProduct.id.isNotEmpty) {
        // Update existing product by adding quantity
        Product updatedProduct = Product(
          id: existingProduct.id,
          name: name,
          type: type,
          quantity: existingProduct.quantity + newQuantity,
          price: price, // Update price to new price
          notes: notes.isEmpty ? existingProduct.notes : notes,
          createdAt: existingProduct.createdAt,
        );

        await widget.firebaseService.updateProduct(existingProduct.id, updatedProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة ${newQuantity} قطعة إلى البضاعة الموجودة. الكمية الجديدة: ${updatedProduct.quantity}')),
        );
      } else {
        // Create new product
        Product product = Product(
          id: '',
          name: name,
          type: type,
          quantity: newQuantity,
          price: price,
          notes: notes,
          createdAt: DateTime.now(),
        );

        await widget.firebaseService.addProduct(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة البضاعة الجديدة بنجاح')),
        );
      }

      // Clear form
      _nameController.clear();
      _typeController.clear();
      _quantityController.clear();
      _priceController.clear();
      _notesController.clear();
    }
  }

  @override
  void dispose() {
    // إخفاء لوحة المفاتيح عند الخروج
    FocusScope.of(context).unfocus();
    _nameController.dispose();
    _typeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
