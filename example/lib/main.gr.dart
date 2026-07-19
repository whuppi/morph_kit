// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'main.dart';

/// generated route for
/// [AdminDomainScreen]
class AdminDomainRoute extends PageRouteInfo<void> {
  const AdminDomainRoute({List<PageRouteInfo>? children})
    : super(AdminDomainRoute.name, initialChildren: children);

  static const String name = 'AdminDomainRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AdminDomainScreen();
    },
  );
}

/// generated route for
/// [AdvancedTabScreen]
class AdvancedTabRoute extends PageRouteInfo<void> {
  const AdvancedTabRoute({List<PageRouteInfo>? children})
    : super(AdvancedTabRoute.name, initialChildren: children);

  static const String name = 'AdvancedTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AdvancedTabScreen();
    },
  );
}

/// generated route for
/// [AgentDetailScreen]
class AgentDetailRoute extends PageRouteInfo<AgentDetailRouteArgs> {
  AgentDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         AgentDetailRoute.name,
         args: AgentDetailRouteArgs(key: key, id: id),
         rawPathParams: {'agentId': id},
         initialChildren: children,
       );

  static const String name = 'AgentDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<AgentDetailRouteArgs>(
        orElse: () => AgentDetailRouteArgs(id: pathParams.getString('agentId')),
      );
      return AgentDetailScreen(key: args.key, id: args.id);
    },
  );
}

class AgentDetailRouteArgs {
  const AgentDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'AgentDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AgentDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [AppShellScreen]
class AppShellRoute extends PageRouteInfo<void> {
  const AppShellRoute({List<PageRouteInfo>? children})
    : super(AppShellRoute.name, initialChildren: children);

  static const String name = 'AppShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AppShellScreen();
    },
  );
}

/// generated route for
/// [AppearanceTabScreen]
class AppearanceTabRoute extends PageRouteInfo<void> {
  const AppearanceTabRoute({List<PageRouteInfo>? children})
    : super(AppearanceTabRoute.name, initialChildren: children);

  static const String name = 'AppearanceTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AppearanceTabScreen();
    },
  );
}

/// generated route for
/// [BuildDetailScreen]
class BuildDetailRoute extends PageRouteInfo<BuildDetailRouteArgs> {
  BuildDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         BuildDetailRoute.name,
         args: BuildDetailRouteArgs(key: key, id: id),
         rawPathParams: {'buildId': id},
         initialChildren: children,
       );

  static const String name = 'BuildDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<BuildDetailRouteArgs>(
        orElse: () => BuildDetailRouteArgs(id: pathParams.getString('buildId')),
      );
      return BuildDetailScreen(key: args.key, id: args.id);
    },
  );
}

class BuildDetailRouteArgs {
  const BuildDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'BuildDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BuildDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [BuildsTabScreen]
class BuildsTabRoute extends PageRouteInfo<void> {
  const BuildsTabRoute({List<PageRouteInfo>? children})
    : super(BuildsTabRoute.name, initialChildren: children);

  static const String name = 'BuildsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const BuildsTabScreen();
    },
  );
}

/// generated route for
/// [CacheDetailScreen]
class CacheDetailRoute extends PageRouteInfo<CacheDetailRouteArgs> {
  CacheDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         CacheDetailRoute.name,
         args: CacheDetailRouteArgs(key: key, id: id),
         rawPathParams: {'cacheId': id},
         initialChildren: children,
       );

  static const String name = 'CacheDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<CacheDetailRouteArgs>(
        orElse: () => CacheDetailRouteArgs(id: pathParams.getString('cacheId')),
      );
      return CacheDetailScreen(key: args.key, id: args.id);
    },
  );
}

class CacheDetailRouteArgs {
  const CacheDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'CacheDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CacheDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [DirectoryShellScreen]
class DirectoryShellRoute extends PageRouteInfo<void> {
  const DirectoryShellRoute({List<PageRouteInfo>? children})
    : super(DirectoryShellRoute.name, initialChildren: children);

