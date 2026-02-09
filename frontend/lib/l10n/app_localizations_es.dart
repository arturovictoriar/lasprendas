// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'LAS PRENDAS';

  @override
  String get login => 'INICIAR SESIÓN';

  @override
  String get register => 'REGISTRARSE';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get name => 'Nombre';

  @override
  String get enterName => 'Ingrese nombre';

  @override
  String get enterEmail => 'Ingrese correo electrónico';

  @override
  String get enterPassword => 'Ingrese contraseña';

  @override
  String get forgotPassword => '¿Olvidó su contraseña?';

  @override
  String get needAccount => '¿No tiene una cuenta? Regístrese';

  @override
  String get haveAccount => '¿Ya tiene una cuenta? Inicie sesión';

  @override
  String get termsAndConditions => 'Términos y Condiciones';

  @override
  String get acceptTermsPrefix => 'Acepto los ';

  @override
  String get acceptTermsSuffix =>
      ', autorizando el procesamiento de mis fotos mediante IA para generar imágenes derivadas y reconociendo el acceso administrativo a mi contenido para fines de soporte y mejora del servicio.';

  @override
  String get termsModalTitle => 'TÉRMINOS Y CONDICIONES';

  @override
  String get profileTitle => 'MI PERFIL';

  @override
  String get profileNameLabel => 'NOMBRE';

  @override
  String get profileEmailLabel => 'CORREO ELECTRÓNICO';

  @override
  String get logout => 'CERRAR SESIÓN';

  @override
  String get closetTitle => 'CLOSET';

  @override
  String get myGarmentsTab => 'MIS PRENDAS';

  @override
  String get myOutfitsTab => 'MIS OUTFITS';

  @override
  String get selectButton => 'SELECCIONAR';

  @override
  String get cancel => 'CANCELAR';

  @override
  String get deleteSelected => 'ELIMINAR';

  @override
  String get camera => 'CÁMARA';

  @override
  String get gallery => 'GALERÍA';

  @override
  String get paste => 'PEGAR';

  @override
  String get closetButton => 'CLOSET';

  @override
  String get selectGarmentsPrompt => 'SELECCIONA PRENDAS';

  @override
  String dressButton(int count) {
    return 'VESTIR ($count/10)';
  }

  @override
  String useButton(int count) {
    return 'USAR ($count/10)';
  }

  @override
  String get retakeOutfit => 'RETOMAR ESTE OUTFIT';

  @override
  String get garmentsUsed => 'PRENDAS UTILIZADAS';

  @override
  String get dressingStatus1 => 'Vistiendo';

  @override
  String get dressingStatus2 => 'Ajustando';

  @override
  String get dressingStatus3 => 'Retocando';

  @override
  String get dressingStatus4 => 'Modelando';

  @override
  String get dressingStatus5 => 'Estilando';

  @override
  String get dressingStatus6 => 'Entallando';

  @override
  String get dressingStatus7 => 'Puliendo';

  @override
  String get dressingStatus8 => 'Combinando';

  @override
  String get dressingStatus9 => 'Entelando';

  @override
  String get dressingStatus10 => 'Cociendo';

  @override
  String get dressingStatus11 => 'Probando';

  @override
  String get loading => 'Cargando...';

  @override
  String get errorLoadingResult => 'Error cargando resultado';

  @override
  String get waiting => 'Esperando...';

  @override
  String get noGarmentsSaved => 'Aún no tienes prendas guardadas';

  @override
  String get noOutfitsSaved => 'Aún no tienes outfits guardados';

  @override
  String get allCategories => 'Todas';

  @override
  String get shirtsCategory => 'Camisas';

  @override
  String get pantsCategory => 'Pantalones';

  @override
  String get shoesCategory => 'Zapatos';

  @override
  String get skirtsCategory => 'Faldas';

  @override
  String get jacketsCategory => 'Chaquetas';

  @override
  String get accessoriesCategory => 'Accesorios';

  @override
  String get selectGarments => 'Seleccionar';

  @override
  String get confirmDeleteTitle => 'Confirmar eliminación';

  @override
  String deleteItemConfirm(int count, String itemType) {
    return '¿Eliminar $count $itemType?';
  }

  @override
  String get prenda => 'prenda';

  @override
  String get prendas => 'prendas';

  @override
  String get outfit => 'outfit';

  @override
  String get outfits => 'outfits';

  @override
  String get forgotPasswordTitle => 'RECUPERAR CONTRASEÑA';

  @override
  String get forgotPasswordInstruction =>
      'Ingresa tu email para recibir un código de verificación.';

  @override
  String get sendCode => 'ENVIAR CÓDIGO';

  @override
  String get verificationTitle => 'VERIFICACIÓN';

  @override
  String get verificationInstruction =>
      'Ingresa el código de 6 dígitos enviado a';

  @override
  String get verify => 'VERIFICAR';

  @override
  String get resendCode => 'Reenviar código';

  @override
  String codeWillExpire(String time) {
    return 'El código expirará en $time';
  }

  @override
  String get newPasswordTitle => 'NUEVA CONTRASEÑA';

  @override
  String get newPasswordLabel => 'Nueva Contraseña';

  @override
  String get confirmPasswordLabel => 'Confirmar Contraseña';

  @override
  String get resetPasswordButton => 'RESETEAR CONTRASEÑA';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get passwordResetSuccess =>
      '¡Contraseña restablecida con éxito! Por favor inicie sesión.';

  @override
  String get minCharacters => 'Mínimo 6 caracteres';

  @override
  String get confirmYourPassword => 'Confirma tu contraseña';

  @override
  String get codeInvalidated => 'CÓDIGO INVALIDADO';

  @override
  String resendAvailableIn(String time) {
    return 'Reenvío disponible en $time';
  }

  @override
  String get continueButton => 'CONTINUAR';

  @override
  String get resendSuccess => '¡Código reenviado con éxito!';

  @override
  String get resendError => 'Error al reenviar el código';

  @override
  String get resetPasswordError => 'Falló al restablecer la contraseña.';

  @override
  String get codeRequestError => 'Error al enviar el código';

  @override
  String get loginFailed => 'Error al iniciar sesión';

  @override
  String get registerFailed => 'Error al registrarse';

  @override
  String get termsContent =>
      'Última actualización: 07 de febrero de 2026\n\nAl crear una cuenta en la aplicación Las Prendas, usted (el \"Usuario\") acepta los siguientes términos:\n\n1. NATURALEZA DEL SERVICIO\nLas Prendas es una plataforma de probador virtual que permite a los usuarios subir imágenes de prendas de vestir y fotografías personales para visualizar combinaciones de ropa mediante procesamiento digital.\n\n2. CONTENIDO GENERADO POR EL USUARIO\nEl Usuario es el único responsable de las imágenes, fotografías y cualquier material (el \"Contenido\") que suba a la plataforma. El Usuario garantiza que tiene los derechos legales sobre dicho contenido y que no infringe derechos de terceros ni contiene material ilegal u ofensivo.\n\n3. ACCESO ADMINISTRATIVO Y PRIVACIDAD\nEl Usuario reconoce y acepta que los administradores de la plataforma tienen acceso total al Contenido subido y generado dentro de la aplicación. Este acceso se utiliza exclusivamente para: Mantenimiento técnico, soporte al Usuario, moderación de contenido y mejora de algoritmos.\n\n4. PROCESAMIENTO DE IMÁGENES Y OBRAS DERIVADAS\nAl usar Las Prendas, el Usuario otorga una licencia expresa a la plataforma para: Procesamiento mediante IA para analizar fotos subidas y creación de nuevas imágenes que resulten de la combinación del contenido del Usuario.\n\n5. PROPIEDAD INTELECTUAL\nEl Usuario conserva la propiedad de sus fotos originales. Las Prendas otorga al Usuario una licencia de uso personal sobre las imágenes generadas dentro de la app.\n\n6. USO ACEPTABLE\nQueda terminantemente prohibido subir contenido que incluya desnudez, contenido sexual explícito, imágenes de terceros sin consentimiento o material que incite al odio.\n\n7. LIMITACIÓN DE RESPONSABILIDAD\nLas Prendas no se hace responsable por el uso indebido que terceros puedan hacer de las imágenes si el usuario decide compartirlas fuera de la aplicación.';
}
