import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Product {
  final String code;
  int quantity;

  Product(this.code, this.quantity);

  Map<String, dynamic> toJson() => {
        'code': code,
        'quantity': quantity,
      };

  static Product fromJson(Map<String, dynamic> json) {
    return Product(json['code'], json['quantity']);
  }
}

class ProductListNotifier extends StateNotifier<List<Product>> {
  ProductListNotifier() : super([]) {
    _loadProducts(); // Cargar productos al iniciar
  }

  Future<void> _loadProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedProducts = prefs.getString('productList');
      if (savedProducts != null) {
        // Cambiar a List<dynamic> y asegurarse de que se convierte a Map<String, dynamic>
        List<dynamic> jsonList = jsonDecode(savedProducts);
        state = jsonList.map((json) {
          if (json is Map<String, dynamic>) {
            return Product.fromJson(json);
          } else {
            // Manejar el caso en que no es el formato esperado
            throw Exception('Formato inesperado para el producto: $json');
          }
        }).toList();
      }
    } catch (e) {
      print('Error al cargar productos: $e');
      state = []; // Reiniciar la lista si hay un error
    }
  }

  Future<void> addProduct(String code, int quantity) async {
    state = [...state, Product(code, quantity)];
    await _saveProducts(); // Guardar cada vez que se añade un producto
  }

  Future<void> updateQuantity(int index, int newQuantity) async {
    final updatedProduct = state[index];
    updatedProduct.quantity = newQuantity;
    state = [...state];
    await _saveProducts(); // Guardar cambios
  }

  Future<void> removeProduct(int index) async {
    state.removeAt(index);
    state = [...state];
    await _saveProducts(); // Guardar cambios
  }

  Future<void> clearProducts() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('productList'); // Limpiar almacenamiento
  }

  Future<void> _saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        state.map((product) => product.toJson()).toList();
    await prefs.setString('productList', jsonEncode(jsonList));
  }

  bool get isEmpty => state.isEmpty;
}

final productListProvider =
    StateNotifierProvider<ProductListNotifier, List<Product>>((ref) {
  return ProductListNotifier();
});
