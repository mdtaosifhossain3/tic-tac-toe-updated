import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:tic_tac_toe/game_screen.dart';

import '../otpView/otp_verify_view.dart';

class SendOTPService {
  // Function to validate if the input is a valid mobile number
  bool _isValidMobile(String mobile) {
    // Check if the input contains only digits (0-9) and is at least 11 digits long
    final regex = RegExp(r'^\d{11,15}$');
    return regex.hasMatch(mobile);
  }

  // Helper function to extract values
  String _extractValue(String body, String key) {
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

  Future<void> sendOTP(context, controller) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    String mobile = controller.text.trim();
    if (mobile.isEmpty) {
      // Show a message if the mobile number is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a mobile number')),
      );
      return;
    }

    if (!_isValidMobile(mobile)) {
      // Show error message if the mobile number is invalid
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Invalid mobile number. Please enter a valid number')),
      );
      return;
    }
    // Prepare the request data
    Map<String, String> data = {
      'user_mobile': mobile,
    };
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
        Uri.parse('https://fluttbizitsolutions.com/api/request_otp_atms.php'),
        body: data,
      );

      var body = response.body;

      final statusCode = _extractValue(body, 'Status code').trim();
      final result = statusCode.replaceAll(":", "").trim();
      Navigator.pop(context);
      if (result == "S1000") {
        final ref = _extractValue(body, 'Reference number');
        final refResult = ref.replaceAll(":", "").trim();
        sharedPreferences.setString("REFERENCE_NUMBER", refResult);

        //OTP Verification Page
        Navigator.push(context, MaterialPageRoute(builder: (_) {
          return OtpVerificationView();
        }));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent successfully')),
        );
      } else if (result == "E1351") {
        //OTP Verification Page
        Navigator.push(context, MaterialPageRoute(builder: (_) {
          return const GameScreen();
        }));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome Back!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please Enter a valid Robi/Airtel Number')),
        );
      }
    } on SocketException {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network Issue')),
      );
    } catch (e) {
      Navigator.pop(context);
      // Handle error in case of network issues
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  }
}
