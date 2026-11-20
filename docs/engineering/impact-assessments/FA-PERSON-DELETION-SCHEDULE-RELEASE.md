# FA-PERSON-DELETION-SCHEDULE-RELEASE — Impact Assessment & Technical Specification

**Task ID**: FA-PERSON-DELETION-SCHEDULE-RELEASE  
**Date**: 2026-11-19  
**Standard**: Field Assistant Engineering Standard (FAES) v1.0  
**Status**: APPROVED DESIGN — IMPLEMENTATION IN PROGRESS  

---

## 1. Problem and Desired Outcome

### 1.1 Problem Statement
1. **Missing UI path for Person deletion**: The database and `AppRepository` possess `deletePerson` (soft-delete) and `permanentlyDeleteItem('people', id)` (hard-delete), and `TrashScreen` allows permanently deleting already soft-deleted records. However, neither `person_detail_screen.dart` nor `contacts_map_screen.dart` / `contacts_map_list_view.dart` provides an interface option to delete a person, force-retaining unwanted contacts or forcing manual database tampering.
2. **Phone Contacts lack coherent permanent deletion and clear separation**: In `phone_contacts_screen.dart`, clicking "Excluir" performs an unconfirmed soft-delete. `PhoneContacts` are absent from `TrashScreen` (`getDeletedItems` / `restoreDeletedItem` / `permanentlyDeleteItem`). When a contact was converted/promoted to `People`, deleting either record lacks transparency regarding record independence.
3. **Ghost schedule blockages and orphaned reminders upon ending studies or revisits**: When a Bible Study is ended in `studies_screen.dart` / `study_dialogs.dart` or `person_detail_screen.dart` / `person_study_dialogs.dart`, or when a revisit is ended in `person_visit_and_profile_dialogs.dart`:
   - Future appointments linked to that study or person remain active in `Appointments`.
   - `AvailabilityEngine` continues treating those slots as occupied (`hasCollision == true`), generating false conflict warnings for future field service planning.
   - Local reminders (`LocalReminderService`) continue firing for ended studies/revisits.
   - External calendar sync (Google Calendar / Apple EventKit) leaves obsolete events in external calendars.

### 1.2 Desired Outcome
1. **Clear Person Deletion with Detailed Impact Confirmation**:
   - Provide explicit deletion actions from `person_detail_screen.dart` and `contacts_map_list_view.dart`.
   - Comprehensive confirmation dialog identifying the person, enumerating all linked entities (visits, study participations, future appointments, past appointments, notes, photos, publications, family ties), explaining what is removed vs unlinked, warning of irreversibility in local DB, and offering Cancel, Move to Trash, and Permanent Delete.
2. **Coherent Phone Contacts Deletion**:
   - Add confirmed deletion dialog for phone contacts explaining independence from promoted Person entries.
   - Add full Trash lifecycle for `phone_contacts` (trash view, restoration, permanent delete).
3. **Automated Schedule Release and Reminder Cleanup**:
   - When ending/deleting a study or revisit, or deleting a person, proactively identify all linked future appointments.
   - Display their count, dates, and times in the confirmation dialog.
   - Upon confirmation, cancel/remove future appointments within an atomic transaction, cancel associated local reminders, and propagate deletions to linked external calendars (Google/Apple) via `CalendarSyncCoordinator`.
   - Past appointments and historical ministry reports remain strictly preserved when ending a study or revisit.
   - Availability engine calculations (`hasCollision`, `checkAvailability`) immediately treat released slots as free.

---

## 2. Current Behavior and Evidence

- `lib/database/repository.dart`:
  - `deletePerson`: soft-deletes person and study participants.
  - `permanentlyDeleteItem('people', id)`: deletes visits, participants, voiceNotes, appointments, familyTies, photos, publications, person. Does not touch tasks, knowledgeNotes, or handle shared multi-participant studies safely.
  - `getDeletedItems()`: only queries `people`, `visits`, `bibleStudies`, `appointments`, `activityRecords`. Does not include `phone_contacts`.
- `lib/ui/screens/person_detail_screen.dart`:
  - `appBar` only has an Edit Contact button (`IconButton(icon: Icon(Icons.edit_outlined))`). No delete action exists.
- `lib/ui/screens/phone_contacts_screen.dart`:
  - Popup menu item `'delete'` directly invokes `mgr.deletePhoneContact(item.id)` with zero confirmation dialog and no distinction shown if promoted to Person.
- `lib/ui/screens/studies/study_dialogs.dart` & `person_study_dialogs.dart`:
  - `_showEndStudyDialog`: updates study status to `'encerrado'` / `'concluido'`, updates participant person status to `'revisita'`. Does not search for future appointments, does not free schedule, does not cancel reminders, does not delete external calendar events.
- `lib/ui/screens/person_detail/person_visit_and_profile_dialogs.dart`:
  - `_showEndReturnVisitDialog`: updates person status to `'revisita_encerrada'`. Leaves future revisit appointments active, blocking availability.

---

## 3. User Journey & Dependency Map

### Journey 1: Person Deletion (Profile or Contact List)
1. User opens Person Profile or Contact List.
2. Taps "Excluir Contato / Pessoa".
3. System scans relationships: visits count, study links, future appointments (with dates/times), photos, publications, family ties, promoted phone contact source.
4. System displays `PersonDeletionConfirmationDialog`:
   - Name of person.
   - Breakdown of data: future appointments to be cancelled & slots freed, past visit history to be deleted, unlinking of phone contact if present.
   - Clear warning: irreversibility in local storage, separate handling for cloud sync and backups.
   - Actions: "Cancelar", "Mover para Lixeira" (soft delete), "Excluir Definitivamente" (destructive red).
