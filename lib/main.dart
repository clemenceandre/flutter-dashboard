//Le main comprend l'interface visuel de l'application et l'appel des fonctions
//construitent dans le fichier api.dart

//Import des packages nécessaires chargé dans pubspec.yaml
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'api.dart';
import 'dart:async';

//Initialisation et lancement de l'application Flutter
void main() {
  runApp(MyApp());
}

//Construction du widget racine MyApp avec
// FlightInspirationScreen comme page d'accueil
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amadeus Flight Inspiration',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: FlightInspirationScreen(),
    );
  }
}

//Création du widget d'état associé à la class
// _FlightInspirationScreenState
class FlightInspirationScreen extends StatefulWidget {
  @override
  _FlightInspirationScreenState createState() =>
      _FlightInspirationScreenState();
}

class _FlightInspirationScreenState extends State<FlightInspirationScreen> {
  //Initialisation des variables
  final AmadeusApi _amadeusApi = AmadeusApi();
  List<Map<String, dynamic>> _destinations = [];
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _destinationDetails = {};
  Map<String, Map<String, dynamic>> _destinationBasics = {};
  DateTime? _selectedDate;
  int _selectedYear = DateTime.now().year;
  String _selectedMonth = '';
  final List<String> months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  @override
  //Etat initial du widget au lancement de l'application
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _selectedMonth = months[DateTime.now().month - 1];
    _selectedDate = DateTime.now();
    _getFlightInspiration();
  }

  //Fonction déterminant la date de départ pour _getFlightInspiration
  DateTime _getStartDate(String month, int year) {
    int monthIndex = months.indexOf(month) + 1;
    DateTime firstDayOfMonth = DateTime(year, monthIndex, 1);
    DateTime today = DateTime.now();

    if (year == today.year && monthIndex == today.month) {
      return today;
    }
    return firstDayOfMonth;
  }

  // Widget d'affichage pour l'animation de chargement
  Widget _buildLoadingIndicator() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        return Center(
          child: Image.asset(
            'plane_loading.gif',
            width: width * 1.3,
          ),
        );
      },
    );
  }

  //Fonction pour construire la selection des mois
  // dans une limite des 6 mois suivant la date actuelle
  // afin de relancer un appel à _getFlightInspiration
  Future<void> _selectDate(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height,
        buttonPosition.dx + button.size.width,
        buttonPosition.dy + button.size.height,
      ),
      constraints: BoxConstraints(
        minWidth: button.size.width,
        maxWidth: button.size.width,
      ),
      color : Color.fromARGB(255,241,249,255),
      elevation : 5,
      items: List.generate(6, (index) {
        DateTime currentDate = DateTime.now();
        DateTime targetDate =
        DateTime(currentDate.year, currentDate.month + index, 1);
        return PopupMenuItem(
          value: targetDate,
          child: Text(
            '${months[targetDate.month - 1]} ${targetDate.year}',
            style: TextStyle(fontSize: 14),
          ),
        );
      }),
    ).then((selectedDate) {
      if (selectedDate != null) {
        setState(() {
          _selectedDate = selectedDate;
          _selectedMonth = months[selectedDate.month - 1];
          _selectedYear = selectedDate.year;
          _isLoading = true;
        });
        _getFlightInspiration();
      }
    });
  }

  //Méthode pour récupérer les 5 destinations les moins chères
  // à partir des résultats obtenu par _getFlightInspiration
  List<Map<String, dynamic>> _getCheapestDestinations() {
    if (_destinations.isEmpty) return [];
    List<Map<String, dynamic>> sortedDestinations = List.from(_destinations);
    sortedDestinations.sort((a, b) {
      double priceA =
          double.tryParse(a['prix']?.toString() ?? '0') ?? double.infinity;
      double priceB =
          double.tryParse(b['prix']?.toString() ?? '0') ?? double.infinity;
      return priceA.compareTo(priceB);
    });
    return sortedDestinations.take(5).toList();
  }

  //Méthode principale de l'application récupérant des
  // destinations inspirantes pour des voyages au départ de Madrid
  void _getFlightInspiration() async {
    String departureDate =
        '${_getStartDate(_selectedMonth, _selectedYear).toIso8601String().split('T')[0]}';
    try {
      // Appel API avec la fonction getFlightInspiration définie dans api.dart
      _destinations =
      await _amadeusApi.getFlightInspiration('MAD', departureDate);
      setState(() {
        _isLoading = false;
      });
      //Utilisation du système de microtask Flutter pour
      // charger les détails des destinations en arrière-plan
      Future.delayed(Duration.zero, () async {
        await _loadAllDestinationDetails();
      });
    } catch (e) {
      // Gestion des erreurs dans la console
      print('Erreur lors de la récupération des destinations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  //Méthode de récupération des détails pour une destination
  Future<Map<String, dynamic>> _fetchDestinationDetails(
      Map<String, dynamic> destination) async {
    try {
      //Appel de la fonction fetchDestinationDetails définie dans api.dart
      final details = await _amadeusApi.fetchDestinationDetails(destination);
      return details;
    } catch (e) {
      //Gestion des erreurs dans la console
      print('Erreur dans _fetchDestinationDetails: $e');
      throw Exception(
          'Erreur lors du chargement des détails de la destination');
    }
  }

  //Méthode pour le chargement des détails par destinations
  Future<void> _loadAllDestinationDetails() async {
    for (var destination in _destinations) {
      _destinationBasics[destination['destination']] = destination;
      final details = await _fetchDestinationDetails(destination);
      //Stockage des infos dans un cache
      _destinationDetails[destination['destination']] = details;
    }
  }

  //Fonction définissant la mise en page pour l'affichage des détails
  void _displayDestinationDetails(BuildContext context, String destinationKey) {
    final details = _destinationDetails[destinationKey];
    final basics = _destinationBasics[destinationKey];
    if (details == null) {
      print('Détails non disponibles pour $destinationKey');
      return;
    }
    final destination = details['destination'];
    final cheapestFlight = details['cheapestFlight'];
    final matchedDate = details['matchedDate'];

    //Définition d'une échelle de prix pour le slider
    double price = matchedDate['prix'] != 'N/A'
        ? double.tryParse(matchedDate['prix'].toString()) ?? 0.0
        : 0.0;
    double minPrice = 50.0;
    double maxPrice = 1000.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.33,
            heightFactor: 1.0,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //En-tête
                    Center(
                      child: Column(
                        children: [
                          Text(
                            destination['destination'] ??
                                'Destination inconnue',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ville: ${destination['city'] ?? 'Inconnue'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Pays: ${destination['country'] ?? 'Inconnu'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    //Informations sur le vol proposé
                    Card(
                      margin: EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                'Informations sur le vol proposé',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Prix: ${basics!['prix']} €',
                            ),
                            Text(
                              'Départ: ${basics!['departureDate']}',
                            ),
                            Text(
                              'Retour: ${basics!['returnDate']}',
                            ),
                          ],
                        ),
                      ),
                    ),

                    //Vol le moins cher pour le mois sélectionné
                    if (cheapestFlight != null)
                      Card(
                        margin: EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Vol le moins cher pour le mois sélectionné',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Prix: ${cheapestFlight['price']['total']} €',
                              ),
                              Text(
                                'Aller le : ${DateTime.parse(cheapestFlight['itineraries'][0]['segments'][0]['departure']['at']).toLocal().toString().split(' ')[0]} à : ${DateTime.parse(cheapestFlight['itineraries'][0]['segments'][0]['departure']['at']).toLocal().toString().split(' ')[1].substring(0, 5)} selon l\'heure locale',
                              ),
                              Text(
                                'Retour le : ${DateTime.parse(cheapestFlight['itineraries'][1]['segments'][0]['departure']['at']).toLocal().toString().split(' ')[0]} à : ${DateTime.parse(cheapestFlight['itineraries'][1]['segments'][0]['departure']['at']).toLocal().toString().split(' ')[1].substring(0, 5)} selon l\'heure locale',
                              ),
                              Text(
                                'Déservi par la compagnie: ${cheapestFlight['validatingAirlineCodes'][0]}',
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Le prix le moins cher pour cette destination pour les 6 prochains mois
                    if (matchedDate['prix'] != 'N/A')
                      Card(
                        margin: EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Le prix le moins cher pour \n'
                                      'les 6 prochains mois',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Prix: ${matchedDate['prix']} €',
                              ),
                              Text(
                                'Date Aller: ${matchedDate['allerDate']}',
                              ),
                              Text(
                                'Date Retour: ${matchedDate['retourDate']}',
                              ),
                              SizedBox(height: 20),

                              //Représentation du prix avec une barre
                              // graduée selon l'ensembles des prix proposés
                              Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green,
                                      Colors.yellow,
                                      Colors.red,
                                    ],
                                    stops: [0.0, 0.5, 1.0],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    FractionallySizedBox(
                                      widthFactor: (price - minPrice) /
                                          (maxPrice - minPrice) >
                                          0.1
                                          ? (price - minPrice) /
                                          (maxPrice - minPrice)
                                          : 0.1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _getPriceColor(
                                              price, minPrice, maxPrice),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),
                              Center(
                                child: Text(
                                  price <=
                                      (minPrice + (maxPrice - minPrice) / 3)
                                      ? 'Prix bas'
                                      : price >=
                                      (minPrice +
                                          2 * (maxPrice - minPrice) / 3)
                                      ? 'Prix élevé'
                                      : 'Prix moyen',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (matchedDate['prix'] == 'N/A')
                      Text(
                        'Pas de meilleur prix disponible pour cette destination.',
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  //Fonction pour déterminer la couleur selon le prix
  Color _getPriceColor(double price, double minPrice, double maxPrice) {
    if (price <= minPrice) return Colors.green;
    if (price >= maxPrice) return Colors.red;
    double normalizedPrice = (price - minPrice) / (maxPrice - minPrice);
    return Color.lerp(Colors.green, Colors.red, normalizedPrice) ??
        Colors.yellow;
  }

  //Mise en page du dashboard
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(90),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Color(0xFFF8FBFF),
          elevation: 2,
          flexibleSpace: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0),
            child: Stack(
              children: [
                //Logo
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'amadeus.png',
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                //Titre
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Dream. Book. Fly.',
                    style: TextStyle(
                      fontFamily:
                      'OpenSansCondensed',
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      color: Colors.black87,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Color(0xFFF8FBFF),
      body: Row(
        children: [
          //Bloc principal
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMainContent(),
            ),
          ),
          //Bloc de détail
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildCheapestDestinationsWidget(),
            ),
          ),
        ],
      ),
    );
  }

  //Mise en page de la selection du mois de voyage
  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => _selectDate(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255,241,249,255),
                foregroundColor: Colors.black87,
                elevation: 1,
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: Color(0xFF9BD5FF), width: 1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Color(0xFF9BD5FF),
                  ),
                  SizedBox(width: 10),
                  Text(
                    _selectedDate != null
                        ? 'Date : ${months[_selectedDate!.month - 1]} ${_selectedDate!.year}'
                        : 'Sélectionner un mois',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      fontFamily:
                      'OpenSansCondensed',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        //Affichage de la carte ou de l'animation de chargement
        _isLoading
            ? Expanded(child: Center(child: _buildLoadingIndicator()))
            : Expanded(
          child: MapPage(
            destinations: _destinations,
            showDestinationDetails: _displayDestinationDetails,
          ),
        ),
      ],
    );
  }

  //Mise en page des informations concernant le top 5 des
  // destinations les moins chères sur le mois choisi
  Widget _buildCheapestDestinationsWidget() {
    List<Map<String, dynamic>> cheapestDestinations =
    _getCheapestDestinations();
    //Chargement des données
    if (cheapestDestinations.isEmpty) {
      return Center(
        child: Text(
          'Chargement des destinations les moins chères...',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    //Affichage des informations
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Titre
            Center(
              child: Text(
                'Top 5 des destinations les moins chères',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20),

            //Liste des destinations
            for (var destination in cheapestDestinations)
              Container(
                margin: EdgeInsets.only(bottom: 10),
                width: double.infinity,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${destination['destination']} - ${destination['city']}, ${destination['country']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Prix: ${destination['prix']} €'),
                        Text(
                          'Dates: ${destination['departureDate']} - ${destination['returnDate']}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;
  final Function(BuildContext, String) showDestinationDetails;

  MapPage({required this.destinations, required this.showDestinationDetails});

  //Fonction pour la coloration des pins
  Color _getColorForPrice(Map<String, dynamic> destination,
      List<Map<String, dynamic>> destinations) {
    double minPrice = double.infinity;
    double maxPrice = 0.0;

    //Calcul des prix min et max en fonction des
    // résultats de getFilghtInspiration
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
  //Mise en page de la carte et des pins de destinations
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.center,
      widthFactor: 1,
      child: FlutterMap(
        options: MapOptions(
          center: LatLng(20.0, 0.0),
          zoom: 1.7,
          interactiveFlags: InteractiveFlag.none,
          maxZoom: 6.0,
          minZoom: 1.7,
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
                width: 30.0,
                height: 30.0,
                point: LatLng(latitude, longitude),
                builder: (ctx) => GestureDetector(
                  onTap: () {
                    //Affichage des détails au clic
                    showDestinationDetails(context, destination['destination']);
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
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
