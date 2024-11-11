import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class AmadeusApi {
  static const String apiKey =
      '2y0TgiYeI9Sbto6EkBROIwxildynlqRr'; // Remplace avec ta clé
  static const String apiSecret =
      'VVwKLDKpumpvHAWD'; // Remplace avec ton secret
  static const String tokenUrl =
      'https://test.api.amadeus.com/v1/security/oauth2/token';
  static const String flightInspirationUrl =
      'https://test.api.amadeus.com/v1/shopping/flight-destinations';

  // URL de l'API OpenCage pour la géocodage
  static const String geocodingUrl =
      'https://api.opencagedata.com/geocode/v1/json';
  static const String geocodingApiKey =
      'b9eed95672044446bf6f2e39a69bd9b5'; // Remplace avec ta clé OpenCage

  // URL du proxy CORS Anywhere
  static const String corsProxyUrl = 'https://cors-anywhere.herokuapp.com/';

  // Obtenir un token d'accès
  Future<String> getAccessToken() async {
    final response = await http.post(
      Uri.parse('$corsProxyUrl$tokenUrl'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
        'client_id': apiKey,
        'client_secret': apiSecret,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Token d\'accès: ${data['access_token']}');
      return data['access_token'];
    } else {
      throw Exception('Erreur d\'authentification: ${response.body}');
    }
  }

  // Appeler l'API pour obtenir les destinations de vol
  Future<List<Map<String, dynamic>>> getFlightInspiration(
      String origin, String departureDate) async {
    final token = await getAccessToken();

    final response = await http.get(
      Uri.parse('$corsProxyUrl$flightInspirationUrl').replace(queryParameters: {
        'origin': origin,
        'departureDate': departureDate,
        'nonStop': 'true', // Que les vols directs
      }),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print(
        'Appel API: ${response.request?.url}'); // Affiche l'URL de l'appel API

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Réponse API: $data');

      // Extraire les destinations
      List<Map<String, dynamic>> destinations = [];
      for (var item in data['data']) {
        final destinationName = item['destination'];
        final coords =
            await getCoordinates(destinationName); // Récupère les coordonnées
        if (coords['lat'] != null && coords['lng'] != null) {
          final cityAndCountry = await getCityAndCountry(
              coords['lat']!, coords['lng']!); // Récupère la ville et le pays

          destinations.add({
            'destination': destinationName,
            'latitude': coords['lat'],
            'longitude': coords['lng'],
            'city': cityAndCountry['city'],
            'country': cityAndCountry['country'],
            'flightOffersLink': item['links']['flightOffers'],
            'prix': item['price']['total'],
          });
        } else {
          print('Les coordonnées pour $destinationName sont nulles');
        }
      }
      return destinations; // Retourne la liste des destinations
    } else {
      print('Erreur: ${response.statusCode}, Message: ${response.body}');
      throw Exception('Erreur lors de la récupération des destinations');
    }
  }

  // Appeler l'API pour obtenir les destinations de vol sans dates spécifiques
  Future<List<Map<String, dynamic>>> getOtherDates(String origin) async {
    final token = await getAccessToken();

    final response = await http.get(
      Uri.parse('$corsProxyUrl$flightInspirationUrl').replace(queryParameters: {
        'origin': origin,
        'nonStop': 'true', // Que les vols directs
      }),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print(
        'Appel API: ${response.request?.url}'); // Affiche l'URL de l'appel API

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Réponse API: $data');

      // Extraire les destinations
      List<Map<String, dynamic>> dateslist = [];
      for (var item in data['data']) {
        final destinationName = item['destination'];

        dateslist.add({
          'destination': destinationName,
          'prix': item['price']['total'],
          'allerDate': item['departureDate'],
          'retourDate': item['returnDate'],
        });
      }
      return dateslist; // Retourne la liste des destinations
    } else {
      print('Erreur: ${response.statusCode}, Message: ${response.body}');
      throw Exception('Erreur lors de la récupération des destinations');
    }
  }

  // Récupérer les coordonnées à partir d'un nom de ville
  Future<Map<String, double>> getCoordinates(String cityName) async {
    final response = await http.get(
      Uri.parse('$corsProxyUrl$geocodingUrl?q=$cityName&key=$geocodingApiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'].isNotEmpty) {
        return {
          'lat': data['results'][0]['geometry']['lat'],
          'lng': data['results'][0]['geometry']['lng'],
        };
      } else {
        throw Exception('Aucune coordonnée trouvée pour la ville: $cityName');
      }
    } else {
      throw Exception(
          'Erreur lors de la récupération des coordonnées: ${response.statusCode}');
    }
  }

  // Récupérer le nom de la ville et du pays à partir des coordonnées
  Future<Map<String, String>> getCityAndCountry(
      double latitude, double longitude) async {
    final response = await http.get(
      Uri.parse(
          '$corsProxyUrl$geocodingUrl?q=$latitude+$longitude&key=$geocodingApiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'].isNotEmpty) {
        final components = data['results'][0]['components'];
        return {
          'city': components['city'] ?? 'Unknown',
          'country': components['country'] ?? 'Unknown',
        };
      } else {
        throw Exception(
            'Aucun résultat trouvé pour les coordonnées: $latitude, $longitude');
      }
    } else {
      throw Exception(
          'Erreur lors du géocodage inverse: ${response.statusCode}');
    }
  }

  // Sauvegarder les résultats dans un fichier (facultatif)
  Future<void> saveToFile(String data) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/flight_inspiration.json';
    final file = File(filePath);
    await file.writeAsString(data);
    print('Données sauvegardées dans: $filePath');
  }
}
