import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do/main.dart';

void main() {
  testWidgets('Add task and mark as done test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(isDarkMode: false));

    // Verify that initial screen has no tasks message.
    expect(find.text('No tasks. Tap + to add one.'), findsOneWidget);

    // Tap the '+' icon to add a task.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Enter a title for the new task.
    await tester.enterText(find.byType(TextField).first, 'Test Task');

    // Save the task.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify the task appears in the list.
    expect(find.text('Test Task'), findsOneWidget);

    // Mark the task as done.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    // Verify the checkbox is now checked (completed task).
    final Checkbox checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, isTrue);

    // Delete the task.
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Confirm delete.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify the task was removed.
    expect(find.text('Test Task'), findsNothing);
  });
}