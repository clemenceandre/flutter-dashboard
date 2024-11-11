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
  int _selectedYear = DateTime.now().year;
  String _selectedMonth = '';
  final List<String> months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août',
    'Septembre', 'Octobre', 'Novembre', 'Décembre'
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
    _selectedYear = DateTime.now().year;
    _selectedMonth = months[DateTime.now().month];
    _getFlightInspiration();
  }

  void _getFlightInspiration() async {
    String departureDate =
        '${_getStartDate(_selectedMonth, _selectedYear).toIso8601String().split('T')[0]},${_getEndDate(_selectedMonth, _selectedYear).toIso8601String().split('T')[0]}';

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

  void _showDestinationDetails(BuildContext context, Map<String, dynamic> destination) {
    _selectedDestination = destination;
    // Appel API pour obtenir les informations du vol
    _showPriceGraph(destination['flightOffersLink']).then((cheapestFlight) {
      setState(() {
        _cheapestFlightDetails = cheapestFlight;
      });
    });
  }

  Future<Map<String, dynamic>?> _showPriceGraph(String flightOffersLink) async {
    try {
      final token = await _amadeusApi.getAccessToken();
      final response = await http.get(
        Uri.parse(flightOffersLink),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final cheapestOffer = data['data']
            .where((offer) => offer['price'] != null)
            .reduce((a, b) {
          final aPrice = double.tryParse(a['price']['total'] ?? '0') ?? double.infinity;
          final bPrice = double.tryParse(b['price']['total'] ?? '0') ?? double.infinity;
          return aPrice < bPrice ? a : b;
        });

        return cheapestOffer;
      }
    } catch (e) {
      print('Erreur : $e');
    }
    return null;
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
        // Affichage de la carte ou du chargement
        _isLoading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(child: MapPage(
            destinations: _destinations,
            showDestinationDetails: _showDestinationDetails
        )),
      ],
    );
  }
}

class MapPage extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;
  final Function(BuildContext, Map<String, dynamic>) showDestinationDetails;

  const MapPage({super.key, required this.destinations, required this.showDestinationDetails});

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
              point: LatLng(latitude, longitude),
              builder: (ctx) => GestureDetector(
                onTap: () {
                  showDestinationDetails(context, destination);
                },
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue, // Couleur des icônes restaurée
                  size: 30,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
