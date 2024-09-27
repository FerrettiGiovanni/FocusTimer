import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cronometra il tuo studio',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF34495E),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF1ABC9C),
          surface: const Color(0xFFF7F9FB),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Color(0xFF34495E)),
          titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF34495E)),
          bodyMedium: TextStyle(fontSize: 18.0, color: Color(0xFF34495E)),
        ),
      ),
      home: const StudyTimerPage(),
    );
  }
}

class StudySession {
  final String formattedTime;
  final String topic;
  final DateTime date;

  StudySession(this.formattedTime, this.topic, this.date);

  Map<String, dynamic> toJson() => {
        'formattedTime': formattedTime,
        'topic': topic,
        'date': date.toIso8601String(),
      };

  static StudySession fromJson(Map<String, dynamic> json) {
    return StudySession(
      json['formattedTime'],
      json['topic'],
      DateTime.parse(json['date']),
    );
  }

  Duration get duration => Duration(
        hours: int.parse(formattedTime.split(":")[0]),
        minutes: int.parse(formattedTime.split(":")[1]),
        seconds: int.parse(formattedTime.split(":")[2]),
      );
}

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({super.key});

  @override
  _StudyTimerPageState createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _formattedTime = "00:00:00";
  List<StudySession> _studySessions = [];
  final List<String> _topics = ['Math', 'Science', 'History'];
  String? _selectedTopic;
  DateTime? _startDate;
  DateTime? _endDate;
  Duration _totalStudyTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTime);
    _loadStudySessions();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadStudySessions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? sessions = prefs.getStringList('studySessions');
    if (sessions != null) {
      setState(() {
        _studySessions = sessions.map((e) => StudySession.fromJson(jsonDecode(e))).toList();
      });
      _calculateTotalStudyTime();
    }
  }

  Future<void> _saveStudySession(StudySession session) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _studySessions.add(session);
    List<String> sessions = _studySessions.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('studySessions', sessions);
    _calculateTotalStudyTime();
  }

  Future<void> _deleteStudySession(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> sessions = _studySessions.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('studySessions', sessions);
    _calculateTotalStudyTime();
  }

  void _calculateTotalStudyTime({String? filterTopic, DateTime? startDate, DateTime? endDate}) {
    setState(() {
      _totalStudyTime = _studySessions
          .where((session) {
            final matchTopic = filterTopic == null || session.topic == filterTopic;
            final matchDate = (startDate == null || session.date.isAfter(startDate)) &&
                (endDate == null || session.date.isBefore(endDate));
            return matchTopic && matchDate;
          })
          .fold(Duration.zero, (total, session) => total + session.duration);
    });
  }

  void _updateTime(Timer timer) {
    if (_stopwatch.isRunning) {
      setState(() {
        _formattedTime = _formatDuration(_stopwatch.elapsed);
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _startTimer() {
    setState(() {
      _stopwatch.start();
    });
  }

  void _stopTimer() {
    setState(() {
      if (_selectedTopic != null) {
        _stopwatch.stop();
        StudySession session =
            StudySession(_formattedTime, _selectedTopic!, DateTime.now());
        _saveStudySession(session);
        _resetTimer();
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _stopwatch.reset();
      _formattedTime = "00:00:00";
    });
  }

  Future<void> _addNewTopic() async {
    String? newTopic = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String tempTopic = '';
        return AlertDialog(
          title: const Text('Aggiungi un nuovo argomento'),
          content: TextField(
            onChanged: (value) {
              tempTopic = value;
            },
            decoration: const InputDecoration(hintText: "Inserisci argomento"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(tempTopic);
              },
              child: const Text('Aggiungi'),
            ),
          ],
        );
      },
    );

    if (newTopic != null && newTopic.isNotEmpty) {
      setState(() {
        _topics.add(newTopic);
      });
    }
  }

  Future<void> _removeTopic() async {
    String? topicToRemove = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rimuovi Argomento'),
          content: DropdownButton<String>(
            hint: const Text('Seleziona argomento da rimuovere'),
            value: _selectedTopic,
            items: _topics.map((String topic) {
              return DropdownMenuItem<String>(
                value: topic,
                child: Text(topic),
              );
            }).toList(),
            onChanged: (String? newValue) {
              Navigator.of(context).pop(newValue);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annulla'),
            ),
          ],
        );
      },
    );

    if (topicToRemove != null) {
      setState(() {
        _topics.remove(topicToRemove);
        if (_selectedTopic == topicToRemove) {
          _selectedTopic = null;
        }
      });
    }
  }

  void _filterByTopic(String? topic) {
    _calculateTotalStudyTime(filterTopic: topic, startDate: _startDate, endDate: _endDate);
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _calculateTotalStudyTime(filterTopic: _selectedTopic, startDate: _startDate, endDate: _endDate);
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      _calculateTotalStudyTime(filterTopic: _selectedTopic, startDate: _startDate, endDate: _endDate);
    }
  }

  // Funzione per mostrare il pop-up con informazioni
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Info'),
          content: const Text('Developed by Giovanni Ferretti'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronometra il tuo studio'),
        elevation: 0,
        backgroundColor: const Color(0xFF34495E),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _formattedTime,
              style: const TextStyle(
                fontSize: 60.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF34495E),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              hint: const Text('Seleziona argomento'),
              value: _selectedTopic,
              items: _topics.map((String topic) {
                return DropdownMenuItem<String>(
                  value: topic,
                  child: Text(topic),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTopic = newValue;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _stopwatch.isRunning ? null : _startTimer,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    backgroundColor: const Color(0xFF34495E),
                    textStyle: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  child: const Text('Start'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _stopwatch.isRunning ? _stopTimer : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    backgroundColor: const Color(0xFF34495E),
                    textStyle: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _addNewTopic,
                  child: const Text('Aggiungi Argomento'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _removeTopic,
                  child: const Text('Rimuovi Argomento'),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _selectStartDate,
                  child: const Text('Seleziona Data Inizio'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _selectEndDate,
                  child: const Text('Seleziona Data Fine'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            Text(
              'Totale ore di studio: ${_formatDuration(_totalStudyTime)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF34495E)),
            ),
            const Divider(),
            const Text(
              'Sessioni di studio passate',
              style: TextStyle(fontSize: 24, color: Color(0xFF34495E)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _studySessions.length,
                itemBuilder: (context, index) {
                  StudySession session = _studySessions[index];
                  return Dismissible(
                    key: UniqueKey(),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) async {
                      StudySession removedSession = _studySessions[index];
                      setState(() {
                        _studySessions.removeAt(index);
                      });
                      await _deleteStudySession(index);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sessione di studio eliminata: ${removedSession.topic}'),
                        ),
                      );
                    },
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: ListTile(
                      title: Text(
                        '${session.topic}: ${session.formattedTime} (${session.date.toLocal()})',
                        style: const TextStyle(color: Color(0xFF34495E), fontSize: 18),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            DropdownButton<String>(
              hint: const Text('Filtra per argomento'),
              value: _selectedTopic,
              items: _topics.map((String topic) {
                return DropdownMenuItem<String>(
                  value: topic,
                  child: Text(topic),
                );
              }).toList(),
              onChanged: (String? newValue) {
                _filterByTopic(newValue);
              },
            ),
          ],
        ),
      ),
    );
  }
}
