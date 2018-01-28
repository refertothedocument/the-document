//
//  NewChallengeViewController.swift
//  TheDocument
//

import UIKit
import Firebase
import SearchTextField

class NewChallengeViewController: BaseViewController {

    @IBOutlet weak var challengeName:           InputField!
    @IBOutlet weak var challengeFormat:         InputField!
    @IBOutlet weak var challengeLocation:       InputField!
    @IBOutlet weak var challengeTime:           InputField!
    @IBOutlet weak var challengePrice:          InputField!
    @IBOutlet weak var createChallengeButton:   UIButton!
    @IBOutlet weak var walletBalanceLabel:      UILabel!
    
    var challenge:Challenge!
    var toId:String? = nil
    var groupId:String? = nil
    var dollarLabel: UILabel!
    var toggle: UIBarButtonItem!
    var togglePicker: Bool = true
    
    var approvedChallenges: [String] = [String]()
    var challengeFormats: [String] = [String]()
    var priceOptions: [Int] = [Int]()
    
    let challengePicker = UIPickerView()
    let amountPicker = UIPickerView()
    let formatPicker = UIPickerView()
    let timePicker = UIDatePicker()
    
    var accountBalance: Float = 0.00
    var walletAccount: [String: Any]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set initial picker values
        priceOptions = [0, 1, 5, 10, 25, 50]
        challengeFormats = ["1-on-1", "2-on-2"]
        approvedChallenges = ["Cornhole", "Ladder Toss", "Washers", "Frisbee Golf", "Ring Toss", "Pop-a-Shot", "Pong",
                              "Flip Cup", "Spinning", "Running", "Circuit Training", "Weight Lifting", "Golf", "Tennis", "Basketball", "Bowling",
                              "Skiing", "Video Game", "Checkers", "Chess", "Backgammon"].sorted()
        
        walletBalanceLabel.isHidden = true
        challengePicker.delegate = self
        amountPicker.delegate = self
        formatPicker.delegate = self
        
        // Set up challenge picker
        challengeName.inputView = challengePicker
        
