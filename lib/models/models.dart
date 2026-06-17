class Organization {
  final String id;
  final String name;
  final String sportType;
  final String inviteCode;
  final String ownerId;

  Organization({required this.id, required this.name, required this.sportType,
      required this.inviteCode, required this.ownerId});

  factory Organization.fromJson(Map<String, dynamic> j) => Organization(
    id: j['id'], name: j['name'], sportType: j['sport_type'],
    inviteCode: j['invite_code'], ownerId: j['owner_id'],
  );
}

class Court {
  final String id;
  final String organizationId;
  final String name;
  final bool isActive;
  final String openFrom;
  final String openUntil;

  Court({required this.id, required this.organizationId, required this.name,
      required this.isActive, required this.openFrom, required this.openUntil});

  factory Court.fromJson(Map<String, dynamic> j) => Court(
    id: j['id'], organizationId: j['organization_id'], name: j['name'],
    isActive: j['is_active'] ?? true,
    openFrom: j['open_from'] ?? '07:00',
    openUntil: j['open_until'] ?? '22:00',
  );
}

class Booking {
  final String id;
  final String courtId;
  final String profileId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? infoId;
  final String? displayName;
  final String? infoLabel;

  Booking({required this.id, required this.courtId, required this.profileId,
      required this.startTime, required this.endTime, required this.status,
      this.infoId, this.displayName, this.infoLabel});

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: j['id'], courtId: j['court_id'], profileId: j['profile_id'],
    startTime: DateTime.parse(j['start_time']).toLocal(),
    endTime: DateTime.parse(j['end_time']).toLocal(),
    status: j['status'],
    infoId: j['info_id'],
    displayName: j['profiles']?['display_name'],
    infoLabel: j['profile_infos']?['label'],
  );
}

class ProfileInfo {
  final String id;
  final String profileId;
  final String label;

  ProfileInfo({required this.id, required this.profileId, required this.label});

  factory ProfileInfo.fromJson(Map<String, dynamic> j) => ProfileInfo(
    id: j['id'], profileId: j['profile_id'], label: j['label'],
  );
}
