import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nominatim_geocoding/nominatim_geocoding.dart';

class HomeTab extends StatefulWidget {
  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.reference();
  GoogleMapController? _mapController;
  LatLng _location = LatLng(0, 0);
  BitmapDescriptor? _customIcon; // For bus marker
  BitmapDescriptor? _pickupIcon;
  MapType _currentMapType = MapType.hybrid;
  int _userCount = 0;
  int _forPickupCount = 0;
  bool _loadingUserCount = true;
  bool _loadingForPickupCount = true;
  List<Map<String, dynamic>> _pickupData = [];
  Set<Marker> _markers = {};
  int _availableSeats = 0;
  int _occupiedSeats = 0;
  bool _loadingSeats = true;
  String _busAddress = 'Loading...'; // State variable for bus address
  bool _iconsLoaded = false;


  @override
  void initState() {
    super.initState();
    _initializeIcons();
    _fetchCoordinates();
    _fetchBusCoordinates(); // Fetch coordinates for the bus marker
    _listenToUserCount();
    _listenToForPickupCount();
    _listenToForPickupData();
    _listenToSeatCounts();

  }

  Future<void> _initializeIcons() async {
    try {
      await Future.wait([
        _setBusMarker(),
        _setPickupIcon(),
      ]);
      setState(() {
        _iconsLoaded = true; // Set iconsLoaded to true when icons are ready
      });
      print('Icons initialized successfully.');
    } catch (e) {
      print('Error initializing icons: $e');
    }
  }

