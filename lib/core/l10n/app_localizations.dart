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
  /// **'المجموع'**
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

  /// No description provided for @todayRevenue.
  ///
  /// In ar, this message translates to:
  /// **'إيرادات اليوم'**
  String get todayRevenue;

  /// No description provided for @todayOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلبات اليوم'**
  String get todayOrders;

  /// No description provided for @topDebtors.
  ///
  /// In ar, this message translates to:
  /// **'أكبر المدينين'**
  String get topDebtors;

  /// No description provided for @packageAlerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات العبوات'**
  String get packageAlerts;

  /// No description provided for @noDebts.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ديون مستحقة'**
  String get noDebts;

  /// No description provided for @allPackagesReturned.
  ///
  /// In ar, this message translates to:
  /// **'جميع العبوات مُسترجعة'**
  String get allPackagesReturned;

  /// No description provided for @currencyUnit.
  ///
  /// In ar, this message translates to:
  /// **'د.ج'**
  String get currencyUnit;

  /// No description provided for @packageUnit.
  ///
  /// In ar, this message translates to:
  /// **'عبوة'**
  String get packageUnit;

  /// No description provided for @viewAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get viewAll;

  /// No description provided for @noActiveDrivers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سائقين في الخدمة'**
  String get noActiveDrivers;

  /// No description provided for @lastSeenAgo.
  ///
  /// In ar, this message translates to:
  /// **'آخر ظهور منذ {minutes} دقيقة'**
  String lastSeenAgo(int minutes);

  /// No description provided for @locationPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'يجب تفعيل صلاحية الموقع وخدمة GPS'**
  String get locationPermissionDenied;

  /// No description provided for @tapToToggleDuty.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لتغيير حالة الخدمة'**
  String get tapToToggleDuty;

  /// No description provided for @discount.
  ///
  /// In ar, this message translates to:
  /// **'خصم'**
  String get discount;

  /// No description provided for @discountAmount.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ الخصم'**
  String get discountAmount;

  /// No description provided for @requiresOwnerApproval.
  ///
  /// In ar, this message translates to:
  /// **'يتطلب موافقة المالك'**
  String get requiresOwnerApproval;

  /// No description provided for @discountPending.
  ///
  /// In ar, this message translates to:
  /// **'خصم معلق'**
  String get discountPending;

  /// No description provided for @discountApproved.
  ///
  /// In ar, this message translates to:
  /// **'خصم مقبول'**
  String get discountApproved;

  /// No description provided for @discountRejected.
  ///
  /// In ar, this message translates to:
  /// **'خصم مرفوض'**
  String get discountRejected;

  /// No description provided for @pendingDiscounts.
  ///
  /// In ar, this message translates to:
  /// **'خصومات معلقة'**
  String get pendingDiscounts;

  /// No description provided for @noPendingDiscounts.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد خصومات معلقة'**
  String get noPendingDiscounts;

  /// No description provided for @approveDiscount.
  ///
  /// In ar, this message translates to:
  /// **'قبول الخصم'**
  String get approveDiscount;

  /// No description provided for @rejectDiscount.
  ///
  /// In ar, this message translates to:
  /// **'رفض الخصم'**
  String get rejectDiscount;

  /// No description provided for @confirmApproveDiscount.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد قبول هذا الخصم؟'**
  String get confirmApproveDiscount;

  /// No description provided for @confirmRejectDiscount.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد رفض هذا الخصم؟ سيتم تعديل الإجمالي.'**
  String get confirmRejectDiscount;

  /// No description provided for @discountExceedsSubtotal.
  ///
  /// In ar, this message translates to:
  /// **'الخصم لا يمكن أن يتجاوز المجموع الفرعي'**
  String get discountExceedsSubtotal;

  /// No description provided for @discountAlreadyProcessed.
  ///
  /// In ar, this message translates to:
  /// **'الخصم تمت معالجته مسبقاً'**
  String get discountAlreadyProcessed;

  /// No description provided for @timeRemaining.
  ///
  /// In ar, this message translates to:
  /// **'متبقي {minutes}:{seconds}'**
  String timeRemaining(int minutes, String seconds);

  /// No description provided for @storeDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المتجر'**
  String get storeDetails;

  /// No description provided for @recentOrders.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات الأخيرة'**
  String get recentOrders;

  /// No description provided for @recentPayments.
  ///
  /// In ar, this message translates to:
  /// **'المدفوعات الأخيرة'**
  String get recentPayments;

  /// No description provided for @packageBalances.
  ///
  /// In ar, this message translates to:
  /// **'رصيد العبوات'**
  String get packageBalances;

  /// No description provided for @noOrdersForStore.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات لهذا المتجر'**
  String get noOrdersForStore;

  /// No description provided for @noPaymentsForStore.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مدفوعات لهذا المتجر'**
  String get noPaymentsForStore;

  /// No description provided for @noPackageActivity.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركة عبوات'**
  String get noPackageActivity;

  /// No description provided for @address.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get address;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف'**
  String get phone;

  /// No description provided for @contactPerson.
  ///
  /// In ar, this message translates to:
  /// **'جهة الاتصال'**
  String get contactPerson;

  /// No description provided for @users.
  ///
  /// In ar, this message translates to:
  /// **'المستخدمين'**
  String get users;

  /// No description provided for @createUser.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مستخدم'**
  String get createUser;

  /// No description provided for @userCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الحساب بنجاح'**
  String get userCreated;

  /// No description provided for @selectRole.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدور'**
  String get selectRole;

  /// No description provided for @deactivateUser.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف المستخدم'**
  String get deactivateUser;

  /// No description provided for @activateUser.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل المستخدم'**
  String get activateUser;

  /// No description provided for @confirmDeactivate.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إيقاف هذا المستخدم؟ سيتم إخفاؤه من القوائم النشطة.'**
  String get confirmDeactivate;

  /// No description provided for @active.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In ar, this message translates to:
  /// **'غير نشط'**
  String get inactive;

  /// No description provided for @noUsers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مستخدمين'**
  String get noUsers;

  /// No description provided for @passwordMinLength.
  ///
  /// In ar, this message translates to:
  /// **'6 أحرف على الأقل'**
  String get passwordMinLength;

  /// No description provided for @usernameNoSpaces.
  ///
  /// In ar, this message translates to:
  /// **'بدون مسافات'**
  String get usernameNoSpaces;

  /// No description provided for @discountPendingPrintBlocked.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن الطباعة أثناء انتظار الموافقة على الخصم'**
  String get discountPendingPrintBlocked;

  /// No description provided for @cancelOrder.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cancelOrder;

  /// No description provided for @cancelOrderConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من إلغاء هذا الطلب؟ سيتم عكس الرصيد.'**
  String get cancelOrderConfirm;

  /// No description provided for @orderCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الطلب'**
  String get orderCancelled;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get thisMonth;

  /// No description provided for @allTime.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get allTime;

  /// No description provided for @driverPerformance.
  ///
  /// In ar, this message translates to:
  /// **'أداء السائق'**
  String get driverPerformance;

  /// No description provided for @totalCollected.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المحصّل'**
  String get totalCollected;

  /// No description provided for @totalOrders.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الطلبات'**
  String get totalOrders;

  /// No description provided for @totalPayments.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المدفوعات'**
  String get totalPayments;

  /// No description provided for @recentActivity.
  ///
  /// In ar, this message translates to:
  /// **'النشاط الأخير'**
  String get recentActivity;

  /// No description provided for @noActivity.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد نشاط'**
  String get noActivity;

  /// No description provided for @adjustBalance.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرصيد'**
  String get adjustBalance;

  /// No description provided for @adjustmentAmount.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ التعديل'**
  String get adjustmentAmount;

  /// No description provided for @adjustmentReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب التعديل'**
  String get adjustmentReason;

  /// No description provided for @adjustmentReasonRequired.
  ///
  /// In ar, this message translates to:
  /// **'يجب إدخال السبب'**
  String get adjustmentReasonRequired;

  /// No description provided for @adjustmentSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تعديل الرصيد'**
  String get adjustmentSuccess;

  /// No description provided for @confirmAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد التعديل'**
  String get confirmAdjustment;

  /// No description provided for @positiveAddsCredit.
  ///
  /// In ar, this message translates to:
  /// **'موجب = إضافة دين، سالب = خصم'**
  String get positiveAddsCredit;

  /// No description provided for @alertThreshold.
  ///
  /// In ar, this message translates to:
  /// **'حد التنبيه'**
  String get alertThreshold;

  /// No description provided for @appVersion.
  ///
  /// In ar, this message translates to:
  /// **'إصدار التطبيق'**
  String get appVersion;

  /// No description provided for @updateAvailable.
  ///
  /// In ar, this message translates to:
  /// **'تحديث متاح'**
  String get updateAvailable;

  /// No description provided for @downloadUpdate.
  ///
  /// In ar, this message translates to:
  /// **'تحميل التحديث'**
  String get downloadUpdate;

  /// No description provided for @latestVersion.
  ///
  /// In ar, this message translates to:
  /// **'لديك أحدث إصدار'**
  String get latestVersion;

  /// No description provided for @syncStatus.
  ///
  /// In ar, this message translates to:
  /// **'حالة المزامنة'**
  String get syncStatus;

  /// No description provided for @syncAutomatic.
  ///
  /// In ar, this message translates to:
  /// **'يتطلب اتصال بالإنترنت'**
  String get syncAutomatic;

  /// No description provided for @printerReconnecting.
  ///
  /// In ar, this message translates to:
  /// **'جاري إعادة الاتصال بالطابعة...'**
  String get printerReconnecting;

  /// No description provided for @storeLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقع المتجر'**
  String get storeLocation;

  /// No description provided for @tapToSetLocation.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على الخريطة لتحديد الموقع'**
  String get tapToSetLocation;

  /// No description provided for @removeLocation.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الموقع'**
  String get removeLocation;

  /// No description provided for @suppliers.
  ///
  /// In ar, this message translates to:
  /// **'الموردين'**
  String get suppliers;

  /// No description provided for @supplier.
  ///
  /// In ar, this message translates to:
  /// **'المورد'**
  String get supplier;

  /// No description provided for @addSupplier.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مورد'**
  String get addSupplier;

  /// No description provided for @editSupplier.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المورد'**
  String get editSupplier;

  /// No description provided for @supplierName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المورد'**
  String get supplierName;

  /// No description provided for @noSuppliers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موردين'**
  String get noSuppliers;

  /// No description provided for @costPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر التكلفة'**
  String get costPrice;

  /// No description provided for @sellPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get sellPrice;

  /// No description provided for @purchaseOrders.
  ///
  /// In ar, this message translates to:
  /// **'المشتريات'**
  String get purchaseOrders;

  /// No description provided for @createPurchaseOrder.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مشتريات'**
  String get createPurchaseOrder;

  /// No description provided for @noPurchaseOrders.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مشتريات'**
  String get noPurchaseOrders;

  /// No description provided for @selectSupplier.
  ///
  /// In ar, this message translates to:
  /// **'اختر المورد'**
  String get selectSupplier;

  /// No description provided for @addProducts.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتجات'**
  String get addProducts;

  /// No description provided for @totalCost.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي التكلفة'**
  String get totalCost;

  /// No description provided for @purchaseNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get purchaseNotes;

  /// No description provided for @unitCost.
  ///
  /// In ar, this message translates to:
  /// **'سعر الوحدة'**
  String get unitCost;

  /// No description provided for @confirmPurchase.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد المشتريات'**
  String get confirmPurchase;

  /// No description provided for @purchaseCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل المشتريات'**
  String get purchaseCreated;

  /// No description provided for @purchaseDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المشتريات'**
  String get purchaseDetails;

  /// No description provided for @todayPurchases.
  ///
  /// In ar, this message translates to:
  /// **'مشتريات اليوم'**
  String get todayPurchases;

  /// No description provided for @todayProfit.
  ///
  /// In ar, this message translates to:
  /// **'التدفق النقدي اليوم'**
  String get todayProfit;

  /// No description provided for @stockOnHand.
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get stockOnHand;

  /// No description provided for @outOfStock.
  ///
  /// In ar, this message translates to:
  /// **'نفذ المخزون'**
  String get outOfStock;

  /// No description provided for @stockLevel.
  ///
  /// In ar, this message translates to:
  /// **'المخزون: {count}'**
  String stockLevel(int count);

  /// No description provided for @lowStockAlerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات المخزون'**
  String get lowStockAlerts;

  /// No description provided for @noLowStock.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات منخفضة المخزون'**
  String get noLowStock;

  /// No description provided for @adjustStock.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المخزون'**
  String get adjustStock;

  /// No description provided for @stockMovements.
  ///
  /// In ar, this message translates to:
  /// **'سجل الحركات'**
  String get stockMovements;

  /// No description provided for @stockAdjusted.
  ///
  /// In ar, this message translates to:
  /// **'تم تعديل المخزون'**
  String get stockAdjusted;

  /// No description provided for @noStockMovements.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركات مخزون'**
  String get noStockMovements;

  /// No description provided for @movementOrderOut.
  ///
  /// In ar, this message translates to:
  /// **'طلب (خروج)'**
  String get movementOrderOut;

  /// No description provided for @movementPurchaseIn.
  ///
  /// In ar, this message translates to:
  /// **'مشتريات (دخول)'**
  String get movementPurchaseIn;

  /// No description provided for @movementCancellationRestore.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء (إرجاع)'**
  String get movementCancellationRestore;

  /// No description provided for @movementAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'تعديل يدوي'**
  String get movementAdjustment;

  /// No description provided for @projectedResult.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة: {count}'**
  String projectedResult(int count);

  /// No description provided for @resultCannotBeNegative.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة لا يمكن أن تكون سالبة'**
  String get resultCannotBeNegative;
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
