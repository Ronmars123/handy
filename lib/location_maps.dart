import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMaps {
  static Future<void> openGoogleMaps(double latitude, double longitude) async {
    final Uri googleMapUrl = Uri.parse('https://www.google.com/maps?q=$latitude,$longitude');
    if (await canLaunchUrl(googleMapUrl)) {
      await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open Google Maps');
    }
  }
}
