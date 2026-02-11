// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LAS PRENDAS';

  @override
  String get login => 'LOGIN';

  @override
  String get register => 'REGISTER';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get name => 'Name';

  @override
  String get enterName => 'Enter name';

  @override
  String get enterEmail => 'Enter email';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get needAccount => 'Need an account? Register';

  @override
  String get haveAccount => 'Have an account? Login';

  @override
  String get termsAndConditions => 'Terms and Conditions';

  @override
  String get acceptTermsPrefix => 'I accept the ';

  @override
  String get acceptTermsSuffix =>
      ', authorizing the processing of my photos via AI to generate derivative images and acknowledging administrative access to my content for support and service improvement purposes.';

  @override
  String get termsModalTitle => 'TERMS AND CONDITIONS';

  @override
  String get profileTitle => 'MY PROFILE';

  @override
  String get profileNameLabel => 'NAME';

  @override
  String get profileEmailLabel => 'EMAIL';

  @override
  String get logout => 'LOGOUT';

  @override
  String get closetTitle => 'CLOSET';

  @override
  String get myGarmentsTab => 'MY GARMENTS';

  @override
  String get myOutfitsTab => 'MY OUTFITS';

  @override
  String get selectButton => 'SELECT';

  @override
  String get cancel => 'CANCEL';

  @override
  String get deleteSelected => 'DELETE';

  @override
  String get camera => 'CAMERA';

  @override
  String get gallery => 'GALLERY';

  @override
  String get paste => 'PASTE';

  @override
  String get closetButton => 'CLOSET';

  @override
  String get selectGarmentsPrompt => 'SELECT GARMENTS';

  @override
  String dressButton(int count) {
    return 'DRESS ($count/10)';
  }

  @override
  String useButton(int count) {
    return 'USE ($count/10)';
  }

  @override
  String get retakeOutfit => 'RETAKE THIS OUTFIT';

  @override
  String get garmentsUsed => 'GARMENTS USED';

  @override
  String get dressingStatus1 => 'Dressing';

  @override
  String get dressingStatus2 => 'Adjusting';

  @override
  String get dressingStatus3 => 'Retouching';

  @override
  String get dressingStatus4 => 'Modeling';

  @override
  String get dressingStatus5 => 'Styling';

  @override
  String get dressingStatus6 => 'Fitting';

  @override
  String get dressingStatus7 => 'Polishing';

  @override
  String get dressingStatus8 => 'Combining';

  @override
  String get dressingStatus9 => 'Texturing';

  @override
  String get dressingStatus10 => 'Sewing';

  @override
  String get dressingStatus11 => 'Testing';

  @override
  String get loading => 'Loading...';

  @override
  String get errorLoadingResult => 'Error loading result';

  @override
  String get waiting => 'Waiting...';

  @override
  String get noGarmentsSaved => 'You don\'t have saved garments yet';

  @override
  String get noOutfitsSaved => 'You don\'t have saved outfits yet';

  @override
  String get allCategories => 'All';

  @override
  String get shirtsCategory => 'Shirts';

  @override
  String get pantsCategory => 'Pants';

  @override
  String get shoesCategory => 'Shoes';

  @override
  String get skirtsCategory => 'Skirts';

  @override
  String get jacketsCategory => 'Jackets';

  @override
  String get accessoriesCategory => 'Accessories';

  @override
  String get selectGarments => 'Select';

  @override
  String get confirmDeleteTitle => 'Confirm deletion';

  @override
  String deleteItemConfirm(int count, String itemType) {
    return 'Delete $count $itemType?';
  }

  @override
  String get prenda => 'garment';

  @override
  String get prendas => 'garments';

  @override
  String get outfit => 'outfit';

  @override
  String get outfits => 'outfits';

  @override
  String get forgotPasswordTitle => 'RESET PASSWORD';

  @override
  String get forgotPasswordInstruction =>
      'Enter your email to receive a verification code.';

  @override
  String get sendCode => 'SEND CODE';

  @override
  String get verificationTitle => 'VERIFICATION';

  @override
  String get verificationInstruction => 'Enter the 6-digit code sent to';

  @override
  String get verify => 'VERIFY';

  @override
  String get resendCode => 'Resend code';

  @override
  String codeWillExpire(String time) {
    return 'Code will expire in $time';
  }

  @override
  String get newPasswordTitle => 'NEW PASSWORD';

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get resetPasswordButton => 'RESET PASSWORD';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordResetSuccess => 'Password reset successful! Please login.';

  @override
  String get minCharacters => 'Min 6 characters';

  @override
  String get confirmYourPassword => 'Confirm your password';

  @override
  String get codeInvalidated => 'CODE INVALIDATED';

  @override
  String resendAvailableIn(String time) {
    return 'Resend available in $time';
  }

  @override
  String get continueButton => 'CONTINUE';

  @override
  String get resendSuccess => 'Code resent successfully!';

  @override
  String get resendError => 'Failed to resend code';

  @override
  String get resetPasswordError => 'Failed to reset password.';

  @override
  String get codeRequestError => 'Failed to request password reset.';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get registerFailed => 'Registration failed';

  @override
  String get termsContent =>
      'Last updated: February 07, 2026\n\nBy creating an account in the Las Prendas application, you (the \"User\") agree to the following terms:\n\n1. NATURE OF THE SERVICE\nLas Prendas is a virtual fitting room platform that allows users to upload clothing images and personal photographs to visualize clothing combinations through digital processing.\n\n2. USER-GENERATED CONTENT\nThe User is solely responsible for images, photographs, and any material (the \"Content\") they upload to the platform. The User warrants that they have the legal rights to such content and that it does not infringe on third-party rights or contain illegal or offensive material.\n\n3. ADMINISTRATIVE ACCESS AND PRIVACY\nThe User acknowledges and agrees that the platform administrators have full access to the Content uploaded and generated within the application. This access is used exclusively for: Technical maintenance, User support, content moderation, and algorithm improvement.\n\n4. IMAGE PROCESSING AND DERIVATIVE WORKS\nBy using Las Prendas, the User grants an express license to the platform for: AI processing to analyze uploaded photos and creation of new images resulting from the combination of User content.\n\n5. PROPIEDAD INTELECTUAL\nThe User retains ownership of their original photos. Las Prendas grants the User a personal use license for the images generated within the app.\n\n6. USO ACEPTABLE\nIt is strictly prohibited to upload content that includes nudity, explicit sexual content, images of third parties without consent, or material that incites hatred.\n\n7. LIMITATION OF LIABILITY\nLas Prendas is not responsible for the misuse that third parties may make of images if the user decides to share them outside the application.';
}
