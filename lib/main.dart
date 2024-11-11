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

  DateTime? _selectedDate; // Remplace _selectedYear et _selectedMonth

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now(); // Date par défaut (aujourd'hui)
    _getFlightInspiration(); // Appel de l'API avec la date sélectionnée
  }

  // Méthode pour ouvrir un sélecteur de date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime currentDate = DateTime.now();
    final DateTime maxDate = DateTime(
      currentDate.year,
      currentDate.month + 6,
      currentDate.day,
    ); // Limite de sélection jusqu'à 6 mois après aujourd'hui

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? currentDate,
      firstDate: currentDate, // Restriction pour les dates antérieures à aujourd'hui
      lastDate: maxDate, // Restriction jusqu'à 6 mois dans le futur
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _isLoading = true;
      });
      _getFlightInspiration(); // Mise à jour des inspirations de vol
    }
  }

  // Méthode pour obtenir les inspirations de vol (mise à jour pour utiliser _selectedDate)
  void _getFlightInspiration() async {
    final year = _selectedDate?.year;
    final month = _selectedDate?.month ?? 1;
    String departureDate =
        '${DateTime(year!, month, 1).toIso8601String().split('T')[0]},${DateTime(year, month + 1, 0).toIso8601String().split('T')[0]}';

    try {
      _destinations = await _amadeusApi.getFlightInspiration('MAD', departureDate);
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
                            destination['destination'] ?? 'Destination inconnue',
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
                                  ],
                                ),
                              ),
                            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspiration de Vols'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _selectDate(context), // Ouvre le calendrier
              child: Text(
                _selectedDate != null
                    ? 'Date sélectionnée : ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : 'Sélectionner une date',
              ),
            ),
          ),
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
            child: MapPage(
              destinations: _destinations,
              showDestinationDetails: _showDestinationDetails,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget MapPage pour afficher la carte
class MapPage extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;
  final Function(BuildContext, Map<String, dynamic>) showDestinationDetails;

  const MapPage({
    Key? key,
    required this.destinations,
    required this.showDestinationDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        center: LatLng(40.4168, -3.7038), // Centre sur Madrid par défaut
        zoom: 3,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: ['a', 'b', 'c'],
        ),
        MarkerLayer(
          markers: destinations.map((destination) {
            final lat = destination['latitude'] as double?;
            final lon = destination['longitude'] as double?;
            if (lat == null || lon == null) return null;

            return Marker(
              point: LatLng(lat, lon),
              builder: (ctx) => GestureDetector(
                onTap: () => showDestinationDetails(context, destination),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            );
          }).whereType<Marker>().toList(),
        ),
      ],
    );
  }
}
