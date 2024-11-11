import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amadeus Flight Inspiration',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FlightInspirationScreen(),
      debugShowCheckedModeBanner: false, // Désactive le bandeau "debug"
    );
  }
}

class FlightInspirationScreen extends StatefulWidget {
  const FlightInspirationScreen({super.key});

  @override
  _FlightInspirationScreenState createState() =>
      _FlightInspirationScreenState();
}

class _FlightInspirationScreenState extends State<FlightInspirationScreen> {
  final AmadeusApi _amadeusApi = AmadeusApi();
  List<Map<String, dynamic>> _destinations = [];
  bool _isLoading = true;
  Map<String, dynamic>? _cheapestFlightDetails;

  // Variables pour l'année et le mois sélectionnés
  int _selectedYear = DateTime.now().year;
  String _selectedMonth = '';
  final List<String> months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre'
  ];

  DateTime _getStartDate(String month, int year) {
    int monthIndex = months.indexOf(month) + 1;
    return DateTime(year, monthIndex, 1);
  }

  DateTime _getEndDate(String month, int year) {
    int monthIndex = months.indexOf(month) + 1;
    return DateTime(year, monthIndex + 1, 0); // Dernier jour du mois
  }

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year; // Année actuelle
    _selectedMonth = months[DateTime.now().month]; // Mois prochain
    _getFlightInspiration(); // Appelle la méthode lors de l'initialisation
    _getOtherDates();
  }

  // Méthode pour obtenir les inspirations de vol
  void _getFlightInspiration() async {
    String departureDate =
        '${_getStartDate(_selectedMonth, _selectedYear).toIso8601String().split('T')[0]},${_getEndDate(_selectedMonth, _selectedYear).toIso8601String().split('T')[0]}';

    try {
      _destinations =
          await _amadeusApi.getFlightInspiration('MAD', departureDate);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors de la récupération des destinations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Méthode pour obtenir d'autres dates
  Future<List<Map<String, dynamic>>> _getOtherDates() async {
    try {
      final datesList = await _amadeusApi.getOtherDates('MAD');
      setState(() {
        _isLoading = false;
      });
      return datesList; // Retourner la liste des dates
    } catch (e) {
      print('Erreur lors de la récupération des destinations: $e');
      setState(() {
        _isLoading = false;
      });
      return []; // Retourner une liste vide en cas d'erreur
    }
  }

  // Méthode pour afficher les prix selon les dates
  Future<Map<String, dynamic>?> _showPriceGraph(String flightOffersLink) async {
    try {
      final token = await _amadeusApi.getAccessToken();

      print('Appel API avec l\'URL: $flightOffersLink');
      print('Token utilisé: $token');

      final response = await http.get(
        Uri.parse(flightOffersLink),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('$data');

        // Trouver le vol le moins cher
        final cheapestOffer = data['data']
            .where((offer) => offer['price'] != null)
            .reduce((a, b) {
          final aPrice =
              double.tryParse(a['price']['total'] ?? '0') ?? double.infinity;
          final bPrice =
              double.tryParse(b['price']['total'] ?? '0') ?? double.infinity;
          return aPrice < bPrice ? a : b;
        });

        return cheapestOffer;
      } else {
        print(
            'Erreur lors de la récupération des données pour les prix: ${response.statusCode}');
        print('Message d\'erreur : ${response.body}');
      }
    } catch (e) {
      print('Erreur : $e');
    }
    return null; // Retourne null si une erreur se produit
  }

  void _showDestinationDetails(
      BuildContext context, Map<String, dynamic> destination) {
    _showPriceGraph(destination['flightOffersLink']).then((cheapestFlight) {
      setState(() {
        _cheapestFlightDetails =
            cheapestFlight; // Stocke les détails du vol le moins cher
      });

      // Appeler la méthode pour obtenir les autres dates
      _getOtherDates().then((datesList) {
        final matchedDate = datesList.firstWhere(
          (date) => date['destination'] == destination['destination'],
          orElse: () => {
            'destination': destination['destination'],
            'prix': 'N/A',
            'allerDate': 'N/A',
            'retourDate': 'N/A'
          },
        );

        // Assurez-vous que 'prix' est une valeur double, sinon assigner une valeur par défaut
        double price = matchedDate['prix'] != 'N/A'
            ? double.tryParse(matchedDate['prix'].toString()) ??
                0.0 // Si la conversion échoue, utilisez 0.0
            : 0.0;

        double minPrice = 50.0; // Prix minimum pour l'échelle (par exemple, 50)
        double maxPrice =
            1000.0; // Prix maximum pour l'échelle (par exemple, 1000)

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                children: [
                  Positioned(
                    top: 50, // Décale la fenêtre par rapport au haut de l'écran
                    right: 0, // Positionne le popup à droite
                    child: Container(
                      width: 300, // Largeur du popup
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          bottomLeft: Radius.circular(15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(5, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            destination['destination'] ??
                                'Destination inconnue',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('Ville: ${destination['city'] ?? 'Inconnue'}'),
                          Text('Pays: ${destination['country'] ?? 'Inconnu'}'),
                          if (_cheapestFlightDetails != null) ...[
                            const SizedBox(height: 20),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text('Vol le moins cher',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        'Prix: ${_cheapestFlightDetails!['price']['total']} ${_cheapestFlightDetails!['price']['currency']}'),
                                    Text(
                                        'Durée: ${_cheapestFlightDetails!['itineraries'][0]['duration']}'),
                                    Text(
                                        'Départ: ${_cheapestFlightDetails!['itineraries'][0]['segments'][0]['departure']['iataCode']} à ${_cheapestFlightDetails!['itineraries'][0]['segments'][0]['departure']['at']}'),
                                    Text(
                                        'Arrivée: ${_cheapestFlightDetails!['itineraries'][0]['segments'][0]['arrival']['iataCode']} à ${_cheapestFlightDetails!['itineraries'][0]['segments'][0]['arrival']['at']}'),
                                    Text(
                                        'Compagnie: ${_cheapestFlightDetails!['validatingAirlineCodes'][0]}'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Afficher les détails des autres dates si une correspondance est trouvée
                          if (matchedDate['prix'] != 'N/A') ...[
                            const SizedBox(height: 20),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text(
                                        'Le prix le moins cher pour cette destination',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text('Prix: ${matchedDate['prix']}'),
                                    Text(
                                        'Date Aller: ${matchedDate['allerDate']}'),
                                    Text(
                                        'Date Retour: ${matchedDate['retourDate']}'),
                                    const SizedBox(height: 20),
                                    // Afficher un Slider de couleur en fonction du prix
                                    Slider(
                                      value: price,
                                      min: minPrice,
                                      max: maxPrice,
                                      onChanged: (value) {},
                                      activeColor: _getPriceColor(
                                          price, minPrice, maxPrice),
                                      inactiveColor: Colors.grey,
                                    ),
                                    Text(
                                        'Position du prix: ${price.toString()}'),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            // Afficher un message si aucun prix n'est trouvé
                            const SizedBox(height: 20),
                            const Text(
                                'Pas de meilleur prix disponible pour cette destination.',
                                style: TextStyle(fontSize: 16)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      });
    });
  }

  Color _getPriceColor(double price, double minPrice, double maxPrice) {
    if (price <= minPrice) {
      return Colors.green; // Prix faible (vert)
    } else if (price >= maxPrice) {
      return Colors.red; // Prix élevé (rouge)
    } else {
      return Colors.yellow; // Prix moyen (jaune)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspiration de Vols'),
      ),
      body: Column(
        children: [
          // Liste déroulante pour l'année
          DropdownButton<int>(
            value: _selectedYear,
            items: List.generate(
              2,
              (index) => DropdownMenuItem(
                value: DateTime.now().year + index,
                child: Text('${DateTime.now().year + index}'),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _selectedYear = value!;
              });
            },
          ),
          // Boutons pour les mois
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: months.map((month) {
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedMonth = month;
                    _isLoading = true;
                  });
                  _getFlightInspiration(); // Lancer la requête API
                },
                child: Text(month),
              );
            }).toList(),
          ),
          // Affichage de la carte ou du chargement
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: MapPage(
                      destinations: _destinations,
                      showDestinationDetails: _showDestinationDetails)),
        ],
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;
  final Function(BuildContext, Map<String, dynamic>)
      showDestinationDetails; // Change ici

  const MapPage({super.key, required this.destinations, required this.showDestinationDetails});

  Color _getColorForPrice(Map<String, dynamic> destination,
      List<Map<String, dynamic>> destinations) {
    double minPrice = double.infinity;
    double maxPrice = 0.0;

    // Trouver les prix minimum et maximum
    for (var destination in destinations) {
      double prix = double.tryParse(destination['prix'] ?? '0') ?? 0.0;
      if (prix > 0) {
        if (prix < minPrice) minPrice = prix;
        if (prix > maxPrice) maxPrice = prix;
      }
    }
    double currentPrice = double.tryParse(destination['prix'] ?? '0') ?? 0.0;

    // Si le prix est le minimum, retourner vert
    if (currentPrice == minPrice) {
      return Colors.green; // Le moins cher en vert
    }
    // Si le prix est le maximum, retourner rouge
    else if (currentPrice == maxPrice) {
      return Colors.red; // Le plus cher en rouge
    }
    // Pour les autres prix, interpoler la couleur entre vert et rouge
    else {
      double normalizedPrice =
          (currentPrice - minPrice) / (maxPrice - minPrice);
      return Color.lerp(Colors.green, Colors.red, normalizedPrice) ??
          Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        center: LatLng(20.0, 0.0),
        zoom: 2.0,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
        ),
        MarkerLayer(
          markers: destinations.map((destination) {
            final latitude = destination['latitude'];
            final longitude = destination['longitude'];

            return Marker(
              width: 30.0, // Taille de l'ombre
              height: 30.0, // Taille de l'ombre
              point: LatLng(latitude, longitude),
              builder: (ctx) => Container(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {
                    showDestinationDetails(
                        context, destination); // Afficher les détails sur clic
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ombre
                      CircleAvatar(
                        radius: 15, // Rayon de l'ombre
                        backgroundColor:
                            Colors.grey.withOpacity(0.5), // Couleur de l'ombre
                      ),
                      // Pin
                      Icon(
                        Icons.location_on,
                        color: _getColorForPrice(destination, destinations),
                        size: 25, // Taille de l'icône
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
