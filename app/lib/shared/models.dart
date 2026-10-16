// Kelas data untuk tabel di docs/architecture.md bagian 4. Nama kolom DB snake_case, field Dart camelCase.

List<String> _strings(Object? v) => (v as List?)?.cast<String>() ?? const [];
double? _double(Object? v) => (v as num?)?.toDouble();
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
Map<String, dynamic>? _json(Object? v) => (v as Map?)?.cast<String, dynamic>();

class Profile {
  Profile.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        role = m['role'],
        fullName = m['full_name'],
        phone = m['phone'],
        phoneVerified = m['phone_verified'] ?? false,
        foundationId = m['foundation_id'],
        fcmToken = m['fcm_token'],
        nickname = m['nickname'],
        birthDate = _date(m['birth_date']),
        notifyOff = _strings(m['notify_off']),
        avatarPath = m['avatar_path'];

  final String id;
  final String role; // keluarga · relawan · yayasan
  final String? fullName;
  final String? phone;
  final bool phoneVerified;
  final String? foundationId;
  final String? fcmToken;
  final String? nickname;
  final DateTime? birthDate;
  final List<String> notifyOff; // kategori notifikasi yang dimatikan: kondisi · pendamping · pengingat
  final String? avatarPath; // bucket avatars (keluarga & yayasan)
}

class Foundation {
  Foundation.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'],
        verified = m['verified'] ?? false,
        inviteCode = m['invite_code'];

  final String id;
  final String name;
  final bool verified;
  final String inviteCode;
}

class Volunteer {
  Volunteer.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        foundationId = m['foundation_id'],
        status = m['status'],
        areaLabel = m['area_label'],
        lat = _double(m['lat']),
        lng = _double(m['lng']),
        availableDays = _strings(m['available_days']),
        languages = _strings(m['languages']),
        canDementia = m['can_dementia'] ?? false,
        canMobility = m['can_mobility'] ?? false,
        photoPath = m['photo_path'],
        idCheckedBy = m['id_checked_by'],
        idCheckedAt = _date(m['id_checked_at']),
        orientedBy = m['oriented_by'],
        orientedAt = _date(m['oriented_at']),
        maxLoad = m['max_load'] ?? 3,
        statusNote = m['status_note'],
        resignReason = m['resign_reason'],
        resignRequestedAt = _date(m['resign_requested_at']);

  final String id;
  final String foundationId;
  final String status; // terdaftar · aktif
  final String? areaLabel;
  final double? lat;
  final double? lng;
  final List<String> availableDays;
  final List<String> languages;
  final bool canDementia;
  final bool canMobility;
  final String? photoPath;
  final String? idCheckedBy;
  final DateTime? idCheckedAt;
  final String? orientedBy;
  final DateTime? orientedAt;
  final int maxLoad;
  final String? statusNote; // mis. alasan dinonaktifkan yayasan
  final String? resignReason;
  final DateTime? resignRequestedAt; // pengunduran diri menunggu yayasan
}

class Elder {
  Elder.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        familyId = m['family_id'],
        fullName = m['full_name'],
        address = m['address'],
        lat = _double(m['lat']),
        lng = _double(m['lng']),
        needs = m['needs'],
        hasDementia = m['has_dementia'] ?? false,
        hasMobilityIssue = m['has_mobility_issue'] ?? false,
        volunteerId = m['volunteer_id'],
        foundationId = m['foundation_id'],
        pairingState = m['pairing_state'],
        status = m['status'],
        statusReason = m['status_reason'],
        endedReason = m['ended_reason'],
        endedAt = _date(m['ended_at']),
        statusAckAt = _date(m['status_ack_at']),
        statusAckBy = m['status_ack_by'],
        statusAckNote = m['status_ack_note'],
        paidUntil = _date(m['paid_until']),
        verifyState = m['verify_state'] ?? 'belum',
        verifyNote = m['verify_note'],
        firstVisitAt = _date(m['first_visit_at']),
        pairedAt = _date(m['paired_at']),
        birthDate = _date(m['birth_date']),
        photoPath = m['photo_path'],
        scheduleWeekday = m['schedule_weekday'],
        scheduleTime = m['schedule_time'],
        scheduleStatus = m['schedule_status'],
        scheduleShiftAt = _date(m['schedule_shift_at']);

