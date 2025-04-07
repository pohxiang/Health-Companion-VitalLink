import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter/material.dart';
import 'package:vitallinkv2/screens/loginpage.dart';

class Intropage extends StatefulWidget {
  const Intropage({super.key});
  @override
  IntropageState createState() => IntropageState();
}

class IntropageState extends State<Intropage> {
  final PageController _controller = PageController();
  bool onLastPage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                onLastPage = (index == 2);
              });
            },
            children: const [
              FirstPage(),
              SecondPage(),
              ThirdPage(),
            ],
          ),
          Container(
            alignment: const Alignment(-0.85, -0.88),
            child: SmoothPageIndicator(
              controller: _controller,
              count: 3,
              effect: const ExpandingDotsEffect(
                dotHeight: 8,
                dotWidth: 8,
                dotColor: Colors.grey,
                activeDotColor: Colors.blue,
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: Visibility(
              visible: !onLastPage,
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(),
                    ),
                  );
                },
                child: Container(
                  child: const Text(
                    textAlign: TextAlign.right,
                    'Skip >',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.90),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: onLastPage
                  ? GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginPage()));
                      },
                      child: Container(
                        key: const ValueKey('rectangle'),
                        width: 400,
                        height: 65,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            'Get Started',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ),
        ],
      ),
    );
  }
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          Color.fromARGB(255, 72, 149, 239),
          Color.fromARGB(255, 234, 242, 255)
        ]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, // Aligns to the top
        crossAxisAlignment: CrossAxisAlignment.center, // Centers horizontally
        children: [
          SizedBox(height: 70), // Moves content down from the top
          Text(
            "Online Appointment System",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Satoshi",
              color: Colors.black,
              fontSize: 30,
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 250, // Adjust logo size
            child: Image.asset('assets/icon/Appointment.png'),
          ),
          SizedBox(height: 20),
          Text(
            "E-queue System",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Satoshi",
              color: Colors.black,
              fontSize: 25,
            ),
          ),
          SizedBox(height: 1),
          SizedBox(
            height: 250, // Adjust logo size
            child: Image.asset('assets/icon/Equeue.png'),
          ),
          SizedBox(height: 10),
          Text(
            "Book appointments anytime, track your queue status in real-time, and reduce waiting times.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Satoshi",
              color: Colors.black,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          Color.fromARGB(255, 72, 149, 239),
          Color.fromARGB(255, 234, 242, 255)
        ]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, // Aligns to the top
        crossAxisAlignment: CrossAxisAlignment.center, // Centers horizontally
        children: [
          SizedBox(height: 50), // Moves content down from the top
          SizedBox(
            height: 250, // Adjust logo size
            child: Image.asset('assets/icon/logo.png'),
          ),
          SizedBox(height: 1),
          Text(
            "Vital Link",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Satoshi",
              color: Colors.black,
              fontSize: 40,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Your health companion",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Satoshi",
              color: Colors.grey[700],
              fontSize: 20,
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 250, // Adjust logo size
            child: Image.asset('assets/icon/Scheduling.png'),
          ),
          SizedBox(height: 20),
          Text(
            "Manage appointments, track your medical history, and communicate with healthcare providers seamlessly.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Satoshi",
              color: Colors.grey[700],
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class ThirdPage extends StatelessWidget {
  const ThirdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 50),
              Text(
                "Additional Features",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Satoshi",
                  color: Colors.black,
                  fontSize: 30,
                ),
              ),
              SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Image.asset(
                      'assets/icon/Messaging.png',
                      height: 225,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 20, height: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Secure messaging with doctors',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Stay connected with doctors with our messaging features',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Image.asset(
                      'assets/icon/MedicalRecord.png',
                      height: 225,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 20, height: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Access to digital medical records.',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Easy access to your medical records for better health monitoring',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Image.asset(
                      'assets/icon/Delivery.png',
                      height: 225,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 20, height: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Prescription Delivery Service',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Order and receive prescription refills on your doorstep',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
