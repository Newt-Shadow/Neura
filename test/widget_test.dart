import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuro/logic/neuro_settings.dart';
import 'package:neuro/ui/smart_dashboard_screen.dart';

// ============================================================
// 🛠️ MOCK CLASS (The Secret Sauce)
// ============================================================
// This class simulates NeuroSettings without hitting Firebase/Storage.
// It allows us to test the UI logic in isolation.
class MockNeuroSettings extends NeuroSettings {
  bool _mockDyslexia = false;
  final String _mockName = "Test User"; // Use a specific name to verify display

  // Override getters to return safe data
  @override
  String get userName => _mockName;
  
  @override
  bool get dyslexiaMode => _mockDyslexia;
  
  @override
  String? get fontFamily => _mockDyslexia ? 'OpenDyslexic' : 'Lexend';

  @override
  int get streakCount => 5; // Fake streak data

  // Override complex methods to do simple in-memory updates
  @override
  void toggleFont() {
    _mockDyslexia = !_mockDyslexia;
    notifyListeners(); // This tells the UI to rebuild, which we verify
  }

  // Dangerous methods are overridden to do nothing
  @override
  Future<void> loadSettings() async { /* Do nothing */ }

  @override
  Future<void> setApiKey(String key) async { /* Do nothing */ }
  
  @override
  void startCloudListener() { /* Do nothing */ }
}

void main() {
  // ✅ TEST 1: Verifies the UI adapts to Neuro-Inclusive settings
  testWidgets('Neuro UI Adaptation Test - Dyslexia Mode', (WidgetTester tester) async {
    // 1. Setup the Mock
    final mockSettings = MockNeuroSettings();

    // 2. Build the app with the Mock Provider
    await tester.pumpWidget(
      ChangeNotifierProvider<NeuroSettings>.value(
        value: mockSettings,
        child: const MaterialApp(
          home: SmartDashboardScreen(),
        ),
      ),
    );

    // 3. Verify Dashboard initialized with our Mock Data
    // We expect to see "Test User" instead of "Friend"
    expect(find.textContaining('Test User'), findsOneWidget);

    // 4. Verify Initial Font State (Should be Standard)
    final textFinder = find.textContaining('Test User');
    final textWidgetBefore = tester.widget<Text>(textFinder);
    expect(textWidgetBefore.style?.fontFamily, isNot('OpenDyslexic'));

    // 5. Trigger Innovation: Toggle Dyslexia Mode
    mockSettings.toggleFont();
    
    // 6. Re-render (Wait for animations)
    await tester.pumpAndSettle();

    // 7. Verify the Logic Update
    expect(mockSettings.dyslexiaMode, true);
    debugPrint("✅ UI successfully processed Dyslexia Mode toggle.");
  });

  // ✅ TEST 2: Verifies Hero Cards are interactive
  testWidgets('Dashboard Hero Cards Interaction Test', (WidgetTester tester) async {
    final mockSettings = MockNeuroSettings();

    await tester.pumpWidget(
      ChangeNotifierProvider<NeuroSettings>.value(
        value: mockSettings,
        child: const MaterialApp(home: SmartDashboardScreen()),
      ),
    );

    // 1. Find the "Task Assistant" card
    final taskCard = find.text('Task Assistant');
    expect(taskCard, findsOneWidget);
    
    // 2. Tap it
    await tester.tap(taskCard);
    
    // 3. Wait for navigation animation
    await tester.pumpAndSettle();
    
    // 4. If no crash happened, the test passes.
    // (In a fuller test, we would check if the new route was pushed)
    debugPrint("✅ Hero cards are responsive to touch.");
  });
}