//
//  OrderSummaryVC.swift
//  ECommerce
//
//  Created by octal on 26/11/20.
//

import UIKit
import Kingfisher
import CFSDK

class OrderSummaryVC: UIViewController {

    //MARK:- IBOutlet
    @IBOutlet private weak var tableView: UITableView!

    
    var cartDataValue:CartListDataClass?
    
    var cartSections = [CartValues]()
    
    var appId = Global.appId
    var appSecret = Global.appSecret
    var cashFreeEndPoint = Global.cashFreeEndPoint

    var notifyUrl = ""
    var orderId = ""
    var orderAmount = ""
    let customerEmail = ""
    let customerPhone = ""
    let orderNote = ""
    let customerName = ""
    var paymentReadyToken = ""
    let paymentModes = ""
    var source_config = "iossdk" // MUST be "iossdk"
    
    var couponCode = false
    
    var paymentType = "2"
    var currency = Global.currency
    var strPromoCode = ""
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.tableView.tableFooterView = UIView()
                
        self.tableView.register(UINib(nibName: "ProductCell", bundle: nil), forCellReuseIdentifier: "ProductCell")
        
        self.tableView.register(UINib(nibName: "BillingAddressCell", bundle: nil), forCellReuseIdentifier: "BillingAddressCell")

        self.tableView.register(UINib(nibName: "OrderChargesCell", bundle: nil), forCellReuseIdentifier: "OrderChargesCell")
        
        self.tableView.register(UINib(nibName: "PaymentOptionsCell", bundle: nil), forCellReuseIdentifier: "PaymentOptionsCell")

        
        if appDelegate.userSettings != nil
        {
            if appDelegate.userSettings?.payment?.prodMode ?? false == true
            {
                self.appId = appDelegate.userSettings?.payment?.prodAppID ?? ""
                self.appSecret = appDelegate.userSettings?.payment?.prodSecretKey ?? ""
                self.notifyUrl = appDelegate.userSettings?.payment?.notifyURL ?? ""
                self.currency = appDelegate.userSettings?.payment?.currency ?? "INR"
            }
            else
            {
                self.appId = appDelegate.userSettings?.payment?.testAppID ?? ""
                self.appSecret = appDelegate.userSettings?.payment?.testSecretKey ?? ""
                self.notifyUrl = appDelegate.userSettings?.payment?.notifyURL ?? ""
                self.currency = appDelegate.userSettings?.payment?.currency ?? "INR"
            }
            
        }
        else
        {
            self.GetPaymentSettings()
        }
        
        
        if self.cartDataValue?.item?.count ?? 0 > 0
        {
            
            if self.cartDataValue?.item?.count ?? 0 > 0
            {
                self.cartSections.append(.Products)
            }
            
            if self.cartDataValue?.shipping?.count ?? 0 > 0
            {
                self.cartSections.append(.DeliveryAddress)
            }
            
            self.cartSections.append(.CartTotal)

        }
        
    }
    
    // MARK: - IBActions
    
    @IBAction func btnBackTapped(_ sender: Any)
    {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func btnCheckoutTapped(_ sender: Any)
    {
        self.orderAmount = "\(self.cartDataValue?.total ?? 0.0)"
        
        if self.paymentType == "2"
        {
            self.getCashfreeToken(completion: {
                self.CallCreateTransactionApi()
            })
        }
        else
        {
            let dataVal = [K.APIParameterKey.coupon_code:false,
                           K.APIParameterKey.shipping_id:self.cartDataValue?.shapingAddress?.id ?? "",
                           K.APIParameterKey.order_id:self.orderId,
                           K.APIParameterKey.order_type:self.paymentType,
                           K.APIParameterKey.billing_id:self.cartDataValue?.billingAddress?.id ?? ""] as [String : Any]
            self.CheckoutCartProduct(values: dataVal)
        }
        
    }
    
    @IBAction func btnChoosePaymentTapped(_ sender: UIButton)
    {
        if sender.tag == 1
        {
            self.paymentType = "1"
        }
        else if sender.tag == 2
        {
            self.paymentType = "2"
        }
        
        self.tableView.reloadData()
    }
    
}


