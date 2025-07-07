import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
import 'package:tic_tac_toe/game_screen.dart';

class VerifyOTPService {
  // Function to validate if the input is a valid mobile number
  bool isValidOTP(String mobile) {
    // Check if the input contains only digits (0-9) and is at least 6 digits long
    final regex = RegExp(r'^\d{5,15}$');
    return regex.hasMatch(mobile);
  }

  // Helper function to extract values
  String extractValue(String body, String key) {
    final startIndex = body.indexOf(key);
    if (startIndex != -1) {
      final substring = body.substring(startIndex);
      final endIndex = substring.indexOf('\n');
      if (endIndex != -1) {
        return substring.substring(key.length, endIndex).trim();
      }
      return substring.substring(key.length).trim();
    }
    return '';
  }

  Future<void> verifyOTP(context, otpController) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    final referenceNumber = sharedPreferences.getString("REFERENCE_NUMBER");
    String mobile = otpController.text.trim();

    if (mobile.isEmpty) {
      // Show a message if the mobile number is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your otp')),
      );
      return;
    }

    if (!isValidOTP(mobile)) {
      // Show error message if the mobile number is invalid
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid  OTP')),
      );
      return;
    }

    // Prepare the request data
    Map<String, String> data = {"referenceNo": referenceNumber!, "otp": mobile};
    //Loading Effect
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            backgroundColor: Colors.transparent,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SpinKitThreeInOut(
                    color: Colors.black,
                  ),
                ]),
          );
        });
    // Send HTTP POST request to the API
    try {
      final response = await http.post(
        Uri.parse('https://fluttbizitsolutions.com/api/verify_otp_atms.php'),
        body: data,
      );

      var body = response.body;
      final statusCode = extractValue(body, 'Status code').trim();
      final result = statusCode.replaceAll(":", "").trim();

      if (result == "S1000") {
        Navigator.push(context, MaterialPageRoute(builder: (_) {
          return  const GameScreen();
        }));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully Subscribed')),
        );

      } else {
        Navigator.pop(context);
        // print(response.body); // Error occurred
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid OTP')),
        );
      }
    } on SocketException {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network Issue')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  }
}
