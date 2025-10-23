class Country {
  final String id;
  final String name;

  Country({
    required this.id,
    required this.name,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name'] ?? json['name'] ?? json['Nm'] ?? '',
    );
  }
}

class StateRegion {
  final String id;
  final String name;
  final String countryId;

  StateRegion({
    required this.id,
    required this.name,
    required this.countryId,
  });

  factory StateRegion.fromJson(Map<String, dynamic> json) {
    return StateRegion(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name'] ?? json['name'] ?? json['Nm'] ?? '',
      countryId: json['CountryId']?.toString() ?? json['countryId']?.toString() ?? json['CntId']?.toString() ?? '',
    );
  }
}

class City {
  final String id;
  final String name;
  final String stateId;

  City({
    required this.id,
    required this.name,
    required this.stateId,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name'] ?? json['name'] ?? json['Nm'] ?? '',
      stateId: json['StateId']?.toString() ?? json['stateId']?.toString() ?? json['StId']?.toString() ?? '',
    );
  }
}
