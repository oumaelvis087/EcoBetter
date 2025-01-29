import SwiftUI

class UserData: ObservableObject {
    @AppStorage("credits") var credits: Int = 0
    @AppStorage("FirstName") var firstName: String = ""
    @AppStorage("LastName") var lastName: String = ""
    @AppStorage("email") var email: String = ""
    
    // Add other user-related properties here
}
