/// 150.0 -> "150", 3.6 -> "3.6"
String fmtNum(double v) {
  if ((v - v.roundToDouble()).abs() < 0.05) {
    return v.round().toString();
  }
  return v.toStringAsFixed(1);
}