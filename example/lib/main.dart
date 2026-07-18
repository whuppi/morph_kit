// adaptive_layouts — full-app example
//
// One file, one real app topology. This is deliberately NOT a toy: it is a
// small project-tracker app ("tickets / ops / admin") built on the hardest
// shape the package has to survive in production —
//
//   MaterialApp.router (auto_route, URL-synced)
//   └── RootShellScreen            persistent status bar ABOVE the router
//       └── AppShellScreen         domain tabs (bottom nav ↔ rail at 720px)
//           ├── Work domain        secondary tab bar (Tickets / Directory / Prefs)
//           │   ├── Tickets        ListDetailRouter → overlay detail + adaptive modals
//           │   ├── Directory      ANOTHER nested tab router, 4 segments,
//           │   │                  each segment its own overlay list-detail
//           │   └── Prefs          plain settings tab
//           ├── Ops domain         (Monitor / Runs / Setup)
//           │   ├── Monitor        full-screen tab, feeds the status bar
//           │   ├── Runs           nested tab shell → Builds list-detail
//           │   └── Setup          MULTI-TYPE list-detail (3 entity types)
//           └── Admin domain       (Workspace / Integrations / Appearance / Advanced)
//               └── 4 tabs         each a multi-type list-detail
//
// List-details default to CompactDetailMode.overlay (switchable live from
// the ⚙ package-settings panel in the status strip), so on phone widths the
// detail pane covers the tab bars and bottom nav — while inactive domains
// stay mounted (tab routers keep state), which is exactly the case the
// package's paint-visibility suppression exists for.
//
// Also exercised: deep links straight into details (type a URL on
// web), swipe-to-dismiss, back-gesture interception, divider drag, window
// resize across the breakpoint with widget-state preservation (type a comment
// draft in a ticket, resize, the draft survives).

import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ModalRoute;
import 'package:flutter/scheduler.dart';

part 'main.gr.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _router = AppRouter();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PackageSettings.instance,
      builder: (context, _) => AdaptiveLayoutConfig(
        expandedBreakpoint: PackageSettings.instance.expandedBreakpoint,
        child: MaterialApp.router(
          title: 'adaptive_layouts example',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
          ),
          routerConfig: _router.config(),
        ),
      ),
    );
  }
}

// =============================================================================
// BREAKPOINTS
//
// One breakpoint for the whole app: below it the shell uses a bottom nav and
// detail panes slide over; at or above it the shell uses a rail and panes go
// side-by-side. Driven by the package settings panel (⚙ in the status strip)
// through an app-level AdaptiveLayoutConfig.
// =============================================================================

extension BreakpointX on BuildContext {
  bool get isExpanded =>
      MediaQuery.sizeOf(this).width >=
      (AdaptiveLayoutConfig.maybeOf(this)?.expandedBreakpoint ??
          AdaptiveLayoutConfig.defaultExpandedBreakpoint);
  bool get isCompact => !isExpanded;
}

// =============================================================================
// PACKAGE SETTINGS
//
// Live-tweakable package configuration, so every knob the package offers can
// be exercised while playing with the app. Opened from the ⚙ in the status
// strip — as an adaptive modal, so the settings panel itself demos the modal.
// =============================================================================

enum DividerStyle { handle, line, none }

class PackageSettings extends ChangeNotifier {
  PackageSettings._();
  static final PackageSettings instance = PackageSettings._();

  // List-detail
  CompactDetailMode compactDetailMode = CompactDetailMode.overlay;
  DividerStyle divider = DividerStyle.handle;
  PaneResizeMode resizeMode = PaneResizeMode.ratio;
  bool anchorsEnabled = false;
  double expandedBreakpoint = 720;
  bool handleBackGesture = true;
  int slideDurationMs = 300;

  // Adaptive modal
  bool modalMorph = true;
  int modalMorphDurationMs = 350;
  bool modalDragHandle = true;
  bool modalPinnedColor = false;
  bool modalBarrierDismissible = true;

  DividerBuilder? get dividerBuilder => switch (divider) {
    DividerStyle.handle => HandleDivider.builder,
    DividerStyle.line => MaterialDivider.builder,
    DividerStyle.none => null,
  };

  PaneConfig get paneConfig => PaneConfig(
    resizeMode: resizeMode,
    anchors: anchorsEnabled ? PaneAnchor.listDetail : const [],
  );

  CompactConfig get compactConfig => CompactConfig(
    duration: Duration(milliseconds: slideDurationMs),
    handleBackGesture: handleBackGesture,
  );

  ModalConfig get modalConfig => ModalConfig(
    morph: modalMorph,
    morphDuration: Duration(milliseconds: modalMorphDurationMs),
    showDragHandle: modalDragHandle,
    backgroundColor: modalPinnedColor ? const Color(0xFF223038) : null,
    barrierDismissible: modalBarrierDismissible,
  );

  void update(void Function(PackageSettings s) change) {
    change(this);
    notifyListeners();
  }
}

/// Opens the settings panel — as an adaptive modal, so the panel itself
/// exercises the modal with whatever modal settings are currently chosen.
void showPackageSettings(BuildContext context) {
  showAdaptiveModal<void>(
    context: context,
    config: PackageSettings.instance.modalConfig,
    builder: (context, mode) => SizedBox(
      width: mode == ModalLayoutMode.dialog ? 460 : double.infinity,
      child: const PackageSettingsPanel(),
    ),
  );
}

