import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../models/product.dart';
import '../models/invoice.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الصفحة الرئيسية'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<Invoice>>(
                    stream: _firebaseService.getInvoices(),
                    builder: (context, snapshot) {
                      int invoiceCount = snapshot.hasData ? snapshot.data!.length : 0;
                      return _buildStatCard('عدد الفواتير', invoiceCount.toString(), Icons.receipt, Colors.green);
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<List<Product>>(
                    stream: _firebaseService.getProducts(),
                    builder: (context, snapshot) {
                      int productCount = snapshot.hasData ? snapshot.data!.length : 0;
                      return _buildStatCard('عدد البضائع', productCount.toString(), Icons.inventory, Colors.orange);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Low Stock Alert
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: _firebaseService.getProducts(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  List<Product> lowStockProducts = snapshot.data!
                      .where((product) => product.quantity <= 5)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'البضائع على وشك الانتهاء',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Expanded(
                        child: lowStockProducts.isEmpty
                            ? Center(
                          child: Text(
                            'جميع البضائع متوفرة بكميات كافية',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                            : ListView.builder(
                          itemCount: lowStockProducts.length,
                          itemBuilder: (context, index) {
                            Product product = lowStockProducts[index];
                            return Card(
                              color: product.quantity == 0 ? Colors.red[100] : Colors.orange[100],
                              child: ListTile(
                                leading: Icon(
                                  Icons.warning,
                                  color: product.quantity == 0 ? Colors.red : Colors.orange,
                                ),
                                title: Text('${product.name} - ${product.type}'),
                                subtitle: Text('الكمية المتبقية: ${product.quantity}'),
                                trailing: Text(
                                  product.quantity == 0 ? 'نفدت' : 'قليلة',
                                  style: TextStyle(
                                    color: product.quantity == 0 ? Colors.red : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
