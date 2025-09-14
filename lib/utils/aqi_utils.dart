import 'package:flutter/material.dart';

String aqiCategory(int? aqi) {
  if (aqi == null) return "No Data";
  if (aqi <= 50) return "Good";
  if (aqi <= 100) return "Moderate";
  if (aqi <= 150) return "Unhealthy for Sensitive Groups";
  if (aqi <= 200) return "Unhealthy";
  if (aqi <= 300) return "Very Unhealthy";
  return "Hazardous";
}

Color aqiColor(int? aqi, Brightness b) {
  if (aqi == null) {
    return b == Brightness.dark ? Colors.grey[400]! : Colors.grey[700]!;
  }
  if (aqi <= 50) return const Color(0xFF4CAF50);
  if (aqi <= 100) return const Color(0xFFFFC107);
  if (aqi <= 150) return const Color(0xFFFF9800);
  if (aqi <= 200) return const Color(0xFFF44336);
  if (aqi <= 300) return const Color(0xFF9C27B0);
  return const Color(0xFF7E0023);
}

/// Tips based on AQI level (in order shown on the card)
List<String> aqiHealthTips(int? aqi) {
  final c = aqiCategory(aqi);
  switch (c) {
    case "Good":
      return [
        "Air quality is good for outdoor activities",
        "Perfect time for exercise and recreation",
        "Enjoy fresh air responsibly",
      ];
    case "Moderate":
      return [
        "Most people can enjoy outdoor activities",
        "Sensitive groups should limit prolonged exertion",
        "Close windows if you feel irritation",
      ];
    case "Unhealthy for Sensitive Groups":
      return [
        "Sensitive groups: reduce prolonged outdoor activities",
        "Consider wearing a mask outdoors",
        "Use air purifiers indoors if available",
      ];
    case "Unhealthy":
      return [
        "Everyone should reduce outdoor exertion",
        "Wear N95 masks when going outside",
        "Keep windows closed; use air purifiers",
      ];
    case "Very Unhealthy":
      return [
        "Health alert: avoid outdoor activity",
        "Stay indoors; use air filtration",
        "Follow local health advisories",
      ];
    case "Hazardous":
      return [
        "Emergency conditions: stay indoors",
        "Avoid any outdoor exposure",
        "Seek medical advice if symptoms occur",
      ];
    default:
      return [
        "Avoid outdoor activities",
        "Keep windows closed",
        "Use air purifiers indoors",
      ];
  }
}
