import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../models/agent.dart';
import 'components/agent_card.dart';
import 'components/progress_card.dart';

/// The main dashboard page component.
///
/// Displays agent status cards and project progress.
class DashboardPage extends StatelessComponent {
  final List<AgentState> agents;
  final int projectProgress;
  final int totalTasks;
  final int completedTasks;

  const DashboardPage({
    required this.agents,
    required this.projectProgress,
    required this.totalTasks,
    required this.completedTasks,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'dashboard-container',
      styles: const Styles(
        raw: {
          'font-family': 'Inter, system-ui, sans-serif',
          'background-color': '#1a1a2e',
          'color': '#e0e0e0',
          'min-height': '100vh',
          'padding': '24px',
        },
      ),
      [
        // Header
        const h1(
          styles: Styles(
            raw: {
              'color': '#00bcd4',
              'text-align': 'center',
              'margin-bottom': '32px',
              'font-size': '2em',
            },
          ),
          [Component.text('🚀 Spectra Multi-Agent Dashboard')],
        ),

        // Grid of cards
        div(
          classes: 'dashboard-grid',
          styles: const Styles(
            raw: {
              'display': 'grid',
              'grid-template-columns': 'repeat(auto-fit, minmax(300px, 1fr))',
              'gap': '20px',
              'max-width': '1200px',
              'margin': '0 auto',
            },
          ),
          [
            // Agent cards
            for (final agent in agents) AgentCard(agent: agent),

            // Progress card
            ProgressCard(
              progress: projectProgress,
              totalTasks: totalTasks,
              completedTasks: completedTasks,
            ),
          ],
        ),

        // Footer with refresh notice
        const p(
          styles: Styles(
            raw: {
              'text-align': 'center',
              'margin-top': '32px',
              'color': '#666666',
              'font-size': '0.85em',
            },
          ),
          [Component.text('Auto-refreshes every 2 seconds')],
        ),
      ],
    );
  }
}
