import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/customer.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Products Collection
  CollectionReference get _productsCollection => _firestore.collection('products');

  // Invoices Collection
  CollectionReference get _invoicesCollection => _firestore.collection('invoices');

  // Customers Collection
  CollectionReference get _customersCollection => _firestore.collection('customers');

  // Product Methods
  Future<void> addProduct(Product product) async {
    await _productsCollection.add(product.toMap());
  }

  Future<void> updateProduct(String id, Product product) async {
    await _productsCollection.doc(id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _productsCollection.doc(id).delete();
  }

  Stream<List<Product>> getProducts() {
    return _productsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<Product?> getProductById(String id) async {
    DocumentSnapshot doc = await _productsCollection.doc(id).get();
    if (doc.exists) {
      return Product.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Invoice Methods
  Future<void> addInvoice(Invoice invoice) async {
    await _invoicesCollection.add(invoice.toMap());
  }

  Future<void> updateInvoice(String id, Invoice invoice) async {
    await _invoicesCollection.doc(id).update(invoice.toMap());
  }

  Future<void> deleteInvoice(String id) async {
    await _invoicesCollection.doc(id).delete();
  }

  Stream<List<Invoice>> getInvoices() {
    return _invoicesCollection.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Invoice.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<Invoice?> getInvoiceById(String id) async {
    DocumentSnapshot doc = await _invoicesCollection.doc(id).get();
    if (doc.exists) {
      return Invoice.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Update product quantity after invoice
  Future<void> updateProductQuantity(String productId, int newQuantity) async {
    await _productsCollection.doc(productId).update({'quantity': newQuantity});
  }

  // Customer Methods
  Future<void> addCustomer(Customer customer) async {
    await _customersCollection.add(customer.toMap());
  }

  Future<void> updateCustomer(String id, Customer customer) async {
    await _customersCollection.doc(id).update(customer.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    await _customersCollection.doc(id).delete();
  }

  Stream<List<Customer>> getCustomers() {
    return _customersCollection.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<Customer?> getCustomerById(String id) async {
    DocumentSnapshot doc = await _customersCollection.doc(id).get();
    if (doc.exists) {
      return Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Update customer payment
  Future<void> updateCustomerPayment(String customerId, double newPaidAmount, double newRemainingAmount) async {
    await _customersCollection.doc(customerId).update({
      'paidAmount': newPaidAmount,
      'remainingAmount': newRemainingAmount,
    });
  }
}