  static const String name = 'DirectoryShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DirectoryShellScreen();
    },
  );
}

/// generated route for
/// [IntegrationsTabScreen]
class IntegrationsTabRoute extends PageRouteInfo<void> {
  const IntegrationsTabRoute({List<PageRouteInfo>? children})
    : super(IntegrationsTabRoute.name, initialChildren: children);

  static const String name = 'IntegrationsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const IntegrationsTabScreen();
    },
  );
}

/// generated route for
/// [LabelDetailScreen]
class LabelDetailRoute extends PageRouteInfo<LabelDetailRouteArgs> {
  LabelDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         LabelDetailRoute.name,
         args: LabelDetailRouteArgs(key: key, id: id),
         rawPathParams: {'labelId': id},
         initialChildren: children,
       );

  static const String name = 'LabelDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<LabelDetailRouteArgs>(
        orElse: () => LabelDetailRouteArgs(id: pathParams.getString('labelId')),
      );
      return LabelDetailScreen(key: args.key, id: args.id);
    },
  );
}

class LabelDetailRouteArgs {
  const LabelDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'LabelDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LabelDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [LabelsTabScreen]
class LabelsTabRoute extends PageRouteInfo<void> {
  const LabelsTabRoute({List<PageRouteInfo>? children})
    : super(LabelsTabRoute.name, initialChildren: children);

  static const String name = 'LabelsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LabelsTabScreen();
    },
  );
}

/// generated route for
/// [MemberDetailScreen]
class MemberDetailRoute extends PageRouteInfo<MemberDetailRouteArgs> {
  MemberDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         MemberDetailRoute.name,
         args: MemberDetailRouteArgs(key: key, id: id),
         rawPathParams: {'memberId': id},
         initialChildren: children,
       );

  static const String name = 'MemberDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<MemberDetailRouteArgs>(
        orElse: () =>
            MemberDetailRouteArgs(id: pathParams.getString('memberId')),
      );
      return MemberDetailScreen(key: args.key, id: args.id);
    },
  );
}

class MemberDetailRouteArgs {
  const MemberDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'MemberDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MemberDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [MilestoneDetailScreen]
class MilestoneDetailRoute extends PageRouteInfo<MilestoneDetailRouteArgs> {
  MilestoneDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         MilestoneDetailRoute.name,
         args: MilestoneDetailRouteArgs(key: key, id: id),
         rawPathParams: {'milestoneId': id},
         initialChildren: children,
       );

  static const String name = 'MilestoneDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<MilestoneDetailRouteArgs>(
        orElse: () =>
            MilestoneDetailRouteArgs(id: pathParams.getString('milestoneId')),
      );
      return MilestoneDetailScreen(key: args.key, id: args.id);
    },
  );
}

class MilestoneDetailRouteArgs {
  const MilestoneDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'MilestoneDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MilestoneDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [MilestonesTabScreen]
class MilestonesTabRoute extends PageRouteInfo<void> {
  const MilestonesTabRoute({List<PageRouteInfo>? children})
    : super(MilestonesTabRoute.name, initialChildren: children);

  static const String name = 'MilestonesTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MilestonesTabScreen();
    },
  );
}

/// generated route for
/// [MonitorTabScreen]
class MonitorTabRoute extends PageRouteInfo<void> {
  const MonitorTabRoute({List<PageRouteInfo>? children})
    : super(MonitorTabRoute.name, initialChildren: children);

  static const String name = 'MonitorTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MonitorTabScreen();
    },
  );
}

/// generated route for
/// [OpsDomainScreen]
class OpsDomainRoute extends PageRouteInfo<void> {
  const OpsDomainRoute({List<PageRouteInfo>? children})
    : super(OpsDomainRoute.name, initialChildren: children);

  static const String name = 'OpsDomainRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const OpsDomainScreen();
    },
  );
}