class PackageSettingsPanel extends StatelessWidget {
  const PackageSettingsPanel({super.key});

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _choice<T>({
    required BuildContext context,
    required String label,
    required List<T> values,
    required T value,
    required String Function(T) name,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          SegmentedButton<T>(
            segments: [
              for (final v in values)
                ButtonSegment(value: v, label: Text(name(v))),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }

  Widget _toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = PackageSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Package settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Everything applies live — resize, select, and dismiss while '
              'flipping these. This panel is itself an adaptive modal. '
              'Options appear only when the current choices use them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            _section(context, 'Layout'),
            _choice(
              context: context,
              label: 'Expanded breakpoint',
              values: const [600.0, 720.0, 840.0],
              value: s.expandedBreakpoint,
              name: (double v) => v.toInt().toString(),
              onChanged: (v) => s.update((s) => s.expandedBreakpoint = v),
            ),
            _section(context, 'Compact detail'),
            _choice(
              context: context,
              label: 'Mode',
              values: CompactDetailMode.values,
              value: s.compactDetailMode,
              name: (CompactDetailMode v) => v.name,
              onChanged: (v) => s.update((s) => s.compactDetailMode = v),
            ),
            // Route mode delegates back handling and transitions to the
            // real route — these two only exist for the slide-over modes.
            if (s.compactDetailMode != CompactDetailMode.route) ...[
              _toggle(
                label: 'Intercept back gesture',
                value: s.handleBackGesture,
                onChanged: (v) => s.update((s) => s.handleBackGesture = v),
              ),
              _choice(
                context: context,
                label: 'Slide duration (ms)',
                values: const [200, 300, 500],
                value: s.slideDurationMs,
                name: (int v) => '$v',
                onChanged: (v) => s.update((s) => s.slideDurationMs = v),
              ),
            ],
            _section(context, 'Expanded panes'),
            _choice(
              context: context,
              label: 'Divider',
              values: DividerStyle.values,
              value: s.divider,
              name: (DividerStyle v) => v.name,
              onChanged: (v) => s.update((s) => s.divider = v),
            ),
            _choice(
              context: context,
              label: 'Resize mode',
              values: PaneResizeMode.values,
              value: s.resizeMode,
              name: (PaneResizeMode v) => v.name,
              onChanged: (v) => s.update((s) => s.resizeMode = v),
            ),
            _toggle(
              label: 'Divider snap anchors',
              value: s.anchorsEnabled,
              onChanged: (v) => s.update((s) => s.anchorsEnabled = v),
            ),
            _section(context, 'Adaptive modal'),
            _toggle(
              label: 'Container-transform morph',
              value: s.modalMorph,
              onChanged: (v) => s.update((s) => s.modalMorph = v),
            ),
            if (s.modalMorph)
              _choice(
                context: context,
                label: 'Morph duration (ms)',
                values: const [350, 700, 1400],
                value: s.modalMorphDurationMs,
                name: (int v) => '$v',
                onChanged: (v) => s.update((s) => s.modalMorphDurationMs = v),
              ),
            _toggle(
              label: 'Sheet drag handle',
              value: s.modalDragHandle,
              onChanged: (v) => s.update((s) => s.modalDragHandle = v),
            ),
            _toggle(
              label: 'Pin one surface color across forms',
              value: s.modalPinnedColor,
              onChanged: (v) => s.update((s) => s.modalPinnedColor = v),
            ),
            _toggle(
              label: 'Barrier dismissible',
              value: s.modalBarrierDismissible,
              onChanged: (v) => s.update((s) => s.modalBarrierDismissible = v),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DEMO DATA
//
// In-memory stand-in for a data layer. Collections are ValueNotifiers so
// lists rebuild when modals add items and detail panes delete them —
// deletion is what exercises ListDetailRouter.selectedIdExists auto-dismiss.
// =============================================================================

class Item {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;

  const Item({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
  });
}

class Store {
  Store._();
  static final Store instance = Store._();

  int _counter = 0;
  String nextId(String prefix) => '$prefix-${++_counter}';

  // ── Work domain ──
  final tickets = ValueNotifier<List<Item>>(const [
    Item(
      id: 'ticket-hooks',
      name: 'Webhook drops events',
      subtitle: 'high · payments',
      icon: Icons.bolt_outlined,
    ),
    Item(
      id: 'ticket-dark',
      name: 'Dark mode regression',
      subtitle: 'medium · ui',
      icon: Icons.dark_mode_outlined,
    ),
    Item(
      id: 'ticket-cold',
      name: 'Slow cold start',
      subtitle: 'low · perf',
      icon: Icons.speed_outlined,
    ),
  ]);

  final people = ValueNotifier<List<Item>>(const [
    Item(
      id: 'person-rae',
      name: 'Rae',
      subtitle: 'Product',
      icon: Icons.person,
    ),
    Item(
      id: 'person-noah',
      name: 'Noah',
      subtitle: 'Backend',
      icon: Icons.person,
    ),
    Item(id: 'person-io', name: 'Io', subtitle: 'Research', icon: Icons.person),
  ]);

  final teams = ValueNotifier<List<Item>>(const [
    Item(
      id: 'team-platform',
      name: 'Platform',
      subtitle: '6 members',
      icon: Icons.groups_outlined,
    ),
    Item(
      id: 'team-growth',
      name: 'Growth',
      subtitle: '3 members',
      icon: Icons.trending_up,
    ),
  ]);

  final labels = ValueNotifier<List<Item>>(const [
    Item(
      id: 'label-bug',
      name: 'bug',
      subtitle: '14 open tickets',
      icon: Icons.bug_report_outlined,
    ),
    Item(
      id: 'label-perf',
      name: 'perf',
      subtitle: '4 open tickets',
      icon: Icons.speed_outlined,
    ),
  ]);

  final milestones = ValueNotifier<List<Item>>(const [
    Item(
      id: 'milestone-ga',
      name: 'GA Launch',
      subtitle: 'Due in 3 weeks',
      icon: Icons.flag_outlined,
    ),
  ]);

  // ── Ops domain ──
  final builds = ValueNotifier<List<Item>>(const [
    Item(
      id: 'build-412',
      name: 'Build #412',
      subtitle: 'main · passed',
      icon: Icons.check_circle_outline,
    ),
    Item(
      id: 'build-411',
      name: 'Build #411',
      subtitle: 'main · passed',
      icon: Icons.check_circle_outline,
    ),
    Item(
      id: 'build-410',
      name: 'Build #410',
      subtitle: 'fix/webhooks · failed',
      icon: Icons.error_outline,
    ),
  ]);

  final pipelines = ValueNotifier<List<Item>>(const [
    Item(
      id: 'pipeline-ci',
      name: 'CI',
      subtitle: 'lint · test · build',
      icon: Icons.account_tree_outlined,
    ),
    Item(
      id: 'pipeline-nightly',
      name: 'Nightly',
      subtitle: 'full matrix, 2am',
      icon: Icons.nightlight_outlined,
    ),
  ]);

  // ── Admin domain ──
  final workspaces = ValueNotifier<List<Item>>(const [
    Item(
      id: 'workspace-acme',
      name: 'Acme Inc',
      subtitle: 'Owner',
      icon: Icons.business_outlined,
    ),
  ]);

  final members = ValueNotifier<List<Item>>(const [
    Item(id: 'member-rae', name: 'Rae', subtitle: 'Admin', icon: Icons.person),
    Item(
      id: 'member-noah',
      name: 'Noah',
      subtitle: 'Member',
      icon: Icons.person,
    ),
  ]);

  final services = ValueNotifier<List<Item>>(const [
    Item(
      id: 'service-git',
      name: 'Git Hosting',
      subtitle: 'Connected',
      icon: Icons.merge_outlined,
    ),
    Item(
      id: 'service-pager',
      name: 'Pager',
      subtitle: 'Connected',
      icon: Icons.notifications_active_outlined,
    ),
  ]);

  final webhooks = ValueNotifier<List<Item>>(const [
    Item(
      id: 'webhook-deploys',
      name: 'Deploy events',
      subtitle: 'POST /hooks/deploys',
      icon: Icons.webhook_outlined,
    ),
  ]);

  final tokens = ValueNotifier<List<Item>>(const [
    Item(
      id: 'token-ci',
      name: 'CI_TOKEN',
      subtitle: '••••••••',
      icon: Icons.key_outlined,
    ),
  ]);

  final agents = ValueNotifier<List<Item>>(const [
    Item(
      id: 'agent-macos',
      name: 'macos-runner-1',
      subtitle: 'Online · 12 jobs today',
      icon: Icons.computer_outlined,
    ),
  ]);

  // ── Fixed URL-addressed settings entries ──
  static const preferences = [
    Item(
      id: 'theme',
      name: 'Theme',
      subtitle: 'System',
      icon: Icons.palette_outlined,
    ),
    Item(
      id: 'density',
      name: 'Density',
      subtitle: 'Comfortable',
      icon: Icons.density_medium,
    ),
  ];

  static const sessions = [
    Item(
      id: 'login',
      name: 'Sign In',
      subtitle: 'Sync account',
      icon: Icons.login,
    ),
    Item(
      id: 'register',
      name: 'Create Account',
      subtitle: 'New account',
      icon: Icons.person_add_outlined,
    ),
  ];

  static const servers = [
    Item(
      id: 'config',
      name: 'Local Server',
      subtitle: 'Port 9999',
      icon: Icons.dns_outlined,
    ),
  ];

  static const runners = [
    Item(
      id: 'concurrency',
      name: 'Concurrency',
      subtitle: '4 parallel jobs',
      icon: Icons.stacked_line_chart,
    ),
    Item(
      id: 'timeout',
      name: 'Job Timeout',
      subtitle: '30 minutes',
      icon: Icons.timer_outlined,
    ),
  ];

  static const caches = [
    Item(
      id: 'deps',
      name: 'Dependency Cache',
      subtitle: '1.2 GB',
      icon: Icons.archive_outlined,
    ),
    Item(
      id: 'docker',
      name: 'Layer Cache',
      subtitle: '4.7 GB',
      icon: Icons.layers_outlined,
    ),
  ];

  // ── Status-bar state (active deploy) ──
  final deploying = ValueNotifier<Item?>(null);

  void add(ValueNotifier<List<Item>> collection, Item item) {
    collection.value = [...collection.value, item];
  }

  void remove(ValueNotifier<List<Item>> collection, String id) {
    collection.value = collection.value.where((i) => i.id != id).toList();
    if (deploying.value?.id == id) deploying.value = null;
  }

  Item? find(List<Item> items, String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}

// =============================================================================
// ROUTE PATHS + PARAMS
// =============================================================================

abstract final class Paths {
  static const root = '/';
  static const empty = '';

  // Work domain
  static const work = 'work';
  static const tickets = 'tickets';
  static const ticketWithParam = ':${Params.ticketId}';
  static const directory = 'directory';
  static const prefs = 'prefs';
  static const people = 'people';
  static const teams = 'teams';
  static const labels = 'labels';
  static const milestones = 'milestones';

  // Ops domain
  static const ops = 'ops';
  static const monitor = 'monitor';
  static const runs = 'runs';
  static const builds = 'builds';
  static const buildWithParam = ':${Params.buildId}';
  static const setup = 'setup';
  static const pipeline = 'pipeline';
  static const pipelineWithParam = 'pipeline/:${Params.pipelineId}';
  static const runner = 'runner';
  static const runnerWithParam = 'runner/:${Params.runnerId}';
  static const cache = 'cache';
  static const cacheWithParam = 'cache/:${Params.cacheId}';

  // Admin domain
  static const admin = 'admin';
  static const workspace = 'workspace';
  static const workspaceWithParam = 'workspace/:${Params.workspaceId}';
  static const member = 'member';
  static const memberWithParam = 'member/:${Params.memberId}';
  static const session = 'session';
  static const sessionWithParam = 'session/:${Params.sessionId}';
  static const integrations = 'integrations';
  static const service = 'service';
  static const serviceWithParam = 'service/:${Params.serviceId}';
  static const webhook = 'webhook';
  static const webhookWithParam = 'webhook/:${Params.webhookId}';
  static const token = 'token';
  static const tokenWithParam = 'token/:${Params.tokenId}';
  static const agent = 'agent';
  static const agentWithParam = 'agent/:${Params.agentId}';
  static const appearance = 'appearance';
  static const preference = 'preference';
  static const preferenceWithParam = 'preference/:${Params.preferenceId}';
  static const advanced = 'advanced';
  static const server = 'server';
  static const serverWithParam = 'server/:${Params.serverId}';
}

abstract final class Params {
  static const ticketId = 'ticketId';
  static const personId = 'personId';
  static const teamId = 'teamId';
  static const labelId = 'labelId';
  static const milestoneId = 'milestoneId';
  static const buildId = 'buildId';
  static const pipelineId = 'pipelineId';
  static const runnerId = 'runnerId';
  static const cacheId = 'cacheId';
  static const workspaceId = 'workspaceId';
  static const memberId = 'memberId';
  static const sessionId = 'sessionId';
  static const serviceId = 'serviceId';
  static const webhookId = 'webhookId';
  static const tokenId = 'tokenId';
  static const agentId = 'agentId';
  static const preferenceId = 'preferenceId';
  static const serverId = 'serverId';
}

// =============================================================================
// ROUTER
//
// Route structure:
// ```
// /
// └── (app shell)
//     ├── /work
//     │   ├── /tickets/:ticketId
//     │   ├── /directory/{people,teams,labels,milestones}/:id
//     │   └── /prefs
//     ├── /ops
//     │   ├── /monitor
//     │   ├── /runs/builds/:buildId
//     │   └── /setup/{pipeline,runner,cache}/:id
//     └── /admin
//         ├── /workspace/{workspace,member,session}/:id
//         ├── /integrations/{service,webhook,token,agent}/:id
//         ├── /appearance/preference/:preferenceId
//         └── /advanced/server/:serverId
// ```
//
// Detail routes exist for URL registration only — no nested AutoRouter
// materializes them. ListDetailRouter reads them as pendingChildren and
// mirrors them into its ListDetailController.
// =============================================================================

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  /// Forces the browser URL bar to re-sync after a hot restart on web.
  /// No-op when the URL already matches (normal app start).
  void syncBrowserUrl() {
    if (!kIsWeb) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      navigationHistory.rebuildUrl();
    });
  }

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: RootShellRoute.page,
      path: Paths.root,
      children: [

        // App shell — domain navigation (bottom nav / rail).
        AutoRoute(
          page: AppShellRoute.page,
          path: Paths.empty,
          initial: true,
          children: [
            // ── Work domain ──
            AutoRoute(
              page: WorkDomainRoute.page,
              path: Paths.work,
              initial: true,
              children: [
                AutoRoute(
                  page: TicketsTabRoute.page,
                  path: Paths.tickets,
                  initial: true,
                  children: [
                    AutoRoute(
                      page: TicketRoute.page,
                      path: Paths.ticketWithParam,
                    ),
                  ],
                ),
                AutoRoute(
                  page: DirectoryShellRoute.page,
                  path: Paths.directory,
                  children: [
                    AutoRoute(
                      page: PeopleTabRoute.page,
                      path: Paths.people,
                      initial: true,
                      children: [
                        AutoRoute(
                          page: PersonDetailRoute.page,
                          path: ':${Params.personId}',
                        ),
                      ],
                    ),
                    AutoRoute(
                      page: TeamsTabRoute.page,
                      path: Paths.teams,
                      children: [
                        AutoRoute(
                          page: TeamDetailRoute.page,
                          path: ':${Params.teamId}',
                        ),
                      ],
                    ),
                    AutoRoute(
                      page: LabelsTabRoute.page,
                      path: Paths.labels,
                      children: [
                        AutoRoute(
                          page: LabelDetailRoute.page,
                          path: ':${Params.labelId}',
                        ),
                      ],
                    ),
                    AutoRoute(
                      page: MilestonesTabRoute.page,
                      path: Paths.milestones,
                      children: [
                        AutoRoute(
                          page: MilestoneDetailRoute.page,
                          path: ':${Params.milestoneId}',
                        ),
                      ],
                    ),
                  ],
                ),
                AutoRoute(page: WorkPrefsTabRoute.page, path: Paths.prefs),
              ],
            ),

            // ── Ops domain ──
            AutoRoute(
              page: OpsDomainRoute.page,
              path: Paths.ops,
              children: [
                AutoRoute(
                  page: MonitorTabRoute.page,
                  path: Paths.monitor,
                  initial: true,
                ),
                AutoRoute(
                  page: RunsShellRoute.page,
                  path: Paths.runs,
                  children: [
                    AutoRoute(
                      page: BuildsTabRoute.page,
                      path: Paths.builds,
                      initial: true,
                      children: [
                        AutoRoute(
                          page: BuildDetailRoute.page,
                          path: Paths.buildWithParam,
                        ),
                      ],
                    ),
                  ],
                ),
                AutoRoute(
                  page: SetupTabRoute.page,
                  path: Paths.setup,
                  children: [
                    AutoRoute(
                      page: PipelineDetailRoute.page,
                      path: Paths.pipelineWithParam,
                    ),
                    AutoRoute(
                      page: RunnerDetailRoute.page,
                      path: Paths.runnerWithParam,
                    ),
                    AutoRoute(
                      page: CacheDetailRoute.page,
                      path: Paths.cacheWithParam,
                    ),
                  ],
                ),
              ],
            ),

            // ── Admin domain ──
            AutoRoute(
              page: AdminDomainRoute.page,
              path: Paths.admin,
              children: [
                AutoRoute(
                  page: WorkspaceTabRoute.page,
                  path: Paths.workspace,
                  initial: true,
                  children: [
                    AutoRoute(
                      page: WorkspaceDetailRoute.page,
                      path: Paths.workspaceWithParam,
                    ),
                    AutoRoute(
                      page: MemberDetailRoute.page,
                      path: Paths.memberWithParam,
                    ),
                    AutoRoute(
                      page: SessionDetailRoute.page,
                      path: Paths.sessionWithParam,
                    ),
                  ],
                ),
                AutoRoute(
                  page: IntegrationsTabRoute.page,
                  path: Paths.integrations,
                  children: [
                    AutoRoute(
                      page: ServiceDetailRoute.page,
                      path: Paths.serviceWithParam,
                    ),
                    AutoRoute(
                      page: WebhookDetailRoute.page,
                      path: Paths.webhookWithParam,
                    ),
                    AutoRoute(
                      page: TokenDetailRoute.page,
                      path: Paths.tokenWithParam,
                    ),
                    AutoRoute(
                      page: AgentDetailRoute.page,
                      path: Paths.agentWithParam,
                    ),
                  ],
                ),
                AutoRoute(
                  page: AppearanceTabRoute.page,
                  path: Paths.appearance,
                  children: [
                    AutoRoute(
                      page: PreferenceDetailRoute.page,
                      path: Paths.preferenceWithParam,
                    ),
                  ],
                ),
                AutoRoute(
                  page: AdvancedTabRoute.page,
                  path: Paths.advanced,
                  children: [
                    AutoRoute(
                      page: ServerDetailRoute.page,
                      path: Paths.serverWithParam,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}

// =============================================================================
// TAB ROUTERS
//
// Secondary tab bar over an AutoTabsRouter. Inactive tabs stay mounted (state
// preserved) — with overlay-mode list-details inside every tab, this is the
// exact stacking case the package's paint-visibility suppression handles.
// =============================================================================

typedef DomainTabBarBuilder =
    Widget Function(BuildContext context, TabController tabController);

class DomainTabsRouter extends StatelessWidget {
  final List<PageRouteInfo> routes;
  final List<Widget>? tabs;
  final DomainTabBarBuilder? tabBarBuilder;

  const DomainTabsRouter({
    super.key,
    required this.routes,
    this.tabs,
    this.tabBarBuilder,
  }) : assert(
         tabs != null || tabBarBuilder != null,
         'Provide either tabs or tabBarBuilder',
       );

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter.tabBar(
      routes: routes,
      builder: (context, child, tabController) {
        final Widget tabBarContent;
        if (tabBarBuilder != null) {
          tabBarContent = tabBarBuilder!(context, tabController);
        } else {
          tabBarContent = Material(
            child: TabBar.secondary(controller: tabController, tabs: tabs!),
          );
        }

        return Column(
          children: [
            tabBarContent,
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

Widget domainTab({required IconData icon, required String label}) {
  return Tab(
    height: 44,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, softWrap: false, overflow: TextOverflow.fade),
        ),
      ],
    ),
  );
}

// =============================================================================
// LIST-DETAIL ROUTERS (URL SYNC)
//
// The bridge between ListDetailLayout and auto_route: URL → controller on
// deep links / back-forward, controller → URL on select / dismiss. Both run
// the package in whichever CompactDetailMode the ⚙ settings panel selects.
// =============================================================================

/// Single entity type per tab (tickets, people, builds...).
class ListDetailRouter extends StatefulWidget {
  final String idParamName;
  final String? pathPrefix;
  final ListPaneBuilder<String> listBuilder;
  final DetailPaneBuilder<String> detailBuilder;
  final WidgetBuilder? emptyStateBuilder;

  /// When provided, auto-clears selection if the entity no longer exists.
  final bool Function(String id)? selectedIdExists;

  const ListDetailRouter({
    super.key,
    this.idParamName = 'id',
    this.pathPrefix,
    required this.listBuilder,
    required this.detailBuilder,
    this.emptyStateBuilder,
    this.selectedIdExists,
  });

  @override
  State<ListDetailRouter> createState() => _ListDetailRouterState();
}

class _ListDetailRouterState extends State<ListDetailRouter> {
  final _controller = ListDetailController<String>();

  bool _isUpdatingUrl = false;
  StackRouter? _router;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newRouter = context.router;
    if (_router != newRouter) {
      _router?.removeListener(_onRouterChanged);
      _router = newRouter;
      newRouter.addListener(_onRouterChanged);
    }

    _syncSelectionFromUrl();
  }

  @override
  void dispose() {
    _router?.removeListener(_onRouterChanged);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  // ── URL → controller ──

  void _onRouterChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSelectionFromUrl();
    });
  }

  void _syncSelectionFromUrl() {
    if (_isUpdatingUrl) return;

    final routeData = RouteData.of(context);
    final pending = routeData.pendingChildren;

    String? id;
    if (pending.isNotEmpty) {
      id = pending.first.params.optString(widget.idParamName);
    }

    _isUpdatingUrl = true;
    if (id != null) {
      _controller.select(id);
    } else if (_controller.hasSelection) {
      _controller.dismiss();
    }
    _isUpdatingUrl = false;
  }

  // ── Controller → URL ──

  void _onControllerChanged() {
    if (_isUpdatingUrl) return;
    _updateUrl();
  }

  void _updateUrl() {
    _isUpdatingUrl = true;

    final routeData = RouteData.of(context);
    final basePath = routeData.match;
    final id = _controller.selectedId;

    final newPath = id != null
        ? widget.pathPrefix != null
              ? '$basePath/${widget.pathPrefix}/$id'
              : '$basePath/$id'
        : basePath;

    context.router.navigatePath(newPath);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdatingUrl = false;
    });
  }

  // ── Selection validation ──

  void _validateSelection() {
    if (widget.selectedIdExists == null) return;
    if (!_controller.hasSelection) return;
    if (!widget.selectedIdExists!(_controller.selectedId!)) {
      // Deferred: this runs from didUpdateWidget (build phase), and dismiss()
      // synchronously drives navigatePath(), which notifies tab routers —
      // setState-during-build if done inline.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.selectedIdExists == null) return;
        if (!_controller.hasSelection) return;
        if (!widget.selectedIdExists!(_controller.selectedId!)) {
          _controller.dismiss();
        }
      });
    }
  }

  @override
  void didUpdateWidget(ListDetailRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateSelection();
  }

  @override
  Widget build(BuildContext context) {
    // Layout configuration comes from the live package settings (⚙ in the
    // status strip) so every mode and knob is testable at runtime.
    final settings = PackageSettings.instance;
    return ListDetailLayout<String>(
      controller: _controller,
      listBuilder: widget.listBuilder,
      detailBuilder: widget.detailBuilder,
      emptyStateBuilder: widget.emptyStateBuilder,
      dividerBuilder: settings.dividerBuilder,
      paneConfig: settings.paneConfig,
      compactConfig: settings.compactConfig,
      compactDetailMode: settings.compactDetailMode,
    );
  }
}

/// Multi-type selection (settings-style screens where the list mixes entity
/// types, each with its own URL prefix and detail builder).
class MultiTypeSelection {
  final String? activeType;
  final String? selectedId;

  const MultiTypeSelection({this.activeType, this.selectedId});

  bool get hasSelection => activeType != null && selectedId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiTypeSelection &&
          activeType == other.activeType &&
          selectedId == other.selectedId;

  @override
  int get hashCode => Object.hash(activeType, selectedId);
}

class ListDetailRouteType {
  final String pathPrefix;
  final String idParamName;
  final DetailPaneBuilder<String> detailBuilder;
  final bool Function(String id)? selectedIdExists;

  const ListDetailRouteType({
    required this.pathPrefix,
    required this.idParamName,
    required this.detailBuilder,
    this.selectedIdExists,
  });
}

typedef MultiTypeListBuilder =
    Widget Function(
      BuildContext context,
      MultiTypeSelection selection,
      void Function(String type, String id) onSelect,
    );

class MultiTypeListDetailRouter extends StatefulWidget {
  final Map<String, ListDetailRouteType> types;
  final MultiTypeListBuilder listBuilder;
  final WidgetBuilder? emptyStateBuilder;

  const MultiTypeListDetailRouter({
    super.key,
    required this.types,
    required this.listBuilder,
    this.emptyStateBuilder,
  });

  @override
  State<MultiTypeListDetailRouter> createState() =>
      _MultiTypeListDetailRouterState();
}

class _MultiTypeListDetailRouterState extends State<MultiTypeListDetailRouter> {
  final _controller = ListDetailController<String>();

  MultiTypeSelection _selection = const MultiTypeSelection();
  bool _isUpdatingUrl = false;
  StackRouter? _router;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newRouter = context.router;
    if (_router != newRouter) {
      _router?.removeListener(_onRouterChanged);
      _router = newRouter;
      newRouter.addListener(_onRouterChanged);
    }

    _syncSelectionFromUrl();
  }

  @override
  void dispose() {
    _router?.removeListener(_onRouterChanged);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _validateSelection() {
    if (!_selection.hasSelection) return;
    final config = widget.types[_selection.activeType];
    if (config?.selectedIdExists == null) return;
    if (!config!.selectedIdExists!(_selection.selectedId!)) {
      // Deferred for the same reason as ListDetailRouter._validateSelection.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_selection.hasSelection) return;
        final config = widget.types[_selection.activeType];
        if (config?.selectedIdExists == null) return;
        if (!config!.selectedIdExists!(_selection.selectedId!)) {
          _controller.dismiss();
        }
      });
    }
  }

  @override
  void didUpdateWidget(MultiTypeListDetailRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateSelection();
  }

  // ── URL → selection ──

  void _onRouterChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSelectionFromUrl();
    });
  }