//MARK: - CashFree
extension OrderSummaryVC
{
    private func getCashfreeToken(completion:@escaping ()->()) {
        
        let ApiFuture = APIClient.generateTokenWebService(dataValue: self.orderAmount)
        
        ApiFuture.execute(onSuccess:{ ApiData in
            
            if ApiData.status == 200
            {
                if let dataDict = ApiData.data
                {
                    self.paymentReadyToken = dataDict.token ?? ""
                    self.orderId = "\(dataDict.orderID!.value)"
                    completion()
                }
                else
                {
                    self.showMessageFromTop(message: ApiData.message ?? "")
                }
            }
            else if ApiData.status ?? 0 == 401 || ApiData.status ?? 0 == 403
            {
                self.appDelegate.CallLogoutUser(false)
            }
            else
            {
                self.showMessageFromTop(message: ApiData.message ?? "Somthing went wrong, please try again.")
            }
        }, onFailure: { error in
            print(error.localizedDescription)
            self.showMessageFromTop(message: error.underlyingError?.localizedDescription ?? error.localizedDescription)
        })
         
    }
    
    func getPaymentParams() -> Dictionary<String, String> {
        
        let mobile = defaults[.mobileNum]
        
        return [
            "orderId": self.orderId,
            "appId": self.appId,
            "tokenData" : self.paymentReadyToken,
            "orderAmount": self.orderAmount,
            "customerName": defaults[.firstName],
            "orderNote": self.orderNote,
            "orderCurrency": self.currency,
            "customerPhone": mobile,
            "customerEmail": defaults[.email],
            "notifyUrl": self.notifyUrl,
            "appName":kAppName
        ]
    }
    
    func CallCreateTransactionApi()
    {
        let mobile = defaults[.mobileNum]

        if mobile.count == 0
        {
            Loaf("Please provide mobile number. Update your profile", state: .custom(.init(backgroundColor: kAppPrimaryColor,textColor:.white, icon: nil, width: .screenPercentage(0.9))), location: .top, presentingDirection: .vertical, dismissingDirection: .vertical, sender: self).show(.short, completionHandler: .some({_ in

                let storyboard = AppStoryboard.More.instance
                let vc = storyboard.instantiateViewController(withIdentifier: "MyAccountVC") as! MyAccountVC
                vc.isFromCart = true
                self.navigationController?.pushViewController(vc, animated: true)

            }))

            return
        }
        
        getPaymentParams().toJson()
        
        // Loading Payment Gateway's Controller
        let cashfreeVC = CFViewController(params: self.getPaymentParams(), env: Global.environment, callBack: self)
        cashfreeVC.title = "Make Payment".uppercased()
        self.present(cashfreeVC, animated: true, completion: nil)
    }
}

extension OrderSummaryVC: ResultDelegate {
    func onPaymentCompletion(msg: String) {
        print("Result Delegate : onPaymentCompletion")
        print(msg)
        // Handle the payment result here

        if self.orderAmount != "" {
            DispatchQueue.main.async {
                self.appDelegate.window?.rootViewController?.view.showHud()
            }
            let inputJSON = "\(msg)"
            let inputData = inputJSON.data(using: .utf8)!
            let decoder = JSONDecoder()
            if inputJSON != "" {
                do {
                    let result2 = try decoder.decode(Result.self, from: inputData)
                    
                    DispatchQueue.main.async {
                        self.appDelegate.window?.rootViewController?.view.hideHud()
                    }
                    
                    if self.orderId != result2.orderId || result2.txStatus.caseInsensitiveCompare("FAILED") == .orderedSame {
                        return
                    }
                    
                    var parameters = [String:Any]()
                    parameters["order_id"] = result2.orderId
                    parameters["txn_id"] = result2.referenceId
                    parameters["banktxn_id"] = "BANK_CF"
                    parameters["txn_date"] = result2.txTime
                    parameters["txn_amount"] = result2.orderAmount
                    parameters["currency"] = currency
                    parameters["gateway_name"] = "CASH_FREE"
                    parameters["checksum"] = "CASHFREE_CHECKSUM"
                    parameters["user_id"] = defaults[.UserSaltId]
                    parameters["language"] = "en"
                    
                    let dataVal = [K.APIParameterKey.coupon_code:false,
                                   K.APIParameterKey.shipping_id:self.cartDataValue?.shapingAddress?.id ?? "",
                                   K.APIParameterKey.orderId:self.orderId,
                                   K.APIParameterKey.order_type:self.paymentType,
                                   K.APIParameterKey.paymentId:result2.referenceId,
                                   K.APIParameterKey.billing_id:self.cartDataValue?.billingAddress?.id ?? ""] as [String : Any]
                    self.CheckoutCartProduct(values: dataVal)
                    
                } catch {
                    // handle exception
                    DispatchQueue.main.async {
                        self.appDelegate.window?.rootViewController?.view.hideHud()
                    }
                    
                    print("BDEBUG: Error Occured while retrieving transaction response")
                }
            } else {
                DispatchQueue.main.async {
                    self.appDelegate.window?.rootViewController?.view.hideHud()
                }
                
                print("BDEBUG: transactionResult is empty")
            }
        }
    }
}

