import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../models/agent.dart';

/// A Jaspr component that displays a single agent's status.
class AgentCard extends StatelessComponent {
  final AgentState agent;

  const AgentCard({required this.agent, super.key});

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'agent-card',
      styles: const Styles(
        raw: {
          'background-color': '#2a2a4a',
          'border-radius': '10px',
          'padding': '20px',
          'box-shadow': '0 4px 8px rgba(0, 0, 0, 0.2)',
        },
      ),
      [
        // Header with role icon and agent ID
        h3(
          styles: const Styles(
            raw: {
              'display': 'flex',
              'align-items': 'center',
              'gap': '8px',
              'margin-bottom': '12px',
              'color': '#e0e0e0',
            },
          ),
          [
            span(styles: const Styles(raw: {'font-size': '1.2em'}), [
              Component.text(_getRoleIcon(agent.role)),
            ]),
            Component.text(agent.id),
          ],
        ),

        // Status badge
        div(
          styles: const Styles(
            raw: {
              'display': 'flex',
              'align-items': 'center',
              'gap': '8px',
              'margin-bottom': '8px',
            },
          ),
          [
            // Status indicator dot
            span(
              styles: Styles(
                raw: {
                  'width': '10px',
                  'height': '10px',
                  'border-radius': '50%',
                  'background-color': _getStatusColorHex(agent.status),
                },
              ),
              [],
            ),
            span(
              styles: Styles(
                raw: {
                  'font-weight': 'bold',
                  'color': _getStatusColorHex(agent.status),
                },
              ),
              [Component.text(agent.status.name.toUpperCase())],
            ),
          ],
        ),

        // Current task (if any)
        if (agent.currentTaskId != null)
          p(
            styles: const Styles(
              raw: {'margin-bottom': '8px', 'color': '#b0b0b0'},
            ),
            [
              const Component.text('Task: '),
              code(
                styles: const Styles(
                  raw: {
                    'background-color': '#1a1f2e',
                    'padding': '2px 6px',
                    'border-radius': '4px',
                  },
                ),
                [Component.text(agent.currentTaskId!)],
              ),
            ],
          ),

        // Last activity timestamp
        p(
          styles: const Styles(
            raw: {'font-size': '0.85em', 'color': '#888888'},
          ),
          [
            Component.text(
              'Last: ${agent.lastActivity.toLocal().toString().split('.').first}',
            ),
          ],
        ),
      ],
    );
  }

  String _getRoleIcon(AgentRole role) {
    switch (role) {
      case AgentRole.mayor:
        return '👔';
      case AgentRole.worker:
        return '🔧';
      case AgentRole.witness:
        return '👁️';
    }
  }

  String _getStatusColorHex(AgentStatus status) {
    switch (status) {
      case AgentStatus.idle:
        return '#4CAF50'; // Green
      case AgentStatus.working:
        return '#FFC107'; // Amber
      case AgentStatus.stuck:
        return '#FF5722'; // Deep Orange
      case AgentStatus.completed:
        return '#2196F3'; // Blue
      case AgentStatus.failed:
        return '#F44336'; // Red
    }
  }
}
