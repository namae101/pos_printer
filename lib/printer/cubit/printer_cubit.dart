import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class PrinterState {
  const PrinterState({
    this.printers = const [],
    this.selectedPrinter,
    this.isScanning = false,
    this.isConnected = false,
    this.selectedImagePath,
    this.isPrinting = false,
    this.error,
  });

  final List<Printer> printers;
  final Printer? selectedPrinter;
  final bool isScanning;
  final bool isConnected;
  final String? selectedImagePath;
  final bool isPrinting;
  final String? error;

  PrinterState copyWith({
    List<Printer>? printers,
    Printer? selectedPrinter,
    bool? isScanning,
    bool? isConnected,
    String? selectedImagePath,
    bool? isPrinting,
    String? error,
  }) {
    return PrinterState(
      printers: printers ?? this.printers,
      selectedPrinter: selectedPrinter ?? this.selectedPrinter,
      isScanning: isScanning ?? this.isScanning,
      isConnected: isConnected ?? this.isConnected,
      selectedImagePath: selectedImagePath ?? this.selectedImagePath,
      isPrinting: isPrinting ?? this.isPrinting,
      error: error,
    );
  }
}

class PrinterCubit extends Cubit<PrinterState> {
  PrinterCubit() : super(const PrinterState()) {
    _initialize();
  }

  final _flutterThermalPrinterPlugin = FlutterThermalPrinter.instance;
  final _imagePicker = ImagePicker();

  void _initialize() {
    _flutterThermalPrinterPlugin.devicesStream.listen((List<Printer> printers) {
      emit(state.copyWith(
        printers: printers,
        isScanning: false,
        error: null,
      ));
    });
  }

  Future<void> scanPrinters() async {
    try {
      emit(state.copyWith(isScanning: true, error: null));
      await _flutterThermalPrinterPlugin.getPrinters(
        connectionTypes: [ConnectionType.USB],
      );
    } catch (e) {
      emit(state.copyWith(
        isScanning: false,
        error: 'Failed to scan for printers: ${e.toString()}',
      ));
    }
  }

  void selectPrinter(Printer printer) {
    emit(state.copyWith(
      selectedPrinter: printer,
      error: null,
    ));
  }

  Future<void> connect() async {
    if (state.selectedPrinter == null) {
      emit(state.copyWith(error: 'No printer selected'));
      return;
    }

    try {
      emit(state.copyWith(error: null));
      final connected = await _flutterThermalPrinterPlugin.connect(
        state.selectedPrinter!,
      );
      emit(state.copyWith(
        isConnected: connected,
        error: connected ? null : 'Failed to connect to printer',
      ));
    } catch (e) {
      emit(state.copyWith(
        isConnected: false,
        error: 'Failed to connect: ${e.toString()}',
      ));
    }
  }

  Future<void> disconnect() async {
    if (state.selectedPrinter == null) {
      return;
    }

    try {
      await _flutterThermalPrinterPlugin.disconnect(state.selectedPrinter!);
      emit(state.copyWith(isConnected: false, error: null));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to disconnect: ${e.toString()}'));
    }
  }

  Future<void> selectImage() async {
    try {
      emit(state.copyWith(error: null));
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        emit(state.copyWith(
          selectedImagePath: image.path,
          error: null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Failed to select image: ${e.toString()}',
      ));
    }
  }

  Future<void> printImage() async {
    if (state.selectedImagePath == null) {
      emit(state.copyWith(error: 'No image selected'));
      return;
    }

    if (state.selectedPrinter == null) {
      emit(state.copyWith(error: 'No printer selected'));
      return;
    }

    if (!state.isConnected) {
      emit(state.copyWith(error: 'Printer not connected'));
      return;
    }

    try {
      emit(state.copyWith(isPrinting: true, error: null));

      // Read image file
      final imageFile = File(state.selectedImagePath!);
      final imageBytes = await imageFile.readAsBytes();

      // Decode image
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Convert to grayscale
      var processedImage = img.grayscale(decodedImage);
      // Ensure width is 576 dot resolution of the printer
      const imageWidth = 576;
      if (processedImage.width != imageWidth) {
        processedImage = img.copyResize(
          processedImage,
          width: imageWidth,
        );
      }
      // Generate printer commands
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final raster = generator.imageRaster(processedImage);
      final cutCommand = generator.cut();

      // Print the image
      await _flutterThermalPrinterPlugin.printData(
        state.selectedPrinter!,
        [...raster, ...cutCommand],
        longData: true,
      );

      emit(state.copyWith(isPrinting: false, error: null));
    } catch (e) {
      emit(state.copyWith(
        isPrinting: false,
        error: 'Failed to print image: ${e.toString()}',
      ));
    }
  }

  @override
  Future<void> close() {
    if (state.isConnected && state.selectedPrinter != null) {
      disconnect();
    }
    return super.close();
  }
}