  void _syncSelectionFromUrl() {
    if (_isUpdatingUrl) return;

    final routeData = RouteData.of(context);
    final pending = routeData.pendingChildren;

    if (pending.isEmpty) {
      if (_selection.hasSelection) {
        _isUpdatingUrl = true;
        _selection = const MultiTypeSelection();
        _controller.dismiss();
        _isUpdatingUrl = false;
        setState(() {});
      }
      return;
    }

    final firstChild = pending.first;
    String? activeType;
    String? selectedId;

    for (final entry in widget.types.entries) {
      final id = firstChild.params.optString(entry.value.idParamName);
      if (id != null) {
        activeType = entry.key;
        selectedId = id;
        break;
      }
    }

    final newSelection = MultiTypeSelection(
      activeType: activeType,
      selectedId: selectedId,
    );

    if (newSelection != _selection) {
      _isUpdatingUrl = true;
      _selection = newSelection;
      if (selectedId != null) {
        _controller.select(selectedId);
      } else {
        _controller.dismiss();
      }
      _isUpdatingUrl = false;
      setState(() {});
    }
  }

  // ── Controller → URL ──

  void _onControllerChanged() {
    if (_isUpdatingUrl) return;

    if (!_controller.hasSelection && _selection.hasSelection) {
      _selection = const MultiTypeSelection();
      _updateUrl();
      setState(() {});
    }
  }

