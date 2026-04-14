enum FuelType { petrol, diesel, cng, electric, hybrid }

class Vehicle {
  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    this.variant,
    this.fuelType = FuelType.petrol,
    this.mileageKm = 0,
    this.lastServiceDate,
    this.imagePath,
    this.userId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String make;
  final String model;
  final int year;
  final String? variant;
  final FuelType fuelType;
  final int mileageKm;
  final DateTime? lastServiceDate;
  final String? imagePath;
  final String? userId;
  final DateTime createdAt;

  String get displayName => '$year $make $model${variant != null ? ' $variant' : ''}';

  String get fuelLabel => switch (fuelType) {
        FuelType.petrol => 'Petrol',
        FuelType.diesel => 'Diesel',
        FuelType.cng => 'CNG',
        FuelType.electric => 'Electric',
        FuelType.hybrid => 'Hybrid',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'make': make,
        'model': model,
        'year': year,
        'variant': variant,
        'fuel_type': fuelType.name,
        'mileage_km': mileageKm,
        'last_service_date': lastServiceDate?.toIso8601String(),
        'image_path': imagePath,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        make: j['make'] as String,
        model: j['model'] as String,
        year: j['year'] as int,
        variant: j['variant'] as String?,
        fuelType: FuelType.values.byName(j['fuel_type'] as String? ?? 'petrol'),
        mileageKm: j['mileage_km'] as int? ?? 0,
        lastServiceDate: j['last_service_date'] != null
            ? DateTime.tryParse(j['last_service_date'] as String)
            : null,
        imagePath: j['image_path'] as String?,
        userId: j['user_id'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Vehicle copyWith({
    String? make,
    String? model,
    int? year,
    String? variant,
    FuelType? fuelType,
    int? mileageKm,
    DateTime? lastServiceDate,
    String? imagePath,
  }) =>
      Vehicle(
        id: id,
        make: make ?? this.make,
        model: model ?? this.model,
        year: year ?? this.year,
        variant: variant ?? this.variant,
        fuelType: fuelType ?? this.fuelType,
        mileageKm: mileageKm ?? this.mileageKm,
        lastServiceDate: lastServiceDate ?? this.lastServiceDate,
        imagePath: imagePath ?? this.imagePath,
        userId: userId,
        createdAt: createdAt,
      );
}

/// Static lookup table for the vehicle-selector wizard.
abstract final class VehicleData {
  static const makes = [
    'Acura', 'Alfa Romeo', 'Aston Martin', 'Audi', 'Ashok Leyland',
    'Bentley', 'BMW', 'BYD', 'Bugatti', 'Buick',
    'Cadillac', 'Chevrolet', 'Chrysler', 'Citroën',
    'Datsun', 'Dodge',
    'Ferrari', 'Fiat', 'Force', 'Ford',
    'Genesis', 'GMC',
    'Honda', 'Hyundai',
    'Infiniti', 'Isuzu',
    'Jaguar', 'Jeep',
    'Kia',
    'Lamborghini', 'Land Rover', 'Lexus', 'Lincoln', 'Lotus',
    'Mahindra', 'Maruti Suzuki', 'Maserati', 'Mazda', 'McLaren',
    'Mercedes-Benz', 'MG', 'Mini', 'Mitsubishi',
    'Nissan',
    'Pagani', 'Peugeot', 'Porsche',
    'Ram', 'Renault', 'Rolls-Royce',
    'Škoda', 'Subaru', 'Suzuki',
    'Tata', 'Tesla', 'Toyota',
    'Volkswagen', 'Volvo',
  ];

  static List<String> modelsFor(String make) => switch (make) {
        // ── Indian-market brands ──────────────────────────────────────
        'Maruti Suzuki' => [
          'Alto K10', 'S-Presso', 'Celerio', 'WagonR', 'Swift',
          'Dzire', 'Baleno', 'Ignis', 'Ciaz', 'Ertiga', 'XL6',
          'Brezza', 'Grand Vitara', 'Fronx', 'Jimny', 'Invicto',
          'Eeco', 'Vitara', 'Alto 800',
        ],
        'Mahindra' => [
          'Thar', 'Scorpio-N', 'Scorpio Classic', 'XUV700', 'XUV400',
          'XUV300', 'XUV3XO', 'Bolero', 'Bolero Neo', 'Marazzo',
          'KUV100', 'Alturas G4', 'BE 6', 'XEV 9e',
        ],
        'Tata' => [
          'Nexon', 'Nexon EV', 'Punch', 'Punch EV', 'Harrier',
          'Safari', 'Altroz', 'Tiago', 'Tiago EV', 'Tigor',
          'Tigor EV', 'Curvv', 'Curvv EV', 'Sierra EV', 'Nano',
        ],
        'Force' => [
          'Gurkha', 'Gurkha 5-door', 'Traveller', 'Trax', 'Urbania',
          'Citiline', 'Tempo Traveller',
        ],
        'MG' => [
          'Hector', 'Hector Plus', 'Astor', 'ZS EV', 'Gloster',
          'Comet EV', 'Windsor EV',
        ],
        'Datsun' => [
          'GO', 'GO+', 'redi-GO',
        ],
        'Isuzu' => [
          'D-Max V-Cross', 'D-Max Hi-Lander', 'mu-X', 'S-Cab',
        ],
        'BYD' => [
          'Atto 3', 'Seal', 'e6',
        ],
        'Ashok Leyland' => [
          'Dost', 'Bada Dost', 'Partner', 'Stile',
        ],

        // ── Honda (India + global) ───────────────────────────────────
        'Honda' => [
          'City', 'City Hybrid', 'Amaze', 'WR-V', 'BR-V', 'Jazz',
          'Elevate', 'CR-V', 'HR-V', 'Civic', 'Accord', 'Pilot',
        ],

        // ── Hyundai (India + global) ─────────────────────────────────
        'Hyundai' => [
          'i10 Grand / Nios', 'i20', 'i20 N Line', 'Venue', 'Venue N Line',
          'Creta', 'Creta N Line', 'Verna', 'Tucson', 'Alcazar',
          'Exter', 'Ioniq 5', 'Kona Electric', 'Santa Fe', 'Elantra',
        ],

        // ── Kia (India + global) ─────────────────────────────────────
        'Kia' => [
          'Seltos', 'Sonet', 'Carens', 'EV6', 'EV9',
          'Sportage', 'Carnival', 'Telluride', 'Rio', 'Forte', 'Stinger',
        ],

        // ── Toyota (India + global) ──────────────────────────────────
        'Toyota' => [
          'Glanza', 'Urban Cruiser Hyryder', 'Innova Hycross',
          'Innova Crysta', 'Fortuner', 'Fortuner Legender', 'Hilux',
          'Camry', 'Vellfire', 'Land Cruiser', 'Rumion',
          'Corolla', 'RAV4', 'Prius', 'Supra', 'Yaris',
        ],

        // ── Suzuki (global, non-Maruti) ──────────────────────────────
        'Suzuki' => [
          'Swift', 'Baleno', 'Brezza', 'Ertiga', 'Jimny',
          'Grand Vitara', 'Fronx', 'Ignis', 'S-Cross', 'Ciaz',
          'Vitara', 'SX4', 'Alto', 'Celerio',
        ],

        // ── Škoda (India models) ─────────────────────────────────────
        'Škoda' => [
          'Kushaq', 'Slavia', 'Kodiaq', 'Superb', 'Octavia',
          'Rapid', 'Karoq', 'Kamiq',
        ],

        // ── Volkswagen (India + global) ──────────────────────────────
        'Volkswagen' => [
          'Taigun', 'Virtus', 'Tiguan', 'Polo', 'Vento',
          'Golf', 'Passat', 'T-Roc', 'ID.4', 'Jetta', 'Atlas', 'Arteon',
        ],

        // ── Renault (India + global) ─────────────────────────────────
        'Renault' => [
          'Kwid', 'Triber', 'Kiger', 'Duster', 'Captur',
          'Megane', 'Clio',
        ],

        // ── Nissan (India + global) ──────────────────────────────────
        'Nissan' => [
          'Magnite', 'Kicks', 'X-Trail',
          'Altima', 'Sentra', 'Rogue', 'Pathfinder', 'Z', 'Leaf',
        ],

        // ── Ford (India legacy + global) ─────────────────────────────
        'Ford' => [
          'EcoSport', 'Endeavour', 'Figo', 'Aspire', 'Freestyle',
          'Mustang', 'F-150', 'Explorer', 'Bronco', 'Ranger', 'Maverick',
        ],

        // ── Fiat (India legacy + global) ─────────────────────────────
        'Fiat' => [
          'Punto', 'Linea', 'Avventura', 'Urban Cross',
          '500', 'Panda', 'Tipo',
        ],

        // ── Mitsubishi ───────────────────────────────────────────────
        'Mitsubishi' => [
          'Outlander', 'Pajero', 'Pajero Sport', 'Eclipse Cross',
          'Lancer', 'ASX', 'Triton',
        ],

        // ── Jeep (India + global) ────────────────────────────────────
        'Jeep' => [
          'Compass', 'Meridian', 'Wrangler', 'Grand Cherokee',
          'Renegade', 'Gladiator', 'Cherokee',
        ],

        // ── Jaguar / Land Rover ──────────────────────────────────────
        'Jaguar' => [
          'F-Pace', 'E-Pace', 'I-Pace', 'XE', 'XF', 'XJ', 'F-Type',
        ],
        'Land Rover' => [
          'Defender', 'Discovery', 'Discovery Sport', 'Range Rover',
          'Range Rover Sport', 'Range Rover Velar', 'Range Rover Evoque',
        ],

        // ── Premium / Luxury ─────────────────────────────────────────
        'BMW' => [
          '2 Series Gran Coupe', '3 Series', '3 Series Gran Limousine',
          '5 Series', '7 Series', 'X1', 'X3', 'X5', 'X7',
          'Z4', 'iX', 'i4', 'i7', 'M340i', 'XM',
        ],
        'Mercedes-Benz' => [
          'A-Class Limousine', 'C-Class', 'E-Class', 'S-Class', 'Maybach',
          'GLA', 'GLB', 'GLC', 'GLE', 'GLS', 'G-Class',
          'AMG GT', 'EQS', 'EQB', 'EQA',
        ],
        'Audi' => [
          'A4', 'A6', 'A8', 'Q3', 'Q5', 'Q7', 'Q8',
          'e-tron', 'e-tron GT', 'RS5', 'RS Q8', 'TT', 'A3',
        ],
        'Porsche' => [
          '911', 'Cayenne', 'Macan', 'Panamera', 'Taycan', 'Boxster', 'Cayman',
        ],
        'Volvo' => [
          'XC40', 'XC40 Recharge', 'XC60', 'XC90', 'S60', 'S90',
          'C40 Recharge', 'V60 Cross Country',
        ],
        'Lexus' => [
          'ES', 'LS', 'NX', 'RX', 'LX', 'LC', 'IS',
        ],
        'Tesla' => ['Model 3', 'Model Y', 'Model S', 'Model X', 'Cybertruck'],
        'Chevrolet' => ['Silverado', 'Equinox', 'Traverse', 'Camaro', 'Corvette', 'Blazer', 'Tahoe', 'Malibu'],
        'Mazda' => ['3', '6', 'CX-5', 'CX-30', 'CX-50', 'CX-9', 'MX-5 Miata'],
        'Subaru' => ['Outback', 'Forester', 'Crosstrek', 'Impreza', 'WRX', 'BRZ', 'Ascent'],
        _ => ['Sedan', 'SUV', 'Hatchback', 'Coupe', 'Pickup', 'Van', 'Wagon'],
      };

  static List<int> get years {
    final now = DateTime.now().year;
    return [for (int y = now + 1; y >= 1990; y--) y];
  }
}
