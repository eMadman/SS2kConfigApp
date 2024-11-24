import 'package:flutter/material.dart';
import '../utils/workout/workout_tts_settings.dart';

class AudioCoachDialog extends StatefulWidget {
  final WorkoutTTSSettings ttsSettings;

  const AudioCoachDialog({
    Key? key,
    required this.ttsSettings,
  }) : super(key: key);

  @override
  State<AudioCoachDialog> createState() => _AudioCoachDialogState();
}

class _AudioCoachDialogState extends State<AudioCoachDialog> {
  List<String> _voices = [];
  List<String> _engines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVoicesAndEngines();
  }

  Future<void> _loadVoicesAndEngines() async {
    if (widget.ttsSettings.isAndroid) {
      final engines = await widget.ttsSettings.getAvailableEngines();
      setState(() {
        _engines = engines.toSet().toList();
      });
    }
    
    final voices = await widget.ttsSettings.getAvailableVoices();
    setState(() {
      _voices = voices.toSet().toList();
      _loading = false;
    });
  }

  Future<void> _testVoice() async {
    await widget.ttsSettings.speakTest("This is a test of the audio coach voice.");
  }

  String? _getValidVoice() {
    final currentVoice = widget.ttsSettings.voice;
    if (currentVoice != null && _voices.contains(currentVoice)) {
      return currentVoice;
    }
    return _voices.isNotEmpty ? _voices.first : null;
  }

  String? _getValidEngine() {
    final currentEngine = widget.ttsSettings.engine;
    if (currentEngine != null && _engines.contains(currentEngine)) {
      return currentEngine;
    }
    return _engines.isNotEmpty ? _engines.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audio Coach Settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Audio Coach'),
                value: widget.ttsSettings.enabled,
                onChanged: (value) async {
                  await widget.ttsSettings.setEnabled(value);
                  setState(() {});
                },
              ),
              if (widget.ttsSettings.enabled) ...[
                const SizedBox(height: 16),
                const Text('Voice Volume'),
                Slider(
                  value: widget.ttsSettings.volume,
                  onChanged: (value) async {
                    await widget.ttsSettings.setVolume(value);
                    setState(() {});
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(widget.ttsSettings.volume * 100).round()}%',
                ),
                const SizedBox(height: 16),
                const Text('Speech Rate'),
                Slider(
                  value: widget.ttsSettings.rate,
                  onChanged: (value) async {
                    await widget.ttsSettings.setRate(value);
                    setState(() {});
                  },
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(widget.ttsSettings.rate * 100).round()}%',
                ),
                const SizedBox(height: 16),
                const Text('Voice Pitch'),
                Slider(
                  value: widget.ttsSettings.pitch,
                  onChanged: (value) async {
                    await widget.ttsSettings.setPitch(value);
                    setState(() {});
                  },
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${(widget.ttsSettings.pitch * 100).round()}%',
                ),
                if (widget.ttsSettings.isAndroid) ...[
                  const SizedBox(height: 16),
                  const Text('Select Speech Engine'),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_engines.isEmpty)
                    const Text('No engines available')
                  else
                    DropdownButton<String>(
                      value: _getValidEngine(),
                      isExpanded: true,
                      hint: const Text('Select an engine'),
                      items: _engines.map((engine) {
                        return DropdownMenuItem(
                          value: engine,
                          child: Text(engine),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          await widget.ttsSettings.setEngine(value);
                          setState(() {
                            _loading = true;
                            _voices = [];
                          });
                          final voices = await widget.ttsSettings.getAvailableVoices();
                          setState(() {
                            _voices = voices.toSet().toList();
                            _loading = false;
                          });
                        }
                      },
                    ),
                ],
                const SizedBox(height: 16),
                const Text('Select Voice'),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_voices.isEmpty)
                  const Text('No voices available')
                else
                  DropdownButton<String>(
                    value: _getValidVoice(),
                    isExpanded: true,
                    hint: const Text('Select a voice'),
                    items: _voices.map((voice) {
                      return DropdownMenuItem(
                        value: voice,
                        child: Text(voice),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        await widget.ttsSettings.setVoice(value);
                        setState(() {});
                      }
                    },
                  ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: _testVoice,
                    child: const Text('Test Voice'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
