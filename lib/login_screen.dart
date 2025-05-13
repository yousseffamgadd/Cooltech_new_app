import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:sstmapp/token.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _errorMessage = ''; // For error message display
  // final FirebaseAuth _auth = FirebaseAuth.instance;  // Firebase instance

  Future<void> _login() async {
  final String email = emailController.text.trim();
  final String password = passwordController.text.trim();

  final url = Uri.parse("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSyCGsTYuq9WHJKQJptXUQKW4v1yPViAunCM");

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "returnSecureToken": true,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Login successful, navigate to the next screen
      setState(() {
        _errorMessage = '';
      });
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TokenQrScreen(),
      ));
    } else {
      // Handle error
      setState(() {
        _errorMessage = responseData['error']['message'] ?? 'Login failed. Please try again.';
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'An error occurred. Please try again.';
    });
  }
}


  @override
  Widget build(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;

  return Scaffold(
    body: Stack(
      children: [
        /// Background
        Positioned.fill(
          child: Opacity(
            opacity: 1,
            child: Image.asset(
              'images/background.png',
              fit: BoxFit.cover,
            ),
          ),
        ),

        /// Foreground login form
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 30.w),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.75,
                                          minHeight: screenHeight * 0.6,),
                                        
              child: Container(
                padding: EdgeInsets.all(22.r),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.87),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10.r,
                      color: Colors.black12,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Opacity(
                        opacity: 1,
                        child: Image.asset(
                          'images/logo.png',
                          height: screenHeight * 0.15,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 42, 62, 173),
                      ),
                    ),
                    SizedBox(height: 18.h),

                    /// Email field
                    TextField(
                      controller: emailController,
                      style: TextStyle(fontSize: 18.sp),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                                        padding: EdgeInsets.only(left: 12.w, right: 8.w), // scale spacing
                                        child: Icon(Icons.email,color: Colors.grey, size: 22.sp),
                                      ),
                        labelText: 'Email address',
                        labelStyle: TextStyle(fontSize: 13.sp , color:  Color.fromARGB(255, 42, 62, 173)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(25.r)),
                        ),
                        focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25.r)),
                        borderSide: BorderSide(color:Color.fromARGB(255, 42, 62, 173)),
                      ),
                      ),
                    ),
                    SizedBox(height: 15.h),

                    /// Password field
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: 18.sp),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                                        padding: EdgeInsets.only(left: 12.w, right: 8.w), // scale spacing
                                        child: Icon(Icons.lock, color: Colors.grey, size: 22.sp),
                                      ),
                        labelText: 'Password',
                        labelStyle: TextStyle(fontSize: 13.sp , color:const Color.fromARGB(255, 42, 62, 173)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(25.r)),
                        ),
                        focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25.r)),
                        borderSide: BorderSide(color:Color.fromARGB(255, 42, 62, 173)),),
                        suffixIcon: Padding(
                        padding: EdgeInsets.only(right: 5.w),
                        
                        child: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                            size: 22.sp, // scaled size
                          ),
                        
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    ),
                    SizedBox(height: 10.h),

                    /// Error message
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 6.h),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red, fontSize: 14.sp),
                        ),
                      ),

                    SizedBox(height: 15.h), // replaces Spacer

                   /// Login button
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 42, 62, 173),
                          padding: EdgeInsets.symmetric(vertical: 9.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.r),
                          ),
                        ),
                        child: Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}
