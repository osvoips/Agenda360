import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/professional.dart';
import '../models/service.dart';

/// Estado do wizard de agendamento, vivo durante toda a navegação entre as
/// telas de Home até Success (criado uma vez em main.dart).
class BookingController extends ChangeNotifier {
  String? clientName;
  String? clientPhone;
  Service? selectedService;
  Professional? selectedProfessional;
  DateTime? selectedSlot;
  Appointment? confirmedAppointment;

  void setClientInfo({required String name, required String phone}) {
    clientName = name;
    clientPhone = phone;
    notifyListeners();
  }

  void selectService(Service service) {
    if (selectedService?.id != service.id) {
      // trocar de serviço invalida profissional/horário escolhidos antes
      selectedProfessional = null;
      selectedSlot = null;
    }
    selectedService = service;
    notifyListeners();
  }

  void selectProfessional(Professional professional) {
    if (selectedProfessional?.id != professional.id) {
      selectedSlot = null;
    }
    selectedProfessional = professional;
    notifyListeners();
  }

  void selectSlot(DateTime slot) {
    selectedSlot = slot;
    notifyListeners();
  }

  void confirmAppointment(Appointment appointment) {
    confirmedAppointment = appointment;
    notifyListeners();
  }

  void reset() {
    clientName = null;
    clientPhone = null;
    selectedService = null;
    selectedProfessional = null;
    selectedSlot = null;
    confirmedAppointment = null;
    notifyListeners();
  }
}
