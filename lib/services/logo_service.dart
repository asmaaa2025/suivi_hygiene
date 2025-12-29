/// Service pour gérer les logos et leur disponibilité
class LogoService {
  static LogoService? _instance;
  factory LogoService() {
    _instance ??= LogoService._internal();
    return _instance!;
  }
  LogoService._internal();

  /// Vérifie si un logo est disponible
  Future<bool> hasLogo() async {
    return true; // Logo toujours disponible car intégré dans le code
  }

  /// Récupère la commande ZPL du logo
  Future<String> getLogoCommand() async {
    // Logo intégré directement dans le code, positionné en bas à droite
    // Paramètres GFA: totalBytes, rowBytes, rows, resolution, data
    // Resolution: 8=normal, 16=épais, 24=très épais, 32=extra épais, 48=maximum
    return '''^FO500,250^GFA,2048,2048,16,48,,:::::::::::::::U08,,S07JF,R07F8001F,Q07FL06,P01F8,P07C,O01F,O07C,O0F,N03C,N078,N0F,M05C004,M07800C,M0FI08,L01E0018,L03C001,L038003,L07I02,K01EI06,K03EI04208,K03CI08038,K07800180E,K07I01038,K0FI030E,J01EI0238,J01EI06E,J03CI078,J03CI0E,J0380038,J0780078,J07I0DL0484189244,J07I0FL0448909044,J0EI06L0468509044,J0EI07L0438509864,J0EI048K0438509864,I01EI04L0448509I4,I01CI0CL0448899244,I01CI08L06040D9244,I01CI08,I01C001,I018001,I038002,:I038,:::::::::I018,:I01C,::J0C,J0EL0346C8204924,J0EL0224082408,J0EL02140824082,J06L0214082C0838,J07L0216882C0A0C,J07L021408240804,J038K022408240804,J038K0346C922092,J01C,:K0E,:K07,:K038,K01C,:L0E,L07,L038,L03C,L01E,M0F,M078,M03C,N0E,N07,N03C,O0E,O078,O01E,P078,P01E,Q07E,R0FE,S0JFC,,::::::::::::::^FS''';
  }
}
