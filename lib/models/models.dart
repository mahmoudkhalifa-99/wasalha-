// نماذج البيانات - منقولة بالكامل من types.ts في نسخة الويب

enum UserRole { ADMIN, OPERATOR, DRIVER, CUSTOMER }

enum UserStatus { PENDING_APPROVAL, APPROVED, SUSPENDED }

enum PaymentMethod { CASH, WALLET }

enum VehicleType { TOKTOK, MOTORCYCLE, CAR }

enum OrderCategory { TAXI, FOOD, PHARMACY, GROCERY, PARCEL }

enum OrderStatus { DRAFT, PENDING, ASSIGNED, PICKED, IN_DELIVERY, DELIVERED, CANCELLED }

T _enumFromString<T>(List<T> values, String? value, T fallback) {
  if (value == null) return fallback;
  return values.firstWhere(
    (e) => e.toString().split('.').last == value,
    orElse: () => fallback,
  );
}

String enumToStr(Object e) => e.toString().split('.').last;

class GeoPointSimple {
  final double lat;
  final double lng;
  const GeoPointSimple({required this.lat, required this.lng});

  factory GeoPointSimple.fromMap(Map<String, dynamic>? m) => GeoPointSimple(
        lat: (m?['lat'] as num?)?.toDouble() ?? 0,
        lng: (m?['lng'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};
}

class Wallet {
  final double balance;
  final double totalEarnings;
  final double withdrawn;
  const Wallet({this.balance = 0, this.totalEarnings = 0, this.withdrawn = 0});

  factory Wallet.fromMap(Map<String, dynamic>? m) => Wallet(
        balance: (m?['balance'] as num?)?.toDouble() ?? 0,
        totalEarnings: (m?['totalEarnings'] as num?)?.toDouble() ?? 0,
        withdrawn: (m?['withdrawn'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'balance': balance, 'totalEarnings': totalEarnings, 'withdrawn': withdrawn};
}

class AppUser {
  final String id;
  final String email;
  final String phone;
  final String name;
  final UserRole role;
  final UserStatus status;
  final String? photoURL;
  final VehicleType? vehicleType;
  final String? plateNumber;
  final String? operatorId;
  final String? zoneId;
  final Wallet wallet;

  AppUser({
    required this.id,
    required this.email,
    required this.phone,
    required this.name,
    required this.role,
    required this.status,
    this.photoURL,
    this.vehicleType,
    this.plateNumber,
    this.operatorId,
    this.zoneId,
    this.wallet = const Wallet(),
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> m) => AppUser(
        id: id,
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        name: m['name'] ?? '',
        role: _enumFromString(UserRole.values, m['role'], UserRole.CUSTOMER),
        status: _enumFromString(
            UserStatus.values, m['status'], UserStatus.PENDING_APPROVAL),
        photoURL: m['photoURL'],
        vehicleType: m['vehicleType'] != null
            ? _enumFromString(VehicleType.values, m['vehicleType'], VehicleType.TOKTOK)
            : null,
        plateNumber: m['plateNumber'],
        operatorId: m['operatorId'],
        zoneId: m['zoneId'],
        wallet: Wallet.fromMap(m['wallet']),
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'phone': phone,
        'name': name,
        'role': enumToStr(role),
        'status': enumToStr(status),
        if (photoURL != null) 'photoURL': photoURL,
        if (vehicleType != null) 'vehicleType': enumToStr(vehicleType!),
        if (plateNumber != null) 'plateNumber': plateNumber,
        if (operatorId != null) 'operatorId': operatorId,
        if (zoneId != null) 'zoneId': zoneId,
        'wallet': wallet.toMap(),
      };
}

class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  const CartItem(
      {required this.id, required this.name, required this.price, this.quantity = 1});

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'price': price, 'quantity': quantity};

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
        id: m['id'],
        name: m['name'],
        price: (m['price'] as num).toDouble(),
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
      );
}

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? photoURL;
  const MenuItem(
      {required this.id, required this.name, required this.price, this.description, this.photoURL});

  factory MenuItem.fromMap(Map<String, dynamic> m) => MenuItem(
        id: m['id'],
        name: m['name'],
        price: (m['price'] as num).toDouble(),
        description: m['description'],
        photoURL: m['photoURL'],
      );
}

class Restaurant {
  final String id;
  final String name;
  final String category;
  final String address;
  final double lat;
  final double lng;
  final String? photoURL;
  final List<MenuItem> menu;
  final bool isOpen;
  final bool isFeatured;
  final String? promoText;

  Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    this.photoURL,
    this.menu = const [],
    this.isOpen = true,
    this.isFeatured = false,
    this.promoText,
  });

  factory Restaurant.fromMap(String id, Map<String, dynamic> m) => Restaurant(
        id: id,
        name: m['name'] ?? '',
        category: m['category'] ?? '',
        address: m['address'] ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        photoURL: m['photoURL'],
        menu: (m['menu'] as List? ?? [])
            .map((e) => MenuItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        isOpen: m['isOpen'] ?? true,
        isFeatured: m['isFeatured'] ?? false,
        promoText: m['promoText'],
      );
}

