import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset('lib/images/bg.jpg', fit: BoxFit.cover),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 60.0,
                              right: 30,
                              bottom: 30,
                              left: 30,
                            ),
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'lib/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.all(30),
                            child: Text(
                              "One Stop Solution For All Of Remembering Problems",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const Text(
                            "PS.It Barely Works hehe ",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const Text(
                            "Lost way too many stuff over the time lol",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          // const SizedBox(height: 50),
                          Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: ElevatedButton(
                              onPressed:
                                  () => Navigator.pushNamed(context, '/main'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4169E1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 4,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Lets goooo'),
                            ),
                          ),

                          const Spacer(),

                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              "Made with ❤️ by Geervan ",
                              style: TextStyle(
                                color: Color(0xFF1A1A40),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
