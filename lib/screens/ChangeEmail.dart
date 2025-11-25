import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../sevices/ThameProvider.dart';

class ChangeEmailScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();

  ChangeEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.blue,
        elevation: 0,
        title: Text(
          'Change Email',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.blueAccent : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ZoomIn(
              duration: Duration(milliseconds: 800),
              child: TextField(
                controller: _emailController,
                style: TextStyle(color: isDarkMode ? Colors.blueAccent : Colors.black),
                decoration: InputDecoration(
                  labelText: 'New Email Address',
                  labelStyle: TextStyle(color: isDarkMode ? Colors.blueAccent : Colors.blue),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: isDarkMode ? Colors.blueAccent : Colors.blue),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.email, color: isDarkMode ? Colors.blueAccent : Colors.blue),
                ),
              ),
            ),
            SizedBox(height: 20),
            FadeInUp(
              duration: Duration(milliseconds: 800),
              child: ElevatedButton(
                onPressed: () {
                  if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid email address')),
                    );
                    return;
                  }

                  // Add email change logic here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Email changed successfully')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.blueAccent : Colors.blue[700],
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Change Email',
                  style: TextStyle(fontSize: 18, color: isDarkMode ? Colors.black : Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