class StatusHistoryItem {
  final OrderStatus status;
  final int changedAt;
  final String changedBy;
  const StatusHistoryItem(
      {required this.status, required this.changedAt, required this.changedBy});

  Map<String, dynamic> toMap() =>
      {'status': enumToStr(status), 'changedAt': changedAt, 'changedBy': changedBy};

  factory StatusHistoryItem.fromMap(Map<String, dynamic> m) => StatusHistoryItem(
        status: _enumFromString(OrderStatus.values, m['status'], OrderStatus.DRAFT),
        changedAt: (m['changedAt'] as num?)?.toInt() ?? 0,
        changedBy: m['changedBy'] ?? '',
      );
}

class OrderLocation {
  final String address;
  final double lat;
  final double lng;
  final String? villageName;
  const OrderLocation(
      {required this.address, required this.lat, required this.lng, this.villageName});

  Map<String, dynamic> toMap() =>
      {'address': address, 'lat': lat, 'lng': lng, if (villageName != null) 'villageName': villageName};

  factory OrderLocation.fromMap(Map<String, dynamic> m) => OrderLocation(
        address: m['address'] ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        villageName: m['villageName'],
      );
}

class Order {
  final String id;
  final String customerId;
  final String customerPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverPhoto;
  final double? driverRating;
  final String operatorId;
  final String zoneId;
  final OrderCategory category;
  final OrderLocation pickup;
  final OrderLocation dropoff;
  final OrderStatus status;
  final List<StatusHistoryItem> statusHistory;
  final int updatedAt;
  final double price;
  final double distance;
  final double commission;
  final int createdAt;
  final String? notes;
  final int? passengerCount;
  final PaymentMethod paymentMethod;
  final VehicleType requestedVehicleType;
  final double? rating;
  final String? feedback;
  final List<CartItem> foodItems;
  final String? restaurantId;
  final String? restaurantName;
  final String? specialRequest;

  Order({
    required this.id,
    required this.customerId,
    required this.customerPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverPhoto,
    this.driverRating,
    required this.operatorId,
    required this.zoneId,
    required this.category,
    required this.pickup,
    required this.dropoff,
    required this.status,
    this.statusHistory = const [],
    required this.updatedAt,
    required this.price,
    required this.distance,
    required this.commission,
    required this.createdAt,
    this.notes,
    this.passengerCount,
    required this.paymentMethod,
    required this.requestedVehicleType,
    this.rating,
    this.feedback,
    this.foodItems = const [],
    this.restaurantId,
    this.restaurantName,
    this.specialRequest,
  });

