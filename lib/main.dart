import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 

void main() async {

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(360, 690), // <-- base size (match your design)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'sstm app',
          theme: ThemeData(
            textSelectionTheme: TextSelectionThemeData(
            selectionHandleColor: Color.fromARGB(255, 42, 62, 173), // Handle color
            cursorColor: Color.fromARGB(255, 42, 62, 173), // Cursor color  
            selectionColor: Colors.blue[100],   
          ),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => LoginScreen(),
          },
        );
      },
    );
  }
}