/// generated route for
/// [PeopleTabScreen]
class PeopleTabRoute extends PageRouteInfo<void> {
  const PeopleTabRoute({List<PageRouteInfo>? children})
    : super(PeopleTabRoute.name, initialChildren: children);

  static const String name = 'PeopleTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PeopleTabScreen();
    },
  );
}

/// generated route for
/// [PersonDetailScreen]
class PersonDetailRoute extends PageRouteInfo<PersonDetailRouteArgs> {
  PersonDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         PersonDetailRoute.name,
         args: PersonDetailRouteArgs(key: key, id: id),
         rawPathParams: {'personId': id},
         initialChildren: children,
       );

  static const String name = 'PersonDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PersonDetailRouteArgs>(
        orElse: () =>
            PersonDetailRouteArgs(id: pathParams.getString('personId')),
      );
      return PersonDetailScreen(key: args.key, id: args.id);
    },
  );
}

class PersonDetailRouteArgs {
  const PersonDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'PersonDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PersonDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [PipelineDetailScreen]
class PipelineDetailRoute extends PageRouteInfo<PipelineDetailRouteArgs> {
  PipelineDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         PipelineDetailRoute.name,
         args: PipelineDetailRouteArgs(key: key, id: id),
         rawPathParams: {'pipelineId': id},
         initialChildren: children,
       );

  static const String name = 'PipelineDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PipelineDetailRouteArgs>(
        orElse: () =>
            PipelineDetailRouteArgs(id: pathParams.getString('pipelineId')),
      );
      return PipelineDetailScreen(key: args.key, id: args.id);
    },
  );
}

class PipelineDetailRouteArgs {
  const PipelineDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'PipelineDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PipelineDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [PreferenceDetailScreen]
class PreferenceDetailRoute extends PageRouteInfo<PreferenceDetailRouteArgs> {
  PreferenceDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         PreferenceDetailRoute.name,
         args: PreferenceDetailRouteArgs(key: key, id: id),
         rawPathParams: {'preferenceId': id},
         initialChildren: children,
       );

  static const String name = 'PreferenceDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PreferenceDetailRouteArgs>(
        orElse: () =>
            PreferenceDetailRouteArgs(id: pathParams.getString('preferenceId')),
      );
      return PreferenceDetailScreen(key: args.key, id: args.id);
    },
  );
}

class PreferenceDetailRouteArgs {
  const PreferenceDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'PreferenceDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PreferenceDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [RootShellScreen]
class RootShellRoute extends PageRouteInfo<void> {
  const RootShellRoute({List<PageRouteInfo>? children})
    : super(RootShellRoute.name, initialChildren: children);

  static const String name = 'RootShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RootShellScreen();
    },
  );
}

/// generated route for
/// [RunnerDetailScreen]
class RunnerDetailRoute extends PageRouteInfo<RunnerDetailRouteArgs> {
  RunnerDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         RunnerDetailRoute.name,
         args: RunnerDetailRouteArgs(key: key, id: id),
         rawPathParams: {'runnerId': id},
         initialChildren: children,
       );

  static const String name = 'RunnerDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<RunnerDetailRouteArgs>(
        orElse: () =>
            RunnerDetailRouteArgs(id: pathParams.getString('runnerId')),
      );
      return RunnerDetailScreen(key: args.key, id: args.id);
    },
  );
}

class RunnerDetailRouteArgs {
  const RunnerDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'RunnerDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RunnerDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [RunsShellScreen]
class RunsShellRoute extends PageRouteInfo<void> {
  const RunsShellRoute({List<PageRouteInfo>? children})
    : super(RunsShellRoute.name, initialChildren: children);

  static const String name = 'RunsShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RunsShellScreen();
    },
  );
}

