import 'package:drift/drift.dart';

import '../../domain/identity/league_identity.dart';
import '../../domain/league/local_scout.dart';
import 'godsense_database.dart';

class DriftLocalScoutRepository implements LocalScoutRepository {
  DriftLocalScoutRepository(this.database);

  final GodSenseDatabase database;

  @override
  Future<void> upsertMatch(LocalMatchRecord match) {
    return database.transaction(() async {
      await database
          .into(database.matches)
          .insertOnConflictUpdate(
            MatchesCompanion.insert(
              platformId: match.match.platformId.value,
              gameId: match.match.gameId,
              patchKey: Value(match.patch?.value),
              queueId: Value(match.queueId),
              startedAtUs: Value(
                match.startedAt?.toUtc().microsecondsSinceEpoch,
              ),
              endedAtUs: Value(match.endedAt?.toUtc().microsecondsSinceEpoch),
            ),
          );
      await database
          .into(database.accountMatches)
          .insertOnConflictUpdate(
            AccountMatchesCompanion.insert(
              puuid: match.puuid.value,
              platformId: match.match.platformId.value,
              gameId: match.match.gameId,
            ),
          );
      final existing =
          await (database.select(database.matchDocuments)..where(
                (table) =>
                    table.platformId.equals(match.match.platformId.value) &
                    table.gameId.equals(match.match.gameId) &
                    table.puuid.equals(match.puuid.value),
              ))
              .getSingleOrNull();
      await database
          .into(database.matchDocuments)
          .insertOnConflictUpdate(
            MatchDocumentsCompanion.insert(
              platformId: match.match.platformId.value,
              gameId: match.match.gameId,
              puuid: match.puuid.value,
              summaryJson: match.summaryJson,
              detailsJson: Value(match.detailsJson ?? existing?.detailsJson),
              timelineJson: Value(match.timelineJson ?? existing?.timelineJson),
              syncedAtUs: match.syncedAt.toUtc().microsecondsSinceEpoch,
            ),
          );
    });
  }

  @override
  Future<bool> appendRankedSnapshot(LocalRankedSnapshot snapshot) {
    return database.transaction(() async {
      final latest =
          await (database.select(database.rankedSnapshots)
                ..where((table) => table.puuid.equals(snapshot.puuid.value))
                ..orderBy([(table) => OrderingTerm.desc(table.observedAtUs)])
                ..limit(1))
              .getSingleOrNull();
      if (latest?.semanticHash == snapshot.semanticHash) return false;
      await database
          .into(database.rankedSnapshots)
          .insert(
            RankedSnapshotsCompanion.insert(
              puuid: snapshot.puuid.value,
              observedAtUs: snapshot.observedAt.toUtc().microsecondsSinceEpoch,
              payloadJson: snapshot.payloadJson,
              semanticHash: snapshot.semanticHash,
            ),
          );
      return true;
    });
  }

  @override
  Future<List<LocalMatchRecord>> loadMatches(
    Puuid puuid, {
    int limit = 20,
  }) async {
    final query =
        database.select(database.matchDocuments).join([
            innerJoin(
              database.matches,
              database.matches.platformId.equalsExp(
                    database.matchDocuments.platformId,
                  ) &
                  database.matches.gameId.equalsExp(
                    database.matchDocuments.gameId,
                  ),
            ),
          ])
          ..where(database.matchDocuments.puuid.equals(puuid.value))
          ..orderBy([
            OrderingTerm.desc(database.matches.startedAtUs),
            OrderingTerm.desc(database.matchDocuments.syncedAtUs),
          ])
          ..limit(limit);
    final rows = await query.get();
    return rows
        .map((row) {
          final document = row.readTable(database.matchDocuments);
          final match = row.readTable(database.matches);
          return LocalMatchRecord(
            match: MatchKey(
              platformId: PlatformId(match.platformId),
              gameId: match.gameId,
            ),
            puuid: Puuid(document.puuid),
            patch: match.patchKey == null ? null : PatchKey(match.patchKey!),
            queueId: match.queueId,
            startedAt: _date(match.startedAtUs),
            endedAt: _date(match.endedAtUs),
            summaryJson: document.summaryJson,
            detailsJson: document.detailsJson,
            timelineJson: document.timelineJson,
            syncedAt: _date(document.syncedAtUs)!,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<LocalRankedSnapshot?> loadLatestRanked(Puuid puuid) async {
    final row =
        await (database.select(database.rankedSnapshots)
              ..where((table) => table.puuid.equals(puuid.value))
              ..orderBy([(table) => OrderingTerm.desc(table.observedAtUs)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return LocalRankedSnapshot(
      puuid: Puuid(row.puuid),
      payloadJson: row.payloadJson,
      observedAt: _date(row.observedAtUs)!,
      semanticHash: row.semanticHash,
    );
  }
}

DateTime? _date(int? microseconds) => microseconds == null
    ? null
    : DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);
