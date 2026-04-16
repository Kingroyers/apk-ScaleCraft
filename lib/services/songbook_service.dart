import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class SongbookService {
  // Cambia esta URL por la de tu instancia de n8n
  static const String _baseUrl = 'https://elvergalindo.app.n8n.cloud/webhook-test/song-event';

  final http.Client _client;

  SongbookService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // GET /songs — obtener todas las canciones
  Future<List<Song>> getSongs() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/songs'),
      headers: _headers,
    );
    _checkStatus(response);
    final List<dynamic> data = jsonDecode(response.body) as List;
    return data.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  // GET /songs/:id — obtener una canción
  Future<Song> getSong(String id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/songs/$id'),
      headers: _headers,
    );
    _checkStatus(response);
    return Song.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // POST /songs — crear canción
  Future<Song> createSong(Song song) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/songs'),
      headers: _headers,
      body: jsonEncode(song.toJson()),
    );
    _checkStatus(response);
    return Song.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // PATCH /songs/:id — actualizar canción
  Future<Song> updateSong(Song song) async {
    assert(song.id != null, 'Song must have an id to update');
    final response = await _client.patch(
      Uri.parse('$_baseUrl/songs/${song.id}'),
      headers: _headers,
      body: jsonEncode(song.toJson()),
    );
    _checkStatus(response);
    return Song.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // DELETE /songs/:id
  Future<void> deleteSong(String id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/songs/$id'),
      headers: _headers,
    );
    _checkStatus(response);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SongbookException(
        'Error ${response.statusCode}: ${response.body}',
        response.statusCode,
      );
    }
  }
}

class SongbookException implements Exception {
  final String message;
  final int statusCode;
  const SongbookException(this.message, this.statusCode);

  @override
  String toString() => 'SongbookException($statusCode): $message';
}