/// generated route for
/// [ServerDetailScreen]
class ServerDetailRoute extends PageRouteInfo<ServerDetailRouteArgs> {
  ServerDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         ServerDetailRoute.name,
         args: ServerDetailRouteArgs(key: key, id: id),
         rawPathParams: {'serverId': id},
         initialChildren: children,
       );

  static const String name = 'ServerDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ServerDetailRouteArgs>(
        orElse: () =>
            ServerDetailRouteArgs(id: pathParams.getString('serverId')),
      );
      return ServerDetailScreen(key: args.key, id: args.id);
    },
  );
}

class ServerDetailRouteArgs {
  const ServerDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'ServerDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ServerDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [ServiceDetailScreen]
class ServiceDetailRoute extends PageRouteInfo<ServiceDetailRouteArgs> {
  ServiceDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         ServiceDetailRoute.name,
         args: ServiceDetailRouteArgs(key: key, id: id),
         rawPathParams: {'serviceId': id},
         initialChildren: children,
       );

  static const String name = 'ServiceDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ServiceDetailRouteArgs>(
        orElse: () =>
            ServiceDetailRouteArgs(id: pathParams.getString('serviceId')),
      );
      return ServiceDetailScreen(key: args.key, id: args.id);
    },
  );
}

class ServiceDetailRouteArgs {
  const ServiceDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'ServiceDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ServiceDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [SessionDetailScreen]
class SessionDetailRoute extends PageRouteInfo<SessionDetailRouteArgs> {
  SessionDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         SessionDetailRoute.name,
         args: SessionDetailRouteArgs(key: key, id: id),
         rawPathParams: {'sessionId': id},
         initialChildren: children,
       );

  static const String name = 'SessionDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<SessionDetailRouteArgs>(
        orElse: () =>
            SessionDetailRouteArgs(id: pathParams.getString('sessionId')),
      );
      return SessionDetailScreen(key: args.key, id: args.id);
    },
  );
}

class SessionDetailRouteArgs {
  const SessionDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'SessionDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [SetupTabScreen]
class SetupTabRoute extends PageRouteInfo<void> {
  const SetupTabRoute({List<PageRouteInfo>? children})
    : super(SetupTabRoute.name, initialChildren: children);

  static const String name = 'SetupTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SetupTabScreen();
    },
  );
}

/// generated route for
/// [TeamDetailScreen]
class TeamDetailRoute extends PageRouteInfo<TeamDetailRouteArgs> {
  TeamDetailRoute({Key? key, required String id, List<PageRouteInfo>? children})
    : super(
        TeamDetailRoute.name,
        args: TeamDetailRouteArgs(key: key, id: id),
        rawPathParams: {'teamId': id},
        initialChildren: children,
      );

  static const String name = 'TeamDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<TeamDetailRouteArgs>(
        orElse: () => TeamDetailRouteArgs(id: pathParams.getString('teamId')),
      );
      return TeamDetailScreen(key: args.key, id: args.id);
    },
  );
}

class TeamDetailRouteArgs {
  const TeamDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'TeamDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TeamDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [TeamsTabScreen]
class TeamsTabRoute extends PageRouteInfo<void> {
  const TeamsTabRoute({List<PageRouteInfo>? children})
    : super(TeamsTabRoute.name, initialChildren: children);

  static const String name = 'TeamsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TeamsTabScreen();
    },
  );
}

/// generated route for
/// [TicketScreen]
class TicketRoute extends PageRouteInfo<TicketRouteArgs> {
  TicketRoute({Key? key, required String id, List<PageRouteInfo>? children})
    : super(
        TicketRoute.name,
        args: TicketRouteArgs(key: key, id: id),
        rawPathParams: {'ticketId': id},
        initialChildren: children,
      );

  static const String name = 'TicketRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<TicketRouteArgs>(
        orElse: () => TicketRouteArgs(id: pathParams.getString('ticketId')),
      );
      return TicketScreen(key: args.key, id: args.id);
    },
  );
}