  // ── List selection → URL + controller ──

  void _onListSelect(String type, String id) {
    final newSelection = MultiTypeSelection(activeType: type, selectedId: id);
    if (newSelection == _selection) return;

    _isUpdatingUrl = true;
    _selection = newSelection;
    _controller.select(id);
    _isUpdatingUrl = false;

    _updateUrl();
    setState(() {});
  }

  void _updateUrl() {
    _isUpdatingUrl = true;

    final routeData = RouteData.of(context);
    final basePath = routeData.match;

    final String newPath;
    if (_selection.hasSelection) {
      final config = widget.types[_selection.activeType]!;
      newPath = '$basePath/${config.pathPrefix}/${_selection.selectedId}';
    } else {
      newPath = basePath;
    }

    context.router.navigatePath(newPath);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdatingUrl = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeConfig = _selection.hasSelection
        ? widget.types[_selection.activeType]
        : null;

    final settings = PackageSettings.instance;
    return ListDetailLayout<String>(
      controller: _controller,
      listBuilder: (context, selectedId, onSelect) {
        return widget.listBuilder(context, _selection, _onListSelect);
      },
      detailBuilder: (context, id, mode, onDismiss) {
        if (activeConfig != null) {
          return activeConfig.detailBuilder(context, id, mode, onDismiss);
        }
        return const SizedBox.shrink();
      },
      emptyStateBuilder: widget.emptyStateBuilder,
      dividerBuilder: settings.dividerBuilder,
      paneConfig: settings.paneConfig,
      compactConfig: settings.compactConfig,
      compactDetailMode: settings.compactDetailMode,
    );
  }
}

