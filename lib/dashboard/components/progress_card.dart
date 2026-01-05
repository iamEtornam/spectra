import 'package:jaspr/jaspr.dart';

/// A card component displaying project progress.
class ProgressCard extends StatelessComponent {
  final int completed;
  final int total;

  const ProgressCard({
    required this.completed,
    required this.total,
  });

  int get _percent => total == 0 ? 0 : (completed / total * 100).round();

  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(
      classes: 'card',
      styles: Styles.raw({
        'background': '#151a26',
        'border': '1px solid #2d3548',
        'border-radius': '12px',
        'padding': '1.5rem',
      }),
      [
        // Header
        div(
          styles: Styles.raw({
            'display': 'flex',
            'align-items': 'center',
            'justify-content': 'space-between',
            'margin-bottom': '1rem',
          }),
          [
            span(
              styles: Styles.raw({
                'font-size': '0.875rem',
                'text-transform': 'uppercase',
                'letter-spacing': '0.1em',
                'color': '#8b949e',
              }),
              [text('Project Progress')],
            ),
          ],
        ),
        // Percentage
        div(
          styles: Styles.raw({
            'font-size': '2.5rem',
            'font-weight': '700',
            'color': '#00d4aa',
          }),
          [text('$_percent%')],
        ),
        // Progress bar
        div(
          styles: Styles.raw({
            'height': '8px',
            'background': '#1a1f2e',
            'border-radius': '4px',
            'overflow': 'hidden',
            'margin-top': '1rem',
          }),
          [
            div(
              styles: Styles.raw({
                'height': '100%',
                'width': '$_percent%',
                'background':
                    'linear-gradient(90deg, #00d4aa 0%, #00ffcc 100%)',
                'border-radius': '4px',
                'transition': 'width 0.5s ease',
              }),
              [],
            ),
          ],
        ),
        // Task count
        div(
          styles: Styles.raw({
            'display': 'flex',
            'justify-content': 'space-between',
            'margin-top': '0.5rem',
            'font-size': '0.875rem',
            'color': '#8b949e',
          }),
          [
            span([text('$completed / $total tasks')]),
            span([text(_percent == 100 ? 'Complete!' : 'In Progress')]),
          ],
        ),
      ],
    );
  }
}
