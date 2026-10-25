import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:shared_preferences/shared_preferences.dart';

const gettingStartedSeenKey = 'godsense.getting_started.v1.seen';

Future<int?> showGettingStartedGuide(BuildContext context) => showDialog<int>(
  context: context,
  builder: (_) => const GettingStartedGuide(),
);

class GettingStartedGate extends StatefulWidget {
  const GettingStartedGate({
    super.key,
    required this.child,
    required this.onDestination,
  });

  final Widget child;
  final ValueChanged<int> onDestination;

  @override
  State<GettingStartedGate> createState() => _GettingStartedGateState();
}

class _GettingStartedGateState extends State<GettingStartedGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOnce());
  }

  Future<void> _showOnce() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || preferences.getBool(gettingStartedSeenKey) == true) {
        return;
      }
      final destination = await showGettingStartedGuide(context);
      if (!mounted || destination == null) return;
      await preferences.setBool(gettingStartedSeenKey, true);
      if (!mounted) return;
      if (destination >= 0) widget.onDestination(destination);
    } catch (_) {
      // Help remains available from the app bar if preferences are unavailable.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class GettingStartedGuide extends StatelessWidget {
  const GettingStartedGuide({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Primeros pasos con GodSense'),
    content: const SizedBox(
      width: 540,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GodSense se prepara automáticamente para acompañarte en cada partida.',
          ),
          SizedBox(height: 16),
          _GuideStep(
            title: '1. Abre League',
            body:
                'La cuenta se detecta automáticamente desde el cliente. '
                'Scout conserva el historial sincronizado por cuenta.',
          ),
          _GuideStep(
            title: '2. Calibra el minimapa',
            body:
                'Entra a una partida de práctica y abre Mapa. Comprueba '
                'la región detectada; usa el ajuste manual si no coincide. '
                'Revisa la calibración si cambias resolución o escala del HUD.',
          ),
          _GuideStep(
            title: '3. Prueba la voz',
            body:
                'En Ajustes, elige el idioma que hablas y una voz de respuesta. '
                'Prueba la reproducción y mantén pulsada la tecla configurada '
                'para preguntar al coach.',
          ),
          _GuideStep(
            title: '4. Prepara el overlay',
            body:
                'Usa Editar HUD en la barra superior, coloca los paneles y '
                'termina la edición antes de jugar. La información aparecerá '
                'automáticamente cuando la partida esté activa. En League, '
                'elige Vídeo → Modo de ventana → Sin bordes: el overlay '
                'puede no mostrarse sobre pantalla completa exclusiva.',
          ),
          _GuideStep(
            title: '5. Revisa el coaching',
            body:
                'En selección de campeón, Coach muestra runas y objetos '
                'disponibles para el parche. La importación siempre requiere '
                'tu confirmación.',
          ),
          Text('Puedes volver a esta guía desde el botón Ayuda.'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(-1),
        child: const Text('Listo'),
      ),
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(2),
        child: const Text('Abrir Mapa'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(5),
        child: const Text('Configurar voz'),
      ),
    ],
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(body),
      ],
    ),
  );
}

@Preview(name: 'Getting started', size: Size(800, 700))
Widget gettingStartedPreview() =>
    const MaterialApp(home: Scaffold(body: GettingStartedGuide()));
