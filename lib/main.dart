import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components/product/product.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://lhytairgnojpzgbgjhod.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxoeXRhaXJnbm9qcHpnYmdqaG9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1MDI4MjYsImV4cCI6MjA1NzA3ODgyNn0.uDxpy6lcB4STumSknuDmrjwZDuSekcY4i1A07nHCQdM',
  );

  runApp(const ProductApp());
}