5. User confirms -> Transaction runs -> Reminders cancelled -> Calendar sync invoked -> User notified with exact status of local & external removal -> Navigates back safely.

### Journey 2: Ending a Study (Studies Screen or Person Profile)
1. User taps "Encerrar Estudo (com motivo)".
2. System queries future appointments where `studyId == study.id` and `endTime >= now` and `deletedAt == null` and `status != 'cancelado'`.
3. System checks if study has other participants.
4. Dialog shows reason dropdown, notes field, and explicit list of future appointments to be cancelled:
   - "2 compromissos futuros vinculados serão cancelados e os horários liberados na agenda: 24/11 às 14:00, 01/12 às 14:00."
5. User confirms -> Study marked ended -> Future appointments cancelled in DB -> Local reminders cancelled -> External events deleted/marked for sync -> Past sessions preserved -> UI confirms freed slots.

### Journey 3: Ending a Revisit
1. User taps "Encerrar Revisita (com motivo)".
2. System queries future revisit appointments where `personId == person.id` and `studyId == null` and `endTime >= now`.
3. Dialog shows future appointments to be cancelled, leaving past visits and past appointments intact.
4. User confirms -> Revisit marked ended -> Future appointments cancelled -> Slots freed.

### Journey 4: Phone Contact Deletion & Trash
1. User taps "Excluir" on phone contact.
2. Dialog appears. If contact has `convertedPersonId != null`, dialog clarifies:
   - "Este contato foi promovido para o cadastro de Pessoas. O registro de Pessoa e seu histórico NÃO serão apagados."
3. User selects "Mover para Lixeira" or "Excluir Definitivamente".
4. If moved to trash, item appears in `TrashScreen` with restore and permanent delete options.

---

## 4. Component & Data Flow Architecture

```
[UI Layer]
  ├── person_detail_screen.dart (AppBar Delete action)
  ├── contacts_map_list_view.dart (Item Delete action)
  ├── phone_contacts_screen.dart (Confirmed Delete dialog)
  ├── studies/study_dialogs.dart & study_detail_pane.dart (Future appts display & release)
  ├── person_detail/person_study_dialogs.dart (Future appts display & release)
  ├── person_detail/person_visit_and_profile_dialogs.dart (Revisit future appts release)
  └── trash_screen.dart (phone_contacts support & permanent delete)

[Service / Coordination Layer]
  ├── schedule_release_coordinator.dart (NEW / Dedicated helper)
  │     ├── scanFutureAppointments(studyId / personId)
  │     ├── releaseSchedule(appointments, reason)
  │     ├── cancelAssociatedReminders(appointmentIds)
  │     └── propagateExternalCalendarDeletions(appointments)
  ├── local_reminder_service.dart (cancelRemindersForAppointments)
  └── calendar_sync_coordinator.dart (propagateDeletions, syncAll)

[Data Layer (Drift)]
  ├── AppRepository
  │     ├── deletePerson & permanentlyDeletePerson
  │     ├── endStudyWithScheduleRelease
  │     ├── endRevisitWithScheduleRelease
  │     ├── getDeletedItems (including phone_contacts)
  │     ├── restoreDeletedItem (including phone_contacts)
  │     └── permanentlyDeleteItem (including phone_contacts, unlinking tasks & knowledge)
  └── AppDatabase tables (People, Appointments, BibleStudies, StudyParticipants, CalendarEventLinks, SyncQueue, PhoneContacts, etc.)
```

---

## 5. Security, Privacy & Account Isolation
- Account Isolation: All operations operate strictly within the active user's local Drift database instance and authenticated Supabase user scope.
- Audit & Sync: All mutations emit proper sync queue operations (`DELETE` or `HARD_DELETE`) with full JSON payloads and base data for conflict detection.
- Fail-Closed: If a local database transaction fails, no schedule release or status change is committed, and no false success notification is emitted.
- External Calendar Safety: Never deletes unlinked external events. Only events in `calendar_event_links` specifically tied to the targeted `appointment_id` are processed.

---

## 6. Test Plan
1. Unit & Repository Tests:
   - `test/schedule_release_coordinator_test.dart`
   - Cancel confirmation leaves data intact.
   - Deleting person cleans up relationships, releases future appointments, unlinks phone contact, preserves tasks.
   - Phone contact deletion does not delete converted person; person deletion does not delete converted phone contact.
   - Ending study cancels future appointments, preserves past appointments, cancels reminders.
   - Ending revisit cancels future appointments, preserves past visits and past appointments.
   - Multi-participant studies: shared study is not deleted when one participant is removed.
   - `AvailabilityEngine`: freed slot returns `isAvailable == true`.
   - Calendar sync: success, offline/pending, read-only handling.
   - Trash: phone contact appear in trash, restores, and hard-deletes.
2. Widget & Integration Tests:
   - Dialog confirmation flows for Person deletion, Study ending, Revisit ending, Phone contact deletion.

---

## 7. Rollback & Recovery Plan
- All schema migrations are additive or use existing columns (`deletedAt`, `status`, `convertedPersonId`).
- Transactional rollback on any database operation failure.
- Soft-delete remains recoverable via `TrashScreen`.
