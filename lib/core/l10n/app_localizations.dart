import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'دريم لاند للتسوق'**
  String get appTitle;

  /// No description provided for @orders.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get orders;

  /// No description provided for @packages.
  ///
  /// In ar, this message translates to:
  /// **'التغليف'**
  String get packages;

  /// No description provided for @payments.
  ///
  /// In ar, this message translates to:
  /// **'المدفوعات'**
  String get payments;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @dashboard.
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get dashboard;

  /// No description provided for @map.
  ///
  /// In ar, this message translates to:
  /// **'الخريطة'**
  String get map;

  /// No description provided for @stores.
  ///
  /// In ar, this message translates to:
  /// **'المتاجر'**
  String get stores;

  /// No description provided for @drivers.
  ///
  /// In ar, this message translates to:
  /// **'السائقين'**
  String get drivers;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @username.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get username;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @submit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get submit;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get add;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get error;

  /// No description provided for @success.
  ///
  /// In ar, this message translates to:
  /// **'تم بنجاح'**
  String get success;

  /// No description provided for @noData.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات'**
  String get noData;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @owner.
  ///
  /// In ar, this message translates to:
  /// **'المالك'**
  String get owner;

  /// No description provided for @admin.
  ///
  /// In ar, this message translates to:
  /// **'المشرف'**
  String get admin;

  /// No description provided for @driver.
  ///
  /// In ar, this message translates to:
  /// **'السائق'**
  String get driver;

  /// No description provided for @products.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get products;

  /// No description provided for @totalAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ الإجمالي'**
  String get totalAmount;

  /// No description provided for @balance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get balance;

  /// No description provided for @print.
  ///
  /// In ar, this message translates to:
  /// **'طباعة'**
  String get print;

  /// No description provided for @onDuty.
  ///
  /// In ar, this message translates to:
  /// **'في الخدمة'**
  String get onDuty;

  /// No description provided for @offDuty.
  ///
  /// In ar, this message translates to:
  /// **'خارج الخدمة'**
  String get offDuty;

  /// No description provided for @newOrder.
  ///
  /// In ar, this message translates to:
  /// **'طلب جديد'**
  String get newOrder;

  /// No description provided for @createOrder.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء طلب'**
  String get createOrder;

  /// No description provided for @orderCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الطلب'**
  String get orderCreated;

  /// No description provided for @selectStore.
  ///
  /// In ar, this message translates to:
  /// **'اختر المتجر'**
  String get selectStore;

  /// No description provided for @addProduct.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج'**
  String get addProduct;

  /// No description provided for @quantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantity;

  /// No description provided for @unitPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر الوحدة'**
  String get unitPrice;

  /// No description provided for @lineTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get lineTotal;

  /// No description provided for @subtotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع الفرعي'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In ar, this message translates to:
  /// **'الضريبة'**
  String get tax;

  /// No description provided for @total.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي الكلي'**
  String get total;

  /// No description provided for @receipt.
  ///
  /// In ar, this message translates to:
  /// **'إيصال'**
  String get receipt;

  /// No description provided for @noOrders.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات'**
  String get noOrders;

  /// No description provided for @orderDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get orderDetails;

  /// No description provided for @confirmOrder.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الطلب'**
  String get confirmOrder;

  /// No description provided for @orderDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الطلب'**
  String get orderDate;

  /// No description provided for @status.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get status;

  /// No description provided for @statusCreated.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get statusCreated;

  /// No description provided for @statusDelivered.
  ///
  /// In ar, this message translates to:
  /// **'تم التسليم'**
  String get statusDelivered;

  /// No description provided for @statusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغي'**
  String get statusCancelled;

  /// No description provided for @removeItem.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get removeItem;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @emptyOrderMessage.
  ///
  /// In ar, this message translates to:
  /// **'لم تقم بإنشاء أي طلبات بعد'**
  String get emptyOrderMessage;

  /// No description provided for @confirmOrderTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الطلب'**
  String get confirmOrderTitle;

  /// No description provided for @confirmOrderMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إنشاء هذا الطلب؟'**
  String get confirmOrderMessage;

  /// No description provided for @networkError.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت'**
  String get networkError;

  /// No description provided for @saveError.
  ///
  /// In ar, this message translates to:
  /// **'فشل حفظ الطلب'**
  String get saveError;

  /// No description provided for @items.
  ///
  /// In ar, this message translates to:
  /// **'عناصر'**
  String get items;

  /// No description provided for @payment.
  ///
  /// In ar, this message translates to:
  /// **'الدفعة'**
  String get payment;

  /// No description provided for @newPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفعة جديدة'**
  String get newPayment;

  /// No description provided for @collectPayment.
  ///
  /// In ar, this message translates to:
  /// **'تحصيل دفعة'**
  String get collectPayment;

  /// No description provided for @paymentCollected.
  ///
  /// In ar, this message translates to:
  /// **'تم تحصيل الدفعة'**
  String get paymentCollected;

  /// No description provided for @amount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get amount;

  /// No description provided for @enterAmount.
  ///
  /// In ar, this message translates to:
  /// **'أدخل المبلغ'**
  String get enterAmount;

  /// No description provided for @currentBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الحالي'**
  String get currentBalance;

  /// No description provided for @previousBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد السابق'**
  String get previousBalance;

  /// No description provided for @newBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الجديد'**
  String get newBalance;

  /// No description provided for @noPayments.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مدفوعات'**
  String get noPayments;

  /// No description provided for @emptyPaymentMessage.
  ///
  /// In ar, this message translates to:
  /// **'لم تقم بتحصيل أي مدفوعات بعد'**
  String get emptyPaymentMessage;

  /// No description provided for @confirmPayment.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الدفعة'**
  String get confirmPayment;

  /// No description provided for @confirmPaymentMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل هذه الدفعة؟'**
  String get confirmPaymentMessage;

  /// No description provided for @balanceChange.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرصيد'**
  String get balanceChange;

  /// No description provided for @recordPayment.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدفعة'**
  String get recordPayment;

  /// No description provided for @overpaymentWarning.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ أكبر من الرصيد المستحق'**
  String get overpaymentWarning;

  /// No description provided for @packageLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل التغليف'**
  String get packageLog;

  /// No description provided for @collectPackages.
  ///
  /// In ar, this message translates to:
  /// **'تحصيل العبوات'**
  String get collectPackages;

  /// No description provided for @packagesCollected.
  ///
  /// In ar, this message translates to:
  /// **'تم تحصيل العبوات'**
  String get packagesCollected;

  /// No description provided for @givenPackages.
  ///
  /// In ar, this message translates to:
  /// **'مُعطاة'**
  String get givenPackages;

  /// No description provided for @collectedPackages.
  ///
  /// In ar, this message translates to:
  /// **'مُسترجعة'**
  String get collectedPackages;

  /// No description provided for @packageBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيد العبوات'**
  String get packageBalance;

  /// No description provided for @noPackageLogs.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سجلات تغليف'**
  String get noPackageLogs;

  /// No description provided for @emptyPackageMessage.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركة عبوات بعد'**
  String get emptyPackageMessage;

  /// No description provided for @enterCollected.
  ///
  /// In ar, this message translates to:
  /// **'أدخل العدد المسترجع'**
  String get enterCollected;

  /// No description provided for @confirmCollection.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد التحصيل'**
  String get confirmCollection;

  /// No description provided for @confirmCollectionMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل هذا التحصيل؟'**
  String get confirmCollectionMessage;

  /// No description provided for @packagesGiven.
  ///
  /// In ar, this message translates to:
  /// **'عبوات مُسلّمة'**
  String get packagesGiven;

  /// No description provided for @packagesReturned.
  ///
  /// In ar, this message translates to:
  /// **'عبوات مُسترجعة'**
  String get packagesReturned;

  /// No description provided for @currentPackageBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيد العبوات الحالي'**
  String get currentPackageBalance;

  /// No description provided for @overCollectionWarning.
  ///
  /// In ar, this message translates to:
  /// **'العدد المسترجع أكبر من الرصيد الحالي'**
  String get overCollectionWarning;

  /// No description provided for @printerSetup.
  ///
  /// In ar, this message translates to:
  /// **'إعداد الطابعة'**
  String get printerSetup;

  /// No description provided for @scanPrinters.
  ///
  /// In ar, this message translates to:
  /// **'بحث عن طابعات'**
  String get scanPrinters;

  /// No description provided for @scanning.
  ///
  /// In ar, this message translates to:
  /// **'جاري البحث...'**
  String get scanning;

  /// No description provided for @connectPrinter.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get connectPrinter;

  /// No description provided for @disconnectPrinter.
  ///
  /// In ar, this message translates to:
  /// **'قطع الاتصال'**
  String get disconnectPrinter;

  /// No description provided for @printerConnected.
  ///
  /// In ar, this message translates to:
  /// **'متصل بالطابعة'**
  String get printerConnected;

  /// No description provided for @printerDisconnected.
  ///
  /// In ar, this message translates to:
  /// **'الطابعة غير متصلة'**
  String get printerDisconnected;

  /// No description provided for @noPrintersFound.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على طابعات\nتأكد من تشغيل الطابعة وإقرانها'**
  String get noPrintersFound;

  /// No description provided for @printing.
  ///
  /// In ar, this message translates to:
  /// **'جاري الطباعة...'**
  String get printing;

  /// No description provided for @printSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تمت الطباعة بنجاح'**
  String get printSuccess;

  /// No description provided for @printFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشلت الطباعة'**
  String get printFailed;

  /// No description provided for @connectPrinterFirst.
  ///
  /// In ar, this message translates to:
  /// **'قم بتوصيل الطابعة من الإعدادات'**
  String get connectPrinterFirst;

  /// No description provided for @enableBluetooth.
  ///
  /// In ar, this message translates to:
  /// **'قم بتفعيل البلوتوث وصلاحيات الموقع'**
  String get enableBluetooth;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
