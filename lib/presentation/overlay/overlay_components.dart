part of '../../app/godsense_app.dart';

String _enemyLocationStatus(
  Map<String, dynamic> enemy, {
  NativeIdentifiedChampion? native,
  DateTime? now,
}) {
  if (enemy['is_dead'] == true) {
    final timer = (enemy['respawn_timer'] as num?)?.toDouble() ?? 0;
    return timer > 0
        ? 'Muerto · reaparece en ${_formatDuration(timer)}'
        : 'Muerto';
  }
  final currentTime = now ?? DateTime.now();
  if (native != null) {
    final elapsed = currentTime.difference(native.lastSeen);
    if (elapsed.inMilliseconds <= 2000) {
      return 'Visto en ${native.region} · '
          '${(native.confidence * 100).toStringAsFixed(0)}% de confianza';
    }
    return 'Visto hace ${_formatDuration(elapsed.inSeconds)} en '
        '${native.region}';
  }
  final current = enemy['map_location']?.toString();
  if (current != null && current.isNotEmpty) return 'Visto en $current';
  final duration = (enemy['mia_duration'] as num?)?.floor() ?? 0;
  final last = enemy['last_known_location']?.toString();
  if (enemy['is_mia'] == true) {
    return 'MIA ${_formatDuration(duration)}${last == null || last.isEmpty ? '' : ' · última vez en $last'}';
  }
  if (duration > 0 && last != null && last.isNotEmpty) {
    return 'Visto hace ${_formatDuration(duration)} en $last';
  }
  return 'Aún no detectado';
}

String _voiceMessage(CompanionAlert alert) {
  final raw = alert.raw;
  final state = raw['state']?.toString();
  if (state == 'recording') return 'Escuchando…';
  if (state == 'thinking') return 'Pensando…';
  if (state == 'answering' || state == 'answer') {
    return raw['text']?.toString() ?? 'Respondiendo…';
  }
  if (state == 'error') {
    return 'No pude procesar la pregunta. Inténtalo de nuevo.';
  }
  return alert.message;
}

class _CalibrationDangerRing extends StatelessWidget {
  const _CalibrationDangerRing({
    required this.bounds,
    required this.danger,
    required this.devicePixelRatio,
  });

  final Map<String, dynamic> bounds;
  final bool danger;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: ((bounds['left'] as num?)?.toDouble() ?? 0) / devicePixelRatio,
      top: ((bounds['top'] as num?)?.toDouble() ?? 0) / devicePixelRatio,
      width: ((bounds['width'] as num?)?.toDouble() ?? 0) / devicePixelRatio,
      height: ((bounds['height'] as num?)?.toDouble() ?? 0) / devicePixelRatio,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: danger ? Colors.red : Colors.orange,
              width: 5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _OverlayGlassCard extends StatelessWidget {
  const _OverlayGlassCard({
    required this.child,
    this.padding,
    this.borderColor,
    this.backgroundColor,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? const Color(0xCC090D16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        side: BorderSide(
          color: borderColor ?? const Color(0x3338BDF8),
          width: 1,
        ),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

class _OverlayInfoCard extends StatelessWidget {
  const _OverlayInfoCard({
    required this.title,
    required this.width,
    required this.child,
    this.icon,
    this.accentColor,
  });

  final String title;
  final double width;
  final Widget child;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF38BDF8);
    return SizedBox(
      width: width,
      child: _OverlayGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        borderColor: accent.withValues(alpha: 0.35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: accent),
                  const SizedBox(width: 5),
                ],
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            child,
          ],
        ),
      ),
    );
  }
}

typedef _GankAlertHUD = GankAlertHUD;
typedef _ThreatRadarHUD = ThreatRadarHUD;
typedef _VoiceCapsuleHUD = VoiceCapsuleHUD;
typedef _MatchupInfoHUD = MatchupInfoHUD;
typedef _LinearBuildsHUD = LinearBuildsHUD;
typedef _PriorityDirectivesHUD = PriorityDirectivesHUD;
typedef _EsportsCompositionHUD = EsportsCompositionHUD;
typedef _MiniGoldBadgeHUD = MiniGoldBadgeHUD;

class GankAlertHUD extends StatelessWidget {
  const GankAlertHUD({
    super.key,
    this.nativeGank,
    this.gank,
  });

  final NativeTrackerEvent? nativeGank;
  final CompanionAlert? gank;

