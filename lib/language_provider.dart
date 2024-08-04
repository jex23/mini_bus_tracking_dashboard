import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firestore Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PassengerList(),
    );
  }
}

class PassengerList extends StatelessWidget {
  final CollectionReference passengers = FirebaseFirestore.instance.collection('passengers');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Passengers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: passengers.snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            print('Error fetching data: ${snapshot.error}');
            return Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            print('Loading data...');
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.requireData;

          print('Data fetched successfully: ${data.size} documents');

          return ListView.builder(
            itemCount: data.size,
            itemBuilder: (context, index) {
              final passenger = data.docs[index];
              print('Displaying passenger: ${passenger['firstName']} ${passenger['lastName']}');

              return ListTile(
                title: Text('${passenger['firstName']} ${passenger['lastName']}'),
                subtitle: Text(passenger['email']),
              );
            },
          );
        },
      ),
    );
  }
}
