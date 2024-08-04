import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'loginpage.dart'; // Import the login page
import 'package:geocoding/geocoding.dart';
import 'package:nominatim_geocoding/nominatim_geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Easy SideMenu Dashboard',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: false,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: false,
            brightness: Brightness.dark,
          ),
          themeMode: themeMode,
          home: const AuthCheck(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasData) {
          return const HomeScreen();
        } else {
          return LoginPage();
        }
      },
    );
  }
}

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  static final instance = ThemeNotifier();

  void toggleTheme() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PageController pageController = PageController();
  SideMenuController sideMenuController = SideMenuController();
  late Future<List<Map<String, dynamic>>> passengersFuture;
  // Add Google Map controller
  late GoogleMapController _mapController;
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.reference();
  LatLng _currentLocation = LatLng(37.7749, -122.4194); // Initial location
  String _busLocation = 'Not Available';
  BitmapDescriptor? _busIcon;
  late Future<List<Map<String, dynamic>>> pickUpPassengersFuture;

  @override
  void initState() {
    super.initState();
    _listenForLocationUpdates();
    _loadBusIcon();
    NominatimGeocoding.init(); // Initialize Nominatim
    sideMenuController.addListener((index) {
      pageController.jumpToPage(index);
    });
    passengersFuture = fetchPassengers();
    pickUpPassengersFuture = fetchPickUpPassengers();
  }

  void _loadBusIcon() async {
    _busIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/Images/bus2.png',
    );
    setState(() {});
  }


  void _listenForLocationUpdates() {
    _databaseReference.child('Bus/Location').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final latitude = data?['latitude'];
      final longitude = data?['longitude'];

      if (latitude != null && longitude != null) {
        setState(() {
          _currentLocation = LatLng(latitude, longitude);
          _busLocation = 'Lat: $latitude, Lng: $longitude';
        });
        _updateMapLocation();
      }
    });
  }

  void _updateMapLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentLocation),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMapLocation(); // Update the map when it is created
  }

  Future<int> getUsersCount() async {
    final passengers = await fetchPassengers();
    return passengers.length;
  }

  Future<int> getPickUpCount() async {
    final pickups = await fetchPickUpPassengers();
    return pickups.length;
  }

  Future<List<Map<String, dynamic>>> fetchPassengers() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('passengers').get();
    return querySnapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['docId'] = doc.id; // Include document ID for edit/delete
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPickUpPassengers() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('Pick_Me_Up').get();
    return querySnapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['docId'] = doc.id; // Include document ID for edit/delete
      return data;
    }).toList();
  }

  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    if (latitude == null || longitude == null) {
      return 'Unknown location';
    }

    try {
      print('Fetching address for coordinates: ($latitude, $longitude)');
      final result = await NominatimGeocoding.to.reverseGeoCoding(
        Coordinate(latitude: latitude, longitude: longitude),
      );

      if (result != null) {
        // Assuming result has an address property or similar
        final address = result.address;

        // Check and print address details
        print('Full Address Object: $address');

        // Create a formatted address string based on available properties
        final formattedAddress = [
          address.houseNumber,
          address.road,
          address.neighbourhood,
          address.suburb,
          address.city,
          address.district,
          address.state,
          address.country
        ].where((component) => component != null && component.toString().isNotEmpty).join(', ');

        print('Address found: $formattedAddress');
        return formattedAddress.isNotEmpty ? formattedAddress : 'Unknown location';
      }

      print('No address found.');
      return 'Unknown location';
    } catch (e) {
      print('Error fetching address: $e');
      return 'Unknown location';
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                ); // Navigate to LoginPage and remove all previous routes
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final TextEditingController firstNameController = TextEditingController();
    final TextEditingController middleNameController = TextEditingController();
    final TextEditingController lastNameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController contactNumberController = TextEditingController();
    final TextEditingController ageController = TextEditingController();
    final TextEditingController passengerTypeController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController sexController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
              TextField(controller: middleNameController, decoration: const InputDecoration(labelText: 'Middle Name')),
              TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: contactNumberController, decoration: const InputDecoration(labelText: 'Mobile Number')),
              TextField(controller: ageController, decoration: const InputDecoration(labelText: 'Age')),
              TextField(controller: passengerTypeController, decoration: const InputDecoration(labelText: 'Passenger Type')),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              TextField(
                controller: sexController,
                decoration: const InputDecoration(labelText: 'Sex'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  // Create user in Firebase Authentication
                  UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailController.text,
                    password: passwordController.text,
                  );

                  // Store user details in Firestore
                  await FirebaseFirestore.instance.collection('passengers').add({
                    'firstName': firstNameController.text,
                    'middleName': middleNameController.text,
                    'lastName': lastNameController.text,
                    'email': emailController.text,
                    'contactNumber': contactNumberController.text,
                    'age': int.tryParse(ageController.text) ?? 0,
                    'passengerType': passengerTypeController.text,
                    'sex': sexController.text,
                    'uid': userCredential.user?.uid, // Store Firebase UID for reference
                  });

                  Navigator.of(context).pop();
                  setState(() {
                    passengersFuture = fetchPassengers();
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, String docId, Map<String, dynamic> passenger) {
    final TextEditingController firstNameController = TextEditingController(text: passenger['firstName']);
    final TextEditingController middleNameController = TextEditingController(text: passenger['middleName']);
    final TextEditingController lastNameController = TextEditingController(text: passenger['lastName']);
    final TextEditingController emailController = TextEditingController(text: passenger['email']);
    final TextEditingController contactNumberController = TextEditingController(text: passenger['contactNumber']);
    final TextEditingController ageController = TextEditingController(text: passenger['age']?.toString());
    final TextEditingController passengerTypeController = TextEditingController(text: passenger['passengerType']);
    final TextEditingController sexController = TextEditingController(text: passenger['sex']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
              TextField(controller: middleNameController, decoration: const InputDecoration(labelText: 'Middle Name')),
              TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: contactNumberController, decoration: const InputDecoration(labelText: 'Mobile Number')),
              TextField(controller: ageController, decoration: const InputDecoration(labelText: 'Age')),
              TextField(controller: passengerTypeController, decoration: const InputDecoration(labelText: 'Passenger Type')),
              TextField(controller: sexController, decoration: const InputDecoration(labelText: 'Sex')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('passengers').doc(docId).update({
                  'firstName': firstNameController.text,
                  'middleName': middleNameController.text,
                  'lastName': lastNameController.text,
                  'email': emailController.text,
                  'contactNumber': contactNumberController.text,
                  'age': int.tryParse(ageController.text) ?? 0,
                  'passengerType': passengerTypeController.text,
                  'sex': sexController.text,
                });

                Navigator.of(context).pop();
                setState(() {
                  passengersFuture = fetchPassengers();
                });
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: const Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('passengers').doc(docId).delete();
                Navigator.of(context).pop();
                setState(() {
                  passengersFuture = fetchPassengers();
                });
              },
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
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
        title: const Text('Dashboard'),
        centerTitle: true,
      ),
      body: Row(
        children: [
          SideMenu(
            controller: sideMenuController,
            style: SideMenuStyle(
              displayMode: SideMenuDisplayMode.auto,
              showHamburger: true,
              hoverColor: Colors.blue[100],
              selectedHoverColor: Colors.blue[100],
              selectedColor: Colors.lightBlue,
              selectedTitleTextStyle: const TextStyle(color: Colors.white),
              selectedIconColor: Colors.white,
            ),
            title: Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 150,
                    maxWidth: 150,
                  ),
                  child: Image.asset(
                    'assets/jeep.png', // Replace with your asset path
                  ),
                ),
                const Divider(
                  indent: 8.0,
                  endIndent: 8.0,
                ),
              ],
            ),
            footer: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.lightBlue[50],
                    borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                  child: Text(
                    'Rijam Technologies (2024)',
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                ),
              ),
            ),
            items: [
              SideMenuItem(
                title: 'Home',
                onTap: (index, _) {
                  sideMenuController.changePage(0); // Navigate to the Home page
                },
                icon: const Icon(Icons.home),
              ),
              SideMenuItem(
                title: 'Users',
                onTap: (index, _) {
                  sideMenuController.changePage(1); // Navigate to the Users page
                },
                icon: const Icon(Icons.people_outline_rounded),
              ),
              SideMenuItem(
                title: 'For Pick Up',
                onTap: (index, _) {
                  sideMenuController.changePage(2); // Navigate to the Reports page
                },
                icon: const Icon(Icons.report),
              ),
              SideMenuItem(
                title: 'Logout',
                icon: const Icon(Icons.logout),
                onTap: (index, _) {
                  _showLogoutDialog(); // Show logout dialog
                },
              ),
            ],
          ),
          const VerticalDivider(width: 0),
          Expanded(
            child: PageView(
              controller: pageController,
              children: [
                _buildGoogleMapTab(),
                _buildUsersTab(),
                _buildPickUpTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMapTab() {
    return Column(
      children: [
        // Google Map section
        Expanded(
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation, // Use the initial location
              zoom: 14,
            ),
            markers: {
              if (_busIcon != null)
                Marker(
                  markerId: MarkerId('bus'),
                  position: _currentLocation,
                  icon: _busIcon!,
                ),
            },
          ),
        ),
        // Card section
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.blueGrey[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard Summary',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('Pick_Me_Up').get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildCard('Number of Pick Ups', 'Loading...');
                      } else if (snapshot.hasError) {
                        return _buildCard('Number of Pick Ups', 'Error');
                      } else {
                        int pickUpCount = snapshot.data?.docs.length ?? 0;
                        return _buildCard('Number of Pick Ups', pickUpCount.toString());
                      }
                    },
                  ),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('Passengers').get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildCard('Number of Users', 'Loading...');
                      } else if (snapshot.hasError) {
                        return _buildCard('Number of Users', 'Error');
                      } else {
                        int userCount = snapshot.data?.docs.length ?? 0;
                        return _buildCard('Number of Users', userCount.toString());
                      }
                    },
                  ),
                  _buildCard('Bus Location', _busLocation), // Dynamic bus location data
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String title, String value) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildTabContent(String title) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 35),
        ),
      ),
    );
  }

  Widget _buildPickUpTab() {
    return Column(
      children: [
        Text(
          "Pick Up Request",
          style: TextStyle(
            fontSize: 25,
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Pick_Me_Up').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No pick up requests found.'));
              } else {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth, // Ensure minimum width
                        ),
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowHeight: 56,
                          dataRowHeight: 64,
                          headingTextStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[800],
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Full Name',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Passenger Type',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Location',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Requested At',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Delete',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          rows: snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final GeoPoint coordinates = data['coordinates'] ?? GeoPoint(0, 0);
                            final location = 'Lat: ${coordinates.latitude}, Lng: ${coordinates.longitude}';
                            String docId = doc.id; // Document ID for delete

                            return DataRow(
                              cells: [
                                DataCell(Text(data['fullName'] ?? 'N/A')),
                                DataCell(Text(data['passengerType'] ?? 'N/A')),
                                DataCell(Text(data['status'] ?? 'N/A')),
                                DataCell(FutureBuilder<String>(
                                  future: getAddressFromCoordinates(coordinates.latitude, coordinates.longitude),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Text('Loading...');
                                    } else if (snapshot.hasError) {
                                      return const Text('Unknown location');
                                    } else {
                                      return Text(snapshot.data ?? 'Unknown location');
                                    }
                                  },
                                )),
                                DataCell(Text(data['timestamp']?.toDate().toString() ?? 'N/A')),
                                DataCell(
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () {
                                      _showDeleteDialog(context, docId);
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }









  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent, // Button color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
            ),
            onPressed: () {
              _showAddUserDialog(context);
            },
            child: const Text(
              'Add User',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: passengersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No passengers found.'));
              } else {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth, // Ensure minimum width
                        ),
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowHeight: 56,
                          dataRowHeight: 64,
                          headingTextStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[800],
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          columns: [
                            DataColumn(
                              label: Text(
                                'First Name',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Middle Name',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Last Name',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Email',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Mobile Number',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Age',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Passenger Type',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Sex',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Actions',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          rows: snapshot.data!.map((passenger) {
                            String docId = passenger['docId']; // Ensure docId is included in the data
                            return DataRow(
                              cells: [
                                DataCell(Text(passenger['firstName'] ?? 'N/A')),
                                DataCell(Text(passenger['middleName'] ?? 'N/A')),
                                DataCell(Text(passenger['lastName'] ?? 'N/A')),
                                DataCell(Text(passenger['email'] ?? 'N/A')),
                                DataCell(Text(passenger['contactNumber'] ?? 'N/A')),
                                DataCell(Text(passenger['age']?.toString() ?? 'N/A')),
                                DataCell(Text(passenger['passengerType'] ?? 'N/A')),
                                DataCell(Text(passenger['sex'] ?? 'N/A')), // Display 'Sex'
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Colors.blueAccent),
                                        onPressed: () {
                                          _showEditDialog(context, docId, passenger);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () {
                                          _showDeleteDialog(context, docId);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }



}