  factory Order.fromMap(String id, Map<String, dynamic> m) => Order(
        id: id,
        customerId: m['customerId'] ?? '',
        customerPhone: m['customerPhone'] ?? '',
        driverId: m['driverId'],
        driverName: m['driverName'],
        driverPhone: m['driverPhone'],
        driverPhoto: m['driverPhoto'],
        driverRating: (m['driverRating'] as num?)?.toDouble(),
        operatorId: m['operatorId'] ?? '',
        zoneId: m['zoneId'] ?? '',
        category:
            _enumFromString(OrderCategory.values, m['category'], OrderCategory.TAXI),
        pickup: OrderLocation.fromMap(Map<String, dynamic>.from(m['pickup'] ?? {})),
        dropoff: OrderLocation.fromMap(Map<String, dynamic>.from(m['dropoff'] ?? {})),
        status: _enumFromString(OrderStatus.values, m['status'], OrderStatus.PENDING),
        statusHistory: (m['statusHistory'] as List? ?? [])
            .map((e) => StatusHistoryItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
        price: (m['price'] as num?)?.toDouble() ?? 0,
        distance: (m['distance'] as num?)?.toDouble() ?? 0,
        commission: (m['commission'] as num?)?.toDouble() ?? 0,
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
        notes: m['notes'],
        passengerCount: (m['passengerCount'] as num?)?.toInt(),
        paymentMethod:
            _enumFromString(PaymentMethod.values, m['paymentMethod'], PaymentMethod.CASH),
        requestedVehicleType: _enumFromString(
            VehicleType.values, m['requestedVehicleType'], VehicleType.TOKTOK),
        rating: (m['rating'] as num?)?.toDouble(),
        feedback: m['feedback'],
        foodItems: (m['foodItems'] as List? ?? [])
            .map((e) => CartItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        restaurantId: m['restaurantId'],
        restaurantName: m['restaurantName'],
        specialRequest: m['specialRequest'],
      );

  Map<String, dynamic> toCreateMap() => {
        'customerId': customerId,
        'customerPhone': customerPhone,
        'operatorId': operatorId,
        'zoneId': zoneId,
        'category': enumToStr(category),
        'pickup': pickup.toMap(),
        'dropoff': dropoff.toMap(),
        'status': enumToStr(status),
        'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
        'updatedAt': updatedAt,
        'price': price,
        'distance': distance,
        'commission': commission,
        'createdAt': createdAt,
        if (notes != null) 'notes': notes,
        if (passengerCount != null) 'passengerCount': passengerCount,
        'paymentMethod': enumToStr(paymentMethod),
        'requestedVehicleType': enumToStr(requestedVehicleType),
        'foodItems': foodItems.map((e) => e.toMap()).toList(),
        if (restaurantId != null) 'restaurantId': restaurantId,
        if (restaurantName != null) 'restaurantName': restaurantName,
        if (specialRequest != null) 'specialRequest': specialRequest,
      };
}

class Village {
  final String id;
  final String name;
  final GeoPointSimple center;
  const Village({required this.id, required this.name, required this.center});

  factory Village.fromMap(Map<String, dynamic> m) => Village(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        center: GeoPointSimple.fromMap(m['center']),
      );
}

class Zone {
  final String id;
  final String name;
  final String operatorId;
  final GeoPointSimple center;
  final List<Village> villages;
  Zone(
      {required this.id,
      required this.name,
      required this.operatorId,
      required this.center,
      this.villages = const []});

  factory Zone.fromMap(String id, Map<String, dynamic> m) => Zone(
        id: id,
        name: m['name'] ?? '',
        operatorId: m['operatorId'] ?? '',
        center: GeoPointSimple.fromMap(m['center']),
        villages: (m['villages'] as List? ?? [])
            .map((e) => Village.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

enum TransactionType { CREDIT, DEBIT }

/// حركة مالية في محفظة المستخدم - مقابلة لواجهة Transaction في WalletView.tsx
class WalletTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final int createdAt;
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(String id, Map<String, dynamic> m) => WalletTransaction(
        id: id,
        type: _enumFromString(TransactionType.values, m['type'], TransactionType.DEBIT),
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        description: m['description'] ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      );
}

enum PaymentRequestAction { TOPUP, WITHDRAW }

enum AdType { special_offer, restaurant, service, general }

/// إعلان/بانر ترويجي يظهر أعلى الرئيسية - مقابلة لواجهة Ad في types.ts
class Ad {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String ctaText;
  final AdType type;
  final String? targetId;
  final OrderCategory? targetCategory;
  final String? whatsappNumber;
  final bool isActive;
  final int displayOrder;
  final int views;
  final int clicks;
  final int createdAt;

  const Ad({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.ctaText,
    required this.type,
    this.targetId,
    this.targetCategory,
    this.whatsappNumber,
    this.isActive = true,
    this.displayOrder = 0,
    this.views = 0,
    this.clicks = 0,
    this.createdAt = 0,
  });

  factory Ad.fromMap(String id, Map<String, dynamic> m) => Ad(
        id: id,
        title: m['title'] ?? '',
        description: m['description'] ?? '',
        imageUrl: m['imageUrl'] ?? '',
        ctaText: m['ctaText'] ?? 'اطلب الآن',
        type: _enumFromString(AdType.values, m['type'], AdType.general),
        targetId: m['targetId'],
        targetCategory: m['targetCategory'] != null
            ? _enumFromString(OrderCategory.values, m['targetCategory'], OrderCategory.TAXI)
            : null,
        whatsappNumber: m['whatsappNumber'],
        isActive: m['isActive'] ?? true,
        displayOrder: (m['displayOrder'] as num?)?.toInt() ?? 0,
        views: (m['views'] as num?)?.toInt() ?? 0,
        clicks: (m['clicks'] as num?)?.toInt() ?? 0,
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      );
}

class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String text;
  final int createdAt;
  const ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) => ChatMessage(
        id: id,
        orderId: m['orderId'] ?? '',
        senderId: m['senderId'] ?? '',
        text: m['text'] ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      );
}
