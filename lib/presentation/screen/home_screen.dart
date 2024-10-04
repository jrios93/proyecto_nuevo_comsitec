import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:new_pro_com/presentation/providers/theme_provider.dart';
import 'package:new_pro_com/presentation/providers/product_list_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

class MyCustomForm extends ConsumerStatefulWidget {
  const MyCustomForm({Key? key}) : super(key: key);

  @override
  MyCustomFormState createState() => MyCustomFormState();
}

class MyCustomFormState extends ConsumerState<MyCustomForm> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  final MobileScannerController _scannerController = MobileScannerController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ValueNotifier<List<String>> _generatedFiles =
      ValueNotifier<List<String>>([]);
  final ValueNotifier<bool> _isFlashOn = ValueNotifier<bool>(false);
  final ValueNotifier<String> _lastScannedCode = ValueNotifier<String>('');
  final ValueNotifier<String> _scanFeedback = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _loadGeneratedFiles();
    _quantityController.text = '1';
    _loadAudio();
    _codeController.addListener(_onCodeChanged);
    _quantityFocusNode.addListener(_onQuantityFocused);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _codeController.dispose();
    _quantityController.dispose();
    _codeFocusNode.dispose();
    _quantityFocusNode.dispose();
    _audioPlayer.dispose();
    _generatedFiles.dispose();
    _isFlashOn.dispose();
    _lastScannedCode.dispose();
    _scanFeedback.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    String code = _codeController.text;
    if (code.isEmpty) return;
    if (_isValidCode(code)) {
      _quantityFocusNode.requestFocus();
    } else {
      _showSnackBar(
          'Código inválido. Debe tener 12 dígitos y comenzar con 15-31');
    }
  }

  void _onQuantityFocused() {
    if (_quantityFocusNode.hasFocus) {
      _quantityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _quantityController.text.length,
      );
    }
  }

  Future<void> _loadAudio() async {
    await _audioPlayer.setSource(AssetSource('sounds/beep.mp3'));
  }

  Future<void> _playBeepSound() async {
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.resume();
  }

  Future<void> _loadGeneratedFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.txt'))
        .toList();
    _generatedFiles.value = files.map((file) => file.path).toList();
  }

  bool _isValidCode(String code) {
    if (code.length != 12) return false;
    int prefix = int.tryParse(code.substring(0, 2)) ?? 0;
    return prefix >= 15 && prefix <= 31;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeNotifierProvider);
    final productList = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario Comsitec'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(themeNotifierProvider.notifier).toggleDarkMode(),
            icon: Icon(appTheme.isDarkmode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            tooltip: 'Cambiar tema',
          ),
          IconButton(
            onPressed: () =>
                ref.read(themeNotifierProvider.notifier).nextThemeColor(),
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Cambiar color',
          ),
          IconButton(
            onPressed: _showDeleteAllConfirmation,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Eliminar todo',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputFields(),
            const SizedBox(height: 20),
            const Text(
              'Productos escaneados:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildProductList(productList),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _addProduct,
            child: const Icon(Icons.send),
            tooltip: 'Agregar producto',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _scanBarcode,
            child: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear código',
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAppBar(productList),
    );
  }

  Widget _buildInputFields() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _codeController,
            focusNode: _codeFocusNode,
            decoration: const InputDecoration(
              labelText: 'Código de producto',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: _quantityController,
            focusNode: _quantityFocusNode,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      ],
    );
  }

  Widget _buildProductList(List<Product> productList) {
    return ListView.builder(
      itemCount: productList.length,
      itemExtent: 72.0,
      itemBuilder: (context, index) {
        final product = productList[index];
        return ValueListenableBuilder<String>(
          valueListenable: _lastScannedCode,
          builder: (context, lastScannedCode, child) {
            final isLastScanned = product.code == lastScannedCode;
            return Dismissible(
              key: Key(product.code),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) {
                ref.read(productListProvider.notifier).removeProduct(index);
                _showSnackBar('Producto eliminado: ${product.code}');
              },
              child: Container(
                color: isLastScanned ? Colors.green.withOpacity(0.3) : null,
                child: ListTile(
                  title: Text(product.code),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (product.quantity > 1) {
                            ref
                                .read(productListProvider.notifier)
                                .updateQuantity(index, product.quantity - 1);
                          }
                        },
                        tooltip: 'Disminuir cantidad',
                      ),
                      Text(product.quantity.toString()),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          ref
                              .read(productListProvider.notifier)
                              .updateQuantity(index, product.quantity + 1);
                        },
                        tooltip: 'Aumentar cantidad',
                      ),
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

  Widget _buildBottomAppBar(List<Product> productList) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed:
                productList.isNotEmpty ? _showGeneratedFilesDialog : null,
            tooltip: 'Historial de archivos',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: productList.isNotEmpty
                ? () => _showGenerateTxtConfirmation(productList)
                : null,
            tooltip: 'Generar archivo TXT',
          ),
        ],
      ),
    );
  }

  void _addProduct() {
    if (_codeController.text.isEmpty) {
      _showSnackBar('El código no puede estar vacío');
    } else if (!_isValidCode(_codeController.text)) {
      _showSnackBar(
          'Código inválido. Debe tener 12 dígitos y comenzar con 15-31');
    } else {
      _processScannedCode(_codeController.text);
    }
  }

  void _processScannedCode(String code) {
    final productList = ref.read(productListProvider);
    final existingProductIndex =
        productList.indexWhere((product) => product.code == code);

    if (existingProductIndex != -1) {
      _showSnackBar('Código ya escaneado. Actualizando cantidad.');
      ref.read(productListProvider.notifier).updateQuantity(
            existingProductIndex,
            productList[existingProductIndex].quantity +
                int.parse(_quantityController.text),
          );
    } else {
      ref.read(productListProvider.notifier).addProduct(
            code,
            int.parse(_quantityController.text),
          );
    }

    _lastScannedCode.value = code;
    _codeController.clear();
    _quantityController.text = '1';
    _playBeepSound();
    _codeFocusNode.requestFocus();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteAllConfirmation() {
    if (ref.read(productListProvider).isEmpty) {
      _showSnackBar('La lista está vacía. No hay productos para eliminar.');
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Eliminar todo'),
            content: const Text(
                '¿Estás seguro de que quieres eliminar todos los productos escaneados?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Eliminar'),
                onPressed: () {
                  ref.read(productListProvider.notifier).clearProducts();
                  Navigator.of(context).pop();
                  _showSnackBar('Todos los productos han sido eliminados');
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _scanBarcode() {
    _scanFeedback.value = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: _isFlashOn,
                          builder: (context, isFlashOn, child) {
                            return IconButton(
                              icon: Icon(
                                  isFlashOn ? Icons.flash_on : Icons.flash_off),
                              onPressed: () {
                                _isFlashOn.value = !_isFlashOn.value;
                                _scannerController.toggleTorch();
                              },
                            );
                          },
                        ),
                        const Text('Escanear código de barras',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              final code = barcode.rawValue ?? '';
                              if (_isValidCode(code)) {
                                _playBeepSound();

                                // Actualiza el código y cierra el modal
                                setState(() {
                                  _codeController.text =
                                      code; // Actualiza el controlador aquí
                                });

                                // Solo cerrar el modal después de haber actualizado el código
                                Navigator.pop(context);
                                _quantityFocusNode.requestFocus();
                                break; // Sal del bucle después de procesar un código válido
                              } else {
                                _scanFeedback.value = 'Código inválido: $code';
                              }
                            }
                          },
                        ),
                        ScannerOverlay(),
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: ValueListenableBuilder<String>(
                            valueListenable: _scanFeedback,
                            builder: (context, feedback, child) {
                              if (feedback.isEmpty) return SizedBox.shrink();
                              return Container(
                                padding: EdgeInsets.all(8),
                                margin: EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  feedback,
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
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
    );
  }

  Future<void> _showGenerateTxtConfirmation(List<Product> products) async {
    final String txtContent = products
        .map((product) => '${product.code}, ${product.quantity}')
        .join('\n');
    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/productos_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.txt';
    final file = File(filePath);
    await file.writeAsString(txtContent);

    _showSnackBar('Archivo generado: $filePath');

    _generatedFiles.value = [..._generatedFiles.value, filePath];

    await Share.shareXFiles([XFile(filePath)],
        text: 'Aquí tienes la lista de productos escaneados.');
  }

  Future<void> _showGeneratedFilesDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archivos generados'),
          content: SizedBox(
            height: 300,
            width: 400,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _generatedFiles,
              builder: (context, files, child) {
                return ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(files[index]),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () async {
                              await Share.shareXFiles(
                                [XFile(files[index])],
                                text: 'Aquí tienes el archivo generado.',
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteGeneratedFile(index),
                          ),
                        ],
                      ),
                      onTap: () async {
                        await OpenFile.open(files[index]);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGeneratedFile(int index) async {
    if (index < 0 || index >= _generatedFiles.value.length) {
      _showSnackBar('Error: Índice de archivo inválido');
      return;
    }

    final file = File(_generatedFiles.value[index]);
    if (await file.exists()) {
      await file.delete();
    }

    _generatedFiles.value = List.from(_generatedFiles.value)..removeAt(index);

    _showSnackBar('Archivo eliminado');
    Navigator.of(context).pop();
    _loadGeneratedFiles(); // Recargar la lista de archivos
  }
}

class ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.0),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }
}
