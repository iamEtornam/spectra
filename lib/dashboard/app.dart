import 'package:jaspr/jaspr.dart';

import '../models/agent.dart';
import 'components/agent_card.dart';
import 'components/progress_card.dart';

/// Main dashboard application component.
class DashboardApp extends StatefulComponent {
  final List<AgentState> agents;
  final int completedTasks;
  final int totalTasks;
  final bool isRunning;

  const DashboardApp({
    required this.agents,
    required this.completedTasks,
    required this.totalTasks,
    required this.isRunning,
  });

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(
      styles: Styles.raw({
        'font-family': "'SF Mono', 'Fira Code', 'Consolas', monospace",
        'background': '#0a0e14',
        'color': '#e6e8eb',
        'min-height': '100vh',
        'padding': '2rem',
      }),
      [
        // Header
        _buildHeader(),
        // Main grid
        div(
          styles: Styles.raw({
            'display': 'grid',
            'grid-template-columns': 'repeat(auto-fit, minmax(300px, 1fr))',
            'gap': '1.5rem',
            'margin-top': '2rem',
          }),
          [
            // Agents card (spans 2 columns)
            _buildAgentsCard(),
            // Progress card
            ProgressCard(
              completed: component.completedTasks,
              total: component.totalTasks,
            ),
          ],
        ),
      ],
    );
  }

  Component _buildHeader() {
    return div(
      styles: Styles.raw({
        'display': 'flex',
        'align-items': 'center',
        'justify-content': 'space-between',
        'padding-bottom': '1rem',
        'border-bottom': '1px solid #2d3548',
      }),
      [
        // Logo
        div(
          styles: Styles.raw({
            'font-size': '1.75rem',
            'font-weight': '700',
            'background': 'linear-gradient(135deg, #00d4aa 0%, #00ffcc 100%)',
            '-webkit-background-clip': 'text',
            '-webkit-text-fill-color': 'transparent',
            'background-clip': 'text',
          }),
          [text('⚡ Spectra Dashboard')],
        ),
        // Status badge
        div(
          styles: Styles.raw({
            'display': 'flex',
            'align-items': 'center',
            'gap': '0.5rem',
            'padding': '0.5rem 1rem',
            'border-radius': '2rem',
            'font-size': '0.875rem',
            'background': '#1a1f2e',
          }),
          [
            div(
              styles: Styles.raw({
                'width': '8px',
                'height': '8px',
                'border-radius': '50%',
                'background': component.isRunning ? '#f59e0b' : '#6b7280',
                'animation': component.isRunning ? 'pulse 2s infinite' : 'none',
              }),
              [],
            ),
            span([text(component.isRunning ? 'Running' : 'Stopped')]),
          ],
        ),
      ],
    );
  }

  Component _buildAgentsCard() {
    return div(
      styles: Styles.raw({
        'grid-column': 'span 2',
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
              [text('Active Agents')],
            ),
            span(
              styles: Styles.raw({
                'font-size': '0.75rem',
                'color': '#8b949e',
              }),
              [text('Auto-refreshing...')],
            ),
          ],
        ),
        // Agents list or empty state
        if (component.agents.isEmpty)
          _buildEmptyState()
        else
          div(
            styles: Styles.raw({
              'display': 'flex',
              'flex-direction': 'column',
              'gap': '0.75rem',
            }),
            [
              for (final agent in component.agents) AgentCard(agent: agent),
            ],
          ),
      ],
    );
  }

  Component _buildEmptyState() {
    return div(
      styles: Styles.raw({
        'text-align': 'center',
        'padding': '3rem',
        'color': '#8b949e',
      }),
      [
        div(
          styles: Styles.raw({'font-size': '3rem', 'margin-bottom': '1rem'}),
          [text('🤖')],
        ),
        div([text('No agents running')]),
        div(
          styles: Styles.raw({
            'font-size': '0.875rem',
            'margin-top': '0.5rem',
          }),
          [
            text('Start the orchestrator with '),
            code([text('spectra start')]),
          ],
        ),
      ],
    );
  }
}
