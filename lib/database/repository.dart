import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'domains/base_repository.dart';
import 'domains/sync_queue_domain.dart';
import 'domains/people_domain.dart';
import 'domains/visits_domain.dart';
import 'domains/studies_domain.dart';
import 'domains/appointments_domain.dart';
import 'domains/activities_domain.dart';
import 'domains/trash_domain.dart';

export 'domains/base_repository.dart';
export 'domains/sync_queue_domain.dart';
export 'domains/people_domain.dart';
export 'domains/visits_domain.dart';
export 'domains/studies_domain.dart';
export 'domains/appointments_domain.dart';
export 'domains/activities_domain.dart';
export 'domains/trash_domain.dart';

/// Repositório canônico unificado do aplicativo.
/// Composto através de mixins de domínio desacoplados sobre o BaseRepository Drift.
class AppRepository extends BaseRepository
    with
        SyncQueueDomainMixin,
        PeopleDomainMixin,
        VisitsDomainMixin,
        StudiesDomainMixin,
        AppointmentsDomainMixin,
        ActivitiesDomainMixin,
        TrashDomainMixin {
  @override
  final AppDatabase db;
  @override
  final Uuid uuid;

  AppRepository(this.db, [Uuid? uuid]) : uuid = uuid ?? const Uuid();
}
