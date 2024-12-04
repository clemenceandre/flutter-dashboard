//Fichier regroupant les fonctions API de l'application

//Import des packages nécessaires
import 'dart:convert';
import 'package:http/http.dart' as http;

class AmadeusApi {
  //Clés API Amadeus + URL pour token et accès API
  static const String apiKey = '2y0TgiYeI9Sbto6EkBROIwxildynlqRr';
  static const String apiSecret = 'VVwKLDKpumpvHAWD';
  static const String tokenUrl = 'https://test.api.amadeus.com/v1/security/oauth2/token';
  static const String flightInspirationUrl = 'https://test.api.amadeus.com/v1/shopping/flight-destinations';

  //URL de l'API OpenCage pour le géocodage
  static const String geocodingUrl = 'https://api.opencagedata.com/geocode/v1/json';
  static const String geocodingApiKey = '7f2d9f201fe44f04ad7bf8fb199aed58'; // Remplace avec ta clé OpenCage

  //URL du proxy CORS Anywhere
  static const String corsProxyUrl = 'https://cors-anywhere.herokuapp.com/';

  //Obtenir un token d'accès
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
      return data['access_token'];
    } else {
      throw Exception('Erreur d\'authentification: ${response.body}');
    }
  }

  //Appeler l'API Amadeus pour obtenir les destinations de vol selon des dates
  Future<List<Map<String, dynamic>>> getFlightInspiration(String origin, String departureDate) async {
    final token = await getAccessToken();
    final response = await http.get(
      Uri.parse('$corsProxyUrl$flightInspirationUrl').replace(queryParameters: {
        'origin': origin,
        'departureDate': departureDate,
        'duration' : '2,15',
        'nonStop': 'true',
      }),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dataFlightinspirationDeparturedate = json.decode(response.body);

      // Extraire les infos de l'api et calcul des coordonnées des destinations
      List<Map<String, dynamic>> destinations = [];
      for (var item in dataFlightinspirationDeparturedate['data']) {
        final destinationName = item['destination'];
        //Récupère les coordonnées
        final coords = await getCoordinates(destinationName);
        if (coords['lat'] != null && coords['lng'] != null) {
          final cityAndCountry = await getCityAndCountry(coords['lat']!, coords['lng']!); // Récupère la ville et le pays

          destinations.add({
            'destination': destinationName,
            'latitude': coords['lat'],
            'longitude': coords['lng'],
            'city': cityAndCountry['city'],
            'country': cityAndCountry['country'],
            'flightOffersLink': item['links']['flightOffers'],
            'prix' : item['price']['total'],
            'departureDate' : item['departureDate'],
            'returnDate' : item['returnDate']
          });
        } else {
          print('Les coordonnées pour $destinationName sont nulles');
        }
      }
      return destinations; //Retourne la liste
    } else {
      print('Erreur: ${response.statusCode}, Message: ${response.body}');
      throw Exception('Erreur lors de la récupération des destinations');
    }
  }

  //Appeler l'API Amadeus pour obtenir les destinations de vol sans dates
  Future<List<Map<String, dynamic>>> getOtherDates(String origin) async {
    final token = await getAccessToken();
    final response = await http.get(
      Uri.parse('$corsProxyUrl$flightInspirationUrl').replace(queryParameters: {
        'origin': origin,
        'nonStop': 'true',
      }),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dataGetotherdates = json.decode(response.body);
      //Extraire les infos
      List<Map<String, dynamic>> dateslist = [];
      for (var item in dataGetotherdates['data']) {
        final destinationName = item['destination'];

          dateslist.add({
            'destination': destinationName,
            'prix': item['price']['total'],
            'allerDate': item['departureDate'],
            'retourDate': item['returnDate'],
          });
        }
      return dateslist; //Retourne la liste
    } else {
      print('Erreur: ${response.statusCode}, Message: ${response.body}');
      throw Exception('Erreur lors de la récupération des destinations');
    }
  }

  //Retourne le prix le moins chère pour les dates déterminés par getFlightInspiration
  Future<Map<String, dynamic>?> showPriceGraph(String flightOffersLink) async {
      final token = await getAccessToken();
      final response = await http.get(
        Uri.parse(flightOffersLink),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final dataShowpricegraph = json.decode(response.body);
        final cheapestOffer = dataShowpricegraph['data'].where((offer) =>
        offer['price'] != null).reduce((a, b) {
          final aPrice = double.tryParse(a['price']['total'] ?? '0') ??
              double.infinity;
          final bPrice = double.tryParse(b['price']['total'] ?? '0') ??
              double.infinity;
          return aPrice < bPrice ? a : b;
        });
        return cheapestOffer;
      } else {
        print('Erreur: ${response.statusCode}, Message: ${response.body}');
        throw Exception('Erreur lors de la récupération des destinations');
      }
    }

  //Retourne l'ensemble des informations obtenues
  Future<Map<String, dynamic>> fetchDestinationDetails(Map<String, dynamic> destination) async {
    //Charger les détails de la destination
    final cheapestFlight = await showPriceGraph(
        destination['flightOffersLink']);
    final otherDates = await getOtherDates('MAD');

    if (otherDates != null) {
      final matchedDate = otherDates.firstWhere(
            (date) => date['destination'] == destination['destination'],
        orElse: () =>
        {
          'destination': destination['destination'],
          'prix': 'N/A',
          'allerDate': 'N/A',
          'retourDate': 'N/A',
        },
      );

      return {
        'destination': destination,
        'cheapestFlight': cheapestFlight,
        'matchedDate': matchedDate,
      };
  } else {
      throw Exception('Erreur lors de la récupération des détail de la destination');
    }
  }


  //Récupérer les coordonnées à partir du IATA avec l'API OpenCage
  Future<Map<String, double>> getCoordinates(String cityName) async {
    final response = await http.get(
      Uri.parse('$geocodingUrl?q=$cityName&key=$geocodingApiKey'),
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
      throw Exception('Erreur lors de la récupération des coordonnées: ${response.statusCode}');
    }
  }

  //Récupérer le nom de la ville et du pays à partir des coordonnées de l'API OpenCage
  Future<Map<String, String>> getCityAndCountry(double latitude, double longitude) async {
    final response = await http.get(
      Uri.parse('$geocodingUrl?q=$latitude+$longitude&key=$geocodingApiKey'),
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
        throw Exception('Aucun résultat trouvé pour les coordonnées: $latitude, $longitude');
      }
    } else {
      throw Exception('Erreur lors du géocodage inverse: ${response.statusCode}');
    }
  }
}