        // Set up challenge time
        timePicker.minuteInterval = 30
        timePicker.addTarget(self, action: #selector(NewChallengeViewController.setTime), for: .valueChanged)
        challengeTime.inputView = timePicker
        
        // Set up dollar label
        dollarLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 10, height: 20))
        dollarLabel.backgroundColor = .clear
        dollarLabel.numberOfLines = 1
        dollarLabel.textAlignment = .right
        dollarLabel.textColor = .darkText
        dollarLabel.font = UIFont(name: "OpenSans", size: 16)!
        dollarLabel.text = "$"
        
        // Set up price field
        challengePrice.leftViewMode = challengePrice.text == "" ? .never : .always
        challengePrice.leftView = dollarLabel
        challengePrice.isHidden = false
        challengePrice.isEnabled = false
        challengePrice.inputView = amountPicker
        dollarLabel.sizeToFit()
        
        // Set up format field
        challengeFormat.text = "1-on-1"
        challengeFormat.isEnabled = true
        challengeFormat.isHidden = (toId != nil)
        challengeFormat.inputView = formatPicker
        
        // Final setup
        setupChallengeNameKeyboard()
        addDoneButtonOnKeyboard()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hideControls)))
        
        // Load wallet
        getWallet()
    }

    @IBAction func closeButtonTapped(_ sender: UIBarButtonItem? = nil) { dismiss(animated: true, completion: nil) }
    
    @IBAction func createChallengeButtonTapped(_ sender: Any) {
        let formatText = challengeFormat.text ?? "1-on-1"
        guard let newChallenge = Challenge.short(name: challengeName.text, format: formatText, location: challengeLocation.text, time: challengeTime.text) else {
            showAlert(message: Constants.Errors.inputDataChallenge.rawValue)
            return
        }

        challenge = newChallenge
        challenge.fromId = currentUser.uid
        challenge.group = groupId
        
        if let priceString = challengePrice.text, let price = Int(priceString) {
            if accountBalance < Float(price) {
                showAlert(message: "You don't have enough funds to create this challenge. Please add more funds on the Settings page.")
            } else {
                challenge.price = price
                startChallenge()
            }
        } else {
            startChallenge()
        }
    }
    
    func startChallenge() {
        if let challengeToId = toId {
            challenge.toId = challengeToId
            challenge.fromId = currentUser.uid
            self.startActivityIndicator()
            
            API().challengeFriends(challenge: challenge, friendsIds: [challenge.toId]) {
                self.loadChallengeDetailsView(challenge: self.challenge)
            }
        } else {
            performSegue(withIdentifier: Constants.inviteFriendsNewChallengeStoryboardIdentifier, sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Constants.inviteFriendsNewChallengeStoryboardIdentifier,
            let destVC = segue.destination as? InviteFriendsTableViewController {
            
            if challenge.format == "1-on-1" {
                destVC.mode = .challenge(challenge)
            } else {
                destVC.mode = .teamChallenge(challenge)
            }
        }
    }
    
    func updateAvailableBalance(_ amount: String?) {
        if let newBalance = Float(amount ?? "0.00") {
            self.accountBalance = newBalance
        }
        
        DispatchQueue.main.async {
            self.walletBalanceLabel.text = "You have $\(String(format: "%.2f", self.accountBalance)) available"
            self.walletBalanceLabel.isHidden = false
        }
    }
    
    func refreshAccounts() {
        if let wallet = currentUser.wallet, let info = wallet["info"] as? [String: Any], let balance = info["balance"] as? [String: String] {
            self.updateAvailableBalance(balance["amount"])
        } else {
            self.updateAvailableBalance("0.00")
        }
    }
    
    func getWallet() {
        print("Getting wallet...")
        if let wallet = currentUser.wallet, let _ = wallet["_id"] as? String {
            walletAccount = wallet
            self.refreshAccounts()
        } else {
            API().getWallet({ (success) in
                self.walletAccount = currentUser.wallet
                self.refreshAccounts()
            })
        }
    }
    
    func loadChallengeDetailsView(challenge: Challenge) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "\(UserEvents.challengesRefresh)"), object: nil)
        self.dismiss(animated: false) {
            guard let challengeDetailsViewController = self.storyboard?.instantiateViewController(withIdentifier: "challengeDetailsViewController") as? ChallengeDetailsViewController, let homeViewController = homeVC, homeViewController.containerViewController.childViewControllers.count > 0 else { return }
            
            homeViewController.showOverviewTapped()
            challengeDetailsViewController.challenge = challenge
            if let navController = homeViewController.containerViewController.childViewControllers[0] as? UINavigationController {
                navController.pushViewController(challengeDetailsViewController, animated: false)
                NCVAlertView().showSuccess("Challenge Created!", subTitle: "")
            }
        }
    }
    
    @objc func hideControls() {
        view.endEditing(true)
    }
    
    @objc func setTime() {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        challengeTime.text = formatter.string(from: timePicker.date)
    }
    
    @objc func doneButtonAction() {
        self.challengeName.resignFirstResponder()
        self.challengeFormat.resignFirstResponder()
        self.challengePrice.resignFirstResponder()
        self.challengeTime.resignFirstResponder()
        self.challengeLocation.resignFirstResponder()
    }
    
    @objc func toggleCustomName() {
        if self.togglePicker {
            toggle.title = "View List"
            challengeName.text = nil
            challengeName.inputView = nil
        } else {
            toggle.title = "Custom Challenge"
            challengeName.inputView = self.challengePicker
        }

        challengeName.reloadInputViews()
        self.togglePicker = !self.togglePicker
    }
    
    func setupChallengeNameKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        doneToolbar.barStyle = .default
        doneToolbar.barTintColor = Constants.Theme.mainColor
        doneToolbar.tintColor = .white
        
        toggle = UIBarButtonItem(title: "Custom Challenge", style: .done, target: self, action: #selector(NewChallengeViewController.toggleCustomName))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(NewChallengeViewController.doneButtonAction))
        
        var items = [UIBarButtonItem]()
        items.append(flexSpace)
        items.append(toggle)
        items.append(done)
        doneToolbar.items = items
        doneToolbar.sizeToFit()
        
        self.challengeName.inputAccessoryView = doneToolbar
        self.challengeFormat.inputAccessoryView = doneToolbar
        self.challengePrice.inputAccessoryView = doneToolbar
        self.challengeTime.inputAccessoryView = doneToolbar
    }
    
    func addDoneButtonOnKeyboard()
    {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        doneToolbar.barStyle = .default
        doneToolbar.barTintColor = Constants.Theme.mainColor
        doneToolbar.tintColor = .white
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(NewChallengeViewController.doneButtonAction))
        
        var items = [UIBarButtonItem]()
        items.append(flexSpace)
        items.append(done)
        
        doneToolbar.items = items
        doneToolbar.sizeToFit()
        
        self.challengeFormat.inputAccessoryView = doneToolbar
        self.challengePrice.inputAccessoryView = doneToolbar
        self.challengeTime.inputAccessoryView = doneToolbar
        self.challengeLocation.inputAccessoryView = doneToolbar
    }
}

extension NewChallengeViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView {
        case challengePicker:
            return approvedChallenges.count
        case formatPicker:
            return challengeFormats.count
        case amountPicker:
            return priceOptions.count
        default:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case challengePicker:
            return approvedChallenges[row]
        case formatPicker:
            return challengeFormats[row]
        case amountPicker:
            return "$\(priceOptions[row])"
        default:
            return nil
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == challengePicker {
            challengeName.text = approvedChallenges[row]
        } else if pickerView == formatPicker {
            challengeFormat.text = challengeFormats[row]
        } else if pickerView == amountPicker {
            challengePrice.text = "\(priceOptions[row])"
            challengePrice.leftViewMode = challengePrice.text == "" ? .never : .always
        }
    }
}

extension NewChallengeViewController: UITextFieldDelegate {
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if textField == self.challengeName {
            if let name = textField.text, approvedChallenges.contains(name) {
                self.challengePrice.isEnabled = true
            } else {
                self.challengePrice.isEnabled = false
                self.challengePrice.text = ""
            }
        }
        return true
    }
}