class TicketRouteArgs {
  const TicketRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'TicketRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TicketRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [TicketsTabScreen]
class TicketsTabRoute extends PageRouteInfo<void> {
  const TicketsTabRoute({List<PageRouteInfo>? children})
    : super(TicketsTabRoute.name, initialChildren: children);

  static const String name = 'TicketsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TicketsTabScreen();
    },
  );
}

/// generated route for
/// [TokenDetailScreen]
class TokenDetailRoute extends PageRouteInfo<TokenDetailRouteArgs> {
  TokenDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         TokenDetailRoute.name,
         args: TokenDetailRouteArgs(key: key, id: id),
         rawPathParams: {'tokenId': id},
         initialChildren: children,
       );

  static const String name = 'TokenDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<TokenDetailRouteArgs>(
        orElse: () => TokenDetailRouteArgs(id: pathParams.getString('tokenId')),
      );
      return TokenDetailScreen(key: args.key, id: args.id);
    },
  );
}

class TokenDetailRouteArgs {
  const TokenDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'TokenDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TokenDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [WebhookDetailScreen]
class WebhookDetailRoute extends PageRouteInfo<WebhookDetailRouteArgs> {
  WebhookDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         WebhookDetailRoute.name,
         args: WebhookDetailRouteArgs(key: key, id: id),
         rawPathParams: {'webhookId': id},
         initialChildren: children,
       );

  static const String name = 'WebhookDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<WebhookDetailRouteArgs>(
        orElse: () =>
            WebhookDetailRouteArgs(id: pathParams.getString('webhookId')),
      );
      return WebhookDetailScreen(key: args.key, id: args.id);
    },
  );
}

class WebhookDetailRouteArgs {
  const WebhookDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'WebhookDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WebhookDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [WorkDomainScreen]
class WorkDomainRoute extends PageRouteInfo<void> {
  const WorkDomainRoute({List<PageRouteInfo>? children})
    : super(WorkDomainRoute.name, initialChildren: children);

  static const String name = 'WorkDomainRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const WorkDomainScreen();
    },
  );
}

/// generated route for
/// [WorkPrefsTabScreen]
class WorkPrefsTabRoute extends PageRouteInfo<void> {
  const WorkPrefsTabRoute({List<PageRouteInfo>? children})
    : super(WorkPrefsTabRoute.name, initialChildren: children);

  static const String name = 'WorkPrefsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const WorkPrefsTabScreen();
    },
  );
}

/// generated route for
/// [WorkspaceDetailScreen]
class WorkspaceDetailRoute extends PageRouteInfo<WorkspaceDetailRouteArgs> {
  WorkspaceDetailRoute({
    Key? key,
    required String id,
    List<PageRouteInfo>? children,
  }) : super(
         WorkspaceDetailRoute.name,
         args: WorkspaceDetailRouteArgs(key: key, id: id),
         rawPathParams: {'workspaceId': id},
         initialChildren: children,
       );

  static const String name = 'WorkspaceDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<WorkspaceDetailRouteArgs>(
        orElse: () =>
            WorkspaceDetailRouteArgs(id: pathParams.getString('workspaceId')),
      );
      return WorkspaceDetailScreen(key: args.key, id: args.id);
    },
  );
}

class WorkspaceDetailRouteArgs {
  const WorkspaceDetailRouteArgs({this.key, required this.id});

  final Key? key;

  final String id;

  @override
  String toString() {
    return 'WorkspaceDetailRouteArgs{key: $key, id: $id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WorkspaceDetailRouteArgs) return false;
    return key == other.key && id == other.id;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode;
}

/// generated route for
/// [WorkspaceTabScreen]
class WorkspaceTabRoute extends PageRouteInfo<void> {
  const WorkspaceTabRoute({List<PageRouteInfo>? children})
    : super(WorkspaceTabRoute.name, initialChildren: children);

  static const String name = 'WorkspaceTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const WorkspaceTabScreen();
    },
  );
}