  @override
  Widget build(BuildContext context) {
    final isDanger =
        nativeGank != null || gank?.raw['threat_level'] == 'DANGER';
    final accentColor =
        isDanger ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final champ = nativeGank?.champion ?? gank?.title ?? 'Enemigo';
    final location = nativeGank != null
        ? '${nativeGank!.location} · ${nativeGank!.role}'
        : gank?.message ?? 'Amenaza aproximándose';

    return _OverlayGlassCard(
      borderColor: accentColor,
      backgroundColor:
          isDanger ? const Color(0xE61A0A0E) : const Color(0xE61C1408),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.2),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nativeGank != null ? 'PELIGRO: $champ' : champ,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isDanger ? 'GANK' : 'ALERTA',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFCBD5E1),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ThreatRadarHUD extends StatelessWidget {
  const ThreatRadarHUD({
    super.key,
    required this.jungler,
    required this.threats,
    required this.nativeSighting,
    required this.sighting,
    required this.nativeVision,
    required this.now,
  });

  final Map<String, dynamic>? jungler;
  final List<Map<String, dynamic>> threats;
  final NativeTrackerEvent? nativeSighting;
  final CompanionAlert? sighting;
  final NativeVisionState nativeVision;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final junglerName = jungler?['champion_name'] ?? 'Jungla rival';
    final junglerStatus = jungler == null
        ? 'Esperando identificación…'
        : _enemyLocationStatus(
            jungler!,
            native: _nativeForEnemy(nativeVision.lastKnown, jungler!),
            now: now,
          );

    return _OverlayGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderColor: const Color(0x4D38BDF8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jungler summary header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _NetworkPortrait(
                  url: jungler?['icon_url']?.toString(),
                  fallbackUrls: _stringValues(jungler?['icon_fallback_urls']),
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$junglerName',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF38BDF8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '· JUG',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      junglerStatus,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFFCBD5E1),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (nativeSighting != null || sighting != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x2638BDF8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_rounded,
                        size: 11,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        nativeSighting != null
                            ? _formatDuration(
                                now
                                    .difference(nativeSighting!.timestamp)
                                    .inSeconds,
                              )
                            : _formatDuration(
                                now
                                    .difference(sighting!.receivedAt)
                                    .inSeconds,
                              ),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0x1FFFFFFF)),
          const SizedBox(height: 6),

          // Horizontal radar row of 5 enemies
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: threats.take(5).map((enemy) {
              final isDead = enemy['is_dead'] == true;
              final isMia = enemy['is_mia'] == true;
              final isJungle =
                  enemy['role']?.toString().toUpperCase() == 'JUNGLE';
              final borderColor = isDead
                  ? const Color(0xFF64748B)
                  : isMia
                  ? const Color(0xFFF59E0B)
                  : isJungle
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981);

              final timer = (enemy['respawn_timer'] as num?)?.toDouble() ?? 0;
              final miaDuration = (enemy['mia_duration'] as num?)?.floor() ?? 0;
              final roleStr = enemy['role']?.toString() ?? '';
              String statusLabel =
                  roleStr.length > 3 ? roleStr.substring(0, 3) : roleStr;

              if (isDead) {
                statusLabel = timer > 0 ? '${timer.round()}s' : 'DEAD';
              } else if (isMia && miaDuration > 0) {
                statusLabel = '${miaDuration}s';
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: ClipOval(
                      child: _NetworkPortrait(
                        url: enemy['icon_url']?.toString(),
                        fallbackUrls: _stringValues(
                          enemy['icon_fallback_urls'],
                        ),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: borderColor,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class VoiceCapsuleHUD extends StatelessWidget {
  const VoiceCapsuleHUD({
    super.key,
    required this.isListening,
    required this.transcript,
    required this.isProcessing,
    required this.adviceText,
    required this.voiceAlert,
  });

  final bool isListening;
  final String transcript;
  final bool isProcessing;
  final String? adviceText;
  final CompanionAlert? voiceAlert;

  @override
  Widget build(BuildContext context) {
    String message = 'Esperando voz…';
    if (isListening) {
      message = 'Escuchando… suelta la tecla para enviar';
    } else if (isProcessing) {
      message = 'Preparando respuesta del coach…';
    } else if (adviceText != null && adviceText!.isNotEmpty) {
      message = adviceText!;
    } else if (transcript.isNotEmpty) {
      message = transcript;
    } else if (voiceAlert != null) {
      message = _voiceMessage(voiceAlert!);
    }

    return _OverlayGlassCard(
      borderColor:
          isListening ? const Color(0xFF818CF8) : const Color(0x4D818CF8),
      backgroundColor: const Color(0xE60B0E17),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? const Color(0x33818CF8)
                  : const Color(0x1AFFFFFF),
            ),
            child: Icon(
              isListening
                  ? Icons.mic_rounded
                  : isProcessing
                  ? Icons.psychology_rounded
                  : Icons.record_voice_over_rounded,
              color: isListening
                  ? const Color(0xFF818CF8)
                  : const Color(0xFFCBD5E1),
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isListening ? FontWeight.w600 : FontWeight.w500,
                color: isListening ? const Color(0xFF818CF8) : Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class MatchupInfoHUD extends StatelessWidget {
  const MatchupInfoHUD({
    super.key,
    required this.matchupData,
  });

  final dynamic matchupData;

  @override
  Widget build(BuildContext context) {
    String winCondition = 'Esperando análisis del enfrentamiento…';
    String? spikes;

    if (matchupData is Map) {
      final map = matchupData as Map;
      winCondition = map['win_condition']?.toString() ??
          map['tip']?.toString() ??
          'Controla la oleada y respeta el rango enemigo.';
      spikes =
          map['power_spike']?.toString() ?? map['danger_level']?.toString();
    } else if (matchupData is String && (matchupData as String).isNotEmpty) {
      winCondition = matchupData as String;
    }

    return _OverlayInfoCard(
      title: 'Enfrentamiento',
      icon: Icons.bolt_rounded,
      accentColor: const Color(0xFF38BDF8),
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🎯 ', style: TextStyle(fontSize: 11)),
              Expanded(
                child: Text(
                  winCondition,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF1F5F9),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (spikes != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('⚡ ', style: TextStyle(fontSize: 10)),
                Expanded(
                  child: Text(
                    spikes,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFFBBF24),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class PriorityDirectivesHUD extends StatelessWidget {
  const PriorityDirectivesHUD({
    super.key,
    required this.directives,
  });

  final List<CoachDirective> directives;

  @override
  Widget build(BuildContext context) {
    return _OverlayInfoCard(
      title: 'Directivas',
      icon: Icons.military_tech_rounded,
      accentColor: const Color(0xFF34D399),
      width: 340,
      child: directives.isEmpty
          ? const Text(
              'Esperando directivas…',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < directives.take(3).length; i++) ...[
                  Builder(
                    builder: (context) {
                      final directive = directives[i];
                      final accent = i == 0
                          ? const Color(0xFFEF4444)
                          : i == 1
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF38BDF8);
                      final label = i == 0 ? 'P1' : i == 1 ? 'P2' : 'P3';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border(
                            left: BorderSide(color: accent, width: 2.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                directive.title,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: i == 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

class EsportsCompositionHUD extends StatelessWidget {
  const EsportsCompositionHUD({
    super.key,
    required this.game,
    this.aiTeamComp,
  });

  final GameSnapshot? game;
  final Map<String, dynamic>? aiTeamComp;

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return const _OverlayInfoCard(
        title: 'Composición',
        icon: Icons.group_work_rounded,
        accentColor: Color(0xFF818CF8),
        width: 340,
        child: Text(
          'Esperando partida…',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
      );
    }

    Widget teamLine(List<Map<String, dynamic>> team, Color teamColor) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: team.take(5).map((player) {
          final role = player['role']?.toString().toUpperCase() ?? '';
          final shortRole = role.isNotEmpty ? role[0] : '';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: teamColor, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: _NetworkPortrait(
                      url: player['icon_url']?.toString(),
                      fallbackUrls: _stringValues(
                        player['icon_fallback_urls'],
                      ),
                      size: 20,
                    ),
                  ),
                ),
                Text(
                  shortRole,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    color: teamColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return _OverlayInfoCard(
      title: 'Composición',
      icon: Icons.group_work_rounded,
      accentColor: const Color(0xFF818CF8),
      width: 340,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          teamLine(game!.allies, const Color(0xFF38BDF8)),
          const Text(
            'VS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0x66FFFFFF),
              letterSpacing: 0.5,
            ),
          ),
          teamLine(game!.enemies, const Color(0xFFEF4444)),
        ],
      ),
    );
  }
}

class MiniGoldBadgeHUD extends StatelessWidget {
  const MiniGoldBadgeHUD({
    super.key,
    required this.goldDifference,
  });

  final int? goldDifference;

  @override
  Widget build(BuildContext context) {
    final diff = goldDifference ?? 0;
    final isAhead = diff > 0;
    final isBehind = diff < 0;
    final accentColor = isAhead
        ? const Color(0xFF10B981)
        : isBehind
        ? const Color(0xFFEF4444)
        : const Color(0xFF94A3B8);
    final valueColor = isAhead
        ? const Color(0xFF34D399)
        : isBehind
        ? const Color(0xFFF87171)
        : const Color(0xFFE2E8F0);

    return _OverlayGlassCard(
      borderColor: accentColor.withValues(alpha: 0.4),
      backgroundColor: const Color(0xE60B0E17),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            size: 15,
            color: Color(0xFFFBBF24),
          ),
          const SizedBox(width: 5),
          const Text(
            'DIF. ORO',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            goldDifference == null ? '0' : _signedNumber(goldDifference!),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableOverlayPanel extends ConsumerWidget {
  const _EditableOverlayPanel({
    required this.id,
    required this.title,
    required this.child,
  });

  final String id;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overlayLayoutProvider);
    final layout = state.panels[id];
    if (layout == null) return const SizedBox.shrink();
    final viewport = MediaQuery.sizeOf(context);
    final visible = layout.fitWithin(viewport);

    return Positioned(
      left: visible.left,
      top: visible.top,
      width: visible.width,
      height: visible.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: state.editing
                  ? BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : const BoxDecoration(),
              child: layout.collapsed
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(top: state.editing ? 40 : 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          primary: false,
                          child: child,
                        ),
                      ),
                    ),
            ),
          ),
          if (state.editing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 40,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => ref
                    .read(overlayLayoutProvider.notifier)
                    .move(id, details.delta, viewport),
                onPanEnd: (_) =>
                    ref.read(overlayLayoutProvider.notifier).persist(),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: 0.9),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      const Icon(Icons.drag_indicator, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(title, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          layout.collapsed
                              ? Icons.expand_more
                              : Icons.expand_less,
                        ),
                        onPressed: () => ref
                            .read(overlayLayoutProvider.notifier)
                            .toggleCollapsed(id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (state.editing && !layout.collapsed)
            Positioned(
              right: 0,
              bottom: 0,
              width: 30,
              height: 30,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => ref
                    .read(overlayLayoutProvider.notifier)
                    .resize(id, details.delta, viewport),
                onPanEnd: (_) =>
                    ref.read(overlayLayoutProvider.notifier).persist(),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.drag_handle, size: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LinearBuildsHUD extends StatelessWidget {
  const LinearBuildsHUD({
    super.key,
    required this.coachGroups,
    this.rawBuilds,
  });

  final List<RecommendedItemGroupViewData> coachGroups;
  final Map<String, dynamic>? rawBuilds;

  @override
  Widget build(BuildContext context) {
    final List<Widget> itemWidgets = [];

    if (coachGroups.isNotEmpty) {
      for (final group in coachGroups) {
        for (final item in group.items) {
          if (itemWidgets.length >= 4) break;
          itemWidgets.add(
            _buildItemPill(
              imageUrl: item.imageUrl,
              name: item.metadata?.name ?? item.item.name,
              price: item.metadata?.totalPrice,
            ),
          );
        }
        if (itemWidgets.length >= 4) break;
      }
    } else if (rawBuilds != null) {
      final itemsGroups = rawBuilds!['items'] as List?;
      final patch = rawBuilds!['patch']?.toString() ?? '15.4.1';
      if (itemsGroups != null) {
        for (final group in itemsGroups) {
          if (group is Map && group['items'] is List) {
            for (final rawItem in group['items'] as List) {
              if (itemWidgets.length >= 4) break;
              if (rawItem is Map) {
                final itemId = (rawItem['item_id'] as num?)?.toInt() ?? 0;
                final imageUrl = itemId > 0
                    ? 'https://ddragon.leagueoflegends.com/cdn/$patch/img/item/$itemId.png'
                    : null;
                itemWidgets.add(
                  _buildItemPill(
                    imageUrl: imageUrl,
                    name: rawItem['name']?.toString() ?? '$itemId',
                    count: (rawItem['count'] as num?)?.toInt() ?? 1,
                  ),
                );
              }
            }
          }
          if (itemWidgets.length >= 4) break;
        }
      }
    }

    return _OverlayInfoCard(
      title: 'Build recomendada',
      icon: Icons.shield_outlined,
      accentColor: const Color(0xFFFBBF24),
      width: 340,
      child: itemWidgets.isEmpty
          ? const Text(
              'Esperando build recomendada…',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            )
          : Row(
              children: [
                for (int i = 0; i < itemWidgets.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: Color(0x4DFFFFFF),
                      ),
                    ),
                  itemWidgets[i],
                ],
              ],
            ),
    );
  }

  Widget _buildItemPill({
    required String? imageUrl,
    required String name,
    int? price,
    int count = 1,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x33FBBF24), width: 1),
            color: const Color(0xFF1E293B),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: ResilientNetworkImage(
              urls: [?imageUrl],
              width: 30,
              height: 30,
              fallback: const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        if (price != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                size: 9,
                color: Color(0xFFFBBF24),
              ),
              const SizedBox(width: 2),
              Text(
                '$price',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFBBF24),
                ),
              ),
            ],
          )
        else if (count > 1)
          Text(
            'x$count',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF38BDF8),
            ),
          ),
      ],
    );
  }
}
