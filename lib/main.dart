import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amadeus Flight Inspiration',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false, // Enlève le bandeau debug
      home: FlightInspirationScreen(),
    );
  }
}

class FlightInspirationScreen extends StatefulWidget {
  @override
  _FlightInspirationScreenState createState() =>
      _FlightInspirationScreenState();
}

class _FlightInspirationScreenState extends State<FlightInspirationScreen> {
  final AmadeusApi _amadeusApi = AmadeusApi();
  List<Map<String, dynamic>> _destinations = [];
  bool _isLoading = true;
  Map<String, dynamic>? _cheapestFlightDetails;
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
  Map<String, dynamic>? _selectedDestination;
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

  // Méthode pour afficher l'animation de chargement
  Widget _buildLoadingIndicator() {
    return Center(
      child: Image.asset(
        'assets/plane_loading.gif',
        width: 150, // Ajuste la taille selon tes besoins
        height: 150,
      ),
    );
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
      BuildContext context, Map<String, dynamic> destination) { _selectedDestination = destination;
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
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(5, 5),
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
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Ville: ${destination['city'] ?? 'Inconnue'}'),
                        Text('Pays: ${destination['country'] ?? 'Inconnu'}'),
                        if (_cheapestFlightDetails != null) ...[
                          SizedBox(height: 20),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text('Vol le moins cher',
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
                          SizedBox(height: 20),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                      'Le prix le moins cher pour cette destination',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Text('Prix: ${matchedDate['prix']}'),
                                  Text(
                                      'Date Aller: ${matchedDate['allerDate']}'),
                                  Text(
                                      'Date Retour: ${matchedDate['retourDate']}'),
                                  SizedBox(height: 20),
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
                          SizedBox(height: 20),
                          Text(
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
      appBar: AppBar(title: const Text('Inspiration de Vols')),
      body: Row(
        children: [
          // Bloc Main
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMainContent(),
            ),
          ),
          // Bloc Aside (placé à droite)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildAside(),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAside() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDestination == null) ...[
          const Text('Sélectionnez une destination ou lancez une recherche pour voir les détails.', style: TextStyle(fontSize: 18)),
        ] else if (_cheapestFlightDetails != null) ...[
          const Text('Meilleur Vol', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('Prix: ${_cheapestFlightDetails!['price']['total']} ${_cheapestFlightDetails!['price']['currency']}'),
          Text('Durée: ${_cheapestFlightDetails!['itineraries'][0]['duration']}'),
          Text('Compagnie: ${_cheapestFlightDetails!['validatingAirlineCodes'][0]}'),
        ] else ...[
          const Text('Aucune offre disponible pour cette destination.', style: TextStyle(fontSize: 16)),
        ]
      ],
    );
  }
  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown pour l'année
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
        // Sélection des mois
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
                _getFlightInspiration();
              },
              child: Text(month),
            );
          }).toList(),
        ),
        // Affichage de la carte ou de l'animation de chargement
        _isLoading
            ? Expanded(child: Center(child: _buildLoadingIndicator())) // Remplacement ici
            : Expanded(
          child: MapPage(
            destinations: _destinations,
            showDestinationDetails: _showDestinationDetails,
          ),
        ),
      ],
    );
  }
}


class MapPage extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;
  final Function(BuildContext, Map<String, dynamic>) showDestinationDetails;

  MapPage({required this.destinations, required this.showDestinationDetails});

  Color _getColorForPrice(Map<String, dynamic> destination,
      List<Map<String, dynamic>> destinations) {
    double minPrice = double.infinity;
    double maxPrice = 0.0;

    // Calcul des prix minimum et maximum
    for (var destination in destinations) {
      double prix = double.tryParse(destination['prix'] ?? '0') ?? 0.0;
      if (prix > 0) {
        if (prix < minPrice) minPrice = prix;
        if (prix > maxPrice) maxPrice = prix;
      }
    }

    double currentPrice = double.tryParse(destination['prix'] ?? '0') ?? 0.0;

    if (currentPrice == minPrice) {
      return Colors.green;
    } else if (currentPrice == maxPrice) {
      return Colors.red;
    } else {
      double normalizedPrice =
          (currentPrice - minPrice) / (maxPrice - minPrice);
      return Color.lerp(Colors.green, Colors.red, normalizedPrice) ??
          Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.center,
      widthFactor: 1, // Réduit la largeur de la carte de 10%

      child: FlutterMap(
        options: MapOptions(
          center: LatLng(20.0, 0.0), // Positionnement de la carte
          zoom: 2, // Niveau de zoom
          interactiveFlags: InteractiveFlag
              .none, // Désactive toutes les interactions (pas de pan, pas de zoom)
          maxZoom: 6.0, // Limite du zoom
          minZoom: 1.7, // Limite du zoom (pas de zoom in / zoom out)
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: destinations.map((destination) {
              final latitude = destination['latitude'];
              final longitude = destination['longitude'];

              return Marker(
                width: 30.0, // Taille de l'ombre
                height: 30.0, // Taille de l'ombre
                point: LatLng(latitude, longitude),
                builder: (ctx) => GestureDetector(
                  onTap: () {
                    showDestinationDetails(
                        context, destination); // Affichage des détails au clic
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.grey.withOpacity(0.5),
                      ),
                      Icon(
                        Icons.location_on,
                        color: _getColorForPrice(destination, destinations),
                        size: 25, // Taille de l'icône
                      ),
                    ],
                  ),
                ),
              );
            }).toList(), // Assurez-vous de créer une liste de type List<Marker>
          ),
        ],
      ),
    );
  }
}