  final String id;
  final String familyId;
  final String fullName;
  final String address;
  final double? lat;
  final double? lng;
  final String? needs;
  final bool hasDementia;
  final bool hasMobilityIssue;
  final String? volunteerId;
  final String? foundationId;
  final String pairingState; // mencari · menunggu_keluarga · berpasangan · tanpa_pendamping · perlu_yayasan · selesai
  final String status; // stabil · perlu_perhatian · segera_dikabari
  final String? statusReason;
  final String? endedReason; // diisi saat pendampingan selesai
  final DateTime? endedAt;
  final DateTime? statusAckAt; // status sudah ditangani keluarga/yayasan (hilang saat status dihitung ulang)
  final String? statusAckBy;
  final String? statusAckNote;
  final DateTime? paidUntil; // langganan per lansia (simulasi untuk demo)
  final String verifyState; // belum · menunggu · terverifikasi · ditolak (dokumen keluarga diperiksa yayasan)
  final String? verifyNote; // alasan penolakan dokumen
  final DateTime? firstVisitAt; // relawan memastikan lansia ada & setuju
  final DateTime? pairedAt; // pasangan saat ini dimulai (trigger elders_paired_at)
  final DateTime? birthDate;
  final String? photoPath; // bucket elder-photos
  final int? scheduleWeekday; // jadwal kunjungan rutin: 1 = Senin … 7 = Minggu
  final String? scheduleTime; // "HH:MM:SS" (WIB)
  final String? scheduleStatus; // diusulkan · disetujui
  final DateTime? scheduleShiftAt; // satu kunjungan digeser relawan

  bool get paid => paidUntil != null && paidUntil!.isAfter(DateTime.now());

  /// Pendaftar masih harus berlangganan atau mengirim (ulang) dokumen sebelum relawan dicarikan.
  bool get needsSetup => !paid || verifyState == 'belum' || verifyState == 'ditolak';
}

class HealthProfile {
  HealthProfile.fromMap(Map<String, dynamic> m)
      : elderId = m['elder_id'],
        conditions = m['conditions'],
        allergies = m['allergies'],
        medications = ((m['medications'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        dietRestrictions = m['diet_restrictions'],
        mobilityAids = m['mobility_aids'],
        mobility = m['mobility'],
        doctorHospital = m['doctor_hospital'],
        emergencyInstructions = m['emergency_instructions'],
        hasChronic = m['has_chronic'] ?? false;

  final String elderId;
  final String? conditions;
  final String? allergies;
  final List<Map<String, dynamic>> medications; // [{name, times}]
  final String? dietRestrictions;
  final String? mobilityAids; // alat bantu
  final String? mobility; // kemampuan bergerak
  final String? doctorHospital;
  final String? emergencyInstructions;
  final bool hasChronic;
}

class Proposal {
  Proposal.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        elderId = m['elder_id'],
        volunteerId = m['volunteer_id'],
        attempt = m['attempt'],
        distanceKm = _double(m['distance_km']),
        reasonText = m['reason_text'],
        state = m['state'],
        rejectReason = m['reject_reason'],
        rejectNote = m['reject_note'];

  final String id;
  final String elderId;
  final String volunteerId;
  final int attempt; // 1..3
  final double? distanceKm;
  final String? reasonText;
  final String state; // pending · accepted · rejected · manual
  final String? rejectReason; // jarak · jadwal · bahasa · lainnya
  final String? rejectNote;
}

class Visit {
  Visit.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        elderId = m['elder_id'],
        volunteerId = m['volunteer_id'],
        visitedAt = DateTime.parse(m['visited_at']),
        answers = _json(m['answers']) ?? const {},
        aiResult = _json(m['ai_result']),
        finalResult = _json(m['final_result']),
        overrides = _json(m['overrides']),
        confirmedAt = _date(m['confirmed_at']),
        statusAfter = m['status_after'];

  final String id;
  final String elderId;
  final String? volunteerId; // null bila akun relawan sudah dihapus
  final DateTime visitedAt;
  final Map<String, dynamic> answers; // {makan, obat, gerak, harian, ingatan, hati, lain}
  final Map<String, dynamic>? aiResult; // {domain: {level, evidence}, red_flags: [...]}
  final Map<String, dynamic>? finalResult;
  final Map<String, dynamic>? overrides; // koreksi relawan yang menurunkan penilaian AI, beserta alasannya
  final DateTime? confirmedAt;
  final String? statusAfter; // status lansia setelah kunjungan ini (kosong untuk kunjungan lama)
}

class Emergency {
  Emergency.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        elderId = m['elder_id'],
        volunteerId = m['volunteer_id'],
        lat = _double(m['lat']),
        lng = _double(m['lng']),
        summary = m['summary'],
        notified = m['notified'] ?? false,
        createdAt = _date(m['created_at']);

  final String id;
  final String elderId;
  final String? volunteerId; // null bila akun relawan sudah dihapus
  final double? lat;
  final double? lng;
  final String? summary;
  final bool notified;
  final DateTime? createdAt;
}
