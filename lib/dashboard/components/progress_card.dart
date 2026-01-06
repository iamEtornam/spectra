import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// A Jaspr component that displays project progress.
class ProgressCard extends StatelessComponent {
  final int progress;
  final int totalTasks;
  final int completedTasks;

  const ProgressCard({
    required this.progress,
    required this.totalTasks,
    required this.completedTasks,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'progress-card',
      styles: const Styles(
        raw: {
          'background-color': '#2a2a4a',
          'border-radius': '10px',
          'padding': '20px',
          'box-shadow': '0 4px 8px rgba(0, 0, 0, 0.2)',
        },
      ),
      [
        // Title
        const h3(
          styles: Styles(raw: {'margin-bottom': '16px', 'color': '#e0e0e0'}),
          [Component.text('📊 Project Progress')],
        ),

        // Progress bar container
        div(
          styles: const Styles(
            raw: {
              'background-color': '#4a4a6a',
              'border-radius': '8px',
              'height': '20px',
              'overflow': 'hidden',
              'margin-bottom': '12px',
            },
          ),
          [
            // Progress bar fill
            div(
              styles: Styles(
                raw: {
                  'width': '$progress%',
                  'height': '100%',
                  'background-color': '#00bcd4',
                  'border-radius': '8px',
                  'display': 'flex',
                  'align-items': 'center',
                  'justify-content': 'center',
                },
              ),
              [
                span(
                  styles: const Styles(
                    raw: {
                      'font-size': '0.75em',
                      'font-weight': 'bold',
                      'color': 'white',
                    },
                  ),
                  [Component.text('$progress%')],
                ),
              ],
            ),
          ],
        ),

        // Task count
        p(
          styles: const Styles(raw: {'color': '#b0b0b0', 'font-size': '0.9em'}),
          [Component.text('Completed: $completedTasks / $totalTasks tasks')],
        ),
      ],
    );
  }
}
