// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'godsense_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _puuidMeta = const VerificationMeta('puuid');
  @override
  late final GeneratedColumn<String> puuid = GeneratedColumn<String>(
    'puuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformIdMeta = const VerificationMeta(
    'platformId',
  );
  @override
  late final GeneratedColumn<String> platformId = GeneratedColumn<String>(
    'platform_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameNameMeta = const VerificationMeta(
    'gameName',
  );
  @override
  late final GeneratedColumn<String> gameName = GeneratedColumn<String>(
    'game_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagLineMeta = const VerificationMeta(
    'tagLine',
  );
  @override
  late final GeneratedColumn<String> tagLine = GeneratedColumn<String>(
    'tag_line',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summonerIdMeta = const VerificationMeta(
    'summonerId',
  );
  @override
  late final GeneratedColumn<int> summonerId = GeneratedColumn<int>(
    'summoner_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summonerLevelMeta = const VerificationMeta(
    'summonerLevel',
  );
  @override
  late final GeneratedColumn<int> summonerLevel = GeneratedColumn<int>(
    'summoner_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileIconIdMeta = const VerificationMeta(
    'profileIconId',
  );
  @override
  late final GeneratedColumn<int> profileIconId = GeneratedColumn<int>(
    'profile_icon_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastClientVersionMeta = const VerificationMeta(
    'lastClientVersion',
  );
  @override
  late final GeneratedColumn<String> lastClientVersion =
      GeneratedColumn<String>(
        'last_client_version',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastPatchKeyMeta = const VerificationMeta(
    'lastPatchKey',
  );
  @override
  late final GeneratedColumn<String> lastPatchKey = GeneratedColumn<String>(
    'last_patch_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstSeenAtUsMeta = const VerificationMeta(
    'firstSeenAtUs',
  );
  @override
  late final GeneratedColumn<int> firstSeenAtUs = GeneratedColumn<int>(
    'first_seen_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtUsMeta = const VerificationMeta(
    'lastSeenAtUs',
  );
  @override
  late final GeneratedColumn<int> lastSeenAtUs = GeneratedColumn<int>(
    'last_seen_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordSchemaVersionMeta =
      const VerificationMeta('recordSchemaVersion');
  @override
  late final GeneratedColumn<int> recordSchemaVersion = GeneratedColumn<int>(
    'record_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    puuid,
    platformId,
    gameName,
    tagLine,
    summonerId,
    summonerLevel,
    profileIconId,
    lastClientVersion,
    lastPatchKey,
    firstSeenAtUs,
    lastSeenAtUs,
    recordSchemaVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('puuid')) {
      context.handle(
        _puuidMeta,
        puuid.isAcceptableOrUnknown(data['puuid']!, _puuidMeta),
      );
    } else if (isInserting) {
      context.missing(_puuidMeta);
    }
    if (data.containsKey('platform_id')) {
      context.handle(
        _platformIdMeta,
        platformId.isAcceptableOrUnknown(data['platform_id']!, _platformIdMeta),
      );
    } else if (isInserting) {
      context.missing(_platformIdMeta);
    }
    if (data.containsKey('game_name')) {
      context.handle(
        _gameNameMeta,
        gameName.isAcceptableOrUnknown(data['game_name']!, _gameNameMeta),
      );
    }
    if (data.containsKey('tag_line')) {
      context.handle(
        _tagLineMeta,
        tagLine.isAcceptableOrUnknown(data['tag_line']!, _tagLineMeta),
      );
    }
    if (data.containsKey('summoner_id')) {
      context.handle(
        _summonerIdMeta,
        summonerId.isAcceptableOrUnknown(data['summoner_id']!, _summonerIdMeta),
      );
    }
    if (data.containsKey('summoner_level')) {
      context.handle(
        _summonerLevelMeta,
        summonerLevel.isAcceptableOrUnknown(
          data['summoner_level']!,
          _summonerLevelMeta,
        ),
      );
    }
    if (data.containsKey('profile_icon_id')) {
      context.handle(
        _profileIconIdMeta,
        profileIconId.isAcceptableOrUnknown(
          data['profile_icon_id']!,
          _profileIconIdMeta,
        ),
      );
    }
    if (data.containsKey('last_client_version')) {
      context.handle(
        _lastClientVersionMeta,
        lastClientVersion.isAcceptableOrUnknown(
          data['last_client_version']!,
          _lastClientVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_patch_key')) {
      context.handle(
        _lastPatchKeyMeta,
        lastPatchKey.isAcceptableOrUnknown(
          data['last_patch_key']!,
          _lastPatchKeyMeta,
        ),
      );
    }
    if (data.containsKey('first_seen_at_us')) {
      context.handle(
        _firstSeenAtUsMeta,
        firstSeenAtUs.isAcceptableOrUnknown(
          data['first_seen_at_us']!,
          _firstSeenAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtUsMeta);
    }
    if (data.containsKey('last_seen_at_us')) {
      context.handle(
        _lastSeenAtUsMeta,
        lastSeenAtUs.isAcceptableOrUnknown(
          data['last_seen_at_us']!,
          _lastSeenAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtUsMeta);
    }
    if (data.containsKey('record_schema_version')) {
      context.handle(
        _recordSchemaVersionMeta,
        recordSchemaVersion.isAcceptableOrUnknown(
          data['record_schema_version']!,
          _recordSchemaVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {puuid};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      puuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}puuid'],
      )!,
      platformId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_id'],
      )!,
      gameName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_name'],
      ),
      tagLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_line'],
      ),
      summonerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}summoner_id'],
      ),
      summonerLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}summoner_level'],
      ),
      profileIconId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_icon_id'],
      ),
      lastClientVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_client_version'],
      ),
      lastPatchKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_patch_key'],
      ),
      firstSeenAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen_at_us'],
      )!,
      lastSeenAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at_us'],
      )!,
      recordSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}record_schema_version'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String puuid;
  final String platformId;
  final String? gameName;
  final String? tagLine;
  final int? summonerId;
  final int? summonerLevel;
  final int? profileIconId;
  final String? lastClientVersion;
  final String? lastPatchKey;
  final int firstSeenAtUs;
  final int lastSeenAtUs;
  final int recordSchemaVersion;
  const Account({
    required this.puuid,
    required this.platformId,
    this.gameName,
    this.tagLine,
    this.summonerId,
    this.summonerLevel,
    this.profileIconId,
    this.lastClientVersion,
    this.lastPatchKey,
    required this.firstSeenAtUs,
    required this.lastSeenAtUs,
    required this.recordSchemaVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['puuid'] = Variable<String>(puuid);
    map['platform_id'] = Variable<String>(platformId);
    if (!nullToAbsent || gameName != null) {
      map['game_name'] = Variable<String>(gameName);
    }
    if (!nullToAbsent || tagLine != null) {
      map['tag_line'] = Variable<String>(tagLine);
    }
    if (!nullToAbsent || summonerId != null) {
      map['summoner_id'] = Variable<int>(summonerId);
    }
    if (!nullToAbsent || summonerLevel != null) {
      map['summoner_level'] = Variable<int>(summonerLevel);
    }
    if (!nullToAbsent || profileIconId != null) {
      map['profile_icon_id'] = Variable<int>(profileIconId);
    }
    if (!nullToAbsent || lastClientVersion != null) {
      map['last_client_version'] = Variable<String>(lastClientVersion);
    }
    if (!nullToAbsent || lastPatchKey != null) {
      map['last_patch_key'] = Variable<String>(lastPatchKey);
    }
    map['first_seen_at_us'] = Variable<int>(firstSeenAtUs);
    map['last_seen_at_us'] = Variable<int>(lastSeenAtUs);
    map['record_schema_version'] = Variable<int>(recordSchemaVersion);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      puuid: Value(puuid),
      platformId: Value(platformId),
      gameName: gameName == null && nullToAbsent
          ? const Value.absent()
          : Value(gameName),
      tagLine: tagLine == null && nullToAbsent
          ? const Value.absent()
          : Value(tagLine),
      summonerId: summonerId == null && nullToAbsent
          ? const Value.absent()
          : Value(summonerId),
      summonerLevel: summonerLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(summonerLevel),
      profileIconId: profileIconId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileIconId),
      lastClientVersion: lastClientVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(lastClientVersion),
      lastPatchKey: lastPatchKey == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPatchKey),
      firstSeenAtUs: Value(firstSeenAtUs),
      lastSeenAtUs: Value(lastSeenAtUs),
      recordSchemaVersion: Value(recordSchemaVersion),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      puuid: serializer.fromJson<String>(json['puuid']),
      platformId: serializer.fromJson<String>(json['platformId']),
      gameName: serializer.fromJson<String?>(json['gameName']),
      tagLine: serializer.fromJson<String?>(json['tagLine']),
      summonerId: serializer.fromJson<int?>(json['summonerId']),
      summonerLevel: serializer.fromJson<int?>(json['summonerLevel']),
      profileIconId: serializer.fromJson<int?>(json['profileIconId']),
      lastClientVersion: serializer.fromJson<String?>(
        json['lastClientVersion'],
      ),
      lastPatchKey: serializer.fromJson<String?>(json['lastPatchKey']),
      firstSeenAtUs: serializer.fromJson<int>(json['firstSeenAtUs']),
      lastSeenAtUs: serializer.fromJson<int>(json['lastSeenAtUs']),
      recordSchemaVersion: serializer.fromJson<int>(
        json['recordSchemaVersion'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'puuid': serializer.toJson<String>(puuid),
      'platformId': serializer.toJson<String>(platformId),
      'gameName': serializer.toJson<String?>(gameName),
      'tagLine': serializer.toJson<String?>(tagLine),
      'summonerId': serializer.toJson<int?>(summonerId),
      'summonerLevel': serializer.toJson<int?>(summonerLevel),
      'profileIconId': serializer.toJson<int?>(profileIconId),
      'lastClientVersion': serializer.toJson<String?>(lastClientVersion),
      'lastPatchKey': serializer.toJson<String?>(lastPatchKey),
      'firstSeenAtUs': serializer.toJson<int>(firstSeenAtUs),
      'lastSeenAtUs': serializer.toJson<int>(lastSeenAtUs),
      'recordSchemaVersion': serializer.toJson<int>(recordSchemaVersion),
    };
  }

  Account copyWith({
    String? puuid,
    String? platformId,
    Value<String?> gameName = const Value.absent(),
    Value<String?> tagLine = const Value.absent(),
    Value<int?> summonerId = const Value.absent(),
    Value<int?> summonerLevel = const Value.absent(),
    Value<int?> profileIconId = const Value.absent(),
    Value<String?> lastClientVersion = const Value.absent(),
    Value<String?> lastPatchKey = const Value.absent(),
    int? firstSeenAtUs,
    int? lastSeenAtUs,
    int? recordSchemaVersion,
  }) => Account(
    puuid: puuid ?? this.puuid,
    platformId: platformId ?? this.platformId,
    gameName: gameName.present ? gameName.value : this.gameName,
    tagLine: tagLine.present ? tagLine.value : this.tagLine,
    summonerId: summonerId.present ? summonerId.value : this.summonerId,
    summonerLevel: summonerLevel.present
        ? summonerLevel.value
        : this.summonerLevel,
    profileIconId: profileIconId.present
        ? profileIconId.value
        : this.profileIconId,
    lastClientVersion: lastClientVersion.present
        ? lastClientVersion.value
        : this.lastClientVersion,
    lastPatchKey: lastPatchKey.present ? lastPatchKey.value : this.lastPatchKey,
    firstSeenAtUs: firstSeenAtUs ?? this.firstSeenAtUs,
    lastSeenAtUs: lastSeenAtUs ?? this.lastSeenAtUs,
    recordSchemaVersion: recordSchemaVersion ?? this.recordSchemaVersion,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      puuid: data.puuid.present ? data.puuid.value : this.puuid,
      platformId: data.platformId.present
          ? data.platformId.value
          : this.platformId,
      gameName: data.gameName.present ? data.gameName.value : this.gameName,
      tagLine: data.tagLine.present ? data.tagLine.value : this.tagLine,
      summonerId: data.summonerId.present
          ? data.summonerId.value
          : this.summonerId,
      summonerLevel: data.summonerLevel.present
          ? data.summonerLevel.value
          : this.summonerLevel,
      profileIconId: data.profileIconId.present
          ? data.profileIconId.value
          : this.profileIconId,
      lastClientVersion: data.lastClientVersion.present
          ? data.lastClientVersion.value
          : this.lastClientVersion,
      lastPatchKey: data.lastPatchKey.present
          ? data.lastPatchKey.value
          : this.lastPatchKey,
      firstSeenAtUs: data.firstSeenAtUs.present
          ? data.firstSeenAtUs.value
          : this.firstSeenAtUs,
      lastSeenAtUs: data.lastSeenAtUs.present
          ? data.lastSeenAtUs.value
          : this.lastSeenAtUs,
      recordSchemaVersion: data.recordSchemaVersion.present
          ? data.recordSchemaVersion.value
          : this.recordSchemaVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('puuid: $puuid, ')
          ..write('platformId: $platformId, ')
          ..write('gameName: $gameName, ')
          ..write('tagLine: $tagLine, ')
          ..write('summonerId: $summonerId, ')
          ..write('summonerLevel: $summonerLevel, ')
          ..write('profileIconId: $profileIconId, ')
          ..write('lastClientVersion: $lastClientVersion, ')
          ..write('lastPatchKey: $lastPatchKey, ')
          ..write('firstSeenAtUs: $firstSeenAtUs, ')
          ..write('lastSeenAtUs: $lastSeenAtUs, ')
          ..write('recordSchemaVersion: $recordSchemaVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    puuid,
    platformId,
    gameName,
    tagLine,
    summonerId,
    summonerLevel,
    profileIconId,
    lastClientVersion,
    lastPatchKey,
    firstSeenAtUs,
    lastSeenAtUs,
    recordSchemaVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.puuid == this.puuid &&
          other.platformId == this.platformId &&
          other.gameName == this.gameName &&
          other.tagLine == this.tagLine &&
          other.summonerId == this.summonerId &&
          other.summonerLevel == this.summonerLevel &&
          other.profileIconId == this.profileIconId &&
          other.lastClientVersion == this.lastClientVersion &&
          other.lastPatchKey == this.lastPatchKey &&
          other.firstSeenAtUs == this.firstSeenAtUs &&
          other.lastSeenAtUs == this.lastSeenAtUs &&
          other.recordSchemaVersion == this.recordSchemaVersion);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> puuid;
  final Value<String> platformId;
  final Value<String?> gameName;
  final Value<String?> tagLine;
  final Value<int?> summonerId;
  final Value<int?> summonerLevel;
  final Value<int?> profileIconId;
  final Value<String?> lastClientVersion;
  final Value<String?> lastPatchKey;
  final Value<int> firstSeenAtUs;
  final Value<int> lastSeenAtUs;
  final Value<int> recordSchemaVersion;
  final Value<int> rowid;
  const AccountsCompanion({
    this.puuid = const Value.absent(),
    this.platformId = const Value.absent(),
    this.gameName = const Value.absent(),
    this.tagLine = const Value.absent(),
    this.summonerId = const Value.absent(),
    this.summonerLevel = const Value.absent(),
    this.profileIconId = const Value.absent(),
    this.lastClientVersion = const Value.absent(),
    this.lastPatchKey = const Value.absent(),
    this.firstSeenAtUs = const Value.absent(),
    this.lastSeenAtUs = const Value.absent(),
    this.recordSchemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String puuid,
    required String platformId,
    this.gameName = const Value.absent(),
    this.tagLine = const Value.absent(),
    this.summonerId = const Value.absent(),
    this.summonerLevel = const Value.absent(),
    this.profileIconId = const Value.absent(),
    this.lastClientVersion = const Value.absent(),
    this.lastPatchKey = const Value.absent(),
    required int firstSeenAtUs,
    required int lastSeenAtUs,
    this.recordSchemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : puuid = Value(puuid),
       platformId = Value(platformId),
       firstSeenAtUs = Value(firstSeenAtUs),
       lastSeenAtUs = Value(lastSeenAtUs);
  static Insertable<Account> custom({
    Expression<String>? puuid,
    Expression<String>? platformId,
    Expression<String>? gameName,
    Expression<String>? tagLine,
    Expression<int>? summonerId,
    Expression<int>? summonerLevel,
    Expression<int>? profileIconId,
    Expression<String>? lastClientVersion,
    Expression<String>? lastPatchKey,
    Expression<int>? firstSeenAtUs,
    Expression<int>? lastSeenAtUs,
    Expression<int>? recordSchemaVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (puuid != null) 'puuid': puuid,
      if (platformId != null) 'platform_id': platformId,
      if (gameName != null) 'game_name': gameName,
      if (tagLine != null) 'tag_line': tagLine,
      if (summonerId != null) 'summoner_id': summonerId,
      if (summonerLevel != null) 'summoner_level': summonerLevel,
      if (profileIconId != null) 'profile_icon_id': profileIconId,
      if (lastClientVersion != null) 'last_client_version': lastClientVersion,
      if (lastPatchKey != null) 'last_patch_key': lastPatchKey,
      if (firstSeenAtUs != null) 'first_seen_at_us': firstSeenAtUs,
      if (lastSeenAtUs != null) 'last_seen_at_us': lastSeenAtUs,
      if (recordSchemaVersion != null)
        'record_schema_version': recordSchemaVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? puuid,
    Value<String>? platformId,
    Value<String?>? gameName,
    Value<String?>? tagLine,
    Value<int?>? summonerId,
    Value<int?>? summonerLevel,
    Value<int?>? profileIconId,
    Value<String?>? lastClientVersion,
    Value<String?>? lastPatchKey,
    Value<int>? firstSeenAtUs,
    Value<int>? lastSeenAtUs,
    Value<int>? recordSchemaVersion,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      puuid: puuid ?? this.puuid,
      platformId: platformId ?? this.platformId,
      gameName: gameName ?? this.gameName,
      tagLine: tagLine ?? this.tagLine,
      summonerId: summonerId ?? this.summonerId,
      summonerLevel: summonerLevel ?? this.summonerLevel,
      profileIconId: profileIconId ?? this.profileIconId,
      lastClientVersion: lastClientVersion ?? this.lastClientVersion,
      lastPatchKey: lastPatchKey ?? this.lastPatchKey,
      firstSeenAtUs: firstSeenAtUs ?? this.firstSeenAtUs,
      lastSeenAtUs: lastSeenAtUs ?? this.lastSeenAtUs,
      recordSchemaVersion: recordSchemaVersion ?? this.recordSchemaVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (puuid.present) {
      map['puuid'] = Variable<String>(puuid.value);
    }
    if (platformId.present) {
      map['platform_id'] = Variable<String>(platformId.value);
    }
    if (gameName.present) {
      map['game_name'] = Variable<String>(gameName.value);
    }
    if (tagLine.present) {
      map['tag_line'] = Variable<String>(tagLine.value);
    }
    if (summonerId.present) {
      map['summoner_id'] = Variable<int>(summonerId.value);
    }
    if (summonerLevel.present) {
      map['summoner_level'] = Variable<int>(summonerLevel.value);
    }
    if (profileIconId.present) {
      map['profile_icon_id'] = Variable<int>(profileIconId.value);
    }
    if (lastClientVersion.present) {
      map['last_client_version'] = Variable<String>(lastClientVersion.value);
    }
    if (lastPatchKey.present) {
      map['last_patch_key'] = Variable<String>(lastPatchKey.value);
    }
    if (firstSeenAtUs.present) {
      map['first_seen_at_us'] = Variable<int>(firstSeenAtUs.value);
    }
    if (lastSeenAtUs.present) {
      map['last_seen_at_us'] = Variable<int>(lastSeenAtUs.value);
    }
    if (recordSchemaVersion.present) {
      map['record_schema_version'] = Variable<int>(recordSchemaVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('puuid: $puuid, ')
          ..write('platformId: $platformId, ')
          ..write('gameName: $gameName, ')
          ..write('tagLine: $tagLine, ')
          ..write('summonerId: $summonerId, ')
          ..write('summonerLevel: $summonerLevel, ')
          ..write('profileIconId: $profileIconId, ')
          ..write('lastClientVersion: $lastClientVersion, ')
          ..write('lastPatchKey: $lastPatchKey, ')
          ..write('firstSeenAtUs: $firstSeenAtUs, ')
          ..write('lastSeenAtUs: $lastSeenAtUs, ')
          ..write('recordSchemaVersion: $recordSchemaVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountContextStatesTable extends AccountContextStates
    with TableInfo<$AccountContextStatesTable, AccountContextState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountContextStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currentPuuidMeta = const VerificationMeta(
    'currentPuuid',
  );
  @override
  late final GeneratedColumn<String> currentPuuid = GeneratedColumn<String>(
    'current_puuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (puuid)',
    ),
  );
  static const VerificationMeta _accountGenerationMeta = const VerificationMeta(
    'accountGeneration',
  );
  @override
  late final GeneratedColumn<int> accountGeneration = GeneratedColumn<int>(
    'account_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncRevisionMeta = const VerificationMeta(
    'syncRevision',
  );
  @override
  late final GeneratedColumn<int> syncRevision = GeneratedColumn<int>(
    'sync_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUs = GeneratedColumn<int>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    singletonId,
    currentPuuid,
    accountGeneration,
    syncRevision,
    updatedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_context_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountContextState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('current_puuid')) {
      context.handle(
        _currentPuuidMeta,
        currentPuuid.isAcceptableOrUnknown(
          data['current_puuid']!,
          _currentPuuidMeta,
        ),
      );
    }
    if (data.containsKey('account_generation')) {
      context.handle(
        _accountGenerationMeta,
        accountGeneration.isAcceptableOrUnknown(
          data['account_generation']!,
          _accountGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountGenerationMeta);
    }
    if (data.containsKey('sync_revision')) {
      context.handle(
        _syncRevisionMeta,
        syncRevision.isAcceptableOrUnknown(
          data['sync_revision']!,
          _syncRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_syncRevisionMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  AccountContextState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountContextState(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      currentPuuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_puuid'],
      ),
      accountGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_generation'],
      )!,
      syncRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_revision'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_us'],
      )!,
    );
  }

  @override
  $AccountContextStatesTable createAlias(String alias) {
    return $AccountContextStatesTable(attachedDatabase, alias);
  }
}

class AccountContextState extends DataClass
    implements Insertable<AccountContextState> {
  final int singletonId;
  final String? currentPuuid;
  final int accountGeneration;
  final int syncRevision;
  final int updatedAtUs;
  const AccountContextState({
    required this.singletonId,
    this.currentPuuid,
    required this.accountGeneration,
    required this.syncRevision,
    required this.updatedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    if (!nullToAbsent || currentPuuid != null) {
      map['current_puuid'] = Variable<String>(currentPuuid);
    }
    map['account_generation'] = Variable<int>(accountGeneration);
    map['sync_revision'] = Variable<int>(syncRevision);
    map['updated_at_us'] = Variable<int>(updatedAtUs);
    return map;
  }

  AccountContextStatesCompanion toCompanion(bool nullToAbsent) {
    return AccountContextStatesCompanion(
      singletonId: Value(singletonId),
      currentPuuid: currentPuuid == null && nullToAbsent
          ? const Value.absent()
          : Value(currentPuuid),
      accountGeneration: Value(accountGeneration),
      syncRevision: Value(syncRevision),
      updatedAtUs: Value(updatedAtUs),
    );
  }

  factory AccountContextState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountContextState(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      currentPuuid: serializer.fromJson<String?>(json['currentPuuid']),
      accountGeneration: serializer.fromJson<int>(json['accountGeneration']),
      syncRevision: serializer.fromJson<int>(json['syncRevision']),
      updatedAtUs: serializer.fromJson<int>(json['updatedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'currentPuuid': serializer.toJson<String?>(currentPuuid),
      'accountGeneration': serializer.toJson<int>(accountGeneration),
      'syncRevision': serializer.toJson<int>(syncRevision),
      'updatedAtUs': serializer.toJson<int>(updatedAtUs),
    };
  }

  AccountContextState copyWith({
    int? singletonId,
    Value<String?> currentPuuid = const Value.absent(),
    int? accountGeneration,
    int? syncRevision,
    int? updatedAtUs,
  }) => AccountContextState(
    singletonId: singletonId ?? this.singletonId,
    currentPuuid: currentPuuid.present ? currentPuuid.value : this.currentPuuid,
    accountGeneration: accountGeneration ?? this.accountGeneration,
    syncRevision: syncRevision ?? this.syncRevision,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
  );
  AccountContextState copyWithCompanion(AccountContextStatesCompanion data) {
    return AccountContextState(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      currentPuuid: data.currentPuuid.present
          ? data.currentPuuid.value
          : this.currentPuuid,
      accountGeneration: data.accountGeneration.present
          ? data.accountGeneration.value
          : this.accountGeneration,
      syncRevision: data.syncRevision.present
          ? data.syncRevision.value
          : this.syncRevision,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountContextState(')
          ..write('singletonId: $singletonId, ')
          ..write('currentPuuid: $currentPuuid, ')
          ..write('accountGeneration: $accountGeneration, ')
          ..write('syncRevision: $syncRevision, ')
          ..write('updatedAtUs: $updatedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    singletonId,
    currentPuuid,
    accountGeneration,
    syncRevision,
    updatedAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountContextState &&
          other.singletonId == this.singletonId &&
          other.currentPuuid == this.currentPuuid &&
          other.accountGeneration == this.accountGeneration &&
          other.syncRevision == this.syncRevision &&
          other.updatedAtUs == this.updatedAtUs);
}

class AccountContextStatesCompanion
    extends UpdateCompanion<AccountContextState> {
  final Value<int> singletonId;
  final Value<String?> currentPuuid;
  final Value<int> accountGeneration;
  final Value<int> syncRevision;
  final Value<int> updatedAtUs;
  const AccountContextStatesCompanion({
    this.singletonId = const Value.absent(),
    this.currentPuuid = const Value.absent(),
    this.accountGeneration = const Value.absent(),
    this.syncRevision = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
  });
  AccountContextStatesCompanion.insert({
    this.singletonId = const Value.absent(),
    this.currentPuuid = const Value.absent(),
    required int accountGeneration,
    required int syncRevision,
    required int updatedAtUs,
  }) : accountGeneration = Value(accountGeneration),
       syncRevision = Value(syncRevision),
       updatedAtUs = Value(updatedAtUs);
  static Insertable<AccountContextState> custom({
    Expression<int>? singletonId,
    Expression<String>? currentPuuid,
    Expression<int>? accountGeneration,
    Expression<int>? syncRevision,
    Expression<int>? updatedAtUs,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (currentPuuid != null) 'current_puuid': currentPuuid,
      if (accountGeneration != null) 'account_generation': accountGeneration,
      if (syncRevision != null) 'sync_revision': syncRevision,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
    });
  }

  AccountContextStatesCompanion copyWith({
    Value<int>? singletonId,
    Value<String?>? currentPuuid,
    Value<int>? accountGeneration,
    Value<int>? syncRevision,
    Value<int>? updatedAtUs,
  }) {
    return AccountContextStatesCompanion(
      singletonId: singletonId ?? this.singletonId,
      currentPuuid: currentPuuid ?? this.currentPuuid,
      accountGeneration: accountGeneration ?? this.accountGeneration,
      syncRevision: syncRevision ?? this.syncRevision,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (currentPuuid.present) {
      map['current_puuid'] = Variable<String>(currentPuuid.value);
    }
    if (accountGeneration.present) {
      map['account_generation'] = Variable<int>(accountGeneration.value);
    }
    if (syncRevision.present) {
      map['sync_revision'] = Variable<int>(syncRevision.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<int>(updatedAtUs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountContextStatesCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('currentPuuid: $currentPuuid, ')
          ..write('accountGeneration: $accountGeneration, ')
          ..write('syncRevision: $syncRevision, ')
          ..write('updatedAtUs: $updatedAtUs')
          ..write(')'))
        .toString();
  }
}

class $MatchesTable extends Matches with TableInfo<$MatchesTable, Matche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _platformIdMeta = const VerificationMeta(
    'platformId',
  );
  @override
  late final GeneratedColumn<String> platformId = GeneratedColumn<String>(
    'platform_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patchKeyMeta = const VerificationMeta(
    'patchKey',
  );
  @override
  late final GeneratedColumn<String> patchKey = GeneratedColumn<String>(
    'patch_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _queueIdMeta = const VerificationMeta(
    'queueId',
  );
  @override
  late final GeneratedColumn<int> queueId = GeneratedColumn<int>(
    'queue_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtUsMeta = const VerificationMeta(
    'startedAtUs',
  );
  @override
  late final GeneratedColumn<int> startedAtUs = GeneratedColumn<int>(
    'started_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtUsMeta = const VerificationMeta(
    'endedAtUs',
  );
  @override
  late final GeneratedColumn<int> endedAtUs = GeneratedColumn<int>(
    'ended_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordSchemaVersionMeta =
      const VerificationMeta('recordSchemaVersion');
  @override
  late final GeneratedColumn<int> recordSchemaVersion = GeneratedColumn<int>(
    'record_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    platformId,
    gameId,
    patchKey,
    queueId,
    startedAtUs,
    endedAtUs,
    recordSchemaVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<Matche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('platform_id')) {
      context.handle(
        _platformIdMeta,
        platformId.isAcceptableOrUnknown(data['platform_id']!, _platformIdMeta),
      );
    } else if (isInserting) {
      context.missing(_platformIdMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('patch_key')) {
      context.handle(
        _patchKeyMeta,
        patchKey.isAcceptableOrUnknown(data['patch_key']!, _patchKeyMeta),
      );
    }
    if (data.containsKey('queue_id')) {
      context.handle(
        _queueIdMeta,
        queueId.isAcceptableOrUnknown(data['queue_id']!, _queueIdMeta),
      );
    }
    if (data.containsKey('started_at_us')) {
      context.handle(
        _startedAtUsMeta,
        startedAtUs.isAcceptableOrUnknown(
          data['started_at_us']!,
          _startedAtUsMeta,
        ),
      );
    }
    if (data.containsKey('ended_at_us')) {
      context.handle(
        _endedAtUsMeta,
        endedAtUs.isAcceptableOrUnknown(data['ended_at_us']!, _endedAtUsMeta),
      );
    }
    if (data.containsKey('record_schema_version')) {
      context.handle(
        _recordSchemaVersionMeta,
        recordSchemaVersion.isAcceptableOrUnknown(
          data['record_schema_version']!,
          _recordSchemaVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {platformId, gameId};
  @override
  Matche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Matche(
      platformId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      )!,
      patchKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patch_key'],
      ),
      queueId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue_id'],
      ),
      startedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_us'],
      ),
      endedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_us'],
      ),
      recordSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}record_schema_version'],
      )!,
    );
  }

  @override
  $MatchesTable createAlias(String alias) {
    return $MatchesTable(attachedDatabase, alias);
  }
}

class Matche extends DataClass implements Insertable<Matche> {
  final String platformId;
  final int gameId;
  final String? patchKey;
  final int? queueId;
  final int? startedAtUs;
  final int? endedAtUs;
  final int recordSchemaVersion;
  const Matche({
    required this.platformId,
    required this.gameId,
    this.patchKey,
    this.queueId,
    this.startedAtUs,
    this.endedAtUs,
    required this.recordSchemaVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['platform_id'] = Variable<String>(platformId);
    map['game_id'] = Variable<int>(gameId);
    if (!nullToAbsent || patchKey != null) {
      map['patch_key'] = Variable<String>(patchKey);
    }
    if (!nullToAbsent || queueId != null) {
      map['queue_id'] = Variable<int>(queueId);
    }
    if (!nullToAbsent || startedAtUs != null) {
      map['started_at_us'] = Variable<int>(startedAtUs);
    }
    if (!nullToAbsent || endedAtUs != null) {
      map['ended_at_us'] = Variable<int>(endedAtUs);
    }
    map['record_schema_version'] = Variable<int>(recordSchemaVersion);
    return map;
  }

  MatchesCompanion toCompanion(bool nullToAbsent) {
    return MatchesCompanion(
      platformId: Value(platformId),
      gameId: Value(gameId),
      patchKey: patchKey == null && nullToAbsent
          ? const Value.absent()
          : Value(patchKey),
      queueId: queueId == null && nullToAbsent
          ? const Value.absent()
          : Value(queueId),
      startedAtUs: startedAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAtUs),
      endedAtUs: endedAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtUs),
      recordSchemaVersion: Value(recordSchemaVersion),
    );
  }

  factory Matche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Matche(
      platformId: serializer.fromJson<String>(json['platformId']),
      gameId: serializer.fromJson<int>(json['gameId']),
      patchKey: serializer.fromJson<String?>(json['patchKey']),
      queueId: serializer.fromJson<int?>(json['queueId']),
      startedAtUs: serializer.fromJson<int?>(json['startedAtUs']),
      endedAtUs: serializer.fromJson<int?>(json['endedAtUs']),
      recordSchemaVersion: serializer.fromJson<int>(
        json['recordSchemaVersion'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'platformId': serializer.toJson<String>(platformId),
      'gameId': serializer.toJson<int>(gameId),
      'patchKey': serializer.toJson<String?>(patchKey),
      'queueId': serializer.toJson<int?>(queueId),
      'startedAtUs': serializer.toJson<int?>(startedAtUs),
      'endedAtUs': serializer.toJson<int?>(endedAtUs),
      'recordSchemaVersion': serializer.toJson<int>(recordSchemaVersion),
    };
  }

  Matche copyWith({
    String? platformId,
    int? gameId,
    Value<String?> patchKey = const Value.absent(),
    Value<int?> queueId = const Value.absent(),
    Value<int?> startedAtUs = const Value.absent(),
    Value<int?> endedAtUs = const Value.absent(),
    int? recordSchemaVersion,
  }) => Matche(
    platformId: platformId ?? this.platformId,
    gameId: gameId ?? this.gameId,
    patchKey: patchKey.present ? patchKey.value : this.patchKey,
    queueId: queueId.present ? queueId.value : this.queueId,
    startedAtUs: startedAtUs.present ? startedAtUs.value : this.startedAtUs,
    endedAtUs: endedAtUs.present ? endedAtUs.value : this.endedAtUs,
    recordSchemaVersion: recordSchemaVersion ?? this.recordSchemaVersion,
  );
  Matche copyWithCompanion(MatchesCompanion data) {
    return Matche(
      platformId: data.platformId.present
          ? data.platformId.value
          : this.platformId,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      patchKey: data.patchKey.present ? data.patchKey.value : this.patchKey,
      queueId: data.queueId.present ? data.queueId.value : this.queueId,
      startedAtUs: data.startedAtUs.present
          ? data.startedAtUs.value
          : this.startedAtUs,
      endedAtUs: data.endedAtUs.present ? data.endedAtUs.value : this.endedAtUs,
      recordSchemaVersion: data.recordSchemaVersion.present
          ? data.recordSchemaVersion.value
          : this.recordSchemaVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Matche(')
          ..write('platformId: $platformId, ')
          ..write('gameId: $gameId, ')
          ..write('patchKey: $patchKey, ')
          ..write('queueId: $queueId, ')
          ..write('startedAtUs: $startedAtUs, ')
          ..write('endedAtUs: $endedAtUs, ')
          ..write('recordSchemaVersion: $recordSchemaVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    platformId,
    gameId,
    patchKey,
    queueId,
    startedAtUs,
    endedAtUs,
    recordSchemaVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Matche &&
          other.platformId == this.platformId &&
          other.gameId == this.gameId &&
          other.patchKey == this.patchKey &&
          other.queueId == this.queueId &&
          other.startedAtUs == this.startedAtUs &&
          other.endedAtUs == this.endedAtUs &&
          other.recordSchemaVersion == this.recordSchemaVersion);
}

class MatchesCompanion extends UpdateCompanion<Matche> {
  final Value<String> platformId;
  final Value<int> gameId;
  final Value<String?> patchKey;
  final Value<int?> queueId;
  final Value<int?> startedAtUs;
  final Value<int?> endedAtUs;
  final Value<int> recordSchemaVersion;
  final Value<int> rowid;
  const MatchesCompanion({
    this.platformId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.patchKey = const Value.absent(),
    this.queueId = const Value.absent(),
    this.startedAtUs = const Value.absent(),
    this.endedAtUs = const Value.absent(),
    this.recordSchemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchesCompanion.insert({
    required String platformId,
    required int gameId,
    this.patchKey = const Value.absent(),
    this.queueId = const Value.absent(),
    this.startedAtUs = const Value.absent(),
    this.endedAtUs = const Value.absent(),
    this.recordSchemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : platformId = Value(platformId),
       gameId = Value(gameId);
  static Insertable<Matche> custom({
    Expression<String>? platformId,
    Expression<int>? gameId,
    Expression<String>? patchKey,
    Expression<int>? queueId,
    Expression<int>? startedAtUs,
    Expression<int>? endedAtUs,
    Expression<int>? recordSchemaVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (platformId != null) 'platform_id': platformId,
      if (gameId != null) 'game_id': gameId,
      if (patchKey != null) 'patch_key': patchKey,
      if (queueId != null) 'queue_id': queueId,
      if (startedAtUs != null) 'started_at_us': startedAtUs,
      if (endedAtUs != null) 'ended_at_us': endedAtUs,
      if (recordSchemaVersion != null)
        'record_schema_version': recordSchemaVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchesCompanion copyWith({
    Value<String>? platformId,
    Value<int>? gameId,
    Value<String?>? patchKey,
    Value<int?>? queueId,
    Value<int?>? startedAtUs,
    Value<int?>? endedAtUs,
    Value<int>? recordSchemaVersion,
    Value<int>? rowid,
  }) {
    return MatchesCompanion(
      platformId: platformId ?? this.platformId,
      gameId: gameId ?? this.gameId,
      patchKey: patchKey ?? this.patchKey,
      queueId: queueId ?? this.queueId,
      startedAtUs: startedAtUs ?? this.startedAtUs,
      endedAtUs: endedAtUs ?? this.endedAtUs,
      recordSchemaVersion: recordSchemaVersion ?? this.recordSchemaVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (platformId.present) {
      map['platform_id'] = Variable<String>(platformId.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (patchKey.present) {
      map['patch_key'] = Variable<String>(patchKey.value);
    }
    if (queueId.present) {
      map['queue_id'] = Variable<int>(queueId.value);
    }
    if (startedAtUs.present) {
      map['started_at_us'] = Variable<int>(startedAtUs.value);
    }
    if (endedAtUs.present) {
      map['ended_at_us'] = Variable<int>(endedAtUs.value);
    }
    if (recordSchemaVersion.present) {
      map['record_schema_version'] = Variable<int>(recordSchemaVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchesCompanion(')
          ..write('platformId: $platformId, ')
          ..write('gameId: $gameId, ')
          ..write('patchKey: $patchKey, ')
          ..write('queueId: $queueId, ')
          ..write('startedAtUs: $startedAtUs, ')
          ..write('endedAtUs: $endedAtUs, ')
          ..write('recordSchemaVersion: $recordSchemaVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountMatchesTable extends AccountMatches
    with TableInfo<$AccountMatchesTable, AccountMatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _puuidMeta = const VerificationMeta('puuid');
  @override
  late final GeneratedColumn<String> puuid = GeneratedColumn<String>(
    'puuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (puuid)',
    ),
  );
  static const VerificationMeta _platformIdMeta = const VerificationMeta(
    'platformId',
  );
  @override
  late final GeneratedColumn<String> platformId = GeneratedColumn<String>(
    'platform_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _participantRoleMeta = const VerificationMeta(
    'participantRole',
  );
  @override
  late final GeneratedColumn<String> participantRole = GeneratedColumn<String>(
    'participant_role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    puuid,
    platformId,
    gameId,
    participantRole,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountMatche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('puuid')) {
      context.handle(
        _puuidMeta,
        puuid.isAcceptableOrUnknown(data['puuid']!, _puuidMeta),
      );
    } else if (isInserting) {
      context.missing(_puuidMeta);
    }
    if (data.containsKey('platform_id')) {
      context.handle(
        _platformIdMeta,
        platformId.isAcceptableOrUnknown(data['platform_id']!, _platformIdMeta),
      );
    } else if (isInserting) {
      context.missing(_platformIdMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('participant_role')) {
      context.handle(
        _participantRoleMeta,
        participantRole.isAcceptableOrUnknown(
          data['participant_role']!,
          _participantRoleMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {puuid, platformId, gameId};
  @override
  AccountMatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountMatche(
      puuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}puuid'],
      )!,
      platformId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      )!,
      participantRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participant_role'],
      ),
    );
  }

  @override
  $AccountMatchesTable createAlias(String alias) {
    return $AccountMatchesTable(attachedDatabase, alias);
  }
}

class AccountMatche extends DataClass implements Insertable<AccountMatche> {
  final String puuid;
  final String platformId;
  final int gameId;
  final String? participantRole;
  const AccountMatche({
    required this.puuid,
    required this.platformId,
    required this.gameId,
    this.participantRole,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['puuid'] = Variable<String>(puuid);
    map['platform_id'] = Variable<String>(platformId);
    map['game_id'] = Variable<int>(gameId);
    if (!nullToAbsent || participantRole != null) {
      map['participant_role'] = Variable<String>(participantRole);
    }
    return map;
  }

  AccountMatchesCompanion toCompanion(bool nullToAbsent) {
    return AccountMatchesCompanion(
      puuid: Value(puuid),
      platformId: Value(platformId),
      gameId: Value(gameId),
      participantRole: participantRole == null && nullToAbsent
          ? const Value.absent()
          : Value(participantRole),
    );
  }

  factory AccountMatche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountMatche(
      puuid: serializer.fromJson<String>(json['puuid']),
      platformId: serializer.fromJson<String>(json['platformId']),
      gameId: serializer.fromJson<int>(json['gameId']),
      participantRole: serializer.fromJson<String?>(json['participantRole']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'puuid': serializer.toJson<String>(puuid),
      'platformId': serializer.toJson<String>(platformId),
      'gameId': serializer.toJson<int>(gameId),
      'participantRole': serializer.toJson<String?>(participantRole),
    };
  }

  AccountMatche copyWith({
    String? puuid,
    String? platformId,
    int? gameId,
    Value<String?> participantRole = const Value.absent(),
  }) => AccountMatche(
    puuid: puuid ?? this.puuid,
    platformId: platformId ?? this.platformId,
    gameId: gameId ?? this.gameId,
    participantRole: participantRole.present
        ? participantRole.value
        : this.participantRole,
  );
  AccountMatche copyWithCompanion(AccountMatchesCompanion data) {
    return AccountMatche(
      puuid: data.puuid.present ? data.puuid.value : this.puuid,
      platformId: data.platformId.present
          ? data.platformId.value
          : this.platformId,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      participantRole: data.participantRole.present
          ? data.participantRole.value
          : this.participantRole,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountMatche(')
          ..write('puuid: $puuid, ')
          ..write('platformId: $platformId, ')
          ..write('gameId: $gameId, ')
          ..write('participantRole: $participantRole')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(puuid, platformId, gameId, participantRole);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountMatche &&
          other.puuid == this.puuid &&
          other.platformId == this.platformId &&
          other.gameId == this.gameId &&
          other.participantRole == this.participantRole);
}

class AccountMatchesCompanion extends UpdateCompanion<AccountMatche> {
  final Value<String> puuid;
  final Value<String> platformId;
  final Value<int> gameId;
  final Value<String?> participantRole;
  final Value<int> rowid;
  const AccountMatchesCompanion({
    this.puuid = const Value.absent(),
    this.platformId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.participantRole = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountMatchesCompanion.insert({
    required String puuid,
    required String platformId,
    required int gameId,
    this.participantRole = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : puuid = Value(puuid),
       platformId = Value(platformId),
       gameId = Value(gameId);
  static Insertable<AccountMatche> custom({
    Expression<String>? puuid,
    Expression<String>? platformId,
    Expression<int>? gameId,
    Expression<String>? participantRole,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (puuid != null) 'puuid': puuid,
      if (platformId != null) 'platform_id': platformId,
      if (gameId != null) 'game_id': gameId,
      if (participantRole != null) 'participant_role': participantRole,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountMatchesCompanion copyWith({
    Value<String>? puuid,
    Value<String>? platformId,
    Value<int>? gameId,
    Value<String?>? participantRole,
    Value<int>? rowid,
  }) {
    return AccountMatchesCompanion(
      puuid: puuid ?? this.puuid,
      platformId: platformId ?? this.platformId,
      gameId: gameId ?? this.gameId,
      participantRole: participantRole ?? this.participantRole,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (puuid.present) {
      map['puuid'] = Variable<String>(puuid.value);
    }
    if (platformId.present) {
      map['platform_id'] = Variable<String>(platformId.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (participantRole.present) {
      map['participant_role'] = Variable<String>(participantRole.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountMatchesCompanion(')
          ..write('puuid: $puuid, ')
          ..write('platformId: $platformId, ')
          ..write('gameId: $gameId, ')
          ..write('participantRole: $participantRole, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchDocumentsTable extends MatchDocuments
    with TableInfo<$MatchDocumentsTable, MatchDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _platformIdMeta = const VerificationMeta(
    'platformId',
  );
  @override
  late final GeneratedColumn<String> platformId = GeneratedColumn<String>(
    'platform_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _puuidMeta = const VerificationMeta('puuid');
  @override
  late final GeneratedColumn<String> puuid = GeneratedColumn<String>(
    'puuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (puuid)',
    ),
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsJsonMeta = const VerificationMeta(
    'detailsJson',
  );
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
    'details_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timelineJsonMeta = const VerificationMeta(
    'timelineJson',
  );
  @override
  late final GeneratedColumn<String> timelineJson = GeneratedColumn<String>(
    'timeline_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtUsMeta = const VerificationMeta(
    'syncedAtUs',
  );
  @override
  late final GeneratedColumn<int> syncedAtUs = GeneratedColumn<int>(
    'synced_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    platformId,
    gameId,
    puuid,
    summaryJson,
    detailsJson,
    timelineJson,
    syncedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('platform_id')) {
      context.handle(
        _platformIdMeta,
        platformId.isAcceptableOrUnknown(data['platform_id']!, _platformIdMeta),
      );
    } else if (isInserting) {
      context.missing(_platformIdMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('puuid')) {
      context.handle(
        _puuidMeta,
        puuid.isAcceptableOrUnknown(data['puuid']!, _puuidMeta),
      );
    } else if (isInserting) {
      context.missing(_puuidMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryJsonMeta);
    }
    if (data.containsKey('details_json')) {
      context.handle(
        _detailsJsonMeta,
        detailsJson.isAcceptableOrUnknown(
          data['details_json']!,
          _detailsJsonMeta,
        ),
      );
    }
    if (data.containsKey('timeline_json')) {
      context.handle(
        _timelineJsonMeta,
        timelineJson.isAcceptableOrUnknown(
          data['timeline_json']!,
          _timelineJsonMeta,
        ),
      );
    }
    if (data.containsKey('synced_at_us')) {
      context.handle(
        _syncedAtUsMeta,
        syncedAtUs.isAcceptableOrUnknown(
          data['synced_at_us']!,
          _syncedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_syncedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {platformId, gameId, puuid};
  @override
  MatchDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchDocument(
      platformId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      )!,
      puuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}puuid'],
      )!,
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      )!,
      detailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details_json'],
      ),
      timelineJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timeline_json'],
      ),
      syncedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at_us'],
      )!,
    );
  }

  @override
  $MatchDocumentsTable createAlias(String alias) {
    return $MatchDocumentsTable(attachedDatabase, alias);
  }
}

class MatchDocument extends DataClass implements Insertable<MatchDocument> {
  final String platformId;
  final int gameId;
  final String puuid;
  final String summaryJson;
  final String? detailsJson;
  final String? timelineJson;
  final int syncedAtUs;
  const MatchDocument({
    required this.platformId,
    required this.gameId,
    required this.puuid,
    required this.summaryJson,
    this.detailsJson,
    this.timelineJson,
    required this.syncedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['platform_id'] = Variable<String>(platformId);
    map['game_id'] = Variable<int>(gameId);
    map['puuid'] = Variable<String>(puuid);
    map['summary_json'] = Variable<String>(summaryJson);
    if (!nullToAbsent || detailsJson != null) {
      map['details_json'] = Variable<String>(detailsJson);
    }
    if (!nullToAbsent || timelineJson != null) {
      map['timeline_json'] = Variable<String>(timelineJson);
    }
    map['synced_at_us'] = Variable<int>(syncedAtUs);
    return map;
  }

  MatchDocumentsCompanion toCompanion(bool nullToAbsent) {
    return MatchDocumentsCompanion(
      platformId: Value(platformId),
      gameId: Value(gameId),
      puuid: Value(puuid),
      summaryJson: Value(summaryJson),
      detailsJson: detailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsJson),
      timelineJson: timelineJson == null && nullToAbsent
          ? const Value.absent()
          : Value(timelineJson),
      syncedAtUs: Value(syncedAtUs),
    );
  }

  factory MatchDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchDocument(
      platformId: serializer.fromJson<String>(json['platformId']),
      gameId: serializer.fromJson<int>(json['gameId']),
      puuid: serializer.fromJson<String>(json['puuid']),
      summaryJson: serializer.fromJson<String>(json['summaryJson']),
      detailsJson: serializer.fromJson<String?>(json['detailsJson']),
      timelineJson: serializer.fromJson<String?>(json['timelineJson']),
      syncedAtUs: serializer.fromJson<int>(json['syncedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'platformId': serializer.toJson<String>(platformId),
      'gameId': serializer.toJson<int>(gameId),
      'puuid': serializer.toJson<String>(puuid),
      'summaryJson': serializer.toJson<String>(summaryJson),
      'detailsJson': serializer.toJson<String?>(detailsJson),
      'timelineJson': serializer.toJson<String?>(timelineJson),
      'syncedAtUs': serializer.toJson<int>(syncedAtUs),
    };
  }

  MatchDocument copyWith({
    String? platformId,
    int? gameId,
    String? puuid,
    String? summaryJson,
    Value<String?> detailsJson = const Value.absent(),
    Value<String?> timelineJson = const Value.absent(),
    int? syncedAtUs,
  }) => MatchDocument(
    platformId: platformId ?? this.platformId,
    gameId: gameId ?? this.gameId,
    puuid: puuid ?? this.puuid,
    summaryJson: summaryJson ?? this.summaryJson,
    detailsJson: detailsJson.present ? detailsJson.value : this.detailsJson,
    timelineJson: timelineJson.present ? timelineJson.value : this.timelineJson,
    syncedAtUs: syncedAtUs ?? this.syncedAtUs,
  );
  MatchDocument copyWithCompanion(MatchDocumentsCompanion data) {
    return MatchDocument(
      platformId: data.platformId.present
          ? data.platformId.value
          : this.platformId,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      puuid: data.puuid.present ? data.puuid.value : this.puuid,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      detailsJson: data.detailsJson.present
          ? data.detailsJson.value
          : this.detailsJson,
      timelineJson: data.timelineJson.present
          ? data.timelineJson.value
          : this.timelineJson,
      syncedAtUs: data.syncedAtUs.present
          ? data.syncedAtUs.value
          : this.syncedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchDocument(')
          ..write('platformId: $platformId, ')
          ..write('gameId: $gameId, ')
          ..write('puuid: $puuid, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('timelineJson: $timelineJson, ')
          ..write('syncedAtUs: $syncedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    platformId,
    gameId,
    puuid,
    summaryJson,
    detailsJson,
    timelineJson,
    syncedAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchDocument &&
          other.platformId == this.platformId &&
          other.gameId == this.gameId &&
          other.puuid == this.puuid &&
          other.summaryJson == this.summaryJson &&
          other.detailsJson == this.detailsJson &&
          other.timelineJson == this.timelineJson &&
          other.syncedAtUs == this.syncedAtUs);
}

class MatchDocumentsCompanion extends UpdateCompanion<MatchDocument> {
  final Value<String> platformId;
  final Value<int> gameId;
  final Value<String> puuid;
  final Value<String> summaryJson;
  final Value<String?> detailsJson;
  final Value<String?> timelineJson;
  final Value<int> syncedAtUs;
  final Value<int> rowid;
  const MatchDocumentsCompanion({
    this.platformId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.puuid = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.timelineJson = const Value.absent(),
    this.syncedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchDocumentsCompanion.insert({
    required String platformId,
    required int gameId,
    required String puuid,
    required String summaryJson,
    this.detailsJson = const Value.absent(),
    this.timelineJson = const Value.absent(),
    required int syncedAtUs,
    this.rowid = const Value.absent(),
  }) : platformId = Value(platformId),
       gameId = Value(gameId),
       puuid = Value(puuid),
       summaryJson = Value(summaryJson),
       syncedAtUs = Value(syncedAtUs);
  static Insertable<MatchDocument> custom({
    Expression<String>? platformId,
    Expression<int>? gameId,
    Expression<String>? puuid,
    Expression<String>? summaryJson,
    Expression<String>? detailsJson,
    Expression<String>? timelineJson,
    Expression<int>? syncedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (platformId != null) 'platform_id': platformId,
      if (gameId != null) 'game_id': gameId,
      if (puuid != null) 'puuid': puuid,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (detailsJson != null) 'details_json': detailsJson,
      if (timelineJson != null) 'timeline_json': timelineJson,
      if (syncedAtUs != null) 'synced_at_us': syncedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchDocumentsCompanion copyWith({
    Value<String>? platformId,
    Value<int>? gameId,
    Value<String>? puuid,
    Value<String>? summaryJson,
    Value<String?>? detailsJson,
    Value<String?>? timelineJson,
    Value<int>? syncedAtUs,
    Value<int>? rowid,
  }) {
    return MatchDocumentsCompanion(
      platformId: platformId ?? this.platformId,
      gameId: gameId ?? this.gameId,
      puuid: puuid ?? this.puuid,
      summaryJson: summaryJson ?? this.summaryJson,
      detailsJson: detailsJson ?? this.detailsJson,
      timelineJson: timelineJson ?? this.timelineJson,
      syncedAtUs: syncedAtUs ?? this.syncedAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (platformId.present) {
      map['platform_id'] = Variable<String>(platformId.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (puuid.present) {
      map['puuid'] = Variable<String>(puuid.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (timelineJson.present) {
      map['timeline_json'] = Variable<String>(timelineJson.value);
    }
    if (syncedAtUs.present) {
      map['synced_at_us'] = Variable<int>(syncedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchDocumentsCompanion(')
          ..write('platformId: $platformId, ')
          ..write('gameId: $gameId, ')
          ..write('puuid: $puuid, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('timelineJson: $timelineJson, ')
          ..write('syncedAtUs: $syncedAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RankedSnapshotsTable extends RankedSnapshots
    with TableInfo<$RankedSnapshotsTable, RankedSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RankedSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _puuidMeta = const VerificationMeta('puuid');
  @override
  late final GeneratedColumn<String> puuid = GeneratedColumn<String>(
    'puuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (puuid)',
    ),
  );
  static const VerificationMeta _observedAtUsMeta = const VerificationMeta(
    'observedAtUs',
  );
  @override
  late final GeneratedColumn<int> observedAtUs = GeneratedColumn<int>(
    'observed_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semanticHashMeta = const VerificationMeta(
    'semanticHash',
  );
  @override
  late final GeneratedColumn<String> semanticHash = GeneratedColumn<String>(
    'semantic_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    puuid,
    observedAtUs,
    payloadJson,
    semanticHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ranked_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<RankedSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('puuid')) {
      context.handle(
        _puuidMeta,
        puuid.isAcceptableOrUnknown(data['puuid']!, _puuidMeta),
      );
    } else if (isInserting) {
      context.missing(_puuidMeta);
    }
    if (data.containsKey('observed_at_us')) {
      context.handle(
        _observedAtUsMeta,
        observedAtUs.isAcceptableOrUnknown(
          data['observed_at_us']!,
          _observedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_observedAtUsMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('semantic_hash')) {
      context.handle(
        _semanticHashMeta,
        semanticHash.isAcceptableOrUnknown(
          data['semantic_hash']!,
          _semanticHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RankedSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RankedSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      puuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}puuid'],
      )!,
      observedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}observed_at_us'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      semanticHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_hash'],
      )!,
    );
  }

  @override
  $RankedSnapshotsTable createAlias(String alias) {
    return $RankedSnapshotsTable(attachedDatabase, alias);
  }
}

class RankedSnapshot extends DataClass implements Insertable<RankedSnapshot> {
  final int id;
  final String puuid;
  final int observedAtUs;
  final String payloadJson;
  final String semanticHash;
  const RankedSnapshot({
    required this.id,
    required this.puuid,
    required this.observedAtUs,
    required this.payloadJson,
    required this.semanticHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['puuid'] = Variable<String>(puuid);
    map['observed_at_us'] = Variable<int>(observedAtUs);
    map['payload_json'] = Variable<String>(payloadJson);
    map['semantic_hash'] = Variable<String>(semanticHash);
    return map;
  }

  RankedSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return RankedSnapshotsCompanion(
      id: Value(id),
      puuid: Value(puuid),
      observedAtUs: Value(observedAtUs),
      payloadJson: Value(payloadJson),
      semanticHash: Value(semanticHash),
    );
  }

  factory RankedSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RankedSnapshot(
      id: serializer.fromJson<int>(json['id']),
      puuid: serializer.fromJson<String>(json['puuid']),
      observedAtUs: serializer.fromJson<int>(json['observedAtUs']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      semanticHash: serializer.fromJson<String>(json['semanticHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'puuid': serializer.toJson<String>(puuid),
      'observedAtUs': serializer.toJson<int>(observedAtUs),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'semanticHash': serializer.toJson<String>(semanticHash),
    };
  }

  RankedSnapshot copyWith({
    int? id,
    String? puuid,
    int? observedAtUs,
    String? payloadJson,
    String? semanticHash,
  }) => RankedSnapshot(
    id: id ?? this.id,
    puuid: puuid ?? this.puuid,
    observedAtUs: observedAtUs ?? this.observedAtUs,
    payloadJson: payloadJson ?? this.payloadJson,
    semanticHash: semanticHash ?? this.semanticHash,
  );
  RankedSnapshot copyWithCompanion(RankedSnapshotsCompanion data) {
    return RankedSnapshot(
      id: data.id.present ? data.id.value : this.id,
      puuid: data.puuid.present ? data.puuid.value : this.puuid,
      observedAtUs: data.observedAtUs.present
          ? data.observedAtUs.value
          : this.observedAtUs,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      semanticHash: data.semanticHash.present
          ? data.semanticHash.value
          : this.semanticHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RankedSnapshot(')
          ..write('id: $id, ')
          ..write('puuid: $puuid, ')
          ..write('observedAtUs: $observedAtUs, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('semanticHash: $semanticHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, puuid, observedAtUs, payloadJson, semanticHash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RankedSnapshot &&
          other.id == this.id &&
          other.puuid == this.puuid &&
          other.observedAtUs == this.observedAtUs &&
          other.payloadJson == this.payloadJson &&
          other.semanticHash == this.semanticHash);
}

class RankedSnapshotsCompanion extends UpdateCompanion<RankedSnapshot> {
  final Value<int> id;
  final Value<String> puuid;
  final Value<int> observedAtUs;
  final Value<String> payloadJson;
  final Value<String> semanticHash;
  const RankedSnapshotsCompanion({
    this.id = const Value.absent(),
    this.puuid = const Value.absent(),
    this.observedAtUs = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.semanticHash = const Value.absent(),
  });
  RankedSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required String puuid,
    required int observedAtUs,
    required String payloadJson,
    required String semanticHash,
  }) : puuid = Value(puuid),
       observedAtUs = Value(observedAtUs),
       payloadJson = Value(payloadJson),
       semanticHash = Value(semanticHash);
  static Insertable<RankedSnapshot> custom({
    Expression<int>? id,
    Expression<String>? puuid,
    Expression<int>? observedAtUs,
    Expression<String>? payloadJson,
    Expression<String>? semanticHash,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (puuid != null) 'puuid': puuid,
      if (observedAtUs != null) 'observed_at_us': observedAtUs,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (semanticHash != null) 'semantic_hash': semanticHash,
    });
  }

  RankedSnapshotsCompanion copyWith({
    Value<int>? id,
    Value<String>? puuid,
    Value<int>? observedAtUs,
    Value<String>? payloadJson,
    Value<String>? semanticHash,
  }) {
    return RankedSnapshotsCompanion(
      id: id ?? this.id,
      puuid: puuid ?? this.puuid,
      observedAtUs: observedAtUs ?? this.observedAtUs,
      payloadJson: payloadJson ?? this.payloadJson,
      semanticHash: semanticHash ?? this.semanticHash,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (puuid.present) {
      map['puuid'] = Variable<String>(puuid.value);
    }
    if (observedAtUs.present) {
      map['observed_at_us'] = Variable<int>(observedAtUs.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (semanticHash.present) {
      map['semantic_hash'] = Variable<String>(semanticHash.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RankedSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('puuid: $puuid, ')
          ..write('observedAtUs: $observedAtUs, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('semanticHash: $semanticHash')
          ..write(')'))
        .toString();
  }
}

class $CaptureEpochsTable extends CaptureEpochs
    with TableInfo<$CaptureEpochsTable, CaptureEpoch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaptureEpochsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtUsMeta = const VerificationMeta(
    'startedAtUs',
  );
  @override
  late final GeneratedColumn<int> startedAtUs = GeneratedColumn<int>(
    'started_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtUsMeta = const VerificationMeta(
    'endedAtUs',
  );
  @override
  late final GeneratedColumn<int> endedAtUs = GeneratedColumn<int>(
    'ended_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, startedAtUs, endedAtUs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capture_epochs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaptureEpoch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at_us')) {
      context.handle(
        _startedAtUsMeta,
        startedAtUs.isAcceptableOrUnknown(
          data['started_at_us']!,
          _startedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUsMeta);
    }
    if (data.containsKey('ended_at_us')) {
      context.handle(
        _endedAtUsMeta,
        endedAtUs.isAcceptableOrUnknown(data['ended_at_us']!, _endedAtUsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaptureEpoch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaptureEpoch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_us'],
      )!,
      endedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_us'],
      ),
    );
  }

  @override
  $CaptureEpochsTable createAlias(String alias) {
    return $CaptureEpochsTable(attachedDatabase, alias);
  }
}

class CaptureEpoch extends DataClass implements Insertable<CaptureEpoch> {
  final String id;
  final int startedAtUs;
  final int? endedAtUs;
  const CaptureEpoch({
    required this.id,
    required this.startedAtUs,
    this.endedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at_us'] = Variable<int>(startedAtUs);
    if (!nullToAbsent || endedAtUs != null) {
      map['ended_at_us'] = Variable<int>(endedAtUs);
    }
    return map;
  }

  CaptureEpochsCompanion toCompanion(bool nullToAbsent) {
    return CaptureEpochsCompanion(
      id: Value(id),
      startedAtUs: Value(startedAtUs),
      endedAtUs: endedAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtUs),
    );
  }

  factory CaptureEpoch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaptureEpoch(
      id: serializer.fromJson<String>(json['id']),
      startedAtUs: serializer.fromJson<int>(json['startedAtUs']),
      endedAtUs: serializer.fromJson<int?>(json['endedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAtUs': serializer.toJson<int>(startedAtUs),
      'endedAtUs': serializer.toJson<int?>(endedAtUs),
    };
  }

  CaptureEpoch copyWith({
    String? id,
    int? startedAtUs,
    Value<int?> endedAtUs = const Value.absent(),
  }) => CaptureEpoch(
    id: id ?? this.id,
    startedAtUs: startedAtUs ?? this.startedAtUs,
    endedAtUs: endedAtUs.present ? endedAtUs.value : this.endedAtUs,
  );
  CaptureEpoch copyWithCompanion(CaptureEpochsCompanion data) {
    return CaptureEpoch(
      id: data.id.present ? data.id.value : this.id,
      startedAtUs: data.startedAtUs.present
          ? data.startedAtUs.value
          : this.startedAtUs,
      endedAtUs: data.endedAtUs.present ? data.endedAtUs.value : this.endedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaptureEpoch(')
          ..write('id: $id, ')
          ..write('startedAtUs: $startedAtUs, ')
          ..write('endedAtUs: $endedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startedAtUs, endedAtUs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureEpoch &&
          other.id == this.id &&
          other.startedAtUs == this.startedAtUs &&
          other.endedAtUs == this.endedAtUs);
}

class CaptureEpochsCompanion extends UpdateCompanion<CaptureEpoch> {
  final Value<String> id;
  final Value<int> startedAtUs;
  final Value<int?> endedAtUs;
  final Value<int> rowid;
  const CaptureEpochsCompanion({
    this.id = const Value.absent(),
    this.startedAtUs = const Value.absent(),
    this.endedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaptureEpochsCompanion.insert({
    required String id,
    required int startedAtUs,
    this.endedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAtUs = Value(startedAtUs);
  static Insertable<CaptureEpoch> custom({
    Expression<String>? id,
    Expression<int>? startedAtUs,
    Expression<int>? endedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAtUs != null) 'started_at_us': startedAtUs,
      if (endedAtUs != null) 'ended_at_us': endedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaptureEpochsCompanion copyWith({
    Value<String>? id,
    Value<int>? startedAtUs,
    Value<int?>? endedAtUs,
    Value<int>? rowid,
  }) {
    return CaptureEpochsCompanion(
      id: id ?? this.id,
      startedAtUs: startedAtUs ?? this.startedAtUs,
      endedAtUs: endedAtUs ?? this.endedAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAtUs.present) {
      map['started_at_us'] = Variable<int>(startedAtUs.value);
    }
    if (endedAtUs.present) {
      map['ended_at_us'] = Variable<int>(endedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaptureEpochsCompanion(')
          ..write('id: $id, ')
          ..write('startedAtUs: $startedAtUs, ')
          ..write('endedAtUs: $endedAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourceRecordsTable extends SourceRecords
    with TableInfo<$SourceRecordsTable, SourceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryKindMeta = const VerificationMeta(
    'entryKind',
  );
  @override
  late final GeneratedColumn<String> entryKind = GeneratedColumn<String>(
    'entry_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceNamespaceMeta = const VerificationMeta(
    'sourceNamespace',
  );
  @override
  late final GeneratedColumn<String> sourceNamespace = GeneratedColumn<String>(
    'source_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRecordKeyMeta = const VerificationMeta(
    'sourceRecordKey',
  );
  @override
  late final GeneratedColumn<String> sourceRecordKey = GeneratedColumn<String>(
    'source_record_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceSequenceMeta = const VerificationMeta(
    'sourceSequence',
  );
  @override
  late final GeneratedColumn<int> sourceSequence = GeneratedColumn<int>(
    'source_sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transportGenerationMeta =
      const VerificationMeta('transportGeneration');
  @override
  late final GeneratedColumn<int> transportGeneration = GeneratedColumn<int>(
    'transport_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameGenerationMeta = const VerificationMeta(
    'gameGeneration',
  );
  @override
  late final GeneratedColumn<int> gameGeneration = GeneratedColumn<int>(
    'game_generation',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _platformIdMeta = const VerificationMeta(
    'platformId',
  );
  @override
  late final GeneratedColumn<String> platformId = GeneratedColumn<String>(
    'platform_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _semanticKeyMeta = const VerificationMeta(
    'semanticKey',
  );
  @override
  late final GeneratedColumn<String> semanticKey = GeneratedColumn<String>(
    'semantic_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captureEpochIdMeta = const VerificationMeta(
    'captureEpochId',
  );
  @override
  late final GeneratedColumn<String> captureEpochId = GeneratedColumn<String>(
    'capture_epoch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES capture_epochs (id)',
    ),
  );
  static const VerificationMeta _receivedAtUsMeta = const VerificationMeta(
    'receivedAtUs',
  );
  @override
  late final GeneratedColumn<int> receivedAtUs = GeneratedColumn<int>(
    'received_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawPayloadMeta = const VerificationMeta(
    'rawPayload',
  );
  @override
  late final GeneratedColumn<Uint8List> rawPayload = GeneratedColumn<Uint8List>(
    'raw_payload',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawFormatMeta = const VerificationMeta(
    'rawFormat',
  );
  @override
  late final GeneratedColumn<String> rawFormat = GeneratedColumn<String>(
    'raw_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawHashMeta = const VerificationMeta(
    'rawHash',
  );
  @override
  late final GeneratedColumn<String> rawHash = GeneratedColumn<String>(
    'raw_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semanticHashMeta = const VerificationMeta(
    'semanticHash',
  );
  @override
  late final GeneratedColumn<String> semanticHash = GeneratedColumn<String>(
    'semantic_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retentionClassMeta = const VerificationMeta(
    'retentionClass',
  );
  @override
  late final GeneratedColumn<String> retentionClass = GeneratedColumn<String>(
    'retention_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeSchemaVersionMeta =
      const VerificationMeta('envelopeSchemaVersion');
  @override
  late final GeneratedColumn<int> envelopeSchemaVersion = GeneratedColumn<int>(
    'envelope_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _redactedMeta = const VerificationMeta(
    'redacted',
  );
  @override
  late final GeneratedColumn<bool> redacted = GeneratedColumn<bool>(
    'redacted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("redacted" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryKind,
    sourceNamespace,
    sourceRecordKey,
    sourceSequence,
    transportGeneration,
    gameGeneration,
    platformId,
    gameId,
    semanticKey,
    captureEpochId,
    receivedAtUs,
    rawPayload,
    rawFormat,
    rawHash,
    semanticHash,
    retentionClass,
    envelopeSchemaVersion,
    redacted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entry_kind')) {
      context.handle(
        _entryKindMeta,
        entryKind.isAcceptableOrUnknown(data['entry_kind']!, _entryKindMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKindMeta);
    }
    if (data.containsKey('source_namespace')) {
      context.handle(
        _sourceNamespaceMeta,
        sourceNamespace.isAcceptableOrUnknown(
          data['source_namespace']!,
          _sourceNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceNamespaceMeta);
    }
    if (data.containsKey('source_record_key')) {
      context.handle(
        _sourceRecordKeyMeta,
        sourceRecordKey.isAcceptableOrUnknown(
          data['source_record_key']!,
          _sourceRecordKeyMeta,
        ),
      );
    }
    if (data.containsKey('source_sequence')) {
      context.handle(
        _sourceSequenceMeta,
        sourceSequence.isAcceptableOrUnknown(
          data['source_sequence']!,
          _sourceSequenceMeta,
        ),
      );
    }
    if (data.containsKey('transport_generation')) {
      context.handle(
        _transportGenerationMeta,
        transportGeneration.isAcceptableOrUnknown(
          data['transport_generation']!,
          _transportGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transportGenerationMeta);
    }
    if (data.containsKey('game_generation')) {
      context.handle(
        _gameGenerationMeta,
        gameGeneration.isAcceptableOrUnknown(
          data['game_generation']!,
          _gameGenerationMeta,
        ),
      );
    }
    if (data.containsKey('platform_id')) {
      context.handle(
        _platformIdMeta,
        platformId.isAcceptableOrUnknown(data['platform_id']!, _platformIdMeta),
      );
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('semantic_key')) {
      context.handle(
        _semanticKeyMeta,
        semanticKey.isAcceptableOrUnknown(
          data['semantic_key']!,
          _semanticKeyMeta,
        ),
      );
    }
    if (data.containsKey('capture_epoch_id')) {
      context.handle(
        _captureEpochIdMeta,
        captureEpochId.isAcceptableOrUnknown(
          data['capture_epoch_id']!,
          _captureEpochIdMeta,
        ),
      );
    }
    if (data.containsKey('received_at_us')) {
      context.handle(
        _receivedAtUsMeta,
        receivedAtUs.isAcceptableOrUnknown(
          data['received_at_us']!,
          _receivedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_receivedAtUsMeta);
    }
    if (data.containsKey('raw_payload')) {
      context.handle(
        _rawPayloadMeta,
        rawPayload.isAcceptableOrUnknown(data['raw_payload']!, _rawPayloadMeta),
      );
    } else if (isInserting) {
      context.missing(_rawPayloadMeta);
    }
    if (data.containsKey('raw_format')) {
      context.handle(
        _rawFormatMeta,
        rawFormat.isAcceptableOrUnknown(data['raw_format']!, _rawFormatMeta),
      );
    } else if (isInserting) {
      context.missing(_rawFormatMeta);
    }
    if (data.containsKey('raw_hash')) {
      context.handle(
        _rawHashMeta,
        rawHash.isAcceptableOrUnknown(data['raw_hash']!, _rawHashMeta),
      );
    } else if (isInserting) {
      context.missing(_rawHashMeta);
    }
    if (data.containsKey('semantic_hash')) {
      context.handle(
        _semanticHashMeta,
        semanticHash.isAcceptableOrUnknown(
          data['semantic_hash']!,
          _semanticHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticHashMeta);
    }
    if (data.containsKey('retention_class')) {
      context.handle(
        _retentionClassMeta,
        retentionClass.isAcceptableOrUnknown(
          data['retention_class']!,
          _retentionClassMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_retentionClassMeta);
    }
    if (data.containsKey('envelope_schema_version')) {
      context.handle(
        _envelopeSchemaVersionMeta,
        envelopeSchemaVersion.isAcceptableOrUnknown(
          data['envelope_schema_version']!,
          _envelopeSchemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeSchemaVersionMeta);
    }
    if (data.containsKey('redacted')) {
      context.handle(
        _redactedMeta,
        redacted.isAcceptableOrUnknown(data['redacted']!, _redactedMeta),
      );
    } else if (isInserting) {
      context.missing(_redactedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entryKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_kind'],
      )!,
      sourceNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_namespace'],
      )!,
      sourceRecordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_record_key'],
      ),
      sourceSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_sequence'],
      ),
      transportGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transport_generation'],
      )!,
      gameGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_generation'],
      ),
      platformId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_id'],
      ),
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      ),
      semanticKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_key'],
      ),
      captureEpochId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_epoch_id'],
      ),
      receivedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_at_us'],
      )!,
      rawPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}raw_payload'],
      )!,
      rawFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_format'],
      )!,
      rawHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_hash'],
      )!,
      semanticHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_hash'],
      )!,
      retentionClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}retention_class'],
      )!,
      envelopeSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}envelope_schema_version'],
      )!,
      redacted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}redacted'],
      )!,
    );
  }

  @override
  $SourceRecordsTable createAlias(String alias) {
    return $SourceRecordsTable(attachedDatabase, alias);
  }
}

class SourceRecord extends DataClass implements Insertable<SourceRecord> {
  final String id;
  final String entryKind;
  final String sourceNamespace;
  final String? sourceRecordKey;
  final int? sourceSequence;
  final int transportGeneration;
  final int? gameGeneration;
  final String? platformId;
  final int? gameId;
  final String? semanticKey;
  final String? captureEpochId;
  final int receivedAtUs;
  final Uint8List rawPayload;
  final String rawFormat;
  final String rawHash;
  final String semanticHash;
  final String retentionClass;
  final int envelopeSchemaVersion;
  final bool redacted;
  const SourceRecord({
    required this.id,
    required this.entryKind,
    required this.sourceNamespace,
    this.sourceRecordKey,
    this.sourceSequence,
    required this.transportGeneration,
    this.gameGeneration,
    this.platformId,
    this.gameId,
    this.semanticKey,
    this.captureEpochId,
    required this.receivedAtUs,
    required this.rawPayload,
    required this.rawFormat,
    required this.rawHash,
    required this.semanticHash,
    required this.retentionClass,
    required this.envelopeSchemaVersion,
    required this.redacted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entry_kind'] = Variable<String>(entryKind);
    map['source_namespace'] = Variable<String>(sourceNamespace);
    if (!nullToAbsent || sourceRecordKey != null) {
      map['source_record_key'] = Variable<String>(sourceRecordKey);
    }
    if (!nullToAbsent || sourceSequence != null) {
      map['source_sequence'] = Variable<int>(sourceSequence);
    }
    map['transport_generation'] = Variable<int>(transportGeneration);
    if (!nullToAbsent || gameGeneration != null) {
      map['game_generation'] = Variable<int>(gameGeneration);
    }
    if (!nullToAbsent || platformId != null) {
      map['platform_id'] = Variable<String>(platformId);
    }
    if (!nullToAbsent || gameId != null) {
      map['game_id'] = Variable<int>(gameId);
    }
    if (!nullToAbsent || semanticKey != null) {
      map['semantic_key'] = Variable<String>(semanticKey);
    }
    if (!nullToAbsent || captureEpochId != null) {
      map['capture_epoch_id'] = Variable<String>(captureEpochId);
    }
    map['received_at_us'] = Variable<int>(receivedAtUs);
    map['raw_payload'] = Variable<Uint8List>(rawPayload);
    map['raw_format'] = Variable<String>(rawFormat);
    map['raw_hash'] = Variable<String>(rawHash);
    map['semantic_hash'] = Variable<String>(semanticHash);
    map['retention_class'] = Variable<String>(retentionClass);
    map['envelope_schema_version'] = Variable<int>(envelopeSchemaVersion);
    map['redacted'] = Variable<bool>(redacted);
    return map;
  }

  SourceRecordsCompanion toCompanion(bool nullToAbsent) {
    return SourceRecordsCompanion(
      id: Value(id),
      entryKind: Value(entryKind),
      sourceNamespace: Value(sourceNamespace),
      sourceRecordKey: sourceRecordKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRecordKey),
      sourceSequence: sourceSequence == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSequence),
      transportGeneration: Value(transportGeneration),
      gameGeneration: gameGeneration == null && nullToAbsent
          ? const Value.absent()
          : Value(gameGeneration),
      platformId: platformId == null && nullToAbsent
          ? const Value.absent()
          : Value(platformId),
      gameId: gameId == null && nullToAbsent
          ? const Value.absent()
          : Value(gameId),
      semanticKey: semanticKey == null && nullToAbsent
          ? const Value.absent()
          : Value(semanticKey),
      captureEpochId: captureEpochId == null && nullToAbsent
          ? const Value.absent()
          : Value(captureEpochId),
      receivedAtUs: Value(receivedAtUs),
      rawPayload: Value(rawPayload),
      rawFormat: Value(rawFormat),
      rawHash: Value(rawHash),
      semanticHash: Value(semanticHash),
      retentionClass: Value(retentionClass),
      envelopeSchemaVersion: Value(envelopeSchemaVersion),
      redacted: Value(redacted),
    );
  }

  factory SourceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRecord(
      id: serializer.fromJson<String>(json['id']),
      entryKind: serializer.fromJson<String>(json['entryKind']),
      sourceNamespace: serializer.fromJson<String>(json['sourceNamespace']),
      sourceRecordKey: serializer.fromJson<String?>(json['sourceRecordKey']),
      sourceSequence: serializer.fromJson<int?>(json['sourceSequence']),
      transportGeneration: serializer.fromJson<int>(
        json['transportGeneration'],
      ),
      gameGeneration: serializer.fromJson<int?>(json['gameGeneration']),
      platformId: serializer.fromJson<String?>(json['platformId']),
      gameId: serializer.fromJson<int?>(json['gameId']),
      semanticKey: serializer.fromJson<String?>(json['semanticKey']),
      captureEpochId: serializer.fromJson<String?>(json['captureEpochId']),
      receivedAtUs: serializer.fromJson<int>(json['receivedAtUs']),
      rawPayload: serializer.fromJson<Uint8List>(json['rawPayload']),
      rawFormat: serializer.fromJson<String>(json['rawFormat']),
      rawHash: serializer.fromJson<String>(json['rawHash']),
      semanticHash: serializer.fromJson<String>(json['semanticHash']),
      retentionClass: serializer.fromJson<String>(json['retentionClass']),
      envelopeSchemaVersion: serializer.fromJson<int>(
        json['envelopeSchemaVersion'],
      ),
      redacted: serializer.fromJson<bool>(json['redacted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entryKind': serializer.toJson<String>(entryKind),
      'sourceNamespace': serializer.toJson<String>(sourceNamespace),
      'sourceRecordKey': serializer.toJson<String?>(sourceRecordKey),
      'sourceSequence': serializer.toJson<int?>(sourceSequence),
      'transportGeneration': serializer.toJson<int>(transportGeneration),
      'gameGeneration': serializer.toJson<int?>(gameGeneration),
      'platformId': serializer.toJson<String?>(platformId),
      'gameId': serializer.toJson<int?>(gameId),
      'semanticKey': serializer.toJson<String?>(semanticKey),
      'captureEpochId': serializer.toJson<String?>(captureEpochId),
      'receivedAtUs': serializer.toJson<int>(receivedAtUs),
      'rawPayload': serializer.toJson<Uint8List>(rawPayload),
      'rawFormat': serializer.toJson<String>(rawFormat),
      'rawHash': serializer.toJson<String>(rawHash),
      'semanticHash': serializer.toJson<String>(semanticHash),
      'retentionClass': serializer.toJson<String>(retentionClass),
      'envelopeSchemaVersion': serializer.toJson<int>(envelopeSchemaVersion),
      'redacted': serializer.toJson<bool>(redacted),
    };
  }

  SourceRecord copyWith({
    String? id,
    String? entryKind,
    String? sourceNamespace,
    Value<String?> sourceRecordKey = const Value.absent(),
    Value<int?> sourceSequence = const Value.absent(),
    int? transportGeneration,
    Value<int?> gameGeneration = const Value.absent(),
    Value<String?> platformId = const Value.absent(),
    Value<int?> gameId = const Value.absent(),
    Value<String?> semanticKey = const Value.absent(),
    Value<String?> captureEpochId = const Value.absent(),
    int? receivedAtUs,
    Uint8List? rawPayload,
    String? rawFormat,
    String? rawHash,
    String? semanticHash,
    String? retentionClass,
    int? envelopeSchemaVersion,
    bool? redacted,
  }) => SourceRecord(
    id: id ?? this.id,
    entryKind: entryKind ?? this.entryKind,
    sourceNamespace: sourceNamespace ?? this.sourceNamespace,
    sourceRecordKey: sourceRecordKey.present
        ? sourceRecordKey.value
        : this.sourceRecordKey,
    sourceSequence: sourceSequence.present
        ? sourceSequence.value
        : this.sourceSequence,
    transportGeneration: transportGeneration ?? this.transportGeneration,
    gameGeneration: gameGeneration.present
        ? gameGeneration.value
        : this.gameGeneration,
    platformId: platformId.present ? platformId.value : this.platformId,
    gameId: gameId.present ? gameId.value : this.gameId,
    semanticKey: semanticKey.present ? semanticKey.value : this.semanticKey,
    captureEpochId: captureEpochId.present
        ? captureEpochId.value
        : this.captureEpochId,
    receivedAtUs: receivedAtUs ?? this.receivedAtUs,
    rawPayload: rawPayload ?? this.rawPayload,
    rawFormat: rawFormat ?? this.rawFormat,
    rawHash: rawHash ?? this.rawHash,
    semanticHash: semanticHash ?? this.semanticHash,
    retentionClass: retentionClass ?? this.retentionClass,
    envelopeSchemaVersion: envelopeSchemaVersion ?? this.envelopeSchemaVersion,
    redacted: redacted ?? this.redacted,
  );
  SourceRecord copyWithCompanion(SourceRecordsCompanion data) {
    return SourceRecord(
      id: data.id.present ? data.id.value : this.id,
      entryKind: data.entryKind.present ? data.entryKind.value : this.entryKind,
      sourceNamespace: data.sourceNamespace.present
          ? data.sourceNamespace.value
          : this.sourceNamespace,
      sourceRecordKey: data.sourceRecordKey.present
          ? data.sourceRecordKey.value
          : this.sourceRecordKey,
      sourceSequence: data.sourceSequence.present
          ? data.sourceSequence.value
          : this.sourceSequence,
      transportGeneration: data.transportGeneration.present
          ? data.transportGeneration.value
          : this.transportGeneration,
      gameGeneration: data.gameGeneration.present
          ? data.gameGeneration.value
          : this.gameGeneration,
      platformId: data.platformId.present
          ? data.platformId.value
          : this.platformId,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      semanticKey: data.semanticKey.present
          ? data.semanticKey.value
          : this.semanticKey,
      captureEpochId: data.captureEpochId.present
          ? data.captureEpochId.value
          : this.captureEpochId,
      receivedAtUs: data.receivedAtUs.present
          ? data.receivedAtUs.value
          : this.receivedAtUs,
      rawPayload: data.rawPayload.present
          ? data.rawPayload.value
          : this.rawPayload,
      rawFormat: data.rawFormat.present ? data.rawFormat.value : this.rawFormat,
      rawHash: data.rawHash.present ? data.rawHash.value : this.rawHash,
      semanticHash: data.semanticHash.present
          ? data.semanticHash.value
          : this.semanticHash,
      retentionClass: data.retentionClass.present
          ? data.retentionClass.value
          : this.retentionClass,
      envelopeSchemaVersion: data.envelopeSchemaVersion.present
          ? data.envelopeSchemaVersion.value
          : this.envelopeSchemaVersion,
      redacted: data.redacted.present ? data.redacted.value : this.redacted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRecord(')
          ..write('id: $id, ')
          ..write('entryKind: $entryKind, ')
          ..write('sourceNamespace: $sourceNamespace, ')
          ..write('sourceRecordKey: $sourceRecordKey, ')
          ..write('sourceSequence: $sourceSequence, ')
          ..write('transportGeneration: $transportGeneration, ')
          ..write('gameGeneration: $gameGeneration, ')
          ..write('platformId: $platformId, ')
          ..write('gameId: $gameId, ')
          ..write('semanticKey: $semanticKey, ')
          ..write('captureEpochId: $captureEpochId, ')
          ..write('receivedAtUs: $receivedAtUs, ')
          ..write('rawPayload: $rawPayload, ')
          ..write('rawFormat: $rawFormat, ')
          ..write('rawHash: $rawHash, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('retentionClass: $retentionClass, ')
          ..write('envelopeSchemaVersion: $envelopeSchemaVersion, ')
          ..write('redacted: $redacted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entryKind,
    sourceNamespace,
    sourceRecordKey,
    sourceSequence,
    transportGeneration,
    gameGeneration,
    platformId,
    gameId,
    semanticKey,
    captureEpochId,
    receivedAtUs,
    $driftBlobEquality.hash(rawPayload),
    rawFormat,
    rawHash,
    semanticHash,
    retentionClass,
    envelopeSchemaVersion,
    redacted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRecord &&
          other.id == this.id &&
          other.entryKind == this.entryKind &&
          other.sourceNamespace == this.sourceNamespace &&
          other.sourceRecordKey == this.sourceRecordKey &&
          other.sourceSequence == this.sourceSequence &&
          other.transportGeneration == this.transportGeneration &&
          other.gameGeneration == this.gameGeneration &&
          other.platformId == this.platformId &&
          other.gameId == this.gameId &&
          other.semanticKey == this.semanticKey &&
          other.captureEpochId == this.captureEpochId &&
          other.receivedAtUs == this.receivedAtUs &&
          $driftBlobEquality.equals(other.rawPayload, this.rawPayload) &&
          other.rawFormat == this.rawFormat &&
          other.rawHash == this.rawHash &&
          other.semanticHash == this.semanticHash &&
          other.retentionClass == this.retentionClass &&
          other.envelopeSchemaVersion == this.envelopeSchemaVersion &&
          other.redacted == this.redacted);
}

class SourceRecordsCompanion extends UpdateCompanion<SourceRecord> {
  final Value<String> id;
  final Value<String> entryKind;
  final Value<String> sourceNamespace;
  final Value<String?> sourceRecordKey;
  final Value<int?> sourceSequence;
  final Value<int> transportGeneration;
  final Value<int?> gameGeneration;
  final Value<String?> platformId;
  final Value<int?> gameId;
  final Value<String?> semanticKey;
  final Value<String?> captureEpochId;
  final Value<int> receivedAtUs;
  final Value<Uint8List> rawPayload;
  final Value<String> rawFormat;
  final Value<String> rawHash;
  final Value<String> semanticHash;
  final Value<String> retentionClass;
  final Value<int> envelopeSchemaVersion;
  final Value<bool> redacted;
  final Value<int> rowid;
  const SourceRecordsCompanion({
    this.id = const Value.absent(),
    this.entryKind = const Value.absent(),
    this.sourceNamespace = const Value.absent(),
    this.sourceRecordKey = const Value.absent(),
    this.sourceSequence = const Value.absent(),
    this.transportGeneration = const Value.absent(),
    this.gameGeneration = const Value.absent(),
    this.platformId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.semanticKey = const Value.absent(),
    this.captureEpochId = const Value.absent(),
    this.receivedAtUs = const Value.absent(),
    this.rawPayload = const Value.absent(),
    this.rawFormat = const Value.absent(),
    this.rawHash = const Value.absent(),
    this.semanticHash = const Value.absent(),
    this.retentionClass = const Value.absent(),
    this.envelopeSchemaVersion = const Value.absent(),
    this.redacted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceRecordsCompanion.insert({
    required String id,
    required String entryKind,
    required String sourceNamespace,
    this.sourceRecordKey = const Value.absent(),
    this.sourceSequence = const Value.absent(),
    required int transportGeneration,
    this.gameGeneration = const Value.absent(),
    this.platformId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.semanticKey = const Value.absent(),
    this.captureEpochId = const Value.absent(),
    required int receivedAtUs,
    required Uint8List rawPayload,
    required String rawFormat,
    required String rawHash,
    required String semanticHash,
    required String retentionClass,
    required int envelopeSchemaVersion,
    required bool redacted,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entryKind = Value(entryKind),
       sourceNamespace = Value(sourceNamespace),
       transportGeneration = Value(transportGeneration),
       receivedAtUs = Value(receivedAtUs),
       rawPayload = Value(rawPayload),
       rawFormat = Value(rawFormat),
       rawHash = Value(rawHash),
       semanticHash = Value(semanticHash),
       retentionClass = Value(retentionClass),
       envelopeSchemaVersion = Value(envelopeSchemaVersion),
       redacted = Value(redacted);
  static Insertable<SourceRecord> custom({
    Expression<String>? id,
    Expression<String>? entryKind,
    Expression<String>? sourceNamespace,
    Expression<String>? sourceRecordKey,
    Expression<int>? sourceSequence,
    Expression<int>? transportGeneration,
    Expression<int>? gameGeneration,
    Expression<String>? platformId,
    Expression<int>? gameId,
    Expression<String>? semanticKey,
    Expression<String>? captureEpochId,
    Expression<int>? receivedAtUs,
    Expression<Uint8List>? rawPayload,
    Expression<String>? rawFormat,
    Expression<String>? rawHash,
    Expression<String>? semanticHash,
    Expression<String>? retentionClass,
    Expression<int>? envelopeSchemaVersion,
    Expression<bool>? redacted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryKind != null) 'entry_kind': entryKind,
      if (sourceNamespace != null) 'source_namespace': sourceNamespace,
      if (sourceRecordKey != null) 'source_record_key': sourceRecordKey,
      if (sourceSequence != null) 'source_sequence': sourceSequence,
      if (transportGeneration != null)
        'transport_generation': transportGeneration,
      if (gameGeneration != null) 'game_generation': gameGeneration,
      if (platformId != null) 'platform_id': platformId,
      if (gameId != null) 'game_id': gameId,
      if (semanticKey != null) 'semantic_key': semanticKey,
      if (captureEpochId != null) 'capture_epoch_id': captureEpochId,
      if (receivedAtUs != null) 'received_at_us': receivedAtUs,
      if (rawPayload != null) 'raw_payload': rawPayload,
      if (rawFormat != null) 'raw_format': rawFormat,
      if (rawHash != null) 'raw_hash': rawHash,
      if (semanticHash != null) 'semantic_hash': semanticHash,
      if (retentionClass != null) 'retention_class': retentionClass,
      if (envelopeSchemaVersion != null)
        'envelope_schema_version': envelopeSchemaVersion,
      if (redacted != null) 'redacted': redacted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? entryKind,
    Value<String>? sourceNamespace,
    Value<String?>? sourceRecordKey,
    Value<int?>? sourceSequence,
    Value<int>? transportGeneration,
    Value<int?>? gameGeneration,
    Value<String?>? platformId,
    Value<int?>? gameId,
    Value<String?>? semanticKey,
    Value<String?>? captureEpochId,
    Value<int>? receivedAtUs,
    Value<Uint8List>? rawPayload,
    Value<String>? rawFormat,
    Value<String>? rawHash,
    Value<String>? semanticHash,
    Value<String>? retentionClass,
    Value<int>? envelopeSchemaVersion,
    Value<bool>? redacted,
    Value<int>? rowid,
  }) {
    return SourceRecordsCompanion(
      id: id ?? this.id,
      entryKind: entryKind ?? this.entryKind,
      sourceNamespace: sourceNamespace ?? this.sourceNamespace,
      sourceRecordKey: sourceRecordKey ?? this.sourceRecordKey,
      sourceSequence: sourceSequence ?? this.sourceSequence,
      transportGeneration: transportGeneration ?? this.transportGeneration,
      gameGeneration: gameGeneration ?? this.gameGeneration,
      platformId: platformId ?? this.platformId,
      gameId: gameId ?? this.gameId,
      semanticKey: semanticKey ?? this.semanticKey,
      captureEpochId: captureEpochId ?? this.captureEpochId,
      receivedAtUs: receivedAtUs ?? this.receivedAtUs,
      rawPayload: rawPayload ?? this.rawPayload,
      rawFormat: rawFormat ?? this.rawFormat,
      rawHash: rawHash ?? this.rawHash,
      semanticHash: semanticHash ?? this.semanticHash,
      retentionClass: retentionClass ?? this.retentionClass,
      envelopeSchemaVersion:
          envelopeSchemaVersion ?? this.envelopeSchemaVersion,
      redacted: redacted ?? this.redacted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entryKind.present) {
      map['entry_kind'] = Variable<String>(entryKind.value);
    }
    if (sourceNamespace.present) {
      map['source_namespace'] = Variable<String>(sourceNamespace.value);
    }
    if (sourceRecordKey.present) {
      map['source_record_key'] = Variable<String>(sourceRecordKey.value);
    }
    if (sourceSequence.present) {
      map['source_sequence'] = Variable<int>(sourceSequence.value);
    }
    if (transportGeneration.present) {
      map['transport_generation'] = Variable<int>(transportGeneration.value);
    }
    if (gameGeneration.present) {
      map['game_generation'] = Variable<int>(gameGeneration.value);
    }
    if (platformId.present) {
      map['platform_id'] = Variable<String>(platformId.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (semanticKey.present) {
      map['semantic_key'] = Variable<String>(semanticKey.value);
    }
    if (captureEpochId.present) {
      map['capture_epoch_id'] = Variable<String>(captureEpochId.value);
    }
    if (receivedAtUs.present) {
      map['received_at_us'] = Variable<int>(receivedAtUs.value);
    }
    if (rawPayload.present) {
      map['raw_payload'] = Variable<Uint8List>(rawPayload.value);
    }
    if (rawFormat.present) {
      map['raw_format'] = Variable<String>(rawFormat.value);
    }
    if (rawHash.present) {
      map['raw_hash'] = Variable<String>(rawHash.value);
    }
    if (semanticHash.present) {
      map['semantic_hash'] = Variable<String>(semanticHash.value);
    }
    if (retentionClass.present) {
      map['retention_class'] = Variable<String>(retentionClass.value);
    }
    if (envelopeSchemaVersion.present) {
      map['envelope_schema_version'] = Variable<int>(
        envelopeSchemaVersion.value,
      );
    }
    if (redacted.present) {
      map['redacted'] = Variable<bool>(redacted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('entryKind: $entryKind, ')
          ..write('sourceNamespace: $sourceNamespace, ')
          ..write('sourceRecordKey: $sourceRecordKey, ')
          ..write('sourceSequence: $sourceSequence, ')
          ..write('transportGeneration: $transportGeneration, ')
          ..write('gameGeneration: $gameGeneration, ')
          ..write('platformId: $platformId, ')
          ..write('gameId: $gameId, ')
          ..write('semanticKey: $semanticKey, ')
          ..write('captureEpochId: $captureEpochId, ')
          ..write('receivedAtUs: $receivedAtUs, ')
          ..write('rawPayload: $rawPayload, ')
          ..write('rawFormat: $rawFormat, ')
          ..write('rawHash: $rawHash, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('retentionClass: $retentionClass, ')
          ..write('envelopeSchemaVersion: $envelopeSchemaVersion, ')
          ..write('redacted: $redacted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DomainEntriesTable extends DomainEntries
    with TableInfo<$DomainEntriesTable, DomainEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DomainEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRecordIdMeta = const VerificationMeta(
    'sourceRecordId',
  );
  @override
  late final GeneratedColumn<String> sourceRecordId = GeneratedColumn<String>(
    'source_record_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES source_records (id)',
    ),
  );
  static const VerificationMeta _entryKindMeta = const VerificationMeta(
    'entryKind',
  );
  @override
  late final GeneratedColumn<String> entryKind = GeneratedColumn<String>(
    'entry_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _producerMeta = const VerificationMeta(
    'producer',
  );
  @override
  late final GeneratedColumn<String> producer = GeneratedColumn<String>(
    'producer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _producerVersionMeta = const VerificationMeta(
    'producerVersion',
  );
  @override
  late final GeneratedColumn<String> producerVersion = GeneratedColumn<String>(
    'producer_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _producedAtUsMeta = const VerificationMeta(
    'producedAtUs',
  );
  @override
  late final GeneratedColumn<int> producedAtUs = GeneratedColumn<int>(
    'produced_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decoderIdMeta = const VerificationMeta(
    'decoderId',
  );
  @override
  late final GeneratedColumn<String> decoderId = GeneratedColumn<String>(
    'decoder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _decoderVersionMeta = const VerificationMeta(
    'decoderVersion',
  );
  @override
  late final GeneratedColumn<String> decoderVersion = GeneratedColumn<String>(
    'decoder_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadSchemaVersionMeta =
      const VerificationMeta('payloadSchemaVersion');
  @override
  late final GeneratedColumn<int> payloadSchemaVersion = GeneratedColumn<int>(
    'payload_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typedPayloadJsonMeta = const VerificationMeta(
    'typedPayloadJson',
  );
  @override
  late final GeneratedColumn<String> typedPayloadJson = GeneratedColumn<String>(
    'typed_payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameTimeMsMeta = const VerificationMeta(
    'gameTimeMs',
  );
  @override
  late final GeneratedColumn<int> gameTimeMs = GeneratedColumn<int>(
    'game_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _derivationKeyMeta = const VerificationMeta(
    'derivationKey',
  );
  @override
  late final GeneratedColumn<String> derivationKey = GeneratedColumn<String>(
    'derivation_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceRecordId,
    entryKind,
    producer,
    producerVersion,
    producedAtUs,
    decoderId,
    decoderVersion,
    payloadSchemaVersion,
    typedPayloadJson,
    gameTimeMs,
    derivationKey,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'domain_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DomainEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_record_id')) {
      context.handle(
        _sourceRecordIdMeta,
        sourceRecordId.isAcceptableOrUnknown(
          data['source_record_id']!,
          _sourceRecordIdMeta,
        ),
      );
    }
    if (data.containsKey('entry_kind')) {
      context.handle(
        _entryKindMeta,
        entryKind.isAcceptableOrUnknown(data['entry_kind']!, _entryKindMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKindMeta);
    }
    if (data.containsKey('producer')) {
      context.handle(
        _producerMeta,
        producer.isAcceptableOrUnknown(data['producer']!, _producerMeta),
      );
    } else if (isInserting) {
      context.missing(_producerMeta);
    }
    if (data.containsKey('producer_version')) {
      context.handle(
        _producerVersionMeta,
        producerVersion.isAcceptableOrUnknown(
          data['producer_version']!,
          _producerVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_producerVersionMeta);
    }
    if (data.containsKey('produced_at_us')) {
      context.handle(
        _producedAtUsMeta,
        producedAtUs.isAcceptableOrUnknown(
          data['produced_at_us']!,
          _producedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_producedAtUsMeta);
    }
    if (data.containsKey('decoder_id')) {
      context.handle(
        _decoderIdMeta,
        decoderId.isAcceptableOrUnknown(data['decoder_id']!, _decoderIdMeta),
      );
    }
    if (data.containsKey('decoder_version')) {
      context.handle(
        _decoderVersionMeta,
        decoderVersion.isAcceptableOrUnknown(
          data['decoder_version']!,
          _decoderVersionMeta,
        ),
      );
    }
    if (data.containsKey('payload_schema_version')) {
      context.handle(
        _payloadSchemaVersionMeta,
        payloadSchemaVersion.isAcceptableOrUnknown(
          data['payload_schema_version']!,
          _payloadSchemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadSchemaVersionMeta);
    }
    if (data.containsKey('typed_payload_json')) {
      context.handle(
        _typedPayloadJsonMeta,
        typedPayloadJson.isAcceptableOrUnknown(
          data['typed_payload_json']!,
          _typedPayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_typedPayloadJsonMeta);
    }
    if (data.containsKey('game_time_ms')) {
      context.handle(
        _gameTimeMsMeta,
        gameTimeMs.isAcceptableOrUnknown(
          data['game_time_ms']!,
          _gameTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('derivation_key')) {
      context.handle(
        _derivationKeyMeta,
        derivationKey.isAcceptableOrUnknown(
          data['derivation_key']!,
          _derivationKeyMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DomainEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DomainEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_record_id'],
      ),
      entryKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_kind'],
      )!,
      producer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}producer'],
      )!,
      producerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}producer_version'],
      )!,
      producedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}produced_at_us'],
      )!,
      decoderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decoder_id'],
      ),
      decoderVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decoder_version'],
      ),
      payloadSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_schema_version'],
      )!,
      typedPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}typed_payload_json'],
      )!,
      gameTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_time_ms'],
      ),
      derivationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}derivation_key'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
    );
  }

  @override
  $DomainEntriesTable createAlias(String alias) {
    return $DomainEntriesTable(attachedDatabase, alias);
  }
}

class DomainEntry extends DataClass implements Insertable<DomainEntry> {
  final String id;
  final String? sourceRecordId;
  final String entryKind;
  final String producer;
  final String producerVersion;
  final int producedAtUs;
  final String? decoderId;
  final String? decoderVersion;
  final int payloadSchemaVersion;
  final String typedPayloadJson;
  final int? gameTimeMs;
  final String? derivationKey;
  final double? confidence;
  const DomainEntry({
    required this.id,
    this.sourceRecordId,
    required this.entryKind,
    required this.producer,
    required this.producerVersion,
    required this.producedAtUs,
    this.decoderId,
    this.decoderVersion,
    required this.payloadSchemaVersion,
    required this.typedPayloadJson,
    this.gameTimeMs,
    this.derivationKey,
    this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || sourceRecordId != null) {
      map['source_record_id'] = Variable<String>(sourceRecordId);
    }
    map['entry_kind'] = Variable<String>(entryKind);
    map['producer'] = Variable<String>(producer);
    map['producer_version'] = Variable<String>(producerVersion);
    map['produced_at_us'] = Variable<int>(producedAtUs);
    if (!nullToAbsent || decoderId != null) {
      map['decoder_id'] = Variable<String>(decoderId);
    }
    if (!nullToAbsent || decoderVersion != null) {
      map['decoder_version'] = Variable<String>(decoderVersion);
    }
    map['payload_schema_version'] = Variable<int>(payloadSchemaVersion);
    map['typed_payload_json'] = Variable<String>(typedPayloadJson);
    if (!nullToAbsent || gameTimeMs != null) {
      map['game_time_ms'] = Variable<int>(gameTimeMs);
    }
    if (!nullToAbsent || derivationKey != null) {
      map['derivation_key'] = Variable<String>(derivationKey);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    return map;
  }

  DomainEntriesCompanion toCompanion(bool nullToAbsent) {
    return DomainEntriesCompanion(
      id: Value(id),
      sourceRecordId: sourceRecordId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRecordId),
      entryKind: Value(entryKind),
      producer: Value(producer),
      producerVersion: Value(producerVersion),
      producedAtUs: Value(producedAtUs),
      decoderId: decoderId == null && nullToAbsent
          ? const Value.absent()
          : Value(decoderId),
      decoderVersion: decoderVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(decoderVersion),
      payloadSchemaVersion: Value(payloadSchemaVersion),
      typedPayloadJson: Value(typedPayloadJson),
      gameTimeMs: gameTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(gameTimeMs),
      derivationKey: derivationKey == null && nullToAbsent
          ? const Value.absent()
          : Value(derivationKey),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
    );
  }

  factory DomainEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DomainEntry(
      id: serializer.fromJson<String>(json['id']),
      sourceRecordId: serializer.fromJson<String?>(json['sourceRecordId']),
      entryKind: serializer.fromJson<String>(json['entryKind']),
      producer: serializer.fromJson<String>(json['producer']),
      producerVersion: serializer.fromJson<String>(json['producerVersion']),
      producedAtUs: serializer.fromJson<int>(json['producedAtUs']),
      decoderId: serializer.fromJson<String?>(json['decoderId']),
      decoderVersion: serializer.fromJson<String?>(json['decoderVersion']),
      payloadSchemaVersion: serializer.fromJson<int>(
        json['payloadSchemaVersion'],
      ),
      typedPayloadJson: serializer.fromJson<String>(json['typedPayloadJson']),
      gameTimeMs: serializer.fromJson<int?>(json['gameTimeMs']),
      derivationKey: serializer.fromJson<String?>(json['derivationKey']),
      confidence: serializer.fromJson<double?>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceRecordId': serializer.toJson<String?>(sourceRecordId),
      'entryKind': serializer.toJson<String>(entryKind),
      'producer': serializer.toJson<String>(producer),
      'producerVersion': serializer.toJson<String>(producerVersion),
      'producedAtUs': serializer.toJson<int>(producedAtUs),
      'decoderId': serializer.toJson<String?>(decoderId),
      'decoderVersion': serializer.toJson<String?>(decoderVersion),
      'payloadSchemaVersion': serializer.toJson<int>(payloadSchemaVersion),
      'typedPayloadJson': serializer.toJson<String>(typedPayloadJson),
      'gameTimeMs': serializer.toJson<int?>(gameTimeMs),
      'derivationKey': serializer.toJson<String?>(derivationKey),
      'confidence': serializer.toJson<double?>(confidence),
    };
  }

  DomainEntry copyWith({
    String? id,
    Value<String?> sourceRecordId = const Value.absent(),
    String? entryKind,
    String? producer,
    String? producerVersion,
    int? producedAtUs,
    Value<String?> decoderId = const Value.absent(),
    Value<String?> decoderVersion = const Value.absent(),
    int? payloadSchemaVersion,
    String? typedPayloadJson,
    Value<int?> gameTimeMs = const Value.absent(),
    Value<String?> derivationKey = const Value.absent(),
    Value<double?> confidence = const Value.absent(),
  }) => DomainEntry(
    id: id ?? this.id,
    sourceRecordId: sourceRecordId.present
        ? sourceRecordId.value
        : this.sourceRecordId,
    entryKind: entryKind ?? this.entryKind,
    producer: producer ?? this.producer,
    producerVersion: producerVersion ?? this.producerVersion,
    producedAtUs: producedAtUs ?? this.producedAtUs,
    decoderId: decoderId.present ? decoderId.value : this.decoderId,
    decoderVersion: decoderVersion.present
        ? decoderVersion.value
        : this.decoderVersion,
    payloadSchemaVersion: payloadSchemaVersion ?? this.payloadSchemaVersion,
    typedPayloadJson: typedPayloadJson ?? this.typedPayloadJson,
    gameTimeMs: gameTimeMs.present ? gameTimeMs.value : this.gameTimeMs,
    derivationKey: derivationKey.present
        ? derivationKey.value
        : this.derivationKey,
    confidence: confidence.present ? confidence.value : this.confidence,
  );
  DomainEntry copyWithCompanion(DomainEntriesCompanion data) {
    return DomainEntry(
      id: data.id.present ? data.id.value : this.id,
      sourceRecordId: data.sourceRecordId.present
          ? data.sourceRecordId.value
          : this.sourceRecordId,
      entryKind: data.entryKind.present ? data.entryKind.value : this.entryKind,
      producer: data.producer.present ? data.producer.value : this.producer,
      producerVersion: data.producerVersion.present
          ? data.producerVersion.value
          : this.producerVersion,
      producedAtUs: data.producedAtUs.present
          ? data.producedAtUs.value
          : this.producedAtUs,
      decoderId: data.decoderId.present ? data.decoderId.value : this.decoderId,
      decoderVersion: data.decoderVersion.present
          ? data.decoderVersion.value
          : this.decoderVersion,
      payloadSchemaVersion: data.payloadSchemaVersion.present
          ? data.payloadSchemaVersion.value
          : this.payloadSchemaVersion,
      typedPayloadJson: data.typedPayloadJson.present
          ? data.typedPayloadJson.value
          : this.typedPayloadJson,
      gameTimeMs: data.gameTimeMs.present
          ? data.gameTimeMs.value
          : this.gameTimeMs,
      derivationKey: data.derivationKey.present
          ? data.derivationKey.value
          : this.derivationKey,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DomainEntry(')
          ..write('id: $id, ')
          ..write('sourceRecordId: $sourceRecordId, ')
          ..write('entryKind: $entryKind, ')
          ..write('producer: $producer, ')
          ..write('producerVersion: $producerVersion, ')
          ..write('producedAtUs: $producedAtUs, ')
          ..write('decoderId: $decoderId, ')
          ..write('decoderVersion: $decoderVersion, ')
          ..write('payloadSchemaVersion: $payloadSchemaVersion, ')
          ..write('typedPayloadJson: $typedPayloadJson, ')
          ..write('gameTimeMs: $gameTimeMs, ')
          ..write('derivationKey: $derivationKey, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceRecordId,
    entryKind,
    producer,
    producerVersion,
    producedAtUs,
    decoderId,
    decoderVersion,
    payloadSchemaVersion,
    typedPayloadJson,
    gameTimeMs,
    derivationKey,
    confidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DomainEntry &&
          other.id == this.id &&
          other.sourceRecordId == this.sourceRecordId &&
          other.entryKind == this.entryKind &&
          other.producer == this.producer &&
          other.producerVersion == this.producerVersion &&
          other.producedAtUs == this.producedAtUs &&
          other.decoderId == this.decoderId &&
          other.decoderVersion == this.decoderVersion &&
          other.payloadSchemaVersion == this.payloadSchemaVersion &&
          other.typedPayloadJson == this.typedPayloadJson &&
          other.gameTimeMs == this.gameTimeMs &&
          other.derivationKey == this.derivationKey &&
          other.confidence == this.confidence);
}

class DomainEntriesCompanion extends UpdateCompanion<DomainEntry> {
  final Value<String> id;
  final Value<String?> sourceRecordId;
  final Value<String> entryKind;
  final Value<String> producer;
  final Value<String> producerVersion;
  final Value<int> producedAtUs;
  final Value<String?> decoderId;
  final Value<String?> decoderVersion;
  final Value<int> payloadSchemaVersion;
  final Value<String> typedPayloadJson;
  final Value<int?> gameTimeMs;
  final Value<String?> derivationKey;
  final Value<double?> confidence;
  final Value<int> rowid;
  const DomainEntriesCompanion({
    this.id = const Value.absent(),
    this.sourceRecordId = const Value.absent(),
    this.entryKind = const Value.absent(),
    this.producer = const Value.absent(),
    this.producerVersion = const Value.absent(),
    this.producedAtUs = const Value.absent(),
    this.decoderId = const Value.absent(),
    this.decoderVersion = const Value.absent(),
    this.payloadSchemaVersion = const Value.absent(),
    this.typedPayloadJson = const Value.absent(),
    this.gameTimeMs = const Value.absent(),
    this.derivationKey = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DomainEntriesCompanion.insert({
    required String id,
    this.sourceRecordId = const Value.absent(),
    required String entryKind,
    required String producer,
    required String producerVersion,
    required int producedAtUs,
    this.decoderId = const Value.absent(),
    this.decoderVersion = const Value.absent(),
    required int payloadSchemaVersion,
    required String typedPayloadJson,
    this.gameTimeMs = const Value.absent(),
    this.derivationKey = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entryKind = Value(entryKind),
       producer = Value(producer),
       producerVersion = Value(producerVersion),
       producedAtUs = Value(producedAtUs),
       payloadSchemaVersion = Value(payloadSchemaVersion),
       typedPayloadJson = Value(typedPayloadJson);
  static Insertable<DomainEntry> custom({
    Expression<String>? id,
    Expression<String>? sourceRecordId,
    Expression<String>? entryKind,
    Expression<String>? producer,
    Expression<String>? producerVersion,
    Expression<int>? producedAtUs,
    Expression<String>? decoderId,
    Expression<String>? decoderVersion,
    Expression<int>? payloadSchemaVersion,
    Expression<String>? typedPayloadJson,
    Expression<int>? gameTimeMs,
    Expression<String>? derivationKey,
    Expression<double>? confidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceRecordId != null) 'source_record_id': sourceRecordId,
      if (entryKind != null) 'entry_kind': entryKind,
      if (producer != null) 'producer': producer,
      if (producerVersion != null) 'producer_version': producerVersion,
      if (producedAtUs != null) 'produced_at_us': producedAtUs,
      if (decoderId != null) 'decoder_id': decoderId,
      if (decoderVersion != null) 'decoder_version': decoderVersion,
      if (payloadSchemaVersion != null)
        'payload_schema_version': payloadSchemaVersion,
      if (typedPayloadJson != null) 'typed_payload_json': typedPayloadJson,
      if (gameTimeMs != null) 'game_time_ms': gameTimeMs,
      if (derivationKey != null) 'derivation_key': derivationKey,
      if (confidence != null) 'confidence': confidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DomainEntriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? sourceRecordId,
    Value<String>? entryKind,
    Value<String>? producer,
    Value<String>? producerVersion,
    Value<int>? producedAtUs,
    Value<String?>? decoderId,
    Value<String?>? decoderVersion,
    Value<int>? payloadSchemaVersion,
    Value<String>? typedPayloadJson,
    Value<int?>? gameTimeMs,
    Value<String?>? derivationKey,
    Value<double?>? confidence,
    Value<int>? rowid,
  }) {
    return DomainEntriesCompanion(
      id: id ?? this.id,
      sourceRecordId: sourceRecordId ?? this.sourceRecordId,
      entryKind: entryKind ?? this.entryKind,
      producer: producer ?? this.producer,
      producerVersion: producerVersion ?? this.producerVersion,
      producedAtUs: producedAtUs ?? this.producedAtUs,
      decoderId: decoderId ?? this.decoderId,
      decoderVersion: decoderVersion ?? this.decoderVersion,
      payloadSchemaVersion: payloadSchemaVersion ?? this.payloadSchemaVersion,
      typedPayloadJson: typedPayloadJson ?? this.typedPayloadJson,
      gameTimeMs: gameTimeMs ?? this.gameTimeMs,
      derivationKey: derivationKey ?? this.derivationKey,
      confidence: confidence ?? this.confidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceRecordId.present) {
      map['source_record_id'] = Variable<String>(sourceRecordId.value);
    }
    if (entryKind.present) {
      map['entry_kind'] = Variable<String>(entryKind.value);
    }
    if (producer.present) {
      map['producer'] = Variable<String>(producer.value);
    }
    if (producerVersion.present) {
      map['producer_version'] = Variable<String>(producerVersion.value);
    }
    if (producedAtUs.present) {
      map['produced_at_us'] = Variable<int>(producedAtUs.value);
    }
    if (decoderId.present) {
      map['decoder_id'] = Variable<String>(decoderId.value);
    }
    if (decoderVersion.present) {
      map['decoder_version'] = Variable<String>(decoderVersion.value);
    }
    if (payloadSchemaVersion.present) {
      map['payload_schema_version'] = Variable<int>(payloadSchemaVersion.value);
    }
    if (typedPayloadJson.present) {
      map['typed_payload_json'] = Variable<String>(typedPayloadJson.value);
    }
    if (gameTimeMs.present) {
      map['game_time_ms'] = Variable<int>(gameTimeMs.value);
    }
    if (derivationKey.present) {
      map['derivation_key'] = Variable<String>(derivationKey.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DomainEntriesCompanion(')
          ..write('id: $id, ')
          ..write('sourceRecordId: $sourceRecordId, ')
          ..write('entryKind: $entryKind, ')
          ..write('producer: $producer, ')
          ..write('producerVersion: $producerVersion, ')
          ..write('producedAtUs: $producedAtUs, ')
          ..write('decoderId: $decoderId, ')
          ..write('decoderVersion: $decoderVersion, ')
          ..write('payloadSchemaVersion: $payloadSchemaVersion, ')
          ..write('typedPayloadJson: $typedPayloadJson, ')
          ..write('gameTimeMs: $gameTimeMs, ')
          ..write('derivationKey: $derivationKey, ')
          ..write('confidence: $confidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LineageEdgesTable extends LineageEdges
    with TableInfo<$LineageEdgesTable, LineageEdge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LineageEdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _childEntryIdMeta = const VerificationMeta(
    'childEntryId',
  );
  @override
  late final GeneratedColumn<String> childEntryId = GeneratedColumn<String>(
    'child_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES domain_entries (id)',
    ),
  );
  static const VerificationMeta _parentKindMeta = const VerificationMeta(
    'parentKind',
  );
  @override
  late final GeneratedColumn<String> parentKind = GeneratedColumn<String>(
    'parent_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationMeta = const VerificationMeta(
    'relation',
  );
  @override
  late final GeneratedColumn<String> relation = GeneratedColumn<String>(
    'relation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    childEntryId,
    parentKind,
    parentId,
    relation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lineage_edges';
  @override
  VerificationContext validateIntegrity(
    Insertable<LineageEdge> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('child_entry_id')) {
      context.handle(
        _childEntryIdMeta,
        childEntryId.isAcceptableOrUnknown(
          data['child_entry_id']!,
          _childEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_childEntryIdMeta);
    }
    if (data.containsKey('parent_kind')) {
      context.handle(
        _parentKindMeta,
        parentKind.isAcceptableOrUnknown(data['parent_kind']!, _parentKindMeta),
      );
    } else if (isInserting) {
      context.missing(_parentKindMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('relation')) {
      context.handle(
        _relationMeta,
        relation.isAcceptableOrUnknown(data['relation']!, _relationMeta),
      );
    } else if (isInserting) {
      context.missing(_relationMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    childEntryId,
    parentKind,
    parentId,
    relation,
  };
  @override
  LineageEdge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LineageEdge(
      childEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_entry_id'],
      )!,
      parentKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_kind'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      )!,
      relation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation'],
      )!,
    );
  }

  @override
  $LineageEdgesTable createAlias(String alias) {
    return $LineageEdgesTable(attachedDatabase, alias);
  }
}

class LineageEdge extends DataClass implements Insertable<LineageEdge> {
  final String childEntryId;
  final String parentKind;
  final String parentId;
  final String relation;
  const LineageEdge({
    required this.childEntryId,
    required this.parentKind,
    required this.parentId,
    required this.relation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['child_entry_id'] = Variable<String>(childEntryId);
    map['parent_kind'] = Variable<String>(parentKind);
    map['parent_id'] = Variable<String>(parentId);
    map['relation'] = Variable<String>(relation);
    return map;
  }

  LineageEdgesCompanion toCompanion(bool nullToAbsent) {
    return LineageEdgesCompanion(
      childEntryId: Value(childEntryId),
      parentKind: Value(parentKind),
      parentId: Value(parentId),
      relation: Value(relation),
    );
  }

  factory LineageEdge.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LineageEdge(
      childEntryId: serializer.fromJson<String>(json['childEntryId']),
      parentKind: serializer.fromJson<String>(json['parentKind']),
      parentId: serializer.fromJson<String>(json['parentId']),
      relation: serializer.fromJson<String>(json['relation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'childEntryId': serializer.toJson<String>(childEntryId),
      'parentKind': serializer.toJson<String>(parentKind),
      'parentId': serializer.toJson<String>(parentId),
      'relation': serializer.toJson<String>(relation),
    };
  }

  LineageEdge copyWith({
    String? childEntryId,
    String? parentKind,
    String? parentId,
    String? relation,
  }) => LineageEdge(
    childEntryId: childEntryId ?? this.childEntryId,
    parentKind: parentKind ?? this.parentKind,
    parentId: parentId ?? this.parentId,
    relation: relation ?? this.relation,
  );
  LineageEdge copyWithCompanion(LineageEdgesCompanion data) {
    return LineageEdge(
      childEntryId: data.childEntryId.present
          ? data.childEntryId.value
          : this.childEntryId,
      parentKind: data.parentKind.present
          ? data.parentKind.value
          : this.parentKind,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      relation: data.relation.present ? data.relation.value : this.relation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LineageEdge(')
          ..write('childEntryId: $childEntryId, ')
          ..write('parentKind: $parentKind, ')
          ..write('parentId: $parentId, ')
          ..write('relation: $relation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(childEntryId, parentKind, parentId, relation);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LineageEdge &&
          other.childEntryId == this.childEntryId &&
          other.parentKind == this.parentKind &&
          other.parentId == this.parentId &&
          other.relation == this.relation);
}

class LineageEdgesCompanion extends UpdateCompanion<LineageEdge> {
  final Value<String> childEntryId;
  final Value<String> parentKind;
  final Value<String> parentId;
  final Value<String> relation;
  final Value<int> rowid;
  const LineageEdgesCompanion({
    this.childEntryId = const Value.absent(),
    this.parentKind = const Value.absent(),
    this.parentId = const Value.absent(),
    this.relation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LineageEdgesCompanion.insert({
    required String childEntryId,
    required String parentKind,
    required String parentId,
    required String relation,
    this.rowid = const Value.absent(),
  }) : childEntryId = Value(childEntryId),
       parentKind = Value(parentKind),
       parentId = Value(parentId),
       relation = Value(relation);
  static Insertable<LineageEdge> custom({
    Expression<String>? childEntryId,
    Expression<String>? parentKind,
    Expression<String>? parentId,
    Expression<String>? relation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (childEntryId != null) 'child_entry_id': childEntryId,
      if (parentKind != null) 'parent_kind': parentKind,
      if (parentId != null) 'parent_id': parentId,
      if (relation != null) 'relation': relation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LineageEdgesCompanion copyWith({
    Value<String>? childEntryId,
    Value<String>? parentKind,
    Value<String>? parentId,
    Value<String>? relation,
    Value<int>? rowid,
  }) {
    return LineageEdgesCompanion(
      childEntryId: childEntryId ?? this.childEntryId,
      parentKind: parentKind ?? this.parentKind,
      parentId: parentId ?? this.parentId,
      relation: relation ?? this.relation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (childEntryId.present) {
      map['child_entry_id'] = Variable<String>(childEntryId.value);
    }
    if (parentKind.present) {
      map['parent_kind'] = Variable<String>(parentKind.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (relation.present) {
      map['relation'] = Variable<String>(relation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LineageEdgesCompanion(')
          ..write('childEntryId: $childEntryId, ')
          ..write('parentKind: $parentKind, ')
          ..write('parentId: $parentId, ')
          ..write('relation: $relation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnapshotCursorsTable extends SnapshotCursors
    with TableInfo<$SnapshotCursorsTable, SnapshotCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceNamespaceMeta = const VerificationMeta(
    'sourceNamespace',
  );
  @override
  late final GeneratedColumn<String> sourceNamespace = GeneratedColumn<String>(
    'source_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semanticKeyMeta = const VerificationMeta(
    'semanticKey',
  );
  @override
  late final GeneratedColumn<String> semanticKey = GeneratedColumn<String>(
    'semantic_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captureEpochIdMeta = const VerificationMeta(
    'captureEpochId',
  );
  @override
  late final GeneratedColumn<String> captureEpochId = GeneratedColumn<String>(
    'capture_epoch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES capture_epochs (id)',
    ),
  );
  static const VerificationMeta _lastSemanticHashMeta = const VerificationMeta(
    'lastSemanticHash',
  );
  @override
  late final GeneratedColumn<String> lastSemanticHash = GeneratedColumn<String>(
    'last_semantic_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSourceRecordIdMeta =
      const VerificationMeta('lastSourceRecordId');
  @override
  late final GeneratedColumn<String> lastSourceRecordId =
      GeneratedColumn<String>(
        'last_source_record_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES source_records (id)',
        ),
      );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUs = GeneratedColumn<int>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceNamespace,
    semanticKey,
    captureEpochId,
    lastSemanticHash,
    lastSourceRecordId,
    updatedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_namespace')) {
      context.handle(
        _sourceNamespaceMeta,
        sourceNamespace.isAcceptableOrUnknown(
          data['source_namespace']!,
          _sourceNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceNamespaceMeta);
    }
    if (data.containsKey('semantic_key')) {
      context.handle(
        _semanticKeyMeta,
        semanticKey.isAcceptableOrUnknown(
          data['semantic_key']!,
          _semanticKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticKeyMeta);
    }
    if (data.containsKey('capture_epoch_id')) {
      context.handle(
        _captureEpochIdMeta,
        captureEpochId.isAcceptableOrUnknown(
          data['capture_epoch_id']!,
          _captureEpochIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_captureEpochIdMeta);
    }
    if (data.containsKey('last_semantic_hash')) {
      context.handle(
        _lastSemanticHashMeta,
        lastSemanticHash.isAcceptableOrUnknown(
          data['last_semantic_hash']!,
          _lastSemanticHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSemanticHashMeta);
    }
    if (data.containsKey('last_source_record_id')) {
      context.handle(
        _lastSourceRecordIdMeta,
        lastSourceRecordId.isAcceptableOrUnknown(
          data['last_source_record_id']!,
          _lastSourceRecordIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSourceRecordIdMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    sourceNamespace,
    semanticKey,
    captureEpochId,
  };
  @override
  SnapshotCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotCursor(
      sourceNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_namespace'],
      )!,
      semanticKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_key'],
      )!,
      captureEpochId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_epoch_id'],
      )!,
      lastSemanticHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_semantic_hash'],
      )!,
      lastSourceRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_source_record_id'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_us'],
      )!,
    );
  }

  @override
  $SnapshotCursorsTable createAlias(String alias) {
    return $SnapshotCursorsTable(attachedDatabase, alias);
  }
}

class SnapshotCursor extends DataClass implements Insertable<SnapshotCursor> {
  final String sourceNamespace;
  final String semanticKey;
  final String captureEpochId;
  final String lastSemanticHash;
  final String lastSourceRecordId;
  final int updatedAtUs;
  const SnapshotCursor({
    required this.sourceNamespace,
    required this.semanticKey,
    required this.captureEpochId,
    required this.lastSemanticHash,
    required this.lastSourceRecordId,
    required this.updatedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_namespace'] = Variable<String>(sourceNamespace);
    map['semantic_key'] = Variable<String>(semanticKey);
    map['capture_epoch_id'] = Variable<String>(captureEpochId);
    map['last_semantic_hash'] = Variable<String>(lastSemanticHash);
    map['last_source_record_id'] = Variable<String>(lastSourceRecordId);
    map['updated_at_us'] = Variable<int>(updatedAtUs);
    return map;
  }

  SnapshotCursorsCompanion toCompanion(bool nullToAbsent) {
    return SnapshotCursorsCompanion(
      sourceNamespace: Value(sourceNamespace),
      semanticKey: Value(semanticKey),
      captureEpochId: Value(captureEpochId),
      lastSemanticHash: Value(lastSemanticHash),
      lastSourceRecordId: Value(lastSourceRecordId),
      updatedAtUs: Value(updatedAtUs),
    );
  }

  factory SnapshotCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotCursor(
      sourceNamespace: serializer.fromJson<String>(json['sourceNamespace']),
      semanticKey: serializer.fromJson<String>(json['semanticKey']),
      captureEpochId: serializer.fromJson<String>(json['captureEpochId']),
      lastSemanticHash: serializer.fromJson<String>(json['lastSemanticHash']),
      lastSourceRecordId: serializer.fromJson<String>(
        json['lastSourceRecordId'],
      ),
      updatedAtUs: serializer.fromJson<int>(json['updatedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceNamespace': serializer.toJson<String>(sourceNamespace),
      'semanticKey': serializer.toJson<String>(semanticKey),
      'captureEpochId': serializer.toJson<String>(captureEpochId),
      'lastSemanticHash': serializer.toJson<String>(lastSemanticHash),
      'lastSourceRecordId': serializer.toJson<String>(lastSourceRecordId),
      'updatedAtUs': serializer.toJson<int>(updatedAtUs),
    };
  }

  SnapshotCursor copyWith({
    String? sourceNamespace,
    String? semanticKey,
    String? captureEpochId,
    String? lastSemanticHash,
    String? lastSourceRecordId,
    int? updatedAtUs,
  }) => SnapshotCursor(
    sourceNamespace: sourceNamespace ?? this.sourceNamespace,
    semanticKey: semanticKey ?? this.semanticKey,
    captureEpochId: captureEpochId ?? this.captureEpochId,
    lastSemanticHash: lastSemanticHash ?? this.lastSemanticHash,
    lastSourceRecordId: lastSourceRecordId ?? this.lastSourceRecordId,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
  );
  SnapshotCursor copyWithCompanion(SnapshotCursorsCompanion data) {
    return SnapshotCursor(
      sourceNamespace: data.sourceNamespace.present
          ? data.sourceNamespace.value
          : this.sourceNamespace,
      semanticKey: data.semanticKey.present
          ? data.semanticKey.value
          : this.semanticKey,
      captureEpochId: data.captureEpochId.present
          ? data.captureEpochId.value
          : this.captureEpochId,
      lastSemanticHash: data.lastSemanticHash.present
          ? data.lastSemanticHash.value
          : this.lastSemanticHash,
      lastSourceRecordId: data.lastSourceRecordId.present
          ? data.lastSourceRecordId.value
          : this.lastSourceRecordId,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotCursor(')
          ..write('sourceNamespace: $sourceNamespace, ')
          ..write('semanticKey: $semanticKey, ')
          ..write('captureEpochId: $captureEpochId, ')
          ..write('lastSemanticHash: $lastSemanticHash, ')
          ..write('lastSourceRecordId: $lastSourceRecordId, ')
          ..write('updatedAtUs: $updatedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceNamespace,
    semanticKey,
    captureEpochId,
    lastSemanticHash,
    lastSourceRecordId,
    updatedAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotCursor &&
          other.sourceNamespace == this.sourceNamespace &&
          other.semanticKey == this.semanticKey &&
          other.captureEpochId == this.captureEpochId &&
          other.lastSemanticHash == this.lastSemanticHash &&
          other.lastSourceRecordId == this.lastSourceRecordId &&
          other.updatedAtUs == this.updatedAtUs);
}

class SnapshotCursorsCompanion extends UpdateCompanion<SnapshotCursor> {
  final Value<String> sourceNamespace;
  final Value<String> semanticKey;
  final Value<String> captureEpochId;
  final Value<String> lastSemanticHash;
  final Value<String> lastSourceRecordId;
  final Value<int> updatedAtUs;
  final Value<int> rowid;
  const SnapshotCursorsCompanion({
    this.sourceNamespace = const Value.absent(),
    this.semanticKey = const Value.absent(),
    this.captureEpochId = const Value.absent(),
    this.lastSemanticHash = const Value.absent(),
    this.lastSourceRecordId = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnapshotCursorsCompanion.insert({
    required String sourceNamespace,
    required String semanticKey,
    required String captureEpochId,
    required String lastSemanticHash,
    required String lastSourceRecordId,
    required int updatedAtUs,
    this.rowid = const Value.absent(),
  }) : sourceNamespace = Value(sourceNamespace),
       semanticKey = Value(semanticKey),
       captureEpochId = Value(captureEpochId),
       lastSemanticHash = Value(lastSemanticHash),
       lastSourceRecordId = Value(lastSourceRecordId),
       updatedAtUs = Value(updatedAtUs);
  static Insertable<SnapshotCursor> custom({
    Expression<String>? sourceNamespace,
    Expression<String>? semanticKey,
    Expression<String>? captureEpochId,
    Expression<String>? lastSemanticHash,
    Expression<String>? lastSourceRecordId,
    Expression<int>? updatedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceNamespace != null) 'source_namespace': sourceNamespace,
      if (semanticKey != null) 'semantic_key': semanticKey,
      if (captureEpochId != null) 'capture_epoch_id': captureEpochId,
      if (lastSemanticHash != null) 'last_semantic_hash': lastSemanticHash,
      if (lastSourceRecordId != null)
        'last_source_record_id': lastSourceRecordId,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnapshotCursorsCompanion copyWith({
    Value<String>? sourceNamespace,
    Value<String>? semanticKey,
    Value<String>? captureEpochId,
    Value<String>? lastSemanticHash,
    Value<String>? lastSourceRecordId,
    Value<int>? updatedAtUs,
    Value<int>? rowid,
  }) {
    return SnapshotCursorsCompanion(
      sourceNamespace: sourceNamespace ?? this.sourceNamespace,
      semanticKey: semanticKey ?? this.semanticKey,
      captureEpochId: captureEpochId ?? this.captureEpochId,
      lastSemanticHash: lastSemanticHash ?? this.lastSemanticHash,
      lastSourceRecordId: lastSourceRecordId ?? this.lastSourceRecordId,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceNamespace.present) {
      map['source_namespace'] = Variable<String>(sourceNamespace.value);
    }
    if (semanticKey.present) {
      map['semantic_key'] = Variable<String>(semanticKey.value);
    }
    if (captureEpochId.present) {
      map['capture_epoch_id'] = Variable<String>(captureEpochId.value);
    }
    if (lastSemanticHash.present) {
      map['last_semantic_hash'] = Variable<String>(lastSemanticHash.value);
    }
    if (lastSourceRecordId.present) {
      map['last_source_record_id'] = Variable<String>(lastSourceRecordId.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<int>(updatedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotCursorsCompanion(')
          ..write('sourceNamespace: $sourceNamespace, ')
          ..write('semanticKey: $semanticKey, ')
          ..write('captureEpochId: $captureEpochId, ')
          ..write('lastSemanticHash: $lastSemanticHash, ')
          ..write('lastSourceRecordId: $lastSourceRecordId, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$GodSenseDatabase extends GeneratedDatabase {
  _$GodSenseDatabase(QueryExecutor e) : super(e);
  $GodSenseDatabaseManager get managers => $GodSenseDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $AccountContextStatesTable accountContextStates =
      $AccountContextStatesTable(this);
  late final $MatchesTable matches = $MatchesTable(this);
  late final $AccountMatchesTable accountMatches = $AccountMatchesTable(this);
  late final $MatchDocumentsTable matchDocuments = $MatchDocumentsTable(this);
  late final $RankedSnapshotsTable rankedSnapshots = $RankedSnapshotsTable(
    this,
  );
  late final $CaptureEpochsTable captureEpochs = $CaptureEpochsTable(this);
  late final $SourceRecordsTable sourceRecords = $SourceRecordsTable(this);
  late final $DomainEntriesTable domainEntries = $DomainEntriesTable(this);
  late final $LineageEdgesTable lineageEdges = $LineageEdgesTable(this);
  late final $SnapshotCursorsTable snapshotCursors = $SnapshotCursorsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    accountContextStates,
    matches,
    accountMatches,
    matchDocuments,
    rankedSnapshots,
    captureEpochs,
    sourceRecords,
    domainEntries,
    lineageEdges,
    snapshotCursors,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String puuid,
  required String platformId,
  Value<String?> gameName,
  Value<String?> tagLine,
  Value<int?> summonerId,
  Value<int?> summonerLevel,
  Value<int?> profileIconId,
  Value<String?> lastClientVersion,
  Value<String?> lastPatchKey,
  required int firstSeenAtUs,
  required int lastSeenAtUs,
  Value<int> recordSchemaVersion,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> puuid,
  Value<String> platformId,
  Value<String?> gameName,
  Value<String?> tagLine,
  Value<int?> summonerId,
  Value<int?> summonerLevel,
  Value<int?> profileIconId,
  Value<String?> lastClientVersion,
  Value<String?> lastPatchKey,
  Value<int> firstSeenAtUs,
  Value<int> lastSeenAtUs,
  Value<int> recordSchemaVersion,
  Value<int> rowid,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$GodSenseDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $AccountContextStatesTable,
    List<AccountContextState>
  >
  _accountContextStatesRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.accountContextStates,
        aliasName: 'accounts__puuid__account_context_states__current_puuid',
      );

  $$AccountContextStatesTableProcessedTableManager
  get accountContextStatesRefs {
    final manager =
        $$AccountContextStatesTableTableManager(
          $_db,
          $_db.accountContextStates,
        ).filter(
          (f) => f.currentPuuid.puuid.sqlEquals($_itemColumn<String>('puuid')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _accountContextStatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AccountMatchesTable, List<AccountMatche>>
  _accountMatchesRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.accountMatches,
        aliasName: 'accounts__puuid__account_matches__puuid',
      );

  $$AccountMatchesTableProcessedTableManager get accountMatchesRefs {
    final manager = $$AccountMatchesTableTableManager(
      $_db,
      $_db.accountMatches,
    ).filter((f) => f.puuid.puuid.sqlEquals($_itemColumn<String>('puuid')!));

    final cache = $_typedResult.readTableOrNull(_accountMatchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchDocumentsTable, List<MatchDocument>>
  _matchDocumentsRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.matchDocuments,
        aliasName: 'accounts__puuid__match_documents__puuid',
      );

  $$MatchDocumentsTableProcessedTableManager get matchDocumentsRefs {
    final manager = $$MatchDocumentsTableTableManager(
      $_db,
      $_db.matchDocuments,
    ).filter((f) => f.puuid.puuid.sqlEquals($_itemColumn<String>('puuid')!));

    final cache = $_typedResult.readTableOrNull(_matchDocumentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RankedSnapshotsTable, List<RankedSnapshot>>
  _rankedSnapshotsRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.rankedSnapshots,
        aliasName: 'accounts__puuid__ranked_snapshots__puuid',
      );

  $$RankedSnapshotsTableProcessedTableManager get rankedSnapshotsRefs {
    final manager = $$RankedSnapshotsTableTableManager(
      $_db,
      $_db.rankedSnapshots,
    ).filter((f) => f.puuid.puuid.sqlEquals($_itemColumn<String>('puuid')!));

    final cache = $_typedResult.readTableOrNull(
      _rankedSnapshotsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$GodSenseDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get puuid => $composableBuilder(
    column: $table.puuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameName => $composableBuilder(
    column: $table.gameName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagLine => $composableBuilder(
    column: $table.tagLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get summonerId => $composableBuilder(
    column: $table.summonerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get summonerLevel => $composableBuilder(
    column: $table.summonerLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileIconId => $composableBuilder(
    column: $table.profileIconId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastClientVersion => $composableBuilder(
    column: $table.lastClientVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastPatchKey => $composableBuilder(
    column: $table.lastPatchKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeenAtUs => $composableBuilder(
    column: $table.firstSeenAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAtUs => $composableBuilder(
    column: $table.lastSeenAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordSchemaVersion => $composableBuilder(
    column: $table.recordSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> accountContextStatesRefs(
    Expression<bool> Function($$AccountContextStatesTableFilterComposer f) f,
  ) {
    final $$AccountContextStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accountContextStates,
      getReferencedColumn: (t) => t.currentPuuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountContextStatesTableFilterComposer(
            $db: $db,
            $table: $db.accountContextStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> accountMatchesRefs(
    Expression<bool> Function($$AccountMatchesTableFilterComposer f) f,
  ) {
    final $$AccountMatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accountMatches,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountMatchesTableFilterComposer(
            $db: $db,
            $table: $db.accountMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchDocumentsRefs(
    Expression<bool> Function($$MatchDocumentsTableFilterComposer f) f,
  ) {
    final $$MatchDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.matchDocuments,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.matchDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rankedSnapshotsRefs(
    Expression<bool> Function($$RankedSnapshotsTableFilterComposer f) f,
  ) {
    final $$RankedSnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.rankedSnapshots,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RankedSnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.rankedSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get puuid => $composableBuilder(
    column: $table.puuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameName => $composableBuilder(
    column: $table.gameName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagLine => $composableBuilder(
    column: $table.tagLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get summonerId => $composableBuilder(
    column: $table.summonerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get summonerLevel => $composableBuilder(
    column: $table.summonerLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileIconId => $composableBuilder(
    column: $table.profileIconId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastClientVersion => $composableBuilder(
    column: $table.lastClientVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastPatchKey => $composableBuilder(
    column: $table.lastPatchKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeenAtUs => $composableBuilder(
    column: $table.firstSeenAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAtUs => $composableBuilder(
    column: $table.lastSeenAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordSchemaVersion => $composableBuilder(
    column: $table.recordSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get puuid =>
      $composableBuilder(column: $table.puuid, builder: (column) => column);

  GeneratedColumn<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gameName =>
      $composableBuilder(column: $table.gameName, builder: (column) => column);

  GeneratedColumn<String> get tagLine =>
      $composableBuilder(column: $table.tagLine, builder: (column) => column);

  GeneratedColumn<int> get summonerId => $composableBuilder(
    column: $table.summonerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get summonerLevel => $composableBuilder(
    column: $table.summonerLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get profileIconId => $composableBuilder(
    column: $table.profileIconId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastClientVersion => $composableBuilder(
    column: $table.lastClientVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastPatchKey => $composableBuilder(
    column: $table.lastPatchKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstSeenAtUs => $composableBuilder(
    column: $table.firstSeenAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenAtUs => $composableBuilder(
    column: $table.lastSeenAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recordSchemaVersion => $composableBuilder(
    column: $table.recordSchemaVersion,
    builder: (column) => column,
  );

  Expression<T> accountContextStatesRefs<T extends Object>(
    Expression<T> Function($$AccountContextStatesTableAnnotationComposer a) f,
  ) {
    final $$AccountContextStatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.puuid,
          referencedTable: $db.accountContextStates,
          getReferencedColumn: (t) => t.currentPuuid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AccountContextStatesTableAnnotationComposer(
                $db: $db,
                $table: $db.accountContextStates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> accountMatchesRefs<T extends Object>(
    Expression<T> Function($$AccountMatchesTableAnnotationComposer a) f,
  ) {
    final $$AccountMatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accountMatches,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountMatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.accountMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchDocumentsRefs<T extends Object>(
    Expression<T> Function($$MatchDocumentsTableAnnotationComposer a) f,
  ) {
    final $$MatchDocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.matchDocuments,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchDocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rankedSnapshotsRefs<T extends Object>(
    Expression<T> Function($$RankedSnapshotsTableAnnotationComposer a) f,
  ) {
    final $$RankedSnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.rankedSnapshots,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RankedSnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.rankedSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool accountContextStatesRefs,
            bool accountMatchesRefs,
            bool matchDocumentsRefs,
            bool rankedSnapshotsRefs,
          })
        > {
  $$AccountsTableTableManager(_$GodSenseDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> puuid = const Value.absent(),
                Value<String> platformId = const Value.absent(),
                Value<String?> gameName = const Value.absent(),
                Value<String?> tagLine = const Value.absent(),
                Value<int?> summonerId = const Value.absent(),
                Value<int?> summonerLevel = const Value.absent(),
                Value<int?> profileIconId = const Value.absent(),
                Value<String?> lastClientVersion = const Value.absent(),
                Value<String?> lastPatchKey = const Value.absent(),
                Value<int> firstSeenAtUs = const Value.absent(),
                Value<int> lastSeenAtUs = const Value.absent(),
                Value<int> recordSchemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                puuid: puuid,
                platformId: platformId,
                gameName: gameName,
                tagLine: tagLine,
                summonerId: summonerId,
                summonerLevel: summonerLevel,
                profileIconId: profileIconId,
                lastClientVersion: lastClientVersion,
                lastPatchKey: lastPatchKey,
                firstSeenAtUs: firstSeenAtUs,
                lastSeenAtUs: lastSeenAtUs,
                recordSchemaVersion: recordSchemaVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String puuid,
                required String platformId,
                Value<String?> gameName = const Value.absent(),
                Value<String?> tagLine = const Value.absent(),
                Value<int?> summonerId = const Value.absent(),
                Value<int?> summonerLevel = const Value.absent(),
                Value<int?> profileIconId = const Value.absent(),
                Value<String?> lastClientVersion = const Value.absent(),
                Value<String?> lastPatchKey = const Value.absent(),
                required int firstSeenAtUs,
                required int lastSeenAtUs,
                Value<int> recordSchemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                puuid: puuid,
                platformId: platformId,
                gameName: gameName,
                tagLine: tagLine,
                summonerId: summonerId,
                summonerLevel: summonerLevel,
                profileIconId: profileIconId,
                lastClientVersion: lastClientVersion,
                lastPatchKey: lastPatchKey,
                firstSeenAtUs: firstSeenAtUs,
                lastSeenAtUs: lastSeenAtUs,
                recordSchemaVersion: recordSchemaVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountContextStatesRefs = false,
                accountMatchesRefs = false,
                matchDocumentsRefs = false,
                rankedSnapshotsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (accountContextStatesRefs) db.accountContextStates,
                    if (accountMatchesRefs) db.accountMatches,
                    if (matchDocumentsRefs) db.matchDocuments,
                    if (rankedSnapshotsRefs) db.rankedSnapshots,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (accountContextStatesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          AccountContextState
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._accountContextStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).accountContextStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.currentPuuid == item.puuid,
                              ),
                          typedResults: items,
                        ),
                      if (accountMatchesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          AccountMatche
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._accountMatchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).accountMatchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.puuid == item.puuid,
                              ),
                          typedResults: items,
                        ),
                      if (matchDocumentsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          MatchDocument
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._matchDocumentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).matchDocumentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.puuid == item.puuid,
                              ),
                          typedResults: items,
                        ),
                      if (rankedSnapshotsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          RankedSnapshot
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._rankedSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).rankedSnapshotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.puuid == item.puuid,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool accountContextStatesRefs,
        bool accountMatchesRefs,
        bool matchDocumentsRefs,
        bool rankedSnapshotsRefs,
      })
    >;
typedef $$AccountContextStatesTableCreateCompanionBuilder =
    AccountContextStatesCompanion Function({
      Value<int> singletonId,
      Value<String?> currentPuuid,
      required int accountGeneration,
      required int syncRevision,
      required int updatedAtUs,
    });
typedef $$AccountContextStatesTableUpdateCompanionBuilder =
    AccountContextStatesCompanion Function({
      Value<int> singletonId,
      Value<String?> currentPuuid,
      Value<int> accountGeneration,
      Value<int> syncRevision,
      Value<int> updatedAtUs,
    });

final class $$AccountContextStatesTableReferences
    extends
        BaseReferences<
          _$GodSenseDatabase,
          $AccountContextStatesTable,
          AccountContextState
        > {
  $$AccountContextStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _currentPuuidTable(_$GodSenseDatabase db) => db.accounts
      .createAlias('account_context_states__current_puuid__accounts__puuid');

  $$AccountsTableProcessedTableManager? get currentPuuid {
    final $_column = $_itemColumn<String>('current_puuid');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.puuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currentPuuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AccountContextStatesTableFilterComposer
    extends Composer<_$GodSenseDatabase, $AccountContextStatesTable> {
  $$AccountContextStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accountGeneration => $composableBuilder(
    column: $table.accountGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get currentPuuid {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentPuuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountContextStatesTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $AccountContextStatesTable> {
  $$AccountContextStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accountGeneration => $composableBuilder(
    column: $table.accountGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get currentPuuid {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentPuuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountContextStatesTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $AccountContextStatesTable> {
  $$AccountContextStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accountGeneration => $composableBuilder(
    column: $table.accountGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get currentPuuid {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentPuuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountContextStatesTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $AccountContextStatesTable,
          AccountContextState,
          $$AccountContextStatesTableFilterComposer,
          $$AccountContextStatesTableOrderingComposer,
          $$AccountContextStatesTableAnnotationComposer,
          $$AccountContextStatesTableCreateCompanionBuilder,
          $$AccountContextStatesTableUpdateCompanionBuilder,
          (AccountContextState, $$AccountContextStatesTableReferences),
          AccountContextState,
          PrefetchHooks Function({bool currentPuuid})
        > {
  $$AccountContextStatesTableTableManager(
    _$GodSenseDatabase db,
    $AccountContextStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountContextStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountContextStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AccountContextStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<String?> currentPuuid = const Value.absent(),
                Value<int> accountGeneration = const Value.absent(),
                Value<int> syncRevision = const Value.absent(),
                Value<int> updatedAtUs = const Value.absent(),
              }) => AccountContextStatesCompanion(
                singletonId: singletonId,
                currentPuuid: currentPuuid,
                accountGeneration: accountGeneration,
                syncRevision: syncRevision,
                updatedAtUs: updatedAtUs,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<String?> currentPuuid = const Value.absent(),
                required int accountGeneration,
                required int syncRevision,
                required int updatedAtUs,
              }) => AccountContextStatesCompanion.insert(
                singletonId: singletonId,
                currentPuuid: currentPuuid,
                accountGeneration: accountGeneration,
                syncRevision: syncRevision,
                updatedAtUs: updatedAtUs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountContextStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({currentPuuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (currentPuuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.currentPuuid,
                        referencedTable: $$AccountContextStatesTableReferences
                            ._currentPuuidTable(db),
                        referencedColumn: $$AccountContextStatesTableReferences
                            ._currentPuuidTable(db)
                            .puuid,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AccountContextStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $AccountContextStatesTable,
      AccountContextState,
      $$AccountContextStatesTableFilterComposer,
      $$AccountContextStatesTableOrderingComposer,
      $$AccountContextStatesTableAnnotationComposer,
      $$AccountContextStatesTableCreateCompanionBuilder,
      $$AccountContextStatesTableUpdateCompanionBuilder,
      (AccountContextState, $$AccountContextStatesTableReferences),
      AccountContextState,
      PrefetchHooks Function({bool currentPuuid})
    >;
typedef $$MatchesTableCreateCompanionBuilder = MatchesCompanion Function({
  required String platformId,
  required int gameId,
  Value<String?> patchKey,
  Value<int?> queueId,
  Value<int?> startedAtUs,
  Value<int?> endedAtUs,
  Value<int> recordSchemaVersion,
  Value<int> rowid,
});
typedef $$MatchesTableUpdateCompanionBuilder = MatchesCompanion Function({
  Value<String> platformId,
  Value<int> gameId,
  Value<String?> patchKey,
  Value<int?> queueId,
  Value<int?> startedAtUs,
  Value<int?> endedAtUs,
  Value<int> recordSchemaVersion,
  Value<int> rowid,
});

class $$MatchesTableFilterComposer
    extends Composer<_$GodSenseDatabase, $MatchesTable> {
  $$MatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patchKey => $composableBuilder(
    column: $table.patchKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUs => $composableBuilder(
    column: $table.startedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtUs => $composableBuilder(
    column: $table.endedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordSchemaVersion => $composableBuilder(
    column: $table.recordSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatchesTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $MatchesTable> {
  $$MatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patchKey => $composableBuilder(
    column: $table.patchKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUs => $composableBuilder(
    column: $table.startedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtUs => $composableBuilder(
    column: $table.endedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordSchemaVersion => $composableBuilder(
    column: $table.recordSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatchesTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $MatchesTable> {
  $$MatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get patchKey =>
      $composableBuilder(column: $table.patchKey, builder: (column) => column);

  GeneratedColumn<int> get queueId =>
      $composableBuilder(column: $table.queueId, builder: (column) => column);

  GeneratedColumn<int> get startedAtUs => $composableBuilder(
    column: $table.startedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtUs =>
      $composableBuilder(column: $table.endedAtUs, builder: (column) => column);

  GeneratedColumn<int> get recordSchemaVersion => $composableBuilder(
    column: $table.recordSchemaVersion,
    builder: (column) => column,
  );
}

class $$MatchesTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $MatchesTable,
          Matche,
          $$MatchesTableFilterComposer,
          $$MatchesTableOrderingComposer,
          $$MatchesTableAnnotationComposer,
          $$MatchesTableCreateCompanionBuilder,
          $$MatchesTableUpdateCompanionBuilder,
          (Matche, BaseReferences<_$GodSenseDatabase, $MatchesTable, Matche>),
          Matche,
          PrefetchHooks Function()
        > {
  $$MatchesTableTableManager(_$GodSenseDatabase db, $MatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> platformId = const Value.absent(),
                Value<int> gameId = const Value.absent(),
                Value<String?> patchKey = const Value.absent(),
                Value<int?> queueId = const Value.absent(),
                Value<int?> startedAtUs = const Value.absent(),
                Value<int?> endedAtUs = const Value.absent(),
                Value<int> recordSchemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion(
                platformId: platformId,
                gameId: gameId,
                patchKey: patchKey,
                queueId: queueId,
                startedAtUs: startedAtUs,
                endedAtUs: endedAtUs,
                recordSchemaVersion: recordSchemaVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String platformId,
                required int gameId,
                Value<String?> patchKey = const Value.absent(),
                Value<int?> queueId = const Value.absent(),
                Value<int?> startedAtUs = const Value.absent(),
                Value<int?> endedAtUs = const Value.absent(),
                Value<int> recordSchemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion.insert(
                platformId: platformId,
                gameId: gameId,
                patchKey: patchKey,
                queueId: queueId,
                startedAtUs: startedAtUs,
                endedAtUs: endedAtUs,
                recordSchemaVersion: recordSchemaVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $MatchesTable,
      Matche,
      $$MatchesTableFilterComposer,
      $$MatchesTableOrderingComposer,
      $$MatchesTableAnnotationComposer,
      $$MatchesTableCreateCompanionBuilder,
      $$MatchesTableUpdateCompanionBuilder,
      (Matche, BaseReferences<_$GodSenseDatabase, $MatchesTable, Matche>),
      Matche,
      PrefetchHooks Function()
    >;
typedef $$AccountMatchesTableCreateCompanionBuilder =
    AccountMatchesCompanion Function({
      required String puuid,
      required String platformId,
      required int gameId,
      Value<String?> participantRole,
      Value<int> rowid,
    });
typedef $$AccountMatchesTableUpdateCompanionBuilder =
    AccountMatchesCompanion Function({
      Value<String> puuid,
      Value<String> platformId,
      Value<int> gameId,
      Value<String?> participantRole,
      Value<int> rowid,
    });

final class $$AccountMatchesTableReferences
    extends
        BaseReferences<
          _$GodSenseDatabase,
          $AccountMatchesTable,
          AccountMatche
        > {
  $$AccountMatchesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _puuidTable(_$GodSenseDatabase db) =>
      db.accounts.createAlias('account_matches__puuid__accounts__puuid');

  $$AccountsTableProcessedTableManager get puuid {
    final $_column = $_itemColumn<String>('puuid')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.puuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_puuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AccountMatchesTableFilterComposer
    extends Composer<_$GodSenseDatabase, $AccountMatchesTable> {
  $$AccountMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantRole => $composableBuilder(
    column: $table.participantRole,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get puuid {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountMatchesTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $AccountMatchesTable> {
  $$AccountMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantRole => $composableBuilder(
    column: $table.participantRole,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get puuid {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountMatchesTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $AccountMatchesTable> {
  $$AccountMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get participantRole => $composableBuilder(
    column: $table.participantRole,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get puuid {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountMatchesTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $AccountMatchesTable,
          AccountMatche,
          $$AccountMatchesTableFilterComposer,
          $$AccountMatchesTableOrderingComposer,
          $$AccountMatchesTableAnnotationComposer,
          $$AccountMatchesTableCreateCompanionBuilder,
          $$AccountMatchesTableUpdateCompanionBuilder,
          (AccountMatche, $$AccountMatchesTableReferences),
          AccountMatche,
          PrefetchHooks Function({bool puuid})
        > {
  $$AccountMatchesTableTableManager(
    _$GodSenseDatabase db,
    $AccountMatchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> puuid = const Value.absent(),
                Value<String> platformId = const Value.absent(),
                Value<int> gameId = const Value.absent(),
                Value<String?> participantRole = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountMatchesCompanion(
                puuid: puuid,
                platformId: platformId,
                gameId: gameId,
                participantRole: participantRole,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String puuid,
                required String platformId,
                required int gameId,
                Value<String?> participantRole = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountMatchesCompanion.insert(
                puuid: puuid,
                platformId: platformId,
                gameId: gameId,
                participantRole: participantRole,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountMatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({puuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (puuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.puuid,
                        referencedTable: $$AccountMatchesTableReferences
                            ._puuidTable(db),
                        referencedColumn: $$AccountMatchesTableReferences
                            ._puuidTable(db)
                            .puuid,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AccountMatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $AccountMatchesTable,
      AccountMatche,
      $$AccountMatchesTableFilterComposer,
      $$AccountMatchesTableOrderingComposer,
      $$AccountMatchesTableAnnotationComposer,
      $$AccountMatchesTableCreateCompanionBuilder,
      $$AccountMatchesTableUpdateCompanionBuilder,
      (AccountMatche, $$AccountMatchesTableReferences),
      AccountMatche,
      PrefetchHooks Function({bool puuid})
    >;
typedef $$MatchDocumentsTableCreateCompanionBuilder =
    MatchDocumentsCompanion Function({
      required String platformId,
      required int gameId,
      required String puuid,
      required String summaryJson,
      Value<String?> detailsJson,
      Value<String?> timelineJson,
      required int syncedAtUs,
      Value<int> rowid,
    });
typedef $$MatchDocumentsTableUpdateCompanionBuilder =
    MatchDocumentsCompanion Function({
      Value<String> platformId,
      Value<int> gameId,
      Value<String> puuid,
      Value<String> summaryJson,
      Value<String?> detailsJson,
      Value<String?> timelineJson,
      Value<int> syncedAtUs,
      Value<int> rowid,
    });

final class $$MatchDocumentsTableReferences
    extends
        BaseReferences<
          _$GodSenseDatabase,
          $MatchDocumentsTable,
          MatchDocument
        > {
  $$MatchDocumentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _puuidTable(_$GodSenseDatabase db) =>
      db.accounts.createAlias('match_documents__puuid__accounts__puuid');

  $$AccountsTableProcessedTableManager get puuid {
    final $_column = $_itemColumn<String>('puuid')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.puuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_puuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchDocumentsTableFilterComposer
    extends Composer<_$GodSenseDatabase, $MatchDocumentsTable> {
  $$MatchDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timelineJson => $composableBuilder(
    column: $table.timelineJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAtUs => $composableBuilder(
    column: $table.syncedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get puuid {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchDocumentsTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $MatchDocumentsTable> {
  $$MatchDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timelineJson => $composableBuilder(
    column: $table.timelineJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAtUs => $composableBuilder(
    column: $table.syncedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get puuid {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchDocumentsTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $MatchDocumentsTable> {
  $$MatchDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timelineJson => $composableBuilder(
    column: $table.timelineJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncedAtUs => $composableBuilder(
    column: $table.syncedAtUs,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get puuid {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchDocumentsTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $MatchDocumentsTable,
          MatchDocument,
          $$MatchDocumentsTableFilterComposer,
          $$MatchDocumentsTableOrderingComposer,
          $$MatchDocumentsTableAnnotationComposer,
          $$MatchDocumentsTableCreateCompanionBuilder,
          $$MatchDocumentsTableUpdateCompanionBuilder,
          (MatchDocument, $$MatchDocumentsTableReferences),
          MatchDocument,
          PrefetchHooks Function({bool puuid})
        > {
  $$MatchDocumentsTableTableManager(
    _$GodSenseDatabase db,
    $MatchDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> platformId = const Value.absent(),
                Value<int> gameId = const Value.absent(),
                Value<String> puuid = const Value.absent(),
                Value<String> summaryJson = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<String?> timelineJson = const Value.absent(),
                Value<int> syncedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchDocumentsCompanion(
                platformId: platformId,
                gameId: gameId,
                puuid: puuid,
                summaryJson: summaryJson,
                detailsJson: detailsJson,
                timelineJson: timelineJson,
                syncedAtUs: syncedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String platformId,
                required int gameId,
                required String puuid,
                required String summaryJson,
                Value<String?> detailsJson = const Value.absent(),
                Value<String?> timelineJson = const Value.absent(),
                required int syncedAtUs,
                Value<int> rowid = const Value.absent(),
              }) => MatchDocumentsCompanion.insert(
                platformId: platformId,
                gameId: gameId,
                puuid: puuid,
                summaryJson: summaryJson,
                detailsJson: detailsJson,
                timelineJson: timelineJson,
                syncedAtUs: syncedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchDocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({puuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (puuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.puuid,
                        referencedTable: $$MatchDocumentsTableReferences
                            ._puuidTable(db),
                        referencedColumn: $$MatchDocumentsTableReferences
                            ._puuidTable(db)
                            .puuid,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MatchDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $MatchDocumentsTable,
      MatchDocument,
      $$MatchDocumentsTableFilterComposer,
      $$MatchDocumentsTableOrderingComposer,
      $$MatchDocumentsTableAnnotationComposer,
      $$MatchDocumentsTableCreateCompanionBuilder,
      $$MatchDocumentsTableUpdateCompanionBuilder,
      (MatchDocument, $$MatchDocumentsTableReferences),
      MatchDocument,
      PrefetchHooks Function({bool puuid})
    >;
typedef $$RankedSnapshotsTableCreateCompanionBuilder =
    RankedSnapshotsCompanion Function({
      Value<int> id,
      required String puuid,
      required int observedAtUs,
      required String payloadJson,
      required String semanticHash,
    });
typedef $$RankedSnapshotsTableUpdateCompanionBuilder =
    RankedSnapshotsCompanion Function({
      Value<int> id,
      Value<String> puuid,
      Value<int> observedAtUs,
      Value<String> payloadJson,
      Value<String> semanticHash,
    });

final class $$RankedSnapshotsTableReferences
    extends
        BaseReferences<
          _$GodSenseDatabase,
          $RankedSnapshotsTable,
          RankedSnapshot
        > {
  $$RankedSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _puuidTable(_$GodSenseDatabase db) =>
      db.accounts.createAlias('ranked_snapshots__puuid__accounts__puuid');

  $$AccountsTableProcessedTableManager get puuid {
    final $_column = $_itemColumn<String>('puuid')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.puuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_puuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RankedSnapshotsTableFilterComposer
    extends Composer<_$GodSenseDatabase, $RankedSnapshotsTable> {
  $$RankedSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get observedAtUs => $composableBuilder(
    column: $table.observedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get puuid {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RankedSnapshotsTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $RankedSnapshotsTable> {
  $$RankedSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get observedAtUs => $composableBuilder(
    column: $table.observedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get puuid {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RankedSnapshotsTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $RankedSnapshotsTable> {
  $$RankedSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get observedAtUs => $composableBuilder(
    column: $table.observedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get puuid {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.puuid,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.puuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RankedSnapshotsTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $RankedSnapshotsTable,
          RankedSnapshot,
          $$RankedSnapshotsTableFilterComposer,
          $$RankedSnapshotsTableOrderingComposer,
          $$RankedSnapshotsTableAnnotationComposer,
          $$RankedSnapshotsTableCreateCompanionBuilder,
          $$RankedSnapshotsTableUpdateCompanionBuilder,
          (RankedSnapshot, $$RankedSnapshotsTableReferences),
          RankedSnapshot,
          PrefetchHooks Function({bool puuid})
        > {
  $$RankedSnapshotsTableTableManager(
    _$GodSenseDatabase db,
    $RankedSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RankedSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RankedSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RankedSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> puuid = const Value.absent(),
                Value<int> observedAtUs = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> semanticHash = const Value.absent(),
              }) => RankedSnapshotsCompanion(
                id: id,
                puuid: puuid,
                observedAtUs: observedAtUs,
                payloadJson: payloadJson,
                semanticHash: semanticHash,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String puuid,
                required int observedAtUs,
                required String payloadJson,
                required String semanticHash,
              }) => RankedSnapshotsCompanion.insert(
                id: id,
                puuid: puuid,
                observedAtUs: observedAtUs,
                payloadJson: payloadJson,
                semanticHash: semanticHash,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RankedSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({puuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (puuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.puuid,
                        referencedTable: $$RankedSnapshotsTableReferences
                            ._puuidTable(db),
                        referencedColumn: $$RankedSnapshotsTableReferences
                            ._puuidTable(db)
                            .puuid,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RankedSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $RankedSnapshotsTable,
      RankedSnapshot,
      $$RankedSnapshotsTableFilterComposer,
      $$RankedSnapshotsTableOrderingComposer,
      $$RankedSnapshotsTableAnnotationComposer,
      $$RankedSnapshotsTableCreateCompanionBuilder,
      $$RankedSnapshotsTableUpdateCompanionBuilder,
      (RankedSnapshot, $$RankedSnapshotsTableReferences),
      RankedSnapshot,
      PrefetchHooks Function({bool puuid})
    >;
typedef $$CaptureEpochsTableCreateCompanionBuilder =
    CaptureEpochsCompanion Function({
      required String id,
      required int startedAtUs,
      Value<int?> endedAtUs,
      Value<int> rowid,
    });
typedef $$CaptureEpochsTableUpdateCompanionBuilder =
    CaptureEpochsCompanion Function({
      Value<String> id,
      Value<int> startedAtUs,
      Value<int?> endedAtUs,
      Value<int> rowid,
    });

final class $$CaptureEpochsTableReferences
    extends
        BaseReferences<_$GodSenseDatabase, $CaptureEpochsTable, CaptureEpoch> {
  $$CaptureEpochsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SourceRecordsTable, List<SourceRecord>>
  _sourceRecordsRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sourceRecords,
        aliasName: 'capture_epochs__id__source_records__capture_epoch_id',
      );

  $$SourceRecordsTableProcessedTableManager get sourceRecordsRefs {
    final manager = $$SourceRecordsTableTableManager(
      $_db,
      $_db.sourceRecords,
    ).filter((f) => f.captureEpochId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourceRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SnapshotCursorsTable, List<SnapshotCursor>>
  _snapshotCursorsRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.snapshotCursors,
        aliasName: 'capture_epochs__id__snapshot_cursors__capture_epoch_id',
      );

  $$SnapshotCursorsTableProcessedTableManager get snapshotCursorsRefs {
    final manager = $$SnapshotCursorsTableTableManager(
      $_db,
      $_db.snapshotCursors,
    ).filter((f) => f.captureEpochId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _snapshotCursorsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CaptureEpochsTableFilterComposer
    extends Composer<_$GodSenseDatabase, $CaptureEpochsTable> {
  $$CaptureEpochsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUs => $composableBuilder(
    column: $table.startedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtUs => $composableBuilder(
    column: $table.endedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sourceRecordsRefs(
    Expression<bool> Function($$SourceRecordsTableFilterComposer f) f,
  ) {
    final $$SourceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sourceRecords,
      getReferencedColumn: (t) => t.captureEpochId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.sourceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> snapshotCursorsRefs(
    Expression<bool> Function($$SnapshotCursorsTableFilterComposer f) f,
  ) {
    final $$SnapshotCursorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snapshotCursors,
      getReferencedColumn: (t) => t.captureEpochId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotCursorsTableFilterComposer(
            $db: $db,
            $table: $db.snapshotCursors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CaptureEpochsTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $CaptureEpochsTable> {
  $$CaptureEpochsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUs => $composableBuilder(
    column: $table.startedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtUs => $composableBuilder(
    column: $table.endedAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaptureEpochsTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $CaptureEpochsTable> {
  $$CaptureEpochsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAtUs => $composableBuilder(
    column: $table.startedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtUs =>
      $composableBuilder(column: $table.endedAtUs, builder: (column) => column);

  Expression<T> sourceRecordsRefs<T extends Object>(
    Expression<T> Function($$SourceRecordsTableAnnotationComposer a) f,
  ) {
    final $$SourceRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sourceRecords,
      getReferencedColumn: (t) => t.captureEpochId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.sourceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> snapshotCursorsRefs<T extends Object>(
    Expression<T> Function($$SnapshotCursorsTableAnnotationComposer a) f,
  ) {
    final $$SnapshotCursorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snapshotCursors,
      getReferencedColumn: (t) => t.captureEpochId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotCursorsTableAnnotationComposer(
            $db: $db,
            $table: $db.snapshotCursors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CaptureEpochsTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $CaptureEpochsTable,
          CaptureEpoch,
          $$CaptureEpochsTableFilterComposer,
          $$CaptureEpochsTableOrderingComposer,
          $$CaptureEpochsTableAnnotationComposer,
          $$CaptureEpochsTableCreateCompanionBuilder,
          $$CaptureEpochsTableUpdateCompanionBuilder,
          (CaptureEpoch, $$CaptureEpochsTableReferences),
          CaptureEpoch,
          PrefetchHooks Function({
            bool sourceRecordsRefs,
            bool snapshotCursorsRefs,
          })
        > {
  $$CaptureEpochsTableTableManager(
    _$GodSenseDatabase db,
    $CaptureEpochsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaptureEpochsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaptureEpochsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaptureEpochsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> startedAtUs = const Value.absent(),
                Value<int?> endedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaptureEpochsCompanion(
                id: id,
                startedAtUs: startedAtUs,
                endedAtUs: endedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int startedAtUs,
                Value<int?> endedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaptureEpochsCompanion.insert(
                id: id,
                startedAtUs: startedAtUs,
                endedAtUs: endedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CaptureEpochsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sourceRecordsRefs = false, snapshotCursorsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sourceRecordsRefs) db.sourceRecords,
                    if (snapshotCursorsRefs) db.snapshotCursors,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sourceRecordsRefs)
                        await $_getPrefetchedData<
                          CaptureEpoch,
                          $CaptureEpochsTable,
                          SourceRecord
                        >(
                          currentTable: table,
                          referencedTable: $$CaptureEpochsTableReferences
                              ._sourceRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CaptureEpochsTableReferences(
                                db,
                                table,
                                p0,
                              ).sourceRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.captureEpochId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (snapshotCursorsRefs)
                        await $_getPrefetchedData<
                          CaptureEpoch,
                          $CaptureEpochsTable,
                          SnapshotCursor
                        >(
                          currentTable: table,
                          referencedTable: $$CaptureEpochsTableReferences
                              ._snapshotCursorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CaptureEpochsTableReferences(
                                db,
                                table,
                                p0,
                              ).snapshotCursorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.captureEpochId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CaptureEpochsTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $CaptureEpochsTable,
      CaptureEpoch,
      $$CaptureEpochsTableFilterComposer,
      $$CaptureEpochsTableOrderingComposer,
      $$CaptureEpochsTableAnnotationComposer,
      $$CaptureEpochsTableCreateCompanionBuilder,
      $$CaptureEpochsTableUpdateCompanionBuilder,
      (CaptureEpoch, $$CaptureEpochsTableReferences),
      CaptureEpoch,
      PrefetchHooks Function({bool sourceRecordsRefs, bool snapshotCursorsRefs})
    >;
typedef $$SourceRecordsTableCreateCompanionBuilder =
    SourceRecordsCompanion Function({
      required String id,
      required String entryKind,
      required String sourceNamespace,
      Value<String?> sourceRecordKey,
      Value<int?> sourceSequence,
      required int transportGeneration,
      Value<int?> gameGeneration,
      Value<String?> platformId,
      Value<int?> gameId,
      Value<String?> semanticKey,
      Value<String?> captureEpochId,
      required int receivedAtUs,
      required Uint8List rawPayload,
      required String rawFormat,
      required String rawHash,
      required String semanticHash,
      required String retentionClass,
      required int envelopeSchemaVersion,
      required bool redacted,
      Value<int> rowid,
    });
typedef $$SourceRecordsTableUpdateCompanionBuilder =
    SourceRecordsCompanion Function({
      Value<String> id,
      Value<String> entryKind,
      Value<String> sourceNamespace,
      Value<String?> sourceRecordKey,
      Value<int?> sourceSequence,
      Value<int> transportGeneration,
      Value<int?> gameGeneration,
      Value<String?> platformId,
      Value<int?> gameId,
      Value<String?> semanticKey,
      Value<String?> captureEpochId,
      Value<int> receivedAtUs,
      Value<Uint8List> rawPayload,
      Value<String> rawFormat,
      Value<String> rawHash,
      Value<String> semanticHash,
      Value<String> retentionClass,
      Value<int> envelopeSchemaVersion,
      Value<bool> redacted,
      Value<int> rowid,
    });

final class $$SourceRecordsTableReferences
    extends
        BaseReferences<_$GodSenseDatabase, $SourceRecordsTable, SourceRecord> {
  $$SourceRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CaptureEpochsTable _captureEpochIdTable(_$GodSenseDatabase db) => db
      .captureEpochs
      .createAlias('source_records__capture_epoch_id__capture_epochs__id');

  $$CaptureEpochsTableProcessedTableManager? get captureEpochId {
    final $_column = $_itemColumn<String>('capture_epoch_id');
    if ($_column == null) return null;
    final manager = $$CaptureEpochsTableTableManager(
      $_db,
      $_db.captureEpochs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_captureEpochIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DomainEntriesTable, List<DomainEntry>>
  _domainEntriesRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.domainEntries,
        aliasName: 'source_records__id__domain_entries__source_record_id',
      );

  $$DomainEntriesTableProcessedTableManager get domainEntriesRefs {
    final manager = $$DomainEntriesTableTableManager(
      $_db,
      $_db.domainEntries,
    ).filter((f) => f.sourceRecordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_domainEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SnapshotCursorsTable, List<SnapshotCursor>>
  _snapshotCursorsRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.snapshotCursors,
        aliasName:
            'source_records__id__snapshot_cursors__last_source_record_id',
      );

  $$SnapshotCursorsTableProcessedTableManager get snapshotCursorsRefs {
    final manager =
        $$SnapshotCursorsTableTableManager($_db, $_db.snapshotCursors).filter(
          (f) => f.lastSourceRecordId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _snapshotCursorsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SourceRecordsTableFilterComposer
    extends Composer<_$GodSenseDatabase, $SourceRecordsTable> {
  $$SourceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryKind => $composableBuilder(
    column: $table.entryKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceNamespace => $composableBuilder(
    column: $table.sourceNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRecordKey => $composableBuilder(
    column: $table.sourceRecordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceSequence => $composableBuilder(
    column: $table.sourceSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transportGeneration => $composableBuilder(
    column: $table.transportGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gameGeneration => $composableBuilder(
    column: $table.gameGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedAtUs => $composableBuilder(
    column: $table.receivedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get rawPayload => $composableBuilder(
    column: $table.rawPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawFormat => $composableBuilder(
    column: $table.rawFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawHash => $composableBuilder(
    column: $table.rawHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get retentionClass => $composableBuilder(
    column: $table.retentionClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get envelopeSchemaVersion => $composableBuilder(
    column: $table.envelopeSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get redacted => $composableBuilder(
    column: $table.redacted,
    builder: (column) => ColumnFilters(column),
  );

  $$CaptureEpochsTableFilterComposer get captureEpochId {
    final $$CaptureEpochsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureEpochId,
      referencedTable: $db.captureEpochs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureEpochsTableFilterComposer(
            $db: $db,
            $table: $db.captureEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> domainEntriesRefs(
    Expression<bool> Function($$DomainEntriesTableFilterComposer f) f,
  ) {
    final $$DomainEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.domainEntries,
      getReferencedColumn: (t) => t.sourceRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainEntriesTableFilterComposer(
            $db: $db,
            $table: $db.domainEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> snapshotCursorsRefs(
    Expression<bool> Function($$SnapshotCursorsTableFilterComposer f) f,
  ) {
    final $$SnapshotCursorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snapshotCursors,
      getReferencedColumn: (t) => t.lastSourceRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotCursorsTableFilterComposer(
            $db: $db,
            $table: $db.snapshotCursors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourceRecordsTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $SourceRecordsTable> {
  $$SourceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryKind => $composableBuilder(
    column: $table.entryKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceNamespace => $composableBuilder(
    column: $table.sourceNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRecordKey => $composableBuilder(
    column: $table.sourceRecordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceSequence => $composableBuilder(
    column: $table.sourceSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transportGeneration => $composableBuilder(
    column: $table.transportGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gameGeneration => $composableBuilder(
    column: $table.gameGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedAtUs => $composableBuilder(
    column: $table.receivedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get rawPayload => $composableBuilder(
    column: $table.rawPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawFormat => $composableBuilder(
    column: $table.rawFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawHash => $composableBuilder(
    column: $table.rawHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get retentionClass => $composableBuilder(
    column: $table.retentionClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get envelopeSchemaVersion => $composableBuilder(
    column: $table.envelopeSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get redacted => $composableBuilder(
    column: $table.redacted,
    builder: (column) => ColumnOrderings(column),
  );

  $$CaptureEpochsTableOrderingComposer get captureEpochId {
    final $$CaptureEpochsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureEpochId,
      referencedTable: $db.captureEpochs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureEpochsTableOrderingComposer(
            $db: $db,
            $table: $db.captureEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SourceRecordsTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $SourceRecordsTable> {
  $$SourceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entryKind =>
      $composableBuilder(column: $table.entryKind, builder: (column) => column);

  GeneratedColumn<String> get sourceNamespace => $composableBuilder(
    column: $table.sourceNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRecordKey => $composableBuilder(
    column: $table.sourceRecordKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceSequence => $composableBuilder(
    column: $table.sourceSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transportGeneration => $composableBuilder(
    column: $table.transportGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gameGeneration => $composableBuilder(
    column: $table.gameGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receivedAtUs => $composableBuilder(
    column: $table.receivedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get rawPayload => $composableBuilder(
    column: $table.rawPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawFormat =>
      $composableBuilder(column: $table.rawFormat, builder: (column) => column);

  GeneratedColumn<String> get rawHash =>
      $composableBuilder(column: $table.rawHash, builder: (column) => column);

  GeneratedColumn<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get retentionClass => $composableBuilder(
    column: $table.retentionClass,
    builder: (column) => column,
  );

  GeneratedColumn<int> get envelopeSchemaVersion => $composableBuilder(
    column: $table.envelopeSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get redacted =>
      $composableBuilder(column: $table.redacted, builder: (column) => column);

  $$CaptureEpochsTableAnnotationComposer get captureEpochId {
    final $$CaptureEpochsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureEpochId,
      referencedTable: $db.captureEpochs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureEpochsTableAnnotationComposer(
            $db: $db,
            $table: $db.captureEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> domainEntriesRefs<T extends Object>(
    Expression<T> Function($$DomainEntriesTableAnnotationComposer a) f,
  ) {
    final $$DomainEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.domainEntries,
      getReferencedColumn: (t) => t.sourceRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.domainEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> snapshotCursorsRefs<T extends Object>(
    Expression<T> Function($$SnapshotCursorsTableAnnotationComposer a) f,
  ) {
    final $$SnapshotCursorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snapshotCursors,
      getReferencedColumn: (t) => t.lastSourceRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotCursorsTableAnnotationComposer(
            $db: $db,
            $table: $db.snapshotCursors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourceRecordsTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $SourceRecordsTable,
          SourceRecord,
          $$SourceRecordsTableFilterComposer,
          $$SourceRecordsTableOrderingComposer,
          $$SourceRecordsTableAnnotationComposer,
          $$SourceRecordsTableCreateCompanionBuilder,
          $$SourceRecordsTableUpdateCompanionBuilder,
          (SourceRecord, $$SourceRecordsTableReferences),
          SourceRecord,
          PrefetchHooks Function({
            bool captureEpochId,
            bool domainEntriesRefs,
            bool snapshotCursorsRefs,
          })
        > {
  $$SourceRecordsTableTableManager(
    _$GodSenseDatabase db,
    $SourceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entryKind = const Value.absent(),
                Value<String> sourceNamespace = const Value.absent(),
                Value<String?> sourceRecordKey = const Value.absent(),
                Value<int?> sourceSequence = const Value.absent(),
                Value<int> transportGeneration = const Value.absent(),
                Value<int?> gameGeneration = const Value.absent(),
                Value<String?> platformId = const Value.absent(),
                Value<int?> gameId = const Value.absent(),
                Value<String?> semanticKey = const Value.absent(),
                Value<String?> captureEpochId = const Value.absent(),
                Value<int> receivedAtUs = const Value.absent(),
                Value<Uint8List> rawPayload = const Value.absent(),
                Value<String> rawFormat = const Value.absent(),
                Value<String> rawHash = const Value.absent(),
                Value<String> semanticHash = const Value.absent(),
                Value<String> retentionClass = const Value.absent(),
                Value<int> envelopeSchemaVersion = const Value.absent(),
                Value<bool> redacted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceRecordsCompanion(
                id: id,
                entryKind: entryKind,
                sourceNamespace: sourceNamespace,
                sourceRecordKey: sourceRecordKey,
                sourceSequence: sourceSequence,
                transportGeneration: transportGeneration,
                gameGeneration: gameGeneration,
                platformId: platformId,
                gameId: gameId,
                semanticKey: semanticKey,
                captureEpochId: captureEpochId,
                receivedAtUs: receivedAtUs,
                rawPayload: rawPayload,
                rawFormat: rawFormat,
                rawHash: rawHash,
                semanticHash: semanticHash,
                retentionClass: retentionClass,
                envelopeSchemaVersion: envelopeSchemaVersion,
                redacted: redacted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entryKind,
                required String sourceNamespace,
                Value<String?> sourceRecordKey = const Value.absent(),
                Value<int?> sourceSequence = const Value.absent(),
                required int transportGeneration,
                Value<int?> gameGeneration = const Value.absent(),
                Value<String?> platformId = const Value.absent(),
                Value<int?> gameId = const Value.absent(),
                Value<String?> semanticKey = const Value.absent(),
                Value<String?> captureEpochId = const Value.absent(),
                required int receivedAtUs,
                required Uint8List rawPayload,
                required String rawFormat,
                required String rawHash,
                required String semanticHash,
                required String retentionClass,
                required int envelopeSchemaVersion,
                required bool redacted,
                Value<int> rowid = const Value.absent(),
              }) => SourceRecordsCompanion.insert(
                id: id,
                entryKind: entryKind,
                sourceNamespace: sourceNamespace,
                sourceRecordKey: sourceRecordKey,
                sourceSequence: sourceSequence,
                transportGeneration: transportGeneration,
                gameGeneration: gameGeneration,
                platformId: platformId,
                gameId: gameId,
                semanticKey: semanticKey,
                captureEpochId: captureEpochId,
                receivedAtUs: receivedAtUs,
                rawPayload: rawPayload,
                rawFormat: rawFormat,
                rawHash: rawHash,
                semanticHash: semanticHash,
                retentionClass: retentionClass,
                envelopeSchemaVersion: envelopeSchemaVersion,
                redacted: redacted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SourceRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                captureEpochId = false,
                domainEntriesRefs = false,
                snapshotCursorsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (domainEntriesRefs) db.domainEntries,
                    if (snapshotCursorsRefs) db.snapshotCursors,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (captureEpochId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.captureEpochId,
                            referencedTable: $$SourceRecordsTableReferences
                                ._captureEpochIdTable(db),
                            referencedColumn: $$SourceRecordsTableReferences
                                ._captureEpochIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (domainEntriesRefs)
                        await $_getPrefetchedData<
                          SourceRecord,
                          $SourceRecordsTable,
                          DomainEntry
                        >(
                          currentTable: table,
                          referencedTable: $$SourceRecordsTableReferences
                              ._domainEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourceRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).domainEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceRecordId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (snapshotCursorsRefs)
                        await $_getPrefetchedData<
                          SourceRecord,
                          $SourceRecordsTable,
                          SnapshotCursor
                        >(
                          currentTable: table,
                          referencedTable: $$SourceRecordsTableReferences
                              ._snapshotCursorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourceRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).snapshotCursorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lastSourceRecordId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SourceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $SourceRecordsTable,
      SourceRecord,
      $$SourceRecordsTableFilterComposer,
      $$SourceRecordsTableOrderingComposer,
      $$SourceRecordsTableAnnotationComposer,
      $$SourceRecordsTableCreateCompanionBuilder,
      $$SourceRecordsTableUpdateCompanionBuilder,
      (SourceRecord, $$SourceRecordsTableReferences),
      SourceRecord,
      PrefetchHooks Function({
        bool captureEpochId,
        bool domainEntriesRefs,
        bool snapshotCursorsRefs,
      })
    >;
typedef $$DomainEntriesTableCreateCompanionBuilder =
    DomainEntriesCompanion Function({
      required String id,
      Value<String?> sourceRecordId,
      required String entryKind,
      required String producer,
      required String producerVersion,
      required int producedAtUs,
      Value<String?> decoderId,
      Value<String?> decoderVersion,
      required int payloadSchemaVersion,
      required String typedPayloadJson,
      Value<int?> gameTimeMs,
      Value<String?> derivationKey,
      Value<double?> confidence,
      Value<int> rowid,
    });
typedef $$DomainEntriesTableUpdateCompanionBuilder =
    DomainEntriesCompanion Function({
      Value<String> id,
      Value<String?> sourceRecordId,
      Value<String> entryKind,
      Value<String> producer,
      Value<String> producerVersion,
      Value<int> producedAtUs,
      Value<String?> decoderId,
      Value<String?> decoderVersion,
      Value<int> payloadSchemaVersion,
      Value<String> typedPayloadJson,
      Value<int?> gameTimeMs,
      Value<String?> derivationKey,
      Value<double?> confidence,
      Value<int> rowid,
    });

final class $$DomainEntriesTableReferences
    extends
        BaseReferences<_$GodSenseDatabase, $DomainEntriesTable, DomainEntry> {
  $$DomainEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SourceRecordsTable _sourceRecordIdTable(_$GodSenseDatabase db) => db
      .sourceRecords
      .createAlias('domain_entries__source_record_id__source_records__id');

  $$SourceRecordsTableProcessedTableManager? get sourceRecordId {
    final $_column = $_itemColumn<String>('source_record_id');
    if ($_column == null) return null;
    final manager = $$SourceRecordsTableTableManager(
      $_db,
      $_db.sourceRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceRecordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LineageEdgesTable, List<LineageEdge>>
  _lineageEdgesRefsTable(_$GodSenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.lineageEdges,
        aliasName: 'domain_entries__id__lineage_edges__child_entry_id',
      );

  $$LineageEdgesTableProcessedTableManager get lineageEdgesRefs {
    final manager = $$LineageEdgesTableTableManager(
      $_db,
      $_db.lineageEdges,
    ).filter((f) => f.childEntryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_lineageEdgesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DomainEntriesTableFilterComposer
    extends Composer<_$GodSenseDatabase, $DomainEntriesTable> {
  $$DomainEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryKind => $composableBuilder(
    column: $table.entryKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get producer => $composableBuilder(
    column: $table.producer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get producerVersion => $composableBuilder(
    column: $table.producerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get producedAtUs => $composableBuilder(
    column: $table.producedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decoderId => $composableBuilder(
    column: $table.decoderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decoderVersion => $composableBuilder(
    column: $table.decoderVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadSchemaVersion => $composableBuilder(
    column: $table.payloadSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typedPayloadJson => $composableBuilder(
    column: $table.typedPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gameTimeMs => $composableBuilder(
    column: $table.gameTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get derivationKey => $composableBuilder(
    column: $table.derivationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$SourceRecordsTableFilterComposer get sourceRecordId {
    final $$SourceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceRecordId,
      referencedTable: $db.sourceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.sourceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> lineageEdgesRefs(
    Expression<bool> Function($$LineageEdgesTableFilterComposer f) f,
  ) {
    final $$LineageEdgesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lineageEdges,
      getReferencedColumn: (t) => t.childEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LineageEdgesTableFilterComposer(
            $db: $db,
            $table: $db.lineageEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DomainEntriesTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $DomainEntriesTable> {
  $$DomainEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryKind => $composableBuilder(
    column: $table.entryKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get producer => $composableBuilder(
    column: $table.producer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get producerVersion => $composableBuilder(
    column: $table.producerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get producedAtUs => $composableBuilder(
    column: $table.producedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decoderId => $composableBuilder(
    column: $table.decoderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decoderVersion => $composableBuilder(
    column: $table.decoderVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadSchemaVersion => $composableBuilder(
    column: $table.payloadSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typedPayloadJson => $composableBuilder(
    column: $table.typedPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gameTimeMs => $composableBuilder(
    column: $table.gameTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get derivationKey => $composableBuilder(
    column: $table.derivationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourceRecordsTableOrderingComposer get sourceRecordId {
    final $$SourceRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceRecordId,
      referencedTable: $db.sourceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.sourceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DomainEntriesTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $DomainEntriesTable> {
  $$DomainEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entryKind =>
      $composableBuilder(column: $table.entryKind, builder: (column) => column);

  GeneratedColumn<String> get producer =>
      $composableBuilder(column: $table.producer, builder: (column) => column);

  GeneratedColumn<String> get producerVersion => $composableBuilder(
    column: $table.producerVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get producedAtUs => $composableBuilder(
    column: $table.producedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decoderId =>
      $composableBuilder(column: $table.decoderId, builder: (column) => column);

  GeneratedColumn<String> get decoderVersion => $composableBuilder(
    column: $table.decoderVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get payloadSchemaVersion => $composableBuilder(
    column: $table.payloadSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get typedPayloadJson => $composableBuilder(
    column: $table.typedPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gameTimeMs => $composableBuilder(
    column: $table.gameTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get derivationKey => $composableBuilder(
    column: $table.derivationKey,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$SourceRecordsTableAnnotationComposer get sourceRecordId {
    final $$SourceRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceRecordId,
      referencedTable: $db.sourceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.sourceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> lineageEdgesRefs<T extends Object>(
    Expression<T> Function($$LineageEdgesTableAnnotationComposer a) f,
  ) {
    final $$LineageEdgesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lineageEdges,
      getReferencedColumn: (t) => t.childEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LineageEdgesTableAnnotationComposer(
            $db: $db,
            $table: $db.lineageEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DomainEntriesTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $DomainEntriesTable,
          DomainEntry,
          $$DomainEntriesTableFilterComposer,
          $$DomainEntriesTableOrderingComposer,
          $$DomainEntriesTableAnnotationComposer,
          $$DomainEntriesTableCreateCompanionBuilder,
          $$DomainEntriesTableUpdateCompanionBuilder,
          (DomainEntry, $$DomainEntriesTableReferences),
          DomainEntry,
          PrefetchHooks Function({bool sourceRecordId, bool lineageEdgesRefs})
        > {
  $$DomainEntriesTableTableManager(
    _$GodSenseDatabase db,
    $DomainEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DomainEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DomainEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DomainEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> sourceRecordId = const Value.absent(),
                Value<String> entryKind = const Value.absent(),
                Value<String> producer = const Value.absent(),
                Value<String> producerVersion = const Value.absent(),
                Value<int> producedAtUs = const Value.absent(),
                Value<String?> decoderId = const Value.absent(),
                Value<String?> decoderVersion = const Value.absent(),
                Value<int> payloadSchemaVersion = const Value.absent(),
                Value<String> typedPayloadJson = const Value.absent(),
                Value<int?> gameTimeMs = const Value.absent(),
                Value<String?> derivationKey = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DomainEntriesCompanion(
                id: id,
                sourceRecordId: sourceRecordId,
                entryKind: entryKind,
                producer: producer,
                producerVersion: producerVersion,
                producedAtUs: producedAtUs,
                decoderId: decoderId,
                decoderVersion: decoderVersion,
                payloadSchemaVersion: payloadSchemaVersion,
                typedPayloadJson: typedPayloadJson,
                gameTimeMs: gameTimeMs,
                derivationKey: derivationKey,
                confidence: confidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> sourceRecordId = const Value.absent(),
                required String entryKind,
                required String producer,
                required String producerVersion,
                required int producedAtUs,
                Value<String?> decoderId = const Value.absent(),
                Value<String?> decoderVersion = const Value.absent(),
                required int payloadSchemaVersion,
                required String typedPayloadJson,
                Value<int?> gameTimeMs = const Value.absent(),
                Value<String?> derivationKey = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DomainEntriesCompanion.insert(
                id: id,
                sourceRecordId: sourceRecordId,
                entryKind: entryKind,
                producer: producer,
                producerVersion: producerVersion,
                producedAtUs: producedAtUs,
                decoderId: decoderId,
                decoderVersion: decoderVersion,
                payloadSchemaVersion: payloadSchemaVersion,
                typedPayloadJson: typedPayloadJson,
                gameTimeMs: gameTimeMs,
                derivationKey: derivationKey,
                confidence: confidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DomainEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sourceRecordId = false, lineageEdgesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (lineageEdgesRefs) db.lineageEdges,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceRecordId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceRecordId,
                            referencedTable: $$DomainEntriesTableReferences
                                ._sourceRecordIdTable(db),
                            referencedColumn: $$DomainEntriesTableReferences
                                ._sourceRecordIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (lineageEdgesRefs)
                        await $_getPrefetchedData<
                          DomainEntry,
                          $DomainEntriesTable,
                          LineageEdge
                        >(
                          currentTable: table,
                          referencedTable: $$DomainEntriesTableReferences
                              ._lineageEdgesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DomainEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).lineageEdgesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childEntryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DomainEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $DomainEntriesTable,
      DomainEntry,
      $$DomainEntriesTableFilterComposer,
      $$DomainEntriesTableOrderingComposer,
      $$DomainEntriesTableAnnotationComposer,
      $$DomainEntriesTableCreateCompanionBuilder,
      $$DomainEntriesTableUpdateCompanionBuilder,
      (DomainEntry, $$DomainEntriesTableReferences),
      DomainEntry,
      PrefetchHooks Function({bool sourceRecordId, bool lineageEdgesRefs})
    >;
typedef $$LineageEdgesTableCreateCompanionBuilder =
    LineageEdgesCompanion Function({
      required String childEntryId,
      required String parentKind,
      required String parentId,
      required String relation,
      Value<int> rowid,
    });
typedef $$LineageEdgesTableUpdateCompanionBuilder =
    LineageEdgesCompanion Function({
      Value<String> childEntryId,
      Value<String> parentKind,
      Value<String> parentId,
      Value<String> relation,
      Value<int> rowid,
    });

final class $$LineageEdgesTableReferences
    extends
        BaseReferences<_$GodSenseDatabase, $LineageEdgesTable, LineageEdge> {
  $$LineageEdgesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DomainEntriesTable _childEntryIdTable(_$GodSenseDatabase db) => db
      .domainEntries
      .createAlias('lineage_edges__child_entry_id__domain_entries__id');

  $$DomainEntriesTableProcessedTableManager get childEntryId {
    final $_column = $_itemColumn<String>('child_entry_id')!;

    final manager = $$DomainEntriesTableTableManager(
      $_db,
      $_db.domainEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LineageEdgesTableFilterComposer
    extends Composer<_$GodSenseDatabase, $LineageEdgesTable> {
  $$LineageEdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get parentKind => $composableBuilder(
    column: $table.parentKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnFilters(column),
  );

  $$DomainEntriesTableFilterComposer get childEntryId {
    final $$DomainEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childEntryId,
      referencedTable: $db.domainEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainEntriesTableFilterComposer(
            $db: $db,
            $table: $db.domainEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineageEdgesTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $LineageEdgesTable> {
  $$LineageEdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get parentKind => $composableBuilder(
    column: $table.parentKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnOrderings(column),
  );

  $$DomainEntriesTableOrderingComposer get childEntryId {
    final $$DomainEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childEntryId,
      referencedTable: $db.domainEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.domainEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineageEdgesTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $LineageEdgesTable> {
  $$LineageEdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get parentKind => $composableBuilder(
    column: $table.parentKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get relation =>
      $composableBuilder(column: $table.relation, builder: (column) => column);

  $$DomainEntriesTableAnnotationComposer get childEntryId {
    final $$DomainEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childEntryId,
      referencedTable: $db.domainEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.domainEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineageEdgesTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $LineageEdgesTable,
          LineageEdge,
          $$LineageEdgesTableFilterComposer,
          $$LineageEdgesTableOrderingComposer,
          $$LineageEdgesTableAnnotationComposer,
          $$LineageEdgesTableCreateCompanionBuilder,
          $$LineageEdgesTableUpdateCompanionBuilder,
          (LineageEdge, $$LineageEdgesTableReferences),
          LineageEdge,
          PrefetchHooks Function({bool childEntryId})
        > {
  $$LineageEdgesTableTableManager(
    _$GodSenseDatabase db,
    $LineageEdgesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LineageEdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LineageEdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LineageEdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> childEntryId = const Value.absent(),
                Value<String> parentKind = const Value.absent(),
                Value<String> parentId = const Value.absent(),
                Value<String> relation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LineageEdgesCompanion(
                childEntryId: childEntryId,
                parentKind: parentKind,
                parentId: parentId,
                relation: relation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String childEntryId,
                required String parentKind,
                required String parentId,
                required String relation,
                Value<int> rowid = const Value.absent(),
              }) => LineageEdgesCompanion.insert(
                childEntryId: childEntryId,
                parentKind: parentKind,
                parentId: parentId,
                relation: relation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LineageEdgesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childEntryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (childEntryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.childEntryId,
                        referencedTable: $$LineageEdgesTableReferences
                            ._childEntryIdTable(db),
                        referencedColumn: $$LineageEdgesTableReferences
                            ._childEntryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LineageEdgesTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $LineageEdgesTable,
      LineageEdge,
      $$LineageEdgesTableFilterComposer,
      $$LineageEdgesTableOrderingComposer,
      $$LineageEdgesTableAnnotationComposer,
      $$LineageEdgesTableCreateCompanionBuilder,
      $$LineageEdgesTableUpdateCompanionBuilder,
      (LineageEdge, $$LineageEdgesTableReferences),
      LineageEdge,
      PrefetchHooks Function({bool childEntryId})
    >;
typedef $$SnapshotCursorsTableCreateCompanionBuilder =
    SnapshotCursorsCompanion Function({
      required String sourceNamespace,
      required String semanticKey,
      required String captureEpochId,
      required String lastSemanticHash,
      required String lastSourceRecordId,
      required int updatedAtUs,
      Value<int> rowid,
    });
typedef $$SnapshotCursorsTableUpdateCompanionBuilder =
    SnapshotCursorsCompanion Function({
      Value<String> sourceNamespace,
      Value<String> semanticKey,
      Value<String> captureEpochId,
      Value<String> lastSemanticHash,
      Value<String> lastSourceRecordId,
      Value<int> updatedAtUs,
      Value<int> rowid,
    });

final class $$SnapshotCursorsTableReferences
    extends
        BaseReferences<
          _$GodSenseDatabase,
          $SnapshotCursorsTable,
          SnapshotCursor
        > {
  $$SnapshotCursorsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CaptureEpochsTable _captureEpochIdTable(_$GodSenseDatabase db) => db
      .captureEpochs
      .createAlias('snapshot_cursors__capture_epoch_id__capture_epochs__id');

  $$CaptureEpochsTableProcessedTableManager get captureEpochId {
    final $_column = $_itemColumn<String>('capture_epoch_id')!;

    final manager = $$CaptureEpochsTableTableManager(
      $_db,
      $_db.captureEpochs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_captureEpochIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourceRecordsTable _lastSourceRecordIdTable(_$GodSenseDatabase db) =>
      db.sourceRecords.createAlias(
        'snapshot_cursors__last_source_record_id__source_records__id',
      );

  $$SourceRecordsTableProcessedTableManager get lastSourceRecordId {
    final $_column = $_itemColumn<String>('last_source_record_id')!;

    final manager = $$SourceRecordsTableTableManager(
      $_db,
      $_db.sourceRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lastSourceRecordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SnapshotCursorsTableFilterComposer
    extends Composer<_$GodSenseDatabase, $SnapshotCursorsTable> {
  $$SnapshotCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceNamespace => $composableBuilder(
    column: $table.sourceNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSemanticHash => $composableBuilder(
    column: $table.lastSemanticHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  $$CaptureEpochsTableFilterComposer get captureEpochId {
    final $$CaptureEpochsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureEpochId,
      referencedTable: $db.captureEpochs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureEpochsTableFilterComposer(
            $db: $db,
            $table: $db.captureEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceRecordsTableFilterComposer get lastSourceRecordId {
    final $$SourceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lastSourceRecordId,
      referencedTable: $db.sourceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.sourceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotCursorsTableOrderingComposer
    extends Composer<_$GodSenseDatabase, $SnapshotCursorsTable> {
  $$SnapshotCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceNamespace => $composableBuilder(
    column: $table.sourceNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSemanticHash => $composableBuilder(
    column: $table.lastSemanticHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  $$CaptureEpochsTableOrderingComposer get captureEpochId {
    final $$CaptureEpochsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureEpochId,
      referencedTable: $db.captureEpochs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureEpochsTableOrderingComposer(
            $db: $db,
            $table: $db.captureEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceRecordsTableOrderingComposer get lastSourceRecordId {
    final $$SourceRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lastSourceRecordId,
      referencedTable: $db.sourceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.sourceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotCursorsTableAnnotationComposer
    extends Composer<_$GodSenseDatabase, $SnapshotCursorsTable> {
  $$SnapshotCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceNamespace => $composableBuilder(
    column: $table.sourceNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSemanticHash => $composableBuilder(
    column: $table.lastSemanticHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  $$CaptureEpochsTableAnnotationComposer get captureEpochId {
    final $$CaptureEpochsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureEpochId,
      referencedTable: $db.captureEpochs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureEpochsTableAnnotationComposer(
            $db: $db,
            $table: $db.captureEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceRecordsTableAnnotationComposer get lastSourceRecordId {
    final $$SourceRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lastSourceRecordId,
      referencedTable: $db.sourceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.sourceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotCursorsTableTableManager
    extends
        RootTableManager<
          _$GodSenseDatabase,
          $SnapshotCursorsTable,
          SnapshotCursor,
          $$SnapshotCursorsTableFilterComposer,
          $$SnapshotCursorsTableOrderingComposer,
          $$SnapshotCursorsTableAnnotationComposer,
          $$SnapshotCursorsTableCreateCompanionBuilder,
          $$SnapshotCursorsTableUpdateCompanionBuilder,
          (SnapshotCursor, $$SnapshotCursorsTableReferences),
          SnapshotCursor,
          PrefetchHooks Function({bool captureEpochId, bool lastSourceRecordId})
        > {
  $$SnapshotCursorsTableTableManager(
    _$GodSenseDatabase db,
    $SnapshotCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceNamespace = const Value.absent(),
                Value<String> semanticKey = const Value.absent(),
                Value<String> captureEpochId = const Value.absent(),
                Value<String> lastSemanticHash = const Value.absent(),
                Value<String> lastSourceRecordId = const Value.absent(),
                Value<int> updatedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnapshotCursorsCompanion(
                sourceNamespace: sourceNamespace,
                semanticKey: semanticKey,
                captureEpochId: captureEpochId,
                lastSemanticHash: lastSemanticHash,
                lastSourceRecordId: lastSourceRecordId,
                updatedAtUs: updatedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceNamespace,
                required String semanticKey,
                required String captureEpochId,
                required String lastSemanticHash,
                required String lastSourceRecordId,
                required int updatedAtUs,
                Value<int> rowid = const Value.absent(),
              }) => SnapshotCursorsCompanion.insert(
                sourceNamespace: sourceNamespace,
                semanticKey: semanticKey,
                captureEpochId: captureEpochId,
                lastSemanticHash: lastSemanticHash,
                lastSourceRecordId: lastSourceRecordId,
                updatedAtUs: updatedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnapshotCursorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({captureEpochId = false, lastSourceRecordId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (captureEpochId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.captureEpochId,
                            referencedTable: $$SnapshotCursorsTableReferences
                                ._captureEpochIdTable(db),
                            referencedColumn: $$SnapshotCursorsTableReferences
                                ._captureEpochIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (lastSourceRecordId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.lastSourceRecordId,
                            referencedTable: $$SnapshotCursorsTableReferences
                                ._lastSourceRecordIdTable(db),
                            referencedColumn: $$SnapshotCursorsTableReferences
                                ._lastSourceRecordIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$SnapshotCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$GodSenseDatabase,
      $SnapshotCursorsTable,
      SnapshotCursor,
      $$SnapshotCursorsTableFilterComposer,
      $$SnapshotCursorsTableOrderingComposer,
      $$SnapshotCursorsTableAnnotationComposer,
      $$SnapshotCursorsTableCreateCompanionBuilder,
      $$SnapshotCursorsTableUpdateCompanionBuilder,
      (SnapshotCursor, $$SnapshotCursorsTableReferences),
      SnapshotCursor,
      PrefetchHooks Function({bool captureEpochId, bool lastSourceRecordId})
    >;

class $GodSenseDatabaseManager {
  final _$GodSenseDatabase _db;
  $GodSenseDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$AccountContextStatesTableTableManager get accountContextStates =>
      $$AccountContextStatesTableTableManager(_db, _db.accountContextStates);
  $$MatchesTableTableManager get matches =>
      $$MatchesTableTableManager(_db, _db.matches);
  $$AccountMatchesTableTableManager get accountMatches =>
      $$AccountMatchesTableTableManager(_db, _db.accountMatches);
  $$MatchDocumentsTableTableManager get matchDocuments =>
      $$MatchDocumentsTableTableManager(_db, _db.matchDocuments);
  $$RankedSnapshotsTableTableManager get rankedSnapshots =>
      $$RankedSnapshotsTableTableManager(_db, _db.rankedSnapshots);
  $$CaptureEpochsTableTableManager get captureEpochs =>
      $$CaptureEpochsTableTableManager(_db, _db.captureEpochs);
  $$SourceRecordsTableTableManager get sourceRecords =>
      $$SourceRecordsTableTableManager(_db, _db.sourceRecords);
  $$DomainEntriesTableTableManager get domainEntries =>
      $$DomainEntriesTableTableManager(_db, _db.domainEntries);
  $$LineageEdgesTableTableManager get lineageEdges =>
      $$LineageEdgesTableTableManager(_db, _db.lineageEdges);
  $$SnapshotCursorsTableTableManager get snapshotCursors =>
      $$SnapshotCursorsTableTableManager(_db, _db.snapshotCursors);
}
