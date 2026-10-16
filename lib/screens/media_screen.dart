import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/websocket_service.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  final WebSocketService _ws = WebSocketService();
  double _volume = 50;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Volume Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.volume_up, color: Color(0xFF38BDF8)),
                          SizedBox(width: 8),
                          Text('Ana Ses Seviyesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Text('%${_volume.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _volume,
                    min: 0,
                    max: 100,
                    divisions: 50,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (v) {
                      setState(() {
                        _volume = v;
                      });
                      _ws.send({'type': 'volume_set', 'percent': v.toInt()});
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _ws.send({'type': 'volume_down', 'steps': 2});
                        },
                        icon: const Icon(Icons.volume_down),
                        label: const Text('-5'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _ws.send({'type': 'volume_mute'});
                        },
                        icon: const Icon(Icons.volume_off, color: Colors.redAccent),
                        label: const Text('Mute', style: TextStyle(color: Colors.redAccent)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _ws.send({'type': 'volume_up', 'steps': 2});
                        },
                        icon: const Icon(Icons.volume_up),
                        label: const Text('+5'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Playback Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 44,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _ws.send({'type': 'media_prev'});
                    },
                  ),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF2563EB),
                    child: IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        _ws.send({'type': 'media_play_pause'});
                      },
                    ),
                  ),
                  IconButton(
                    iconSize: 44,
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _ws.send({'type': 'media_next'});
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Media Launcher
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hızlı Medya Başlatıcı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _ws.send({'type': 'open_url', 'url': 'https://youtube.com'}),
                        icon: const Icon(Icons.play_circle_fill, color: Colors.red),
                        label: const Text('YouTube'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _ws.send({'type': 'launch_app', 'app': 'spotify'}),
                        icon: const Icon(Icons.music_note, color: Colors.green),
                        label: const Text('Spotify'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _ws.send({'type': 'open_url', 'url': 'https://netflix.com'}),
                        icon: const Icon(Icons.movie, color: Colors.redAccent),
                        label: const Text('Netflix'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _ws.send({'type': 'open_url', 'url': 'https://twitch.tv'}),
                        icon: const Icon(Icons.tv, color: Colors.purpleAccent),
                        label: const Text('Twitch'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                      ),
                    ],
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
