import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

const List<Category> kTransactionCategories = [
  // Housing
  Category(
    id: 'rent',
    name: 'Loyer / Prêt',
    icon: Icons.home,
    color: Colors.brown,
  ),
  Category(
    id: 'housing_charges',
    name: 'Charges Logement',
    icon: Icons.domain,
    color: Colors.blueGrey,
  ),
  Category(
    id: 'home_insurance',
    name: 'Assurance Habitation',
    icon: Icons.security,
    color: Colors.indigo,
  ),
  Category(
    id: 'maintenance',
    name: 'Travaux & Entretien',
    icon: Icons.build,
    color: Colors.grey,
  ),

  // Utilities
  Category(
    id: 'electricity',
    name: 'Électricité / Gaz',
    icon: Icons.lightbulb,
    color: Colors.yellow,
  ),
  Category(
    id: 'water',
    name: 'Eau',
    icon: Icons.water_drop,
    color: Colors.blue,
  ),
  Category(
    id: 'internet',
    name: 'Internet & TV',
    icon: Icons.wifi,
    color: Colors.purple,
  ),
  Category(
    id: 'phone',
    name: 'Téléphone',
    icon: Icons.phone_android,
    color: Colors.purple,
  ),
  Category(
    id: 'streaming',
    name: 'Streaming & Abonnements',
    icon: Icons.play_circle_fill,
    color: Colors.red,
  ),

  // Food
  Category(
    id: 'groceries',
    name: 'Courses',
    icon: Icons.shopping_cart,
    color: Colors.green,
  ),
  Category(
    id: 'restaurant',
    name: 'Restaurant / Fast-Food',
    icon: Icons.restaurant,
    color: Colors.orange,
  ),
  Category(
    id: 'bar',
    name: 'Bar / Sorties',
    icon: Icons.local_bar,
    color: Colors.pink,
  ),

  // Transport
  Category(
    id: 'fuel',
    name: 'Carburant',
    icon: Icons.local_gas_station,
    color: Colors.blueGrey,
  ),
  Category(
    id: 'public_transport',
    name: 'Transports en commun',
    icon: Icons.directions_bus,
    color: Colors.blue,
  ),
  Category(
    id: 'parking',
    name: 'Parking / Péage',
    icon: Icons.local_parking,
    color: Colors.grey,
  ),
  Category(
    id: 'car_insurance',
    name: 'Assurance Auto',
    icon: Icons.car_crash,
    color: Colors.indigo,
  ),
  Category(
    id: 'car_maintenance',
    name: 'Entretien Auto',
    icon: Icons.car_repair,
    color: Colors.brown,
  ),

  // Health
  Category(
    id: 'doctor',
    name: 'Médecin',
    icon: Icons.local_hospital,
    color: Colors.red,
  ),
  Category(
    id: 'pharmacy',
    name: 'Pharmacie',
    icon: Icons.medication,
    color: Colors.red,
  ),
  Category(
    id: 'sport',
    name: 'Sport',
    icon: Icons.fitness_center,
    color: Colors.teal,
  ),

  // Personal / Shopping
  Category(
    id: 'clothing',
    name: 'Vêtements',
    icon: Icons.checkroom,
    color: Colors.purple,
  ),
  Category(
    id: 'shopping',
    name: 'Shopping / Cadeaux',
    icon: Icons.shopping_bag,
    color: Colors.pink,
  ),
  Category(
    id: 'beauty',
    name: 'Coiffeur / Esthétique',
    icon: Icons.content_cut,
    color: Colors.pinkAccent,
  ),
  Category(
    id: 'hobbies',
    name: 'Loisirs / Hobbies',
    icon: Icons.sports_esports,
    color: Colors.deepPurple,
  ),

  // Kids
  Category(
    id: 'school',
    name: 'École / Cantine',
    icon: Icons.school,
    color: Colors.amber,
  ),
  Category(
    id: 'activities',
    name: 'Activités Enfants',
    icon: Icons.pool,
    color: Colors.cyan,
  ),
  Category(
    id: 'baby',
    name: 'Bébé / Garde',
    icon: Icons.child_care,
    color: Colors.pink,
  ),

  // Financial
  Category(
    id: 'bank_fees',
    name: 'Frais Bancaires',
    icon: Icons.account_balance,
    color: Colors.grey,
  ),
  Category(
    id: 'savings',
    name: 'Épargne / Investissement',
    icon: Icons.savings,
    color: Colors.green,
  ),
  Category(
    id: 'tax',
    name: 'Impôts & Taxes',
    icon: Icons.request_quote,
    color: Colors.redAccent,
  ),

  // Income
  Category(
    id: 'salary',
    name: 'Salaire',
    icon: Icons.attach_money,
    color: Colors.green,
  ),
  Category(
    id: 'freelance',
    name: 'Freelance / Ventes',
    icon: Icons.work,
    color: Colors.lightGreen,
  ),
  Category(
    id: 'social_aid',
    name: 'Aides Sociales (CAF...)',
    icon: Icons.family_restroom,
    color: Colors.blue,
  ),
  Category(
    id: 'gift_money',
    name: 'Cadeaux Reçus',
    icon: Icons.card_giftcard,
    color: Colors.pink,
  ),

  // Other
  Category(
    id: 'transfer',
    name: 'Virement Interne',
    icon: Icons.compare_arrows,
    color: Colors.grey,
  ),
  Category(
    id: 'other',
    name: 'Autre',
    icon: Icons.category,
    color: Colors.grey,
  ),
];