  Future<void> _setBusMarker() async {
    try {
      _customIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: Size(48, 48)),
        'assets/images/bus.png', // Update with the correct path
      );
      print('Bus marker set successfully.');
    } catch (e) {
      print('Error setting bus marker: $e');
    }
  }

  Future<void> _setPickupIcon() async {
    try {
      _pickupIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: Size(48, 48)),
        'Imagess/arm-up.png',
      );
      print('Pickup icon set successfully.');
    } catch (e) {
      print('Error setting pickup icon: $e');
    }
  }

  Future<void> _fetchCoordinates() async {
    _database.child('/Bus/Location').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final longitude = data['longitude']?.toString() ?? '0.0';
        final latitude = data['latitude']?.toString() ?? '0.0';

        setState(() {
          _location = LatLng(
            double.tryParse(latitude) ?? 0.0,
            double.tryParse(longitude) ?? 0.0,
          );
          _updateMarkers(); // Update markers with the new bus location
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(_location),
          );
        }
      }
    });
  }


  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      await NominatimGeocoding.init();
      final result = await NominatimGeocoding.to.reverseGeoCoding(
        Coordinate(latitude: latitude, longitude: longitude),
      );
      if (result != null && result.address != null) {
        final address = result.address;
        // Check available fields in the Address object and return a formatted address
        return '${address.suburb ?? ''},${address.neighbourhood ?? ''}, ${address.city ?? ''}, ${address.postalCode ?? ''}, ${address.state ?? ''}, ${address.country ?? 'Unknown location'}';
      } else {
        return 'Unknown location';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<void> _fetchBusCoordinates() async {
    _database.child('/Bus/Location').onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final longitude = data['longitude']?.toString() ?? '0.0';
        final latitude = data['latitude']?.toString() ?? '0.0';

        setState(() {
          _location = LatLng(
            double.tryParse(latitude) ?? 0.0,
            double.tryParse(longitude) ?? 0.0,
          );
          _updateMarkers(); // Update markers with the new bus location
        });

        // Fetch the address from coordinates and update the state
        final address = await getAddressFromCoordinates(
          _location.latitude,
          _location.longitude,
        );

        setState(() {
          _busAddress = address;
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(_location),
          );
        }
      }
    });
  }

  void _listenToUserCount() {
    _firestore.collection('passengers').snapshots().listen((snapshot) {
      setState(() {
        _userCount = snapshot.size;
        _loadingUserCount = false;
      });
    });
  }

  void _listenToForPickupCount() {
    _firestore.collection('Pick_Me_Up').snapshots().listen((snapshot) {
      setState(() {
        _forPickupCount = snapshot.size;
        _loadingForPickupCount = false;
      });
    });
  }

  void _listenToForPickupData() {
    _firestore.collection('Pick_Me_Up').snapshots().listen((snapshot) {
      setState(() {
        _pickupData = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        _updateMarkers();
      });
    });
  }

  void _listenToSeatCounts() {
    _database.child('Seats').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          _availableSeats = data['Available'] ?? 0;
          _occupiedSeats = data['Occupied'] ?? 0;
          _loadingSeats = false;
        });
      }
    });
  }

  void _updateMarkers() {
    if (!_iconsLoaded) return; // Do not update markers if icons are not loaded
    final markers = <Marker>{};

    // Add pickup markers
    markers.addAll(_pickupData.map((data) {
      final coordinates = data['coordinates'] as GeoPoint?;
      final position = LatLng(coordinates?.latitude ?? 0.0, coordinates?.longitude ?? 0.0);
      return Marker(
        markerId: MarkerId(data['fullName'] ?? position.toString()),
        position: position,
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: data['fullName'] ?? 'No Name',
          snippet: 'Passenger Type: ${data['passengerType'] ?? 'N/A'}\n'
              'Status: ${data['status'] ?? 'N/A'}\n'
              'Timestamp: ${data['timestamp']?.toDate().toString() ?? 'N/A'}',
        ),
      );
    }));

    // Add bus marker
    markers.add(Marker(
      markerId: MarkerId('bus_location'),
      position: _location,
      icon: _customIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: 'Bus Location',
        snippet: 'Current Location',
      ),
    ));

    print('Updating markers: ${markers.length} markers'); // Debug line
    setState(() {
      _markers = markers;
    });
  }

  void _onMapTypeSelected(MapType mapType) {
    setState(() {
      _currentMapType = mapType;
    });
  }

  Future<void> _showPickupData() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pick Up Details'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _pickupData.length,
              itemBuilder: (context, index) {
                final data = _pickupData[index];
                final coordinates = data['coordinates'] as GeoPoint?;
                final coordinatesString = coordinates != null
                    ? 'Lat: ${coordinates.latitude}, Lng: ${coordinates.longitude}'
                    : 'No Coordinates';

                return ListTile(
                  leading: Icon(Icons.location_on, color: Colors.blue),
                  title: Text(data['fullName'] ?? 'No Name'),
                  subtitle: Text(
                    'Passenger Type: ${data['passengerType'] ?? 'N/A'}\n'
                        'Status: ${data['status'] ?? 'N/A'}\n'
                        'Timestamp: ${data['timestamp']?.toDate().toString() ?? 'N/A'}\n'
                        'Coordinates: $coordinatesString',
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_customIcon == null || _pickupIcon == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _location,
                  zoom: 14.0,
                ),
                mapType: _currentMapType,
                markers: _markers,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
              ),
              Positioned(
                top: 20,
                right: 10,
                child: PopupMenuButton<MapType>(
                  onSelected: _onMapTypeSelected,
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: MapType.normal,
                      child: Text('Normal'),
                    ),
                    PopupMenuItem(
                      value: MapType.satellite,
                      child: Text('Satellite'),
                    ),
                    PopupMenuItem(
                      value: MapType.terrain,
                      child: Text('Terrain'),
                    ),
                    PopupMenuItem(
                      value: MapType.hybrid,
                      child: Text('Hybrid'),
                    ),
                  ],
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.map,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Colors.blue,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadingUserCount ? 'Loading...' : 'Number of Users: $_userCount',
                            style: TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis, // Handle long text
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _showPickupData,
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            color: Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _loadingForPickupCount ? 'Loading...' : 'For Pick Up: $_forPickupCount',
                              style: TextStyle(fontSize: 16),
                              overflow: TextOverflow.ellipsis, // Handle long text
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_bus_filled_outlined,
                          color: Colors.red,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bus Location: $_busAddress',
                            style: TextStyle(fontSize: 16),
                            overflow: TextOverflow.visible, // Allow text to wrap
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_seat,
                          color: Colors.green,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadingSeats ? 'Loading...' : 'Available Seats: $_availableSeats',
                            style: TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis, // Handle long text
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_seat,
                          color: Colors.red,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadingSeats ? 'Loading...' : 'Occupied Seats: $_occupiedSeats',
                            style: TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis, // Handle long text
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
