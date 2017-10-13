//
//  InviteFriendsViewController.swift
//  TheDocument
//

import Foundation
import UIKit

class InviteFriendsTableViewController: BaseTableViewController {
    
    var friends = [Friend]()
    fileprivate var filteredFriends = [Friend]()
    
    enum Mode {
        case group(Group)
        case challenge(Challenge)
        case teamChallenge(Challenge)
    }
    
    var mode:Mode = .group(Group.empty())
    
    var selectedFriendsIds = Set<String>()
    var selectedTeammateIds = Set<String>()
    var selectedCompetitorIds = Set<String>()
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var searchBarContainer: UIView!
    
    lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        return searchController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.shadowImage = Constants.Theme.mainColor.as1ptImage()
        self.navigationController?.navigationBar.setBackgroundImage(Constants.Theme.mainColor.as1ptImage(), for: .default)
        
        let searchBar = searchController.searchBar
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.spellCheckingType = .no
        searchBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        searchBarContainer.addSubview(searchBar)
        searchBar.sizeToFit()
        
        definesPresentationContext = true
        
        friends = currentUser.friends.filter{ !self.selectedFriendsIds.contains($0.id) }
        
        searchController.searchBar.barTintColor = Constants.Theme.mainColor
        searchController.searchBar.tintColor = Constants.Theme.mainColor
        
        if case Mode.group( _ ) = self.mode {
            navigationItem.title = "Invite"
            
        } else if case Mode.challenge( _ ) = self.mode {
            navigationItem.title = "Select Competitors"
            
        } else {
            let barButton = doneButton
            barButton?.title = "Next"
            navigationItem.rightBarButtonItem = barButton
            navigationItem.title = "Select Teammate"
        }
        
        for subView in searchController.searchBar.subviews {
            for searchBarSubView in subView.subviews {
                if let textField = searchBarSubView as? UITextField {
                    textField.font = UIFont(name: "OpenSans", size: 15.0)
                }
            }
        }
    }
    
    @IBAction func inviteFriends(_ sender: Any) {
        print("Invite Friends!")
        self.startActivityIndicator()
        
        if case let Mode.group( group ) = self.mode {   //Invitation to group
            API().addFriendsToGroup(friends: friends.filter{ selectedFriendsIds.contains($0.id) }, group: group  ) { success in
                self.stopActivityIndicator()
                if success {
                    self.performSegue(withIdentifier: "back_group_details", sender: self)
                }
            }
        } else if case let Mode.challenge(challenge) = self.mode {   // Invitation to challenge
            API().challengeFriends(challenge: challenge, friendsIds: selectedFriendsIds ) {
                self.stopActivityIndicator()
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "\(UserEvents.challengesRefresh)"), object: nil)
                self.dismiss(animated: true, completion: {
                    NCVAlertView().showSuccess("Challenge Created!", subTitle: "")
                })
                return
            }
        } else if case let Mode.teamChallenge(challenge) = self.mode {   // Invitation to team challenge
            if selectedTeammateIds.isEmpty {
                self.stopActivityIndicator()
                
                let currentUserSet = Set([currentUser.uid])
                selectedTeammateIds = selectedFriendsIds.union(currentUserSet)
                selectedFriendsIds.removeAll()
                
                navigationItem.title = "Select Competitors"
                
                let barButton = doneButton
                barButton?.title = "Done"
                navigationItem.rightBarButtonItem = barButton
                
                friends = currentUser.friends.filter{ !self.selectedTeammateIds.contains($0.id) }
                tableView.reloadData()
                
            } else {
                selectedCompetitorIds = selectedFriendsIds
                API().challengeTeams(challenge: challenge,
                                     teammateIds: selectedTeammateIds,
                                     competitorIds: selectedCompetitorIds )
                {
                    self.stopActivityIndicator()
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "\(UserEvents.challengesRefresh)"), object: nil)
                    self.dismiss(animated: true, completion: {
                        NCVAlertView().showSuccess("Challenge Created!", subTitle: "")
                    })
                    return
                }
            }
        }
    }
}

//MARK: UITableView delegate & datasource
extension InviteFriendsTableViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchController.isActive ? filteredFriends.count : friends.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemTableViewCell") as! ItemTableViewCell
        let item = searchController.isActive ? filteredFriends[indexPath.row] : friends[indexPath.row]
        cell.setup(item, selected: selectedFriendsIds.contains( item.id ) )
        setImage(id: item.id, forCell: cell)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let friendId = searchController.isActive ? filteredFriends[indexPath.row].id : friends[indexPath.row].id
        let selectionCount = selectedTeammateIds.isEmpty ? selectedFriendsIds.count+1 : selectedFriendsIds.count
        
        if selectedFriendsIds.contains(friendId) {
            selectedFriendsIds.remove(friendId)
        } else if case Mode.group( _ ) = self.mode {
            selectedFriendsIds.insert(friendId)
        } else if selectionCount < 2 {
            selectedFriendsIds.insert(friendId)
        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}

//Mark: Searching
extension InviteFriendsTableViewController: UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchTerm = searchController.searchBar.text else { return }
        self.filterData(searchTerm)
    }
    func filterData( _ searchTerm: String) -> Void {
        
        guard searchTerm.characters.count > 2 else {  return }
        
        filteredFriends = friends.filter { friend -> Bool in
            return friend.name.lowercased().contains(searchTerm.lowercased())
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func didDismissSearchController (_ searchController: UISearchController) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}