// =============================================================================
// SHELLS
// =============================================================================

/// Root shell — a persistent zone that sits ABOVE the router, so route swaps
/// and overlay details never cover or remount it.
@RoutePage()
class RootShellScreen extends StatelessWidget {
  const RootShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: const Column(
        children: [
          StatusStrip(),
          Expanded(child: AutoRouter()),
        ],
      ),
    );
  }
}

/// The persistent strip: shows the active deploy when one is running.
/// Rendered outside the nested router, so overlay-mode details (which live in
/// the nested Navigator's overlay) slide UNDER it — that layering is part of
/// the contract being demonstrated.
class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<Item?>(
      valueListenable: Store.instance.deploying,
      builder: (context, build, _) {
        return Material(
          color: colorScheme.surfaceContainerHighest,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    build == null ? Icons.circle : Icons.rocket_launch,
                    size: 14,
                    color: build == null
                        ? colorScheme.outline
                        : colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      build == null
                          ? 'Status strip — always above the router'
                          : 'Deploying ${build.name}…',
                      style: Theme.of(context).textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (build != null)
                    IconButton(
                      icon: const Icon(Icons.stop, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Store.instance.deploying.value = null,
                    ),
                  IconButton(
                    icon: const Icon(Icons.tune, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Package settings',
                    onPressed: () => showPackageSettings(context),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// App shell — domain navigation. Bottom nav on compact, rail on expanded.
/// Overlay-mode details cover the bottom nav naturally; nothing toggles it.
@RoutePage()
class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [WorkDomainRoute(), OpsDomainRoute(), AdminDomainRoute()],
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);

        if (context.isCompact) {
          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: tabsRouter.activeIndex,
              onDestinationSelected: tabsRouter.setActiveIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: 'Work',
                ),
                NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart),
                  label: 'Ops',
                ),
                NavigationDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
              ],
            ),
          );
        }

        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: tabsRouter.activeIndex,
                onDestinationSelected: tabsRouter.setActiveIndex,
                labelType: NavigationRailLabelType.all,
                backgroundColor: colorScheme.surface,
                indicatorColor: colorScheme.primaryContainer,
                minWidth: 72,
                useIndicator: true,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.task_alt_outlined),
                    selectedIcon: Icon(Icons.task_alt),
                    label: Text('Work'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.monitor_heart_outlined),
                    selectedIcon: Icon(Icons.monitor_heart),
                    label: Text('Ops'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    selectedIcon: Icon(Icons.admin_panel_settings),
                    label: Text('Admin'),
                  ),
                ],
              ),
              VerticalDivider(
                thickness: 1,
                width: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// SHARED DEMO WIDGETS
// =============================================================================

class ItemBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const ItemBadge({super.key, required this.icon, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorScheme.secondaryContainer,
      child: Icon(
        icon,
        size: size * 0.5,
        color: colorScheme.onSecondaryContainer,
      ),
    );
  }
}

/// List pane over a live collection: selected-row highlight (expanded only),
/// "new" affordance as a top row (expanded) or FAB (compact).
class DemoListPane extends StatelessWidget {
  final ValueNotifier<List<Item>> collection;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String newLabel;
  final VoidCallback? onNew;
  final IconData emptyIcon;

