import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_printer/printer/cubit/printer_cubit.dart';
import 'package:pos_printer/printer/printer.dart';

class PrinterPage extends StatelessWidget {
  const PrinterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PrinterCubit(),
      child: const PrinterView(),
    );
  }
}

class PrinterView extends StatelessWidget {
  const PrinterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal Printer'),
      ),
      body: BlocBuilder<PrinterCubit, PrinterState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error message
                if (state.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Printer Selection Section
                _buildSection(
                  title: 'Printer Selection',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: state.isScanning
                            ? null
                            : () => context.read<PrinterCubit>().scanPrinters(),
                        icon: state.isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(state.isScanning
                            ? 'Scanning...'
                            : 'Scan for USB Printers'),
                      ),
                      const SizedBox(height: 16),
                      if (state.printers.isEmpty && !state.isScanning)
                        const Text(
                          'No printers found. Click "Scan for USB Printers" to discover printers.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      if (state.printers.isNotEmpty) ...[
                        const Text(
                          'Available Printers:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...state.printers.map((printer) {
                          final isSelected = state.selectedPrinter != null &&
                              state.selectedPrinter?.address == printer.address;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: ListTile(
                              title: Text(
                                printer.name ?? 'Unknown Printer',
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                printer.address ?? 'No address',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : null,
                              onTap: () => context
                                  .read<PrinterCubit>()
                                  .selectPrinter(printer),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: state.selectedPrinter == null ||
                                        state.isConnected
                                    ? null
                                    : () => context
                                        .read<PrinterCubit>()
                                        .connect(),
                                child: const Text('Connect'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: state.isConnected
                                    ? () => context
                                        .read<PrinterCubit>()
                                        .disconnect()
                                    : null,
                                child: const Text('Disconnect'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              state.isConnected
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: state.isConnected ? Colors.green : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.isConnected
                                  ? 'Connected to ${state.selectedPrinter?.name}'
                                  : 'Not Connected',
                              style: TextStyle(color: state.isConnected ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      ]
                    ]
                  )
                ),

                const SizedBox(height: 24),

                // Image Selection Section
                _buildSection(
                  title: 'Image Selection',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.read<PrinterCubit>().selectImage(),
                        icon: const Icon(Icons.image),
                        label: const Text('Select Image from Gallery'),
                      ),
                      const SizedBox(height: 16),
                      if (state.selectedImagePath == null)
                        const Text(
                          'No image selected',
                          style: TextStyle(color: Colors.grey),
                        ),
                      if (state.selectedImagePath != null) ...[
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(state.selectedImagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Selected: ${state.selectedImagePath!.split('/').last}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Print Section
                _buildSection(
                  title: 'Print',
                  child: ElevatedButton.icon(
                    onPressed: state.isConnected &&
                            state.selectedImagePath != null &&
                            !state.isPrinting
                        ? () => context.read<PrinterCubit>().printImage()
                        : null,
                    icon: state.isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.print),
                    label: Text(state.isPrinting ? 'Printing...' : 'Print Image'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

