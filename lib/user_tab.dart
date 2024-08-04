import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UserTab extends StatefulWidget {
  @override
  _UserTabState createState() => _UserTabState();
}

class _UserTabState extends State<UserTab> {
  late Future<List<Map<String, dynamic>>> passengersFuture;

  @override
  void initState() {
    super.initState();
    passengersFuture = fetchPassengers();
  }

  Future<List<Map<String, dynamic>>> fetchPassengers() async {
    final snapshot = await FirebaseFirestore.instance.collection('passengers').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'docId': doc.id,
        'firstName': data['firstName'],
        'middleName': data['middleName'],
        'lastName': data['lastName'],
        'email': data['email'],
        'contactNumber': data['contactNumber'],
        'age': data['age'],
        'passengerType': data['passengerType'],
        'sex': data['sex'],
      };
    }).toList();
  }

  void _showAddUserDialog(BuildContext context) {
    final TextEditingController firstNameController = TextEditingController();
    final TextEditingController middleNameController = TextEditingController();
    final TextEditingController lastNameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController contactNumberController = TextEditingController();
    final TextEditingController ageController = TextEditingController();

    String selectedPassengerType = 'Regular';
    String selectedSex = 'Male';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
                TextField(controller: middleNameController, decoration: const InputDecoration(labelText: 'Middle Name')),
                TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(controller: contactNumberController, decoration: const InputDecoration(labelText: 'Mobile Number')),
                TextField(controller: ageController, decoration: const InputDecoration(labelText: 'Age')),
                DropdownButtonFormField<String>(
                  value: selectedPassengerType,
                  items: ['Regular', 'Student', 'PWD'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPassengerType = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Passenger Type'),
                ),
                DropdownButtonFormField<String>(
                  value: selectedSex,
                  items: ['Male', 'Female'].map((sex) {
                    return DropdownMenuItem(
                      value: sex,
                      child: Text(sex),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedSex = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Sex'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final email = emailController.text;
                final age = int.tryParse(ageController.text);

                if (firstNameController.text.isEmpty ||
                    lastNameController.text.isEmpty ||
                    email.isEmpty ||
                    contactNumberController.text.isEmpty ||
                    age == null ||
                    age < 0 ||
                    selectedPassengerType.isEmpty ||
                    selectedSex.isEmpty) {
                  // Show an error dialog if validation fails
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Error'),
                        content: const Text('Please complete all fields with valid data.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }

                FirebaseFirestore.instance.collection('passengers').add({
                  'firstName': firstNameController.text,
                  'middleName': middleNameController.text,
                  'lastName': lastNameController.text,
                  'email': email,
                  'contactNumber': contactNumberController.text,
                  'age': age,
                  'passengerType': selectedPassengerType,
                  'sex': selectedSex,
                });

                Navigator.of(context).pop();
                _refreshList();
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

  void _refreshList() {
    setState(() {
      passengersFuture = fetchPassengers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
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
                            minWidth: constraints.maxWidth,
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
                              String docId = passenger['docId'];
                              return DataRow(
                                cells: [
                                  DataCell(Text(passenger['firstName'] ?? 'N/A')),
                                  DataCell(Text(passenger['middleName'] ?? 'N/A')),
                                  DataCell(Text(passenger['lastName'] ?? 'N/A')),
                                  DataCell(Text(passenger['email'] ?? 'N/A')),
                                  DataCell(Text(passenger['contactNumber'] ?? 'N/A')),
                                  DataCell(Text(passenger['age']?.toString() ?? 'N/A')),
                                  DataCell(Text(passenger['passengerType'] ?? 'N/A')),
                                  DataCell(Text(passenger['sex'] ?? 'N/A')),
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
      ),
    );
  }

  void _showEditDialog(BuildContext context, String docId, Map<String, dynamic> passenger) {
    final TextEditingController firstNameController = TextEditingController(text: passenger['firstName']);
    final TextEditingController middleNameController = TextEditingController(text: passenger['middleName']);
    final TextEditingController lastNameController = TextEditingController(text: passenger['lastName']);
    final TextEditingController emailController = TextEditingController(text: passenger['email']);
    final TextEditingController contactNumberController = TextEditingController(text: passenger['contactNumber']);
    final TextEditingController ageController = TextEditingController(text: passenger['age']?.toString());

    String selectedPassengerType = passenger['passengerType'] ?? 'Regular';
    String selectedSex = passenger['sex'] ?? 'Male';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
                TextField(controller: middleNameController, decoration: const InputDecoration(labelText: 'Middle Name')),
                TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(controller: contactNumberController, decoration: const InputDecoration(labelText: 'Mobile Number')),
                TextField(controller: ageController, decoration: const InputDecoration(labelText: 'Age')),
                DropdownButtonFormField<String>(
                  value: selectedPassengerType,
                  items: ['Regular', 'Student', 'PWD'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPassengerType = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Passenger Type'),
                ),
                DropdownButtonFormField<String>(
                  value: selectedSex,
                  items: ['Male', 'Female'].map((sex) {
                    return DropdownMenuItem(
                      value: sex,
                      child: Text(sex),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedSex = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Sex'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final email = emailController.text;
                final age = int.tryParse(ageController.text);

                if (firstNameController.text.isEmpty ||
                    lastNameController.text.isEmpty ||
                    email.isEmpty ||
                    contactNumberController.text.isEmpty ||
                    age == null ||
                    age < 0 ||
                    selectedPassengerType.isEmpty ||
                    selectedSex.isEmpty) {
                  // Show an error dialog if validation fails
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Error'),
                        content: const Text('Please complete all fields with valid data.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }

                FirebaseFirestore.instance.collection('passengers').doc(docId).update({
                  'firstName': firstNameController.text,
                  'middleName': middleNameController.text,
                  'lastName': lastNameController.text,
                  'email': email,
                  'contactNumber': contactNumberController.text,
                  'age': age,
                  'passengerType': selectedPassengerType,
                  'sex': selectedSex,
                });

                Navigator.of(context).pop();
                _refreshList();
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: const Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('passengers').doc(docId).delete();
                Navigator.of(context).pop();
                _refreshList();
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
}


