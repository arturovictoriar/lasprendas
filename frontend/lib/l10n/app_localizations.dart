import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'LAS PRENDAS'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In es, this message translates to:
  /// **'INICIAR SESIÓN'**
  String get login;

  /// No description provided for @register.
  ///
  /// In es, this message translates to:
  /// **'REGISTRARSE'**
  String get register;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @name.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get name;

  /// No description provided for @enterName.
  ///
  /// In es, this message translates to:
  /// **'Ingrese nombre'**
  String get enterName;

  /// No description provided for @enterEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingrese correo electrónico'**
  String get enterEmail;

  /// No description provided for @enterPassword.
  ///
  /// In es, this message translates to:
  /// **'Ingrese contraseña'**
  String get enterPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidó su contraseña?'**
  String get forgotPassword;

  /// No description provided for @needAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tiene una cuenta? Regístrese'**
  String get needAccount;

  /// No description provided for @haveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tiene una cuenta? Inicie sesión'**
  String get haveAccount;

  /// No description provided for @termsAndConditions.
  ///
  /// In es, this message translates to:
  /// **'Términos y Condiciones'**
  String get termsAndConditions;

  /// No description provided for @acceptTermsPrefix.
  ///
  /// In es, this message translates to:
  /// **'Acepto los '**
  String get acceptTermsPrefix;

  /// No description provided for @acceptTermsSuffix.
  ///
  /// In es, this message translates to:
  /// **', autorizando el procesamiento de mis fotos mediante IA para generar imágenes derivadas y reconociendo el acceso administrativo a mi contenido para fines de soporte y mejora del servicio.'**
  String get acceptTermsSuffix;

  /// No description provided for @termsModalTitle.
  ///
  /// In es, this message translates to:
  /// **'TÉRMINOS Y CONDICIONES'**
  String get termsModalTitle;

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'MI PERFIL'**
  String get profileTitle;

  /// No description provided for @profileNameLabel.
  ///
  /// In es, this message translates to:
  /// **'NOMBRE'**
  String get profileNameLabel;

  /// No description provided for @profileEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'CORREO ELECTRÓNICO'**
  String get profileEmailLabel;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'CERRAR SESIÓN'**
  String get logout;

  /// No description provided for @closetTitle.
  ///
  /// In es, this message translates to:
  /// **'CLOSET'**
  String get closetTitle;

  /// No description provided for @myGarmentsTab.
  ///
  /// In es, this message translates to:
  /// **'MIS PRENDAS'**
  String get myGarmentsTab;

  /// No description provided for @myOutfitsTab.
  ///
  /// In es, this message translates to:
  /// **'MIS OUTFITS'**
  String get myOutfitsTab;

  /// No description provided for @selectButton.
  ///
  /// In es, this message translates to:
  /// **'SELECCIONAR'**
  String get selectButton;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'CANCELAR'**
  String get cancel;

  /// No description provided for @deleteSelected.
  ///
  /// In es, this message translates to:
  /// **'ELIMINAR'**
  String get deleteSelected;

  /// No description provided for @camera.
  ///
  /// In es, this message translates to:
  /// **'CÁMARA'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In es, this message translates to:
  /// **'GALERÍA'**
  String get gallery;

  /// No description provided for @paste.
  ///
  /// In es, this message translates to:
  /// **'PEGAR'**
  String get paste;

  /// No description provided for @closetButton.
  ///
  /// In es, this message translates to:
  /// **'CLOSET'**
  String get closetButton;

  /// No description provided for @selectGarmentsPrompt.
  ///
  /// In es, this message translates to:
  /// **'SELECCIONA PRENDAS'**
  String get selectGarmentsPrompt;

  /// No description provided for @dressButton.
  ///
  /// In es, this message translates to:
  /// **'VESTIR ({count}/10)'**
  String dressButton(int count);

  /// No description provided for @useButton.
  ///
  /// In es, this message translates to:
  /// **'USAR ({count}/10)'**
  String useButton(int count);

  /// No description provided for @retakeOutfit.
  ///
  /// In es, this message translates to:
  /// **'RETOMAR ESTE OUTFIT'**
  String get retakeOutfit;

  /// No description provided for @garmentsUsed.
  ///
  /// In es, this message translates to:
  /// **'PRENDAS UTILIZADAS'**
  String get garmentsUsed;

  /// No description provided for @dressingStatus1.
  ///
  /// In es, this message translates to:
  /// **'Vistiendo'**
  String get dressingStatus1;

  /// No description provided for @dressingStatus2.
  ///
  /// In es, this message translates to:
  /// **'Ajustando'**
  String get dressingStatus2;

  /// No description provided for @dressingStatus3.
  ///
  /// In es, this message translates to:
  /// **'Retocando'**
  String get dressingStatus3;

  /// No description provided for @dressingStatus4.
  ///
  /// In es, this message translates to:
  /// **'Modelando'**
  String get dressingStatus4;

  /// No description provided for @dressingStatus5.
  ///
  /// In es, this message translates to:
  /// **'Estilando'**
  String get dressingStatus5;

  /// No description provided for @dressingStatus6.
  ///
  /// In es, this message translates to:
  /// **'Entallando'**
  String get dressingStatus6;

  /// No description provided for @dressingStatus7.
  ///
  /// In es, this message translates to:
  /// **'Puliendo'**
  String get dressingStatus7;

  /// No description provided for @dressingStatus8.
  ///
  /// In es, this message translates to:
  /// **'Combinando'**
  String get dressingStatus8;

  /// No description provided for @dressingStatus9.
  ///
  /// In es, this message translates to:
  /// **'Entelando'**
  String get dressingStatus9;

  /// No description provided for @dressingStatus10.
  ///
  /// In es, this message translates to:
  /// **'Cociendo'**
  String get dressingStatus10;

  /// No description provided for @dressingStatus11.
  ///
  /// In es, this message translates to:
  /// **'Probando'**
  String get dressingStatus11;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando...'**
  String get loading;

  /// No description provided for @errorLoadingResult.
  ///
  /// In es, this message translates to:
  /// **'Error cargando resultado'**
  String get errorLoadingResult;

  /// No description provided for @waiting.
  ///
  /// In es, this message translates to:
  /// **'Esperando...'**
  String get waiting;

  /// No description provided for @noGarmentsSaved.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes prendas guardadas'**
  String get noGarmentsSaved;

  /// No description provided for @noOutfitsSaved.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes outfits guardados'**
  String get noOutfitsSaved;

  /// No description provided for @allCategories.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get allCategories;

  /// No description provided for @shirtsCategory.
  ///
  /// In es, this message translates to:
  /// **'Camisas'**
  String get shirtsCategory;

  /// No description provided for @pantsCategory.
  ///
  /// In es, this message translates to:
  /// **'Pantalones'**
  String get pantsCategory;

  /// No description provided for @shoesCategory.
  ///
  /// In es, this message translates to:
  /// **'Zapatos'**
  String get shoesCategory;

  /// No description provided for @skirtsCategory.
  ///
  /// In es, this message translates to:
  /// **'Faldas'**
  String get skirtsCategory;

  /// No description provided for @jacketsCategory.
  ///
  /// In es, this message translates to:
  /// **'Chaquetas'**
  String get jacketsCategory;

  /// No description provided for @accessoriesCategory.
  ///
  /// In es, this message translates to:
  /// **'Accesorios'**
  String get accessoriesCategory;

  /// No description provided for @selectGarments.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar'**
  String get selectGarments;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirmar eliminación'**
  String get confirmDeleteTitle;

  /// No description provided for @deleteItemConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar {count} {itemType}?'**
  String deleteItemConfirm(int count, String itemType);

  /// No description provided for @prenda.
  ///
  /// In es, this message translates to:
  /// **'prenda'**
  String get prenda;

  /// No description provided for @prendas.
  ///
  /// In es, this message translates to:
  /// **'prendas'**
  String get prendas;

  /// No description provided for @outfit.
  ///
  /// In es, this message translates to:
  /// **'outfit'**
  String get outfit;

  /// No description provided for @outfits.
  ///
  /// In es, this message translates to:
  /// **'outfits'**
  String get outfits;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'RECUPERAR CONTRASEÑA'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordInstruction.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu email para recibir un código de verificación.'**
  String get forgotPasswordInstruction;

  /// No description provided for @sendCode.
  ///
  /// In es, this message translates to:
  /// **'ENVIAR CÓDIGO'**
  String get sendCode;

  /// No description provided for @verificationTitle.
  ///
  /// In es, this message translates to:
  /// **'VERIFICACIÓN'**
  String get verificationTitle;

  /// No description provided for @verificationInstruction.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código de 6 dígitos enviado a'**
  String get verificationInstruction;

  /// No description provided for @verify.
  ///
  /// In es, this message translates to:
  /// **'VERIFICAR'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In es, this message translates to:
  /// **'Reenviar código'**
  String get resendCode;

  /// No description provided for @codeWillExpire.
  ///
  /// In es, this message translates to:
  /// **'El código expirará en {time}'**
  String codeWillExpire(String time);

  /// No description provided for @newPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'NUEVA CONTRASEÑA'**
  String get newPasswordTitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Nueva Contraseña'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar Contraseña'**
  String get confirmPasswordLabel;

  /// No description provided for @resetPasswordButton.
  ///
  /// In es, this message translates to:
  /// **'RESETEAR CONTRASEÑA'**
  String get resetPasswordButton;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Contraseña restablecida con éxito! Por favor inicie sesión.'**
  String get passwordResetSuccess;

  /// No description provided for @minCharacters.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get minCharacters;

  /// No description provided for @confirmYourPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu contraseña'**
  String get confirmYourPassword;

  /// No description provided for @codeInvalidated.
  ///
  /// In es, this message translates to:
  /// **'CÓDIGO INVALIDADO'**
  String get codeInvalidated;

  /// No description provided for @resendAvailableIn.
  ///
  /// In es, this message translates to:
  /// **'Reenvío disponible en {time}'**
  String resendAvailableIn(String time);

  /// No description provided for @continueButton.
  ///
  /// In es, this message translates to:
  /// **'CONTINUAR'**
  String get continueButton;

  /// No description provided for @resendSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Código reenviado con éxito!'**
  String get resendSuccess;

  /// No description provided for @resendError.
  ///
  /// In es, this message translates to:
  /// **'Error al reenviar el código'**
  String get resendError;

  /// No description provided for @resetPasswordError.
  ///
  /// In es, this message translates to:
  /// **'Falló al restablecer la contraseña.'**
  String get resetPasswordError;

  /// No description provided for @codeRequestError.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar el código'**
  String get codeRequestError;

  /// No description provided for @loginFailed.
  ///
  /// In es, this message translates to:
  /// **'Error al iniciar sesión'**
  String get loginFailed;

  /// No description provided for @registerFailed.
  ///
  /// In es, this message translates to:
  /// **'Error al registrarse'**
  String get registerFailed;

  /// No description provided for @termsContent.
  ///
  /// In es, this message translates to:
  /// **'Última actualización: 07 de febrero de 2026\n\nAl crear una cuenta en la aplicación Las Prendas, usted (el \"Usuario\") acepta los siguientes términos:\n\n1. NATURALEZA DEL SERVICIO\nLas Prendas es una plataforma de probador virtual que permite a los usuarios subir imágenes de prendas de vestir y fotografías personales para visualizar combinaciones de ropa mediante procesamiento digital.\n\n2. CONTENIDO GENERADO POR EL USUARIO\nEl Usuario es el único responsable de las imágenes, fotografías y cualquier material (el \"Contenido\") que suba a la plataforma. El Usuario garantiza que tiene los derechos legales sobre dicho contenido y que no infringe derechos de terceros ni contiene material ilegal u ofensivo.\n\n3. ACCESO ADMINISTRATIVO Y PRIVACIDAD\nEl Usuario reconoce y acepta que los administradores de la plataforma tienen acceso total al Contenido subido y generado dentro de la aplicación. Este acceso se utiliza exclusivamente para: Mantenimiento técnico, soporte al Usuario, moderación de contenido y mejora de algoritmos.\n\n4. PROCESAMIENTO DE IMÁGENES Y OBRAS DERIVADAS\nAl usar Las Prendas, el Usuario otorga una licencia expresa a la plataforma para: Procesamiento mediante IA para analizar fotos subidas y creación de nuevas imágenes que resulten de la combinación del contenido del Usuario.\n\n5. PROPIEDAD INTELECTUAL\nEl Usuario conserva la propiedad de sus fotos originales. Las Prendas otorga al Usuario una licencia de uso personal sobre las imágenes generadas dentro de la app.\n\n6. USO ACEPTABLE\nQueda terminantemente prohibido subir contenido que incluya desnudez, contenido sexual explícito, imágenes de terceros sin consentimiento o material que incite al odio.\n\n7. LIMITACIÓN DE RESPONSABILIDAD\nLas Prendas no se hace responsable por el uso indebido que terceros puedan hacer de las imágenes si el usuario decide compartirlas fuera de la aplicación.'**
  String get termsContent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
