import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'main.dart';

/// Result of a presensi selfie upload attempt.
class PresensiUploadResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const PresensiUploadResult.success(Map<String, dynamic> this.data)
    : success = true,
      errorMessage = null;

  const PresensiUploadResult.failure(String this.errorMessage)
    : success = false,
      data = null;
}

/// Shared upload logic used by both [SelfieCameraPage] and
/// `ResumePresensiPage`, so the two pages don't duplicate the same
/// multipart-request code.
class PresensiUploader {
  static Future<PresensiUploadResult> upload({
    required Uint8List imageBytes,
    required String siswaId,
    required String authToken,
  }) async {
    try {
      final uri = Uri.parse('$API_BASE_URL/presensi');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $authToken';
      request.headers['Accept'] = 'application/json';
      request.fields['siswaId'] = siswaId;

      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonResponse =
              json.decode(response.body) as Map<String, dynamic>;
          return PresensiUploadResult.success(jsonResponse);
        } catch (e) {
          return PresensiUploadResult.failure(
            'Response parsing error: ${e.toString()}\nResponse: ${response.body}',
          );
        }
      }

      String errorMessage = 'Status ${response.statusCode}: ';
      try {
        final errorJson = json.decode(response.body);
        errorMessage += errorJson['message']?.toString() ?? errorJson.toString();
      } catch (e) {
        errorMessage += response.body;
      }
      return PresensiUploadResult.failure(errorMessage);
    } catch (e) {
      return PresensiUploadResult.failure(
        'Error uploading image: ${e.toString()}',
      );
    }
  }
}

/// Format an ISO datetime string into Indonesian, converted to WIB (UTC+7).
String formatDateTimeIndonesian(String dateTimeString) {
  try {
    final dateTimeUtc = DateTime.parse(dateTimeString);
    final dateTimeIndonesia = dateTimeUtc.add(const Duration(hours: 7));

    const monthsIndonesian = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final day = dateTimeIndonesia.day;
    final month = monthsIndonesian[dateTimeIndonesia.month - 1];
    final year = dateTimeIndonesia.year;
    final hour = dateTimeIndonesia.hour.toString().padLeft(2, '0');
    final minute = dateTimeIndonesia.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour:$minute WIB';
  } catch (e) {
    return dateTimeString;
  }
}

/// Shared "Presensi Berhasil" dialog, used after a successful upload from
/// either the camera page or the resume-after-restart page.
Future<void> showPresensiSuccessDialog(
  BuildContext context,
  Map<String, dynamic> data, {
  required VoidCallback onClose,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      final waktu = formatDateTimeIndonesian(
        data['data']?['created_at'] ??
            data['data']?['updated_at'] ??
            data['waktu'] ??
            data['timestamp'] ??
            '-',
      );
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
            const SizedBox(width: 12),
            const Text('Presensi Berhasil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 70,
                    child: Text(
                      'Waktu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const Text(': '),
                  Expanded(
                    child: Text(
                      waktu,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              onClose();
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.deepPurple.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}
