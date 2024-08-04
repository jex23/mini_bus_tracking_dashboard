import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_geocoding_api/google_geocoding_api.dart';

class ForPickUpTab extends StatelessWidget {
  const ForPickUpTab({Key? key}) : super(key: key);

  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      print('Fetching address for coordinates: ($latitude, $longitude)');
      const String googleApiKey = 'AIzaSyB1vuvlho95fEGdo9CgYxFJSON5FLXcLps'; // Replace with your actual API key
      final api = GoogleGeocodingApi(googleApiKey);
      final reversedSearchResults = await api.reverse(
        '$latitude,$longitude',
        language: 'en',
      );

      if (reversedSearchResults.results.isNotEmpty) {
        final address = reversedSearchResults.results.first;
        final addressComponents = address.addressComponents ?? [];
        final streetNumber = addressComponents.firstWhere(
              (comp) => comp.types.contains('street_number'),
          orElse: () => GoogleGeocodingAddressComponent(longName: ''),
        ).longName;
        final streetName = addressComponents.firstWhere(
              (comp) => comp.types.contains('route'),
          orElse: () => GoogleGeocodingAddressComponent(longName: ''),
        ).longName;
        final city = addressComponents.firstWhere(
              (comp) => comp.types.contains('locality'),
          orElse: () => GoogleGeocodingAddressComponent(longName: ''),
        ).longName;
        final state = addressComponents.firstWhere(
              (comp) => comp.types.contains('administrative_area_level_1'),
          orElse: () => GoogleGeocodingAddressComponent(longName: ''),
        ).longName;
        final country = addressComponents.firstWhere(
              (comp) => comp.types.contains('country'),
          orElse: () => GoogleGeocodingAddressComponent(longName: ''),
        ).longName;
        final formattedAddress = [
          streetNumber,
          streetName,
          city,
          state,
          country,
        ].where((component) => component.isNotEmpty).join(', ');
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


  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this request?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                FirebaseFirestore.instance.collection('Pick_Me_Up').doc(docId).delete();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPickUpTab() {
    return Column(
      children: [
        Text(
          "Pick Up Request",
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
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
                            final coordinates = data['coordinates'] as GeoPoint?;
                            final location = coordinates != null
                                ? FutureBuilder<String>(
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
                            )
                                : const Text('Unknown location');
                            String docId = doc.id; // Document ID for delete

                            return DataRow(
                              cells: [
                                DataCell(Text(data['fullName'] ?? 'N/A')),
                                DataCell(Text(data['passengerType'] ?? 'N/A')),
                                DataCell(Text(data['status'] ?? 'N/A')),
                                DataCell(location),
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

  @override
  Widget build(BuildContext context) {
    return _buildPickUpTab();
  }
}
