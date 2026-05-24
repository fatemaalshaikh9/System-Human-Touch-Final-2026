import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:humantouch/pages/Communication_page.dart';
import 'package:humantouch/pages/CompanionDashboard_page.dart';
import 'package:humantouch/pages/Dashboard_page.dart';
import 'package:humantouch/pages/Emergency_page.dart';
import 'package:humantouch/pages/ForgetPassword_page.dart';
import 'package:humantouch/pages/Health_page.dart';
import 'package:humantouch/pages/Login_page.dart';
import 'package:humantouch/pages/Map_page.dart';
import 'package:humantouch/pages/Profile2_page.dart';
import 'package:humantouch/pages/Profile_page.dart';
import 'package:humantouch/pages/RemindersCompanion_page.dart';
import 'package:humantouch/pages/Reminders_page.dart';
import 'package:humantouch/pages/Settings_page.dart';
import 'package:humantouch/pages/SignUpCompanion_page.dart';
import 'package:humantouch/pages/SignUpPatient_page.dart';
import 'package:humantouch/pages/SignUpVolunteer_page.dart';
import 'package:humantouch/pages/SignUp_page.dart';
import 'package:humantouch/pages/Splash_page.dart';
import 'package:humantouch/pages/VolunteerDashboard_page.dart';
import 'package:humantouch/pages/VolunteerHelp_page.dart';
import 'package:humantouch/pages/Welcome_page.dart';
import 'package:humantouch/pages/location_picker_page.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:humantouch/pages/services/last_page_store.dart';
import 'package:humantouch/pages/services/fcm_service.dart';
import 'package:humantouch/pages/app_settings_store.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AppSettingsStore.instance.loadSettings();

  await initializeDateFormatting('en', null);
  await initializeDateFormatting('ar', null);

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await notificationsPlugin.initialize(initSettings);

  await FCMService.init(navigatorKey);

  runApp(const HumanTouchApp());
}

class HumanTouchApp extends StatelessWidget {
  const HumanTouchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettingsStore.instance,
      builder: (context, _) {
        final settings = AppSettingsStore.instance;

        return MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [
            LastPageObserver(),
          ],
          debugShowCheckedModeBanner: false,
          title: 'Human Touch',
          locale: settings.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F4F4),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF87CEEB),
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF87CEEB),
              elevation: 0,
              centerTitle: true,
              foregroundColor: Colors.black,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF4F4F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF87CEEB),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF87CEEB),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 3,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFE0E0E0),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF87CEEB),
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF87CEEB),
              elevation: 0,
              centerTitle: true,
              foregroundColor: Colors.black,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              hintStyle: const TextStyle(
                color: Color(0xFF57636C),
              ),
              labelStyle: const TextStyle(
                color: Color(0xFF57636C),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF87CEEB),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF87CEEB),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 3,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(
                color: Color(0xFF14181B),
              ),
              bodyMedium: TextStyle(
                color: Color(0xFF14181B),
              ),
              titleLarge: TextStyle(
                color: Color(0xFF14181B),
              ),
            ),
            iconTheme: const IconThemeData(
              color: Color(0xFF14181B),
            ),
            dividerColor: const Color(0xFFD0D0D0),
          ),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(
                  settings.textScale,
                ),
              ),
              child: Directionality(
                textDirection:
                    settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashPage(),
            '/welcome': (context) => const WelcomePage(),
            '/login': (context) => const LoginPage(),
            '/signup': (context) => const SignUpPage(),
            '/signupVolunteer': (context) => const SignUpVolunteerPage(),
            '/signupCompanion': (context) => const SignUpCompanionPage(),
            '/signupPatient': (context) => const SignUpPatientPage(),
            '/forgetPassword': (context) => const ForgetPasswordPage(),
            '/dashboard': (context) => const DashboardPage(),
            '/companionDashboard': (context) => const CompanionDashboardPage(),
            '/volunteerDashboard': (context) => const VolunteerDashboardPage(),
            '/reminders': (context) => const RemindersPage(),
            '/companionReminders': (context) => const CompanionRemindersPage(),
            '/health': (context) => const HealthPage(),
            '/communication': (context) => const CommunicationPage(),
            '/emergency': (context) => const EmergencyPage(),
            '/map': (context) => const MapPage(),
            '/volunteerHelp': (context) => const VolunteerHelpPage(),
            '/profile': (context) => const ProfilePage(),
            '/profile2': (context) => const Profile2Page(),
            '/settings': (context) => const SettingsPage(),
            '/locationPicker': (context) => const LocationPickerPage(),
          },
          onUnknownRoute: (routeSettings) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(
                  child: Text(
                    'Page not found',
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
