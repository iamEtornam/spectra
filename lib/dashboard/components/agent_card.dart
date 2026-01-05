import 'package:jaspr/jaspr.dart';

import '../../models/agent.dart';

/// A card component displaying an agent's status.
class AgentCard extends StatelessComponent {
  final AgentState agent;

  const AgentCard({required this.agent});

  String get _icon {
    switch (agent.role) {
      case AgentRole.mayor:
        return '👔';
      case AgentRole.worker:
        return '🔧';
      case AgentRole.witness:
        return '👁️';
    }
  }

  String get _statusColor {
    switch (agent.status) {
      case AgentStatus.idle:
        return '#6b7280';
      case AgentStatus.working:
        return '#f59e0b';
      case AgentStatus.completed:
        return '#10b981';
      case AgentStatus.failed:
        return '#ef4444';
      case AgentStatus.stuck:
        return '#f97316';
    }
  }

  String get _roleGradient {
    switch (agent.role) {
      case AgentRole.mayor:
        return 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
      case AgentRole.worker:
        return 'linear-gradient(135deg, #00d4aa 0%, #00a88a 100%)';
      case AgentRole.witness:
        return 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)';
    }
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time).inSeconds;

    if (diff < 60) return '${diff}s ago';
    if (diff < 3600) return '${diff ~/ 60}m ago';
    return '${diff ~/ 3600}h ago';
  }

  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(
      classes: 'agent',
      styles: Styles.raw({
        'display': 'flex',
        'align-items': 'center',
        'gap': '1rem',
        'padding': '1rem',
        'background': '#1a1f2e',
        'border-radius': '8px',
        'transition': 'transform 0.2s, box-shadow 0.2s',
      }),
      [
        // Icon
        div(
          styles: Styles.raw({
            'width': '40px',
            'height': '40px',
            'border-radius': '8px',
            'display': 'flex',
            'align-items': 'center',
            'justify-content': 'center',
            'font-size': '1.25rem',
            'background': _roleGradient,
          }),
          [text(_icon)],
        ),
        // Info
        div(
          styles: Styles.raw({'flex': '1'}),
          [
            div(
              styles: Styles.raw({
                'font-weight': '600',
                'margin-bottom': '0.25rem',
              }),
              [text(agent.id)],
            ),
            div(
              styles: Styles.raw({
                'font-size': '0.75rem',
                'color': '#8b949e',
              }),
              [
                text(agent.currentTaskId != null
                    ? 'Task: ${agent.currentTaskId} · Last active: ${_formatRelativeTime(agent.lastActivity)}'
                    : 'No active task · Last active: ${_formatRelativeTime(agent.lastActivity)}'),
              ],
            ),
          ],
        ),
        // Status badge
        div(
          styles: Styles.raw({
            'padding': '0.25rem 0.75rem',
            'border-radius': '1rem',
            'font-size': '0.75rem',
            'font-weight': '600',
            'text-transform': 'uppercase',
            'background': _statusColor,
            'color': agent.status == AgentStatus.working ? '#000' : '#fff',
          }),
          [text(agent.status.name)],
        ),
      ],
    );
  }
}