extension OrderSummaryVC: UITableViewDataSource,UITableViewDelegate
{
    func numberOfSections(in tableView: UITableView) -> Int
    {
        return self.cartSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch self.cartSections[section] {
        case .Products:
            return self.cartDataValue?.item?.count ?? 0
        case .DeliveryAddress:
            return 1
        case .CartTotal:
            return 1
        case .PaymentType:
            return 1
        default:
            return 0
        }
        
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch self.cartSections[indexPath.section] {
        case .Products:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath) as! ProductCell
            cell.selectionStyle = .none
            
            let dataDict = self.cartDataValue?.item?[indexPath.row]
            cell.lblQty.text = "QTY: \(dataDict?.qty ?? 0)"
            cell.lblPrice.text = "\(dataDict?.currency ?? "")\(dataDict?.price ?? "")"
            cell.lblProductAttribute.text = dataDict?.attributeName ?? ""
            cell.lblProductName.text = dataDict?.title ?? ""
            
            let resource = ImageResource(downloadURL: URL(string:"\(dataDict?.image ?? "")")!, cacheKey: "\(dataDict?.image ?? "")-\(indexPath.row)")
            
            cell.productImg.kf.setImage(
                        with: resource,
                        options: [
                            .cacheOriginalImage
                        ]
                    )
            
            return cell

            
        case .DeliveryAddress:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BillingAddressCell", for: indexPath) as! BillingAddressCell
            cell.selectionStyle = .none
            
            let dataDict = self.cartDataValue?.shapingAddress
            cell.lblUserName.text = dataDict?.name ?? ""
            cell.lblContactNo.text = dataDict?.number ?? ""
            
            if "\(dataDict?.landmark ?? "")".count > 0 && "\(dataDict?.alternateNumber ?? "")".count > 0
            {
                cell.lblAddress.text = "\(dataDict?.address ?? "") \(dataDict?.city ?? "") \(dataDict?.state ?? "") \(dataDict?.pincode ?? "")\nLandmark: -\(dataDict?.landmark ?? "")\nAlternate Number: -\(dataDict?.alternateNumber ?? "")"
            }
            else if dataDict?.landmark ?? "" != ""
            {
                cell.lblAddress.text = "\(dataDict?.address ?? "") \(dataDict?.city ?? "") \(dataDict?.state ?? "") \(dataDict?.pincode ?? "")\nLandmark:-\(dataDict?.landmark ?? "")"
            }
            else if dataDict?.alternateNumber ?? "" != ""
            {
                cell.lblAddress.text = "\(dataDict?.address ?? "") \(dataDict?.city ?? "") \(dataDict?.state ?? "") \(dataDict?.pincode ?? "")\nAlternate Number:-\(dataDict?.alternateNumber ?? "")"
            }
            else
            {
                cell.lblAddress.text = "\(dataDict?.address ?? "") \(dataDict?.city ?? "") \(dataDict?.state ?? "") \(dataDict?.pincode ?? "")"
            }
            
            return cell
            
        case .CartTotal:
            let cell = tableView.dequeueReusableCell(withIdentifier: "OrderChargesCell", for: indexPath) as! OrderChargesCell
            cell.selectionStyle = .none
            
            cell.lblCartSubtotalValue.text = "\(self.cartDataValue?.currency ?? "")\(self.cartDataValue?.cartSubtotal ?? "")"
            
            if self.cartDataValue?.discountAmount ?? "" != ""
            {
                cell.lblDiscountTitle.text = "Discount Amount"
                cell.lblDiscountValue.text = "\(self.cartDataValue?.currency ?? "")\(self.cartDataValue?.discountAmount ?? "")"
            }
            else
            {
                cell.lblDiscountTitle.text = ""
                cell.lblDiscountValue.text = ""
            }
            
            if self.cartDataValue?.subTotalAfterDiscount ?? "" != ""
            {
                cell.lblSubDiscountTitle.text = "Sub Total After Discount"
                cell.lblSubDiscountValue.text = "\(self.cartDataValue?.currency ?? "")\(self.cartDataValue?.subTotalAfterDiscount ?? "")"
            }
            else
            {
                cell.lblSubDiscountTitle.text = ""
                cell.lblSubDiscountValue.text = ""
            }
            
            if self.cartDataValue?.shipping ?? "" != ""
            {
                cell.lblShippingTitle.text = "Shipping & Processing"
                cell.lblShippingValue.text = "\(self.cartDataValue?.currency ?? "")\(self.cartDataValue?.shipping ?? "")"
            }
            else
            {
                cell.lblShippingTitle.text = ""
                cell.lblShippingValue.text = ""
            }
            
            if self.cartDataValue?.tax ?? "" != ""
            {
                cell.lblTaxTitle.text = "Tax"
                cell.lblTaxValue.text = "\(self.cartDataValue?.currency ?? "")\(self.cartDataValue?.tax ?? "")"
            }
            else
            {
                cell.lblTaxTitle.text = ""
                cell.lblTaxValue.text = ""
            }
            
            cell.lblGrandTotalTitle.text = "Grand Total"
            cell.lblGrandTotalValue.text = "\(self.cartDataValue?.currency ?? "")\(self.cartDataValue?.total ?? 0.0)"
            
            return cell
            
        case .PaymentType:
            let cell = tableView.dequeueReusableCell(withIdentifier: "PaymentOptionsCell", for: indexPath) as! PaymentOptionsCell
            cell.selectionStyle = .none
            
            cell.btnOnline.addTarget(self, action: #selector(btnChoosePaymentTapped(_:)), for: .touchUpInside)
            cell.btnOnline.tag = 2
            
            cell.btnCOD.tag = 1
            cell.btnCOD.addTarget(self, action: #selector(btnChoosePaymentTapped(_:)), for: .touchUpInside)

            if self.paymentType == "1"
            {
                cell.btnCOD.setImage(UIImage(named: "radioSelect"), for: .normal)
                cell.btnOnline.setImage(UIImage(named: "radioUnSelect"), for: .normal)
            }
            else
            {
                cell.btnOnline.setImage(UIImage(named: "radioSelect"), for: .normal)
                cell.btnCOD.setImage(UIImage(named: "radioUnSelect"), for: .normal)
            }
            
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch self.cartSections[indexPath.section] {
        case .Products:
            return 92.0
        case .DeliveryAddress:
            return UITableView.automaticDimension
        case .CartTotal:
            return UITableView.automaticDimension
        case .PaymentType:
            return 92.0
        default:
            return 0
        }
    }
    
    
}

//MARK: - Api Calling
extension OrderSummaryVC
{
    func GetPaymentSettings()
    {
        let ApiFuture = APIClient.defaultSettingsWebService()
        
        ApiFuture.execute(onSuccess:{ user in
            if user.status ?? 0 == 200
            {
                if let dataDict = user.data
                {
                    self.appDelegate.userSettings = dataDict
                    
                    if self.appDelegate.userSettings?.payment?.prodMode ?? false == true
                    {
                        self.appId = self.appDelegate.userSettings?.payment?.prodAppID ?? ""
                        self.appSecret = self.appDelegate.userSettings?.payment?.prodSecretKey ?? ""
                        self.notifyUrl = self.appDelegate.userSettings?.payment?.notifyURL ?? ""
                        self.currency = self.appDelegate.userSettings?.payment?.currency ?? "INR"
                    }
                    else
                    {
                        self.appId = self.appDelegate.userSettings?.payment?.testAppID ?? ""
                        self.appSecret = self.appDelegate.userSettings?.payment?.testSecretKey ?? ""
                        self.notifyUrl = self.appDelegate.userSettings?.payment?.notifyURL ?? ""
                        self.currency = self.appDelegate.userSettings?.payment?.currency ?? "INR"
                    }
                    
                }
                
            }
            else if user.status ?? 0 == 401 || user.status ?? 0 == 403
            {
                self.appDelegate.CallLogoutUser(false)
            }
            
        }, onFailure: { error in
            
        })
    }
    
    func GetOrderSummary()
    {
        self.cartSections.removeAll()
        
        let ApiFuture = APIClient.getCartListWebService(deviceToken: kAppDeviceId, coupon_code: self.strPromoCode)
        
        ApiFuture.execute(onSuccess:{ ApiData in
            
            if ApiData.status == 200
            {
                if let dataDict = ApiData.data
                {
                    if dataDict.item?.count ?? 0 > 0
                    {
                        self.cartDataValue = dataDict
                        
                        if dataDict.item?.count ?? 0 > 0
                        {
                            self.cartSections.append(.Products)
                        }
                        
                        if dataDict.shipping?.count ?? 0 > 0
                        {
                            self.cartSections.append(.DeliveryAddress)
                        }
                        
                        self.cartSections.append(.CartTotal)
                        self.cartSections.append(.PaymentType)

                    }
                }
            }
            else if ApiData.status ?? 0 == 401 || ApiData.status ?? 0 == 403
            {
                self.appDelegate.CallLogoutUser(false)
            }
            self.tableView.reloadData()
            
        }, onFailure: { error in
            print(error.localizedDescription)
            self.showMessageFromTop(message: error.underlyingError?.localizedDescription ?? error.localizedDescription)
        })
    }
    
    func CheckoutCartProduct(values:[String:Any])
    {
        
        let ApiFuture = APIClient.checkoutWebService(dataValue:values)
        
        ApiFuture.execute(onSuccess:{ ApiData in
            
            if ApiData.status == 200
            {
                Loaf(ApiData.message ?? "", state: .custom(.init(backgroundColor: kAppPrimaryColor,textColor:.white, icon: nil, width: .screenPercentage(0.9))), location: .top, presentingDirection: .vertical, dismissingDirection: .vertical, sender: self).show(.short, completionHandler: .some({_ in

                    cartData = nil
                    let storyboard = AppStoryboard.Orders.instance
                    let vc = storyboard.instantiateViewController(withIdentifier: "MyOrdersVC") as! MyOrdersVC
                    self.navigationController?.pushViewController(vc, animated: true)
                }))
                
            }
            else if ApiData.status ?? 0 == 401 || ApiData.status ?? 0 == 403
            {
                self.appDelegate.CallLogoutUser(false)
            }
            else
            {
                self.showMessageFromTop(message: ApiData.message ?? "")
            }
            
        }, onFailure: { error in
            print(error.localizedDescription)
            self.showMessageFromTop(message: error.underlyingError?.localizedDescription ?? error.localizedDescription)
        })
    }
}

struct Result : Codable {
    let orderId: String
    let referenceId: String
    let orderAmount: String
    let txStatus: String
    let txMsg: String
    let txTime: String
    let paymentMode: String
    let signature: String
    
    enum CodingKeys : String, CodingKey {
        case orderId
        case referenceId
        case orderAmount
        case txStatus
        case txMsg
        case txTime
        case paymentMode
        case signature
    }
}

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}