  const DemoListPane({
    super.key,
    required this.collection,
    required this.selectedId,
    required this.onSelect,
    this.newLabel = 'New',
    this.onNew,
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpandedLayout = context.isExpanded;

    return ValueListenableBuilder<List<Item>>(
      valueListenable: collection,
      builder: (context, items, _) {
        return Scaffold(
          body: Column(
            children: [
              if (isExpandedLayout && onNew != null && items.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.add, color: colorScheme.primary),
                  title: Text(newLabel),
                  onTap: onNew,
                ),
              Expanded(
                child: items.isEmpty
                    ? _EmptyList(icon: emptyIcon, onNew: onNew, label: newLabel)
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final selected =
                              item.id == selectedId && isExpandedLayout;
                          return ListTile(
                            selected: selected,
                            selectedTileColor: colorScheme.primaryContainer
                                .withValues(alpha: 0.35),
                            leading: ItemBadge(icon: item.icon),
                            title: Text(item.name),
                            subtitle: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => onSelect(item.id),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: !isExpandedLayout && onNew != null
              ? FloatingActionButton(
                  onPressed: onNew,
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}

class _EmptyList extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onNew;
  final String label;

  const _EmptyList({required this.icon, this.onNew, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Nothing here yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (onNew != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}

/// Detail pane contract: back arrow when stacked (compact), close X when
/// side-by-side (expanded). Delete exercises selectedIdExists auto-dismiss.
class DemoDetailPane extends StatelessWidget {
  final Item? item;
  final DetailLayoutMode mode;
  final VoidCallback onDismiss;
  final VoidCallback? onDelete;
  final List<Widget> extraActions;

  const DemoDetailPane({
    super.key,
    required this.item,
    required this.mode,
    required this.onDismiss,
    this.onDelete,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolved = item;

    return Scaffold(
      appBar: AppBar(
        leading: mode == DetailLayoutMode.stacked
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onDismiss,
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(resolved?.name ?? 'Missing'),
        actions: [
          ...extraActions,
          if (mode == DetailLayoutMode.sideBySide)
            IconButton(icon: const Icon(Icons.close), onPressed: onDismiss),
        ],
      ),
      body: resolved == null
          ? const Center(child: Text('This entity no longer exists.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: ItemBadge(icon: resolved.icon, size: 88)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    resolved.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Center(
                  child: Text(
                    resolved.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.fingerprint),
                        title: const Text('ID'),
                        subtitle: Text(resolved.id),
                      ),
                      ListTile(
                        leading: const Icon(Icons.layers_outlined),
                        title: const Text('Layout mode'),
                        subtitle: Text(
                          mode == DetailLayoutMode.stacked
                              ? 'stacked — sliding over the list'
                              : 'sideBySide — sharing the width',
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete (auto-dismisses this pane)'),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Empty state for the expanded layout's detail area.
class DemoEmptyPane extends StatelessWidget {
  final IconData icon;
  final String message;

  const DemoEmptyPane({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrolling segment chips (the directory sub-tab bar).
class SegmentChipBar extends StatelessWidget {
  final List<({String label, IconData icon, IconData selectedIcon})> segments;

  const SegmentChipBar({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    // watch: true — subscribes this widget to index changes. Without it a
    // const chip bar never rebuilds, so the highlight freezes on segment 0.
    final tabsRouter = AutoTabsRouter.of(context, watch: true);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _SegmentChip(
                label: segments[i].label,
                icon: segments[i].icon,
                selectedIcon: segments[i].selectedIcon,
                isSelected: tabsRouter.activeIndex == i,
                onTap: () => tabsRouter.setActiveIndex(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 18,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-type list row helper (settings-style grouped lists).
class MultiTypeSection extends StatelessWidget {
  final String title;
  final String type;
  final List<Item> items;
  final MultiTypeSelection selection;
  final void Function(String type, String id) onSelect;

  const MultiTypeSection({
    super.key,
    required this.title,
    required this.type,
    required this.items,
    required this.selection,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpandedLayout = context.isExpanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final item in items)
                ListTile(
                  selected:
                      selection.activeType == type &&
                      selection.selectedId == item.id &&
                      isExpandedLayout,
                  leading: Icon(item.icon),
                  title: Text(item.name),
                  subtitle: Text(item.subtitle),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => onSelect(type, item.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WORK DOMAIN
// =============================================================================

@RoutePage()
class WorkDomainScreen extends StatelessWidget {
  const WorkDomainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DomainTabsRouter(
      routes: const [
        TicketsTabRoute(),
        DirectoryShellRoute(),
        WorkPrefsTabRoute(),
      ],
      tabs: [
        domainTab(icon: Icons.confirmation_number_outlined, label: 'Tickets'),
        domainTab(icon: Icons.folder_shared_outlined, label: 'Directory'),
        domainTab(icon: Icons.tune_outlined, label: 'Prefs'),
      ],
    );
  }
}

@RoutePage()
class TicketsTabScreen extends StatelessWidget {
  const TicketsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;

    return ValueListenableBuilder<List<Item>>(
      valueListenable: store.tickets,
      builder: (context, tickets, _) {
        return ListDetailRouter(
          idParamName: Params.ticketId,
          selectedIdExists: (id) => tickets.any((t) => t.id == id),
          listBuilder: (context, selectedId, onSelect) => DemoListPane(
            collection: store.tickets,
            selectedId: selectedId,
            onSelect: onSelect,
            newLabel: 'New ticket',
            onNew: () async {
              final id = await showAdaptiveModal<String>(
                context: context,
                config: PackageSettings.instance.modalConfig,
                builder: (context, mode) => SizedBox(
                  width: mode == ModalLayoutMode.dialog ? 420 : double.infinity,
                  child: const NewTicketScreen(),
                ),
              );
              if (id != null && context.mounted) {
                context.router.navigatePath('/work/tickets/$id');
              }
            },
            emptyIcon: Icons.confirmation_number_outlined,
          ),
          detailBuilder: (context, id, mode, onDismiss) =>
              TicketPane(ticketId: id, mode: mode, onDismiss: onDismiss),
          emptyStateBuilder: (_) => const DemoEmptyPane(
            icon: Icons.confirmation_number_outlined,
            message: 'Select a ticket',
          ),
        );
      },
    );
  }
}

/// The ticket thread pane. Comment draft + thread live in this State —
/// resize the window across the breakpoint and both survive, because the
/// package reparents the detail subtree via GlobalKey instead of rebuilding.
class TicketPane extends StatefulWidget {
  final String ticketId;
  final DetailLayoutMode mode;
  final VoidCallback onDismiss;

  const TicketPane({
    super.key,
    required this.ticketId,
    required this.mode,
    required this.onDismiss,
  });

  @override
  State<TicketPane> createState() => _TicketPaneState();
}

class _TicketPaneState extends State<TicketPane> {
  final _composer = TextEditingController();
  final List<String> _comments = [
    'Repro attached, happens on every retry.',
    'This pane keeps its state — try resizing the window.',
  ];

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _post() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.add(text);
      _composer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ticket = Store.instance.find(
      Store.instance.tickets.value,
      widget.ticketId,
    );

    return Scaffold(
      appBar: AppBar(
        leading: widget.mode == DetailLayoutMode.stacked
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onDismiss,
              )
            : null,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ItemBadge(
              icon: ticket?.icon ?? Icons.confirmation_number,
              size: 32,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                ticket?.name ?? widget.ticketId,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Ticket options (modal)',
            onPressed: () => showAdaptiveModal<void>(
              context: context,
              config: PackageSettings.instance.modalConfig,
              builder: (context, mode) => SizedBox(
                width: mode == ModalLayoutMode.dialog ? 420 : double.infinity,
                child: TicketOptionsScreen(ticketId: widget.ticketId),
              ),
            ),
          ),
          if (widget.mode == DetailLayoutMode.sideBySide)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onDismiss,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: colorScheme.tertiaryContainer,
                        child: Text(
                          index.isEven ? 'R' : 'N',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_comments[index]),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      decoration: InputDecoration(
                        hintText: 'Add a comment…',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _post(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _post,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// URL-registration stub for /work/tickets/:ticketId. Never materialized —
/// ListDetailRouter reads the pending child route and renders [TicketPane].
@RoutePage()
class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, @PathParam(Params.ticketId) required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class WorkPrefsTabScreen extends StatelessWidget {
  const WorkPrefsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: true,
                onChanged: null,
                title: Text('Desktop notifications'),
                subtitle: Text('Plain settings tab — no list-detail here'),
              ),
              SwitchListTile(
                value: false,
                onChanged: null,
                title: Text('Auto-assign new tickets'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Work modals ──

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _create() {
    final store = Store.instance;
    final title = _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim();
    final id = store.nextId('ticket');
    store.add(
      store.tickets,
      Item(
        id: id,
        name: title,
        subtitle: 'medium · triage',
        icon: Icons.fiber_new_outlined,
      ),
    );
    // Pop with the id as the modal result — the opener navigates. The
    // result future survives any dialog ↔ sheet swaps in between.
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New ticket', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'This modal is a dialog on wide windows and a bottom sheet on '
            'narrow ones — resize while it is open.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('Create ticket'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class TicketOptionsScreen extends StatelessWidget {
  const TicketOptionsScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final ticket = store.find(store.tickets.value, ticketId);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Options — ${ticket?.name ?? ticketId}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: true,
                  onChanged: null,
                  title: Text('Watch ticket'),
                ),
                SwitchListTile(
                  value: false,
                  onChanged: null,
                  title: Text('Pin'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () {
              // Deleting while the ticket is open behind the modal exercises
              // selectedIdExists → the detail pane auto-dismisses.
              store.remove(store.tickets, ticketId);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete ticket'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Directory (nested tab shell, 4 segments, each its own list-detail) ──

@RoutePage()
class DirectoryShellScreen extends StatelessWidget {
  const DirectoryShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DomainTabsRouter(
      routes: const [
        PeopleTabRoute(),
        TeamsTabRoute(),
        LabelsTabRoute(),
        MilestonesTabRoute(),
      ],
      tabBarBuilder: (context, tabController) => const SegmentChipBar(
        segments: [
          (
            label: 'People',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
          ),
          (
            label: 'Teams',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
          ),
          (
            label: 'Labels',
            icon: Icons.label_outline,
            selectedIcon: Icons.label,
          ),
          (
            label: 'Milestones',
            icon: Icons.flag_outlined,
            selectedIcon: Icons.flag,
          ),
        ],
      ),
    );
  }
}

/// One directory segment = one ListDetailRouter over one collection. All four
/// segments stay mounted while you switch — the overlay-suppression case.
class _DirectorySegment extends StatelessWidget {
  final ValueNotifier<List<Item>> collection;
  final String idParamName;
  final String newLabel;
  final IconData newIcon;
  final IconData emptyIcon;

  const _DirectorySegment({
    required this.collection,
    required this.idParamName,
    required this.newLabel,
    required this.newIcon,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;

    return ValueListenableBuilder<List<Item>>(
      valueListenable: collection,
      builder: (context, items, _) {
        return ListDetailRouter(
          idParamName: idParamName,
          selectedIdExists: (id) => items.any((i) => i.id == id),
          listBuilder: (context, selectedId, onSelect) => DemoListPane(
            collection: collection,
            selectedId: selectedId,
            onSelect: onSelect,
            newLabel: newLabel,
            onNew: () {
              final id = store.nextId(idParamName);
              store.add(
                collection,
                Item(
                  id: id,
                  name: 'Fresh ${id.split('-').last}',
                  subtitle: 'Just created',
                  icon: newIcon,
                ),
              );
            },
            emptyIcon: emptyIcon,
          ),
          detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
            item: store.find(collection.value, id),
            mode: mode,
            onDismiss: onDismiss,
            onDelete: () => store.remove(collection, id),
          ),
          emptyStateBuilder: (_) =>
              DemoEmptyPane(icon: emptyIcon, message: 'Select an item'),
        );
      },
    );
  }
}

@RoutePage()
class PeopleTabScreen extends StatelessWidget {
  const PeopleTabScreen({super.key});

  @override
  Widget build(BuildContext context) => _DirectorySegment(
    collection: Store.instance.people,
    idParamName: Params.personId,
    newLabel: 'Invite person',
    newIcon: Icons.person_add_outlined,
    emptyIcon: Icons.person_outline,
  );
}

@RoutePage()
class TeamsTabScreen extends StatelessWidget {
  const TeamsTabScreen({super.key});

  @override
  Widget build(BuildContext context) => _DirectorySegment(
    collection: Store.instance.teams,
    idParamName: Params.teamId,
    newLabel: 'New team',
    newIcon: Icons.group_add_outlined,
    emptyIcon: Icons.groups_outlined,
  );
}

@RoutePage()
class LabelsTabScreen extends StatelessWidget {
  const LabelsTabScreen({super.key});

  @override
  Widget build(BuildContext context) => _DirectorySegment(
    collection: Store.instance.labels,
    idParamName: Params.labelId,
    newLabel: 'New label',
    newIcon: Icons.new_label_outlined,
    emptyIcon: Icons.label_outline,
  );
}

@RoutePage()
class MilestonesTabScreen extends StatelessWidget {
  const MilestonesTabScreen({super.key});

  @override
  Widget build(BuildContext context) => _DirectorySegment(
    collection: Store.instance.milestones,
    idParamName: Params.milestoneId,
    newLabel: 'New milestone',
    newIcon: Icons.outlined_flag,
    emptyIcon: Icons.flag_outlined,
  );
}

// URL-registration stubs for the directory detail routes.

@RoutePage()
class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({
    super.key,
    @PathParam(Params.personId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class TeamDetailScreen extends StatelessWidget {
  const TeamDetailScreen({
    super.key,
    @PathParam(Params.teamId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class LabelDetailScreen extends StatelessWidget {
  const LabelDetailScreen({
    super.key,
    @PathParam(Params.labelId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class MilestoneDetailScreen extends StatelessWidget {
  const MilestoneDetailScreen({
    super.key,
    @PathParam(Params.milestoneId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// =============================================================================
// OPS DOMAIN
// =============================================================================

@RoutePage()
class OpsDomainScreen extends StatelessWidget {
  const OpsDomainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DomainTabsRouter(
      routes: const [MonitorTabRoute(), RunsShellRoute(), SetupTabRoute()],
      tabs: [
        domainTab(icon: Icons.monitor_heart_outlined, label: 'Monitor'),
        domainTab(icon: Icons.play_circle_outline, label: 'Runs'),
        domainTab(icon: Icons.tune_outlined, label: 'Setup'),
      ],
    );
  }
}

/// Full-screen tab (no list-detail). Starting a deploy feeds the persistent
/// status strip at the top of the app.
@RoutePage()
class MonitorTabScreen extends StatelessWidget {
  const MonitorTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final store = Store.instance;

    return ValueListenableBuilder<Item?>(
      valueListenable: store.deploying,
      builder: (context, build, _) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  build == null
                      ? Icons.cloud_done_outlined
                      : Icons.rocket_launch,
                  size: 96,
                  color: build == null
                      ? colorScheme.outline
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                build == null
                    ? 'Idle — no active deploy'
                    : 'Deploying ${build.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                build == null
                    ? 'Start a deploy to feed the status strip'
                    : build.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  store.deploying.value = build == null
                      ? store.builds.value.first
                      : null;
                },
                icon: Icon(build == null ? Icons.rocket_launch : Icons.stop),
                label: Text(build == null ? 'Deploy latest build' : 'Abort'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Extra nested tab layer: the runs shell currently hosts a single sub-tab,
/// mirroring a shell that will grow more segments later.
@RoutePage()
class RunsShellScreen extends StatelessWidget {
  const RunsShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [BuildsTabRoute()],
      builder: (context, child) => child,
    );
  }
}

@RoutePage()
class BuildsTabScreen extends StatelessWidget {
  const BuildsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;

    return ValueListenableBuilder<List<Item>>(
      valueListenable: store.builds,
      builder: (context, builds, _) {
        return ListDetailRouter(
          idParamName: Params.buildId,
          selectedIdExists: (id) => builds.any((b) => b.id == id),
          listBuilder: (context, selectedId, onSelect) => DemoListPane(
            collection: store.builds,
            selectedId: selectedId,
            onSelect: onSelect,
            newLabel: 'Trigger build',
            onNew: () {
              final id = store.nextId('build');
              store.add(
                store.builds,
                Item(
                  id: id,
                  name: 'Build #${400 + int.parse(id.split('-').last)}',
                  subtitle: 'main · queued',
                  icon: Icons.pending_outlined,
                ),
              );
            },
            emptyIcon: Icons.play_circle_outline,
          ),
          detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
            item: store.find(store.builds.value, id),
            mode: mode,
            onDismiss: onDismiss,
            onDelete: () => store.remove(store.builds, id),
            extraActions: [
              IconButton(
                icon: const Icon(Icons.rocket_launch_outlined),
                tooltip: 'Deploy (feeds the status strip)',
                onPressed: () {
                  Store.instance.deploying.value = store.find(
                    store.builds.value,
                    id,
                  );
                },
              ),
            ],
          ),
          emptyStateBuilder: (_) => const DemoEmptyPane(
            icon: Icons.play_circle_outline,
            message: 'Select a build',
          ),
        );
      },
    );
  }
}

@RoutePage()
class BuildDetailScreen extends StatelessWidget {
  const BuildDetailScreen({
    super.key,
    @PathParam(Params.buildId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Multi-type list-detail: one list mixing three entity types (pipelines,
/// runner settings, cache settings), each with its own URL prefix.
@RoutePage()
class SetupTabScreen extends StatelessWidget {
  const SetupTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;

    return ValueListenableBuilder<List<Item>>(
      valueListenable: store.pipelines,
      builder: (context, pipelines, _) {
        return MultiTypeListDetailRouter(
          emptyStateBuilder: (_) => const DemoEmptyPane(
            icon: Icons.tune_outlined,
            message: 'Select a setting',
          ),
          types: {
            Paths.pipeline: ListDetailRouteType(
              pathPrefix: Paths.pipeline,
              idParamName: Params.pipelineId,
              selectedIdExists: (id) => pipelines.any((p) => p.id == id),
              detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
                item: store.find(store.pipelines.value, id),
                mode: mode,
                onDismiss: onDismiss,
                onDelete: () => store.remove(store.pipelines, id),
              ),
            ),
            Paths.runner: ListDetailRouteType(
              pathPrefix: Paths.runner,
              idParamName: Params.runnerId,
              detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
                item: store.find(Store.runners, id),
                mode: mode,
                onDismiss: onDismiss,
              ),
            ),
            Paths.cache: ListDetailRouteType(
              pathPrefix: Paths.cache,
              idParamName: Params.cacheId,
              detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
                item: store.find(Store.caches, id),
                mode: mode,
                onDismiss: onDismiss,
              ),
            ),
          },
          listBuilder: (context, selection, onSelect) => ListView(
            children: [
              MultiTypeSection(
                title: 'Pipelines',
                type: Paths.pipeline,
                items: pipelines,
                selection: selection,
                onSelect: onSelect,
              ),
              MultiTypeSection(
                title: 'Runners',
                type: Paths.runner,
                items: Store.runners,
                selection: selection,
                onSelect: onSelect,
              ),
              MultiTypeSection(
                title: 'Caches',
                type: Paths.cache,
                items: Store.caches,
                selection: selection,
                onSelect: onSelect,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// URL-registration stubs for the ops setup detail routes.

@RoutePage()
class PipelineDetailScreen extends StatelessWidget {
  const PipelineDetailScreen({
    super.key,
    @PathParam(Params.pipelineId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class RunnerDetailScreen extends StatelessWidget {
  const RunnerDetailScreen({
    super.key,
    @PathParam(Params.runnerId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class CacheDetailScreen extends StatelessWidget {
  const CacheDetailScreen({
    super.key,
    @PathParam(Params.cacheId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// =============================================================================
// ADMIN DOMAIN — four tabs, each a multi-type list-detail
// =============================================================================

@RoutePage()
class AdminDomainScreen extends StatelessWidget {
  const AdminDomainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DomainTabsRouter(
      routes: const [
        WorkspaceTabRoute(),
        IntegrationsTabRoute(),
        AppearanceTabRoute(),
        AdvancedTabRoute(),
      ],
      tabs: [
        domainTab(icon: Icons.business_outlined, label: 'Workspace'),
        domainTab(icon: Icons.extension_outlined, label: 'Integrations'),
        domainTab(icon: Icons.palette_outlined, label: 'Appearance'),
        domainTab(icon: Icons.settings_suggest_outlined, label: 'Advanced'),
      ],
    );
  }
}

@RoutePage()
class WorkspaceTabScreen extends StatelessWidget {
  const WorkspaceTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;

    return MultiTypeListDetailRouter(
      emptyStateBuilder: (_) => const DemoEmptyPane(
        icon: Icons.business_outlined,
        message: 'Select a workspace item',
      ),
      types: {
        Paths.workspace: ListDetailRouteType(
          pathPrefix: Paths.workspace,
          idParamName: Params.workspaceId,
          detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
            item: store.find(store.workspaces.value, id),
            mode: mode,
            onDismiss: onDismiss,
          ),
        ),
        Paths.member: ListDetailRouteType(
          pathPrefix: Paths.member,
          idParamName: Params.memberId,
          detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
            item: store.find(store.members.value, id),
            mode: mode,
            onDismiss: onDismiss,
          ),
        ),
        Paths.session: ListDetailRouteType(
          pathPrefix: Paths.session,
          idParamName: Params.sessionId,
          detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
            item: store.find(Store.sessions, id),
            mode: mode,
            onDismiss: onDismiss,
          ),
        ),
      },
      listBuilder: (context, selection, onSelect) => ListView(
        children: [
          MultiTypeSection(
            title: 'Workspaces',
            type: Paths.workspace,
            items: store.workspaces.value,
            selection: selection,
            onSelect: onSelect,
          ),
          MultiTypeSection(
            title: 'Members',
            type: Paths.member,
            items: store.members.value,
            selection: selection,
            onSelect: onSelect,
          ),
          MultiTypeSection(
            title: 'Account',
            type: Paths.session,
            items: Store.sessions,
            selection: selection,
            onSelect: onSelect,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

@RoutePage()
class IntegrationsTabScreen extends StatelessWidget {
  const IntegrationsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;

    return ValueListenableBuilder<List<Item>>(
      valueListenable: store.services,
      builder: (context, services, _) {
        return MultiTypeListDetailRouter(
          emptyStateBuilder: (_) => const DemoEmptyPane(
            icon: Icons.extension_outlined,
            message: 'Select an integration',
          ),
          types: {
            Paths.service: ListDetailRouteType(
              pathPrefix: Paths.service,
              idParamName: Params.serviceId,
              selectedIdExists: (id) => services.any((s) => s.id == id),
              detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
                item: store.find(store.services.value, id),
                mode: mode,
                onDismiss: onDismiss,
                onDelete: () => store.remove(store.services, id),
              ),
            ),
            Paths.webhook: ListDetailRouteType(
              pathPrefix: Paths.webhook,
              idParamName: Params.webhookId,
              detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
                item: store.find(store.webhooks.value, id),
                mode: mode,
                onDismiss: onDismiss,
              ),
            ),
            Paths.token: ListDetailRouteType(
              pathPrefix: Paths.token,
              idParamName: Params.tokenId,
              detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
                item: store.find(store.tokens.value, id),
                mode: mode,
                onDismiss: onDismiss,
              ),
            ),
            Paths.agent: ListDetailRouteType(
              pathPrefix: Paths.agent,
              idParamName: Params.agentId,
              detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
                item: store.find(store.agents.value, id),
                mode: mode,
                onDismiss: onDismiss,
              ),
            ),
          },
          listBuilder: (context, selection, onSelect) => ListView(
            children: [
              MultiTypeSection(
                title: 'Services',
                type: Paths.service,
                items: services,
                selection: selection,
                onSelect: onSelect,
              ),
              MultiTypeSection(
                title: 'Webhooks',
                type: Paths.webhook,
                items: store.webhooks.value,
                selection: selection,
                onSelect: onSelect,
              ),
              MultiTypeSection(
                title: 'Tokens',
                type: Paths.token,
                items: store.tokens.value,
                selection: selection,
                onSelect: onSelect,
              ),
              MultiTypeSection(
                title: 'Agents',
                type: Paths.agent,
                items: store.agents.value,
                selection: selection,
                onSelect: onSelect,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

@RoutePage()
class AppearanceTabScreen extends StatelessWidget {
  const AppearanceTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiTypeListDetailRouter(
      emptyStateBuilder: (_) => const DemoEmptyPane(
        icon: Icons.palette_outlined,
        message: 'Select a setting',
      ),
      types: {
        Paths.preference: ListDetailRouteType(
          pathPrefix: Paths.preference,
          idParamName: Params.preferenceId,
          detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
            item: Store.instance.find(Store.preferences, id),
            mode: mode,
            onDismiss: onDismiss,
          ),
        ),
      },
      listBuilder: (context, selection, onSelect) => ListView(
        children: [
          MultiTypeSection(
            title: 'Appearance',
            type: Paths.preference,
            items: Store.preferences,
            selection: selection,
            onSelect: onSelect,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

@RoutePage()
class AdvancedTabScreen extends StatelessWidget {
  const AdvancedTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiTypeListDetailRouter(
      emptyStateBuilder: (_) => const DemoEmptyPane(
        icon: Icons.settings_suggest_outlined,
        message: 'Select an item',
      ),
      types: {
        Paths.server: ListDetailRouteType(
          pathPrefix: Paths.server,
          idParamName: Params.serverId,
          detailBuilder: (context, id, mode, onDismiss) => DemoDetailPane(
            item: Store.instance.find(Store.servers, id),
            mode: mode,
            onDismiss: onDismiss,
          ),
        ),
      },
      listBuilder: (context, selection, onSelect) => ListView(
        children: [
          MultiTypeSection(
            title: 'Infrastructure',
            type: Paths.server,
            items: Store.servers,
            selection: selection,
            onSelect: onSelect,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// URL-registration stubs for the admin detail routes.

@RoutePage()
class WorkspaceDetailScreen extends StatelessWidget {
  const WorkspaceDetailScreen({
    super.key,
    @PathParam(Params.workspaceId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({
    super.key,
    @PathParam(Params.memberId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({
    super.key,
    @PathParam(Params.sessionId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({
    super.key,
    @PathParam(Params.serviceId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class WebhookDetailScreen extends StatelessWidget {
  const WebhookDetailScreen({
    super.key,
    @PathParam(Params.webhookId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class TokenDetailScreen extends StatelessWidget {
  const TokenDetailScreen({
    super.key,
    @PathParam(Params.tokenId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class AgentDetailScreen extends StatelessWidget {
  const AgentDetailScreen({
    super.key,
    @PathParam(Params.agentId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class PreferenceDetailScreen extends StatelessWidget {
  const PreferenceDetailScreen({
    super.key,
    @PathParam(Params.preferenceId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@RoutePage()
class ServerDetailScreen extends StatelessWidget {
  const ServerDetailScreen({
    super.key,
    @PathParam(Params.serverId) required this.id,
  });
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
