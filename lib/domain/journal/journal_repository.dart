import 'journal_models.dart';

abstract interface class JournalRepository {
  Future<AppendSourceRecordResult> append(SourceRecordDraft record);

  Future<bool> appendDomainEntry(DomainEntryDraft entry);
}
