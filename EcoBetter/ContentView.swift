import SwiftUI
import WebKit
import Foundation
import CoreLocation
import UserNotifications
import Combine
import CoreML
import Vision

// Custom wrapper for ColorScheme
enum AppColorScheme: Int {
    case light = 0
    case dark = 1
    
    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// Add this new struct at the top of the file, after the imports
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.green.opacity(0.2).edgesIgnoringSafeArea(.all)
            
            VStack {
                Image(systemName: "leaf.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("EcoBetter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var country: String = "global"

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let country = placemarks?.first?.country {
                DispatchQueue.main.async {
                    self.country = country.lowercased()
                }
            }
        }
        
        self.locationManager.stopUpdatingLocation()
    }
}

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.scheduleDailyTipNotification()
                }
            }
        }
    }
    
    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleDailyTipNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Environmental Tip"
        content.body = getRandomTip()
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9 // Set the hour you want the notification to be sent
        dateComponents.minute = 05
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyTip", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }  
    
    private func getRandomTip() -> String {
        // You can expand this array with more tips
        let tips = [
            "Use reusable bags for shopping to reduce plastic waste.",
            "Turn off lights and electronics when not in use to save energy.",
            "Take shorter showers to conserve water.",
            "Use a refillable water bottle instead of buying bottled water.",
            "Compost food scraps to reduce landfill waste and create nutrient-rich soil."
        ]
        return tips.randomElement() ?? "Do your part to protect the environment today!"
    }
}

struct HomeActionWidget: View {
    let action: ActionType
    let progress: Double
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.3)
                    .foregroundColor(action.color)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    .foregroundColor(action.color)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: progress)

                Image(systemName: action.iconName)
                    .font(.title2)
                    .foregroundColor(action.color)
            }
            .frame(width: 80, height: 80)
            
            Text(action.rawValue)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(action.exampleAction)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 40)
        }
        .frame(width: 120)
    }
}

struct ImageCarousel: View {
    let images: [String]
    @State private var currentIndex = 0
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                TabView(selection: $currentIndex) {
                    ForEach(0..<images.count, id: \.self) { index in
                        Image(images[index])
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
            }
        }
    }
}

struct ActivityCell: View {
    let count: Int
    let date: Date
    @Binding var selectedDate: Date?
    
    var color: Color {
        switch count {
        case 0: return .gray.opacity(0.3)
        case 1...2: return .green.opacity(0.3)
        case 3...4: return .green.opacity(0.6)
        default: return .green
        }
    }
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 12, height: 12)
            .cornerRadius(2)
            .onTapGesture {
                selectedDate = date
            }
    }
}

struct ActivityGraph: View {
    @Binding var activityData: [Date: Int]
    @State private var selectedDate: Date?
    
    let columns = Array(repeating: GridItem(.fixed(14), spacing: 2), count: 7)
    let weeks = 52
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity History")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: columns, spacing: 2) {
                    ForEach(0..<weeks, id: \.self) { week in
                        ForEach(0..<7) { day in
                            let date = Calendar.current.date(byAdding: .day, value: -((weeks - week) * 7 + (6 - day)), to: Date()) ?? Date()
                            ActivityCell(count: activityData[date, default: 0], date: date, selectedDate: $selectedDate)
                        }
                    }
                }
            }
            .frame(height: 100)
            
            if let selectedDate = selectedDate {
                VStack(alignment: .leading) {
                    Text(selectedDate, style: .date)
                        .font(.subheadline)
                    Text("Actions: \(activityData[selectedDate, default: 0])")
                        .font(.subheadline)
                }
            }
            
            HStack {
                Text("Less")
                ForEach(0..<4) { i in
                    Rectangle()
                        .fill(Color.green.opacity(Double(i+1) * 0.25))
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                }
                Text("More")
            }
            .font(.caption)
        }
    }
}

struct LearningProgressView: View {
    let progress: Double
    let timeSpent: TimeInterval
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 20)
                .opacity(0.3)
                .foregroundColor(.gray)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                .foregroundColor(.green)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            VStack {
                Text("\(Int(progress * 100))%")
                    .font(.largeTitle)
                    .bold()
                Text("\(formatTime(timeSpent))")
                    .font(.subheadline)
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: timeInterval) ?? ""
    }
}

struct ReusePlasticView: View {
    @State private var searchQuery = "DIY easy ways to reuse plastic at home"
    @State private var videos: [YouTubeVideo] = []

    var body: some View {
        VStack {
            TextField("Search for reuse ideas", text: $searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: fetchVideos) {
                Text("Search")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            List(videos) { video in
                NavigationLink(destination: YouTubeVideoView(videoId: video.id)) {
                    HStack {
                        AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 120, height: 50)
                        .cornerRadius(8)

                        Text(video.title)
                            .lineLimit(2)
                    }
                }
            }
        }
        .onAppear(perform: fetchVideos)
    }

    private func fetchVideos() {
        // Implement YouTube API call here
        // For now, we'll use dummy data
        videos = [
            YouTubeVideo(id: "dQw4w9WgXcQ", title: "10 Creative Ways to Reuse Plastic Bottles", thumbnailUrl: "https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg"),
            YouTubeVideo(id: "dQw4w9WgXcQ", title: "DIY Plastic Bottle Crafts", thumbnailUrl: "https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg"),
            YouTubeVideo(id: "dQw4w9WgXcQ", title: "Upcycling Plastic: From Waste to Art", thumbnailUrl: "https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg")
        ]
    }
}

struct VideoContainer: View {
    let height: CGFloat
    
    var body: some View {
        WebView(urlString: "https://www.youtube.com/results?search_query=diy+easy+ways+to+reuse+plastic+at+home")
            .frame(height: height)
    }
}

public struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("tab") var tab = Tab.home
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @State private var showingSignUp = false
    @State private var showingChallenges = false
    @State private var showingRewards = false
    @State private var showingAchievements = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State var showImagePicker = false
    @State var inputImage: UIImage?
    @State var actionType: ActionType = .recycle
    @State private var environmentalTips: [String] = []
    @State private var conservationImages: [String] = []
    @State private var actionDescription = ""
    @State private var actionDate = Date()
    @State private var actionLocation = ""
    @State private var peopleInvolved = ""
    @State private var actionInspiration = ""
    @State private var userActions: [UserAction] = []
    @State private var showingUploadSuccessAlert = false
    @State private var uploadSuccessMessage = ""
    @Namespace private var animation
    @State private var profileSelection = 0 // 0 for Settings, 1 for Actions
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("colorScheme") private var appColorScheme: AppColorScheme = .light
    @State private var learningSelection = 0 // 0 for Reuse Plastic, 1 for Plastic Data
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationManager = NotificationManager()
    @State private var selectedImage: Int? = nil
    @State private var isProfilePresented = false
    @State private var selectedTab = Tab.home
    @State private var showingLogin = true // New state property
    @State private var phoneNumber = "" // New state variable
    @State private var LastName = ""
    @State private var FirstName = ""
    @FocusState private var isInputFocused: Bool
    @FocusState private var isEmailFocused: Bool
    @State private var showingActionGuide = false
    @State private var selectedAction: ActionType?
    @State private var isLoading = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("dailyGoal") private var dailyGoal = 3
    @AppStorage("preferredUnits") private var preferredUnits = "Metric"
    @StateObject private var userData = UserData()
    
    // Define color scheme
    var primaryColor: Color {
        colorScheme == .dark ? .green : .blue
    }
    
    var secondaryColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.7) : Color.blue.opacity(0.7)
    }
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white
    }

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if showingLogin {
                loginView
            } else {
                mainAppView
            }
        }
        .preferredColorScheme(appColorScheme.colorScheme)
        .onAppear {
            // Simulate a loading delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isLoading = false
                }
            }
        }
    }

    private var mainAppView: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                homeView
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(Tab.home)
                
                uploadView
                    .tabItem {
                        Label("Upload", systemImage: "square.and.arrow.up")
                    }
                    .tag(Tab.upload)
                
                learningView
                    .tabItem {
                        Label("Learn", systemImage: "book.fill")
                    }
                    .tag(Tab.learn)
            }
            .navigationTitle(selectedTab.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isProfilePresented = true
                    }) {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileView(userData: userData, onLogout: {
                showingLogin = true
                isProfilePresented = false
            })
        }
        .onAppear {
            if !notificationManager.isAuthorized {
                notificationManager.requestAuthorization()
            }
        }
    }

    private var homeView: some View {
        ScrollView {
            VStack(spacing: 20) {
                welcomeSection
                
                availableActionsSection
                
                ecoBetterDescription
                
                environmentalTipView
                
                challengesSection
                
                conservationImageGallery
                
                impactSummarySection
                
                rewardsSection
                
                achievementsSection
            }
        }
        .onAppear(perform: loadEnvironmentalData)
        .sheet(isPresented: $showingActionGuide) {
            if let action = selectedAction {
        NavigationView {
                    ActionGuideView(actionType: action, selectedTab: $selectedTab)
                }
            }
        }
    }

     private var challengesSection: some View {
        VStack(alignment: .leading) {
            Text("Daily Challenges")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(0..<3) { _ in
                        ChallengeCard()
                    }
                }
                .padding(.horizontal)
            }
        }
        .onTapGesture {
            showingChallenges = true
        }
        .sheet(isPresented: $showingChallenges) {
            ChallengesView()
        }
    }


     private var rewardsSection: some View {
        VStack(alignment: .leading) {
            Text("Rewards")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            HStack {
                Text("You have \(userData.credits) credits")
                        .font(.subheadline)
                Spacer()
                Button("Redeem") {
                    showingRewards = true
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
        }
        .onTapGesture {
            showingRewards = true
        }
        .sheet(isPresented: $showingRewards) {
            RewardsView(userData: userData)
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading) {
            Text("Achievements")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(0..<3) { _ in
                        AchievementBadge()
                    }
                }
                .padding(.horizontal)
            }
        }
        .onTapGesture {
            showingAchievements = true
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView()
        }
    }



    private var availableActionsSection: some View {
        VStack(alignment: .leading) {
            Text("Today's Actions")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(ActionType.allCases, id: \.self) { action in
                        HomeActionWidget(
                            action: action,
                            progress: calculateProgress(for: action)
                        )
                            .onTapGesture {
                                selectedAction = action
                                showingActionGuide = true
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func calculateProgress(for action: ActionType) -> Double {
        // Implement logic to calculate progress based on user's actions
        // For now, return a random value
        return Double.random(in: 0...1)
    }

    private var impactSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Environmental Impact")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                ImpactMetricView(icon: "leaf.fill", value: "5", unit: "Trees Planted")
                ImpactMetricView(icon: "trash.fill", value: "20", unit: "kg Waste Recycled")
                ImpactMetricView(icon: "drop.fill", value: "100", unit: "L Water Saved")
                }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var welcomeSection: some View {
        VStack(spacing: 10) {
            Text("Welcome to EcoBetter, \(FirstName) \(LastName)!")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding()
                .matchedGeometryEffect(id: "welcomeTitle", in: animation)

            Text("Your current credits: \(userData.credits)")
                .font(.headline)
                .foregroundColor(primaryColor)
                .padding(.bottom)
                .matchedGeometryEffect(id: "credits", in: animation)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(secondaryColor.opacity(0.1))
        )
        .padding()
    }

    private var ecoBetterDescription: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("What is EcoBetter?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryColor)

            Text("EcoBetter is your personal guide to making a positive impact on the environment. We believe that small actions, when multiplied by millions, can transform the world.")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Our Mission")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(primaryColor)
                .padding(.top, 5)

            Text("To inspire and empower individuals to take daily actions that contribute to a healthier planet. By gamifying eco-friendly behaviors, we make sustainability fun and rewarding.")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Why It Matters")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(primaryColor)
                .padding(.top, 5)

            Text("Every action you take, no matter how small, contributes to a larger movement. Together, we can combat climate change, reduce pollution, and preserve our planet for future generations.")
                .font(.body)
                .foregroundColor(.secondary)
                    }
                    .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(cardBackgroundColor)
                .shadow(color: Color.primary.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding()
    }

    private var environmentalTipView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tip of the Day")
                .font(.title2)
                .fontWeight(.bold)
            
            if let tip = environmentalTips.randomElement() {
                Text(tip)
                    .font(.body)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    private var conservationImageGallery: some View {
        VStack(alignment: .leading) {
            Text("Conservation Gallery")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(0..<conservationImages.count, id: \.self) { index in
                        Image(conservationImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                selectedImage = index
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(item: $selectedImage) { index in
            ImageCarousel(images: conservationImages)
        }
    }

    private func loadEnvironmentalData() {
        environmentalTips = [
            "Use reusable bags for shopping to reduce plastic waste.",
            "Turn off lights and electronics when not in use to save energy.",
            "Take shorter showers to conserve water.",
            "Use a refillable water bottle instead of buying bottled water.",
            "Compost food scraps to reduce landfill waste and create nutrient-rich soil.",
            "Plant trees or support local tree-planting initiatives.",
            "Use public transportation, bike, or walk when possible to reduce emissions.",
            "Support local and organic farmers to reduce the carbon footprint of your food.",
            "Reduce meat consumption to lower your environmental impact.",
            "Properly dispose of hazardous waste like batteries and electronics."
        ]

        conservationImages = [
            "conservation1", "conservation2", "conservation3", "conservation4", "conservation5"
        ]
    }

    private var uploadView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Action Type Picker (Dropdown)
                Menu {
                    ForEach(ActionType.allCases, id: \.self) { action in
                        Button(action.rawValue) {
                            actionType = action
                        }
                    }
                } label: {
                HStack {
                        Text("Action Type: \(actionType.rawValue)")
                        .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.down")
        }
        .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                // Image Selection
                VStack {
                    if let inputImage = inputImage {
                        Image(uiImage: inputImage)
                        .resizable()
                            .scaledToFit()
                            .frame(height: 200)
        .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary, lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary))
                    }
                    
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Label("Select Image", systemImage: "photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(primaryColor)
                            .cornerRadius(10)
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)

                // Additional Fields
                VStack(spacing: 15) {
                    TextField("Description", text: $actionDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    DatePicker("Date", selection: $actionDate, displayedComponents: .date)
                        .padding(.horizontal)
                    
                    TextField("Location", text: $actionLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    TextField("People Involved", text: $peopleInvolved)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    TextField("Inspiration", text: $actionInspiration)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }

                // Upload Button
            Button(action: {
                    uploadAction()
                }) {
                    Text("Upload and Earn \(actionType.creditValue) Credits")
                .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(inputImage == nil || actionDescription.isEmpty ? Color.gray : primaryColor)
                        .cornerRadius(10)
                }
                .disabled(inputImage == nil || actionDescription.isEmpty)
                .padding()
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $inputImage)
        }
        .alert(isPresented: $showingUploadSuccessAlert) {
            Alert(
                title: Text("Action Uploaded!"),
                message: Text(uploadSuccessMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("Upload Action")
    }

    private func uploadAction() {
        guard let image = inputImage else { return }
        
        ImageClassifier.shared.classifyImage(image) { classifications in
            // Validate the image matches the action type
            let isValid = ImageClassifier.shared.validateEnvironmentalAction(classifications, for: actionType)
            
            // Create a formatted string of classifications
            let classificationResults = classifications
                .map { "\($0.label): \($0.formattedConfidence)" }
                .joined(separator: "\n")
            
            if isValid {
                // Proceed with the upload
                userData.credits += actionType.creditValue
                uploadSuccessMessage = """
                    Great job! Your \(actionType.rawValue.lowercased()) action has been verified and recorded.
                    
                    Classifications detected:
                    \(classificationResults)
                    """
                showingUploadSuccessAlert = true
                
                // Reset fields
                inputImage = nil
                actionDescription = ""
                actionDate = Date()
                actionLocation = ""
                peopleInvolved = ""
                actionInspiration = ""
            } else {
                // Show error message with classifications
                uploadSuccessMessage = """
                    The image doesn't seem to match the selected action type. Please try again with a different photo.
                    
                    Classifications detected:
                    \(classificationResults)
                    """
                showingUploadSuccessAlert = true
            }
        }
    }

    private var learningView: some View {
        VStack {
            Picker("Learning Content", selection: $learningSelection) {
                Text("Reuse Plastic").tag(0)
                Text("Plastic Data").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
        .padding()

            if learningSelection == 0 {
                ReusePlasticView()
            } else {
                plasticDataView
            }
        }
        .navigationTitle("Learn")
    }

    private var plasticDataView: some View {
        VStack {
            Text("Global Plastic Watch")
                .font(.title)
                .padding()

            Text("Explore real-time data on plastic waste sites in \(locationManager.country.capitalized)")
                .font(.subheadline)
                .padding()

            WebView(urlString: "https://globalplasticwatch.org/map#\(locationManager.country.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "global")")
                .frame(height: 300)
                .cornerRadius(10)
                .padding()

            Button(action: {
                // Implement action to show more detailed statistics or information
            }) {
                Text("Learn More About Plastic Pollution")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
        }
        .padding()
        }
    }

    // ... existing code ...

private var loginView: some View {
    NavigationStack {
        VStack(spacing: 20) {
            Image("EcoBetterLogo") // Replace with your app logo
                .resizable()
                .scaledToFit()
                .frame(height: 100)
            
            Text("Welcome to EcoBetter")
                .font(.title)
                .fontWeight(.bold)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .focused($isEmailFocused)
            if isEmailFocused {
                if email.count >= 1 {
                    if !isValidEmail(email) {
                        Text("Please enter a valid email")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isInputFocused)
            
            if isInputFocused {
                if password.count >= 1 {
                    let passwordErrors = passwordStrengthCheck(password: password)
                    if !passwordErrors.isEmpty {
                        ForEach(passwordErrors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            if isValidEmail(email) && passwordStrengthCheck(password: password).isEmpty {
                Button(action: performLogin) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(primaryColor)
        .cornerRadius(10)
    }
            } else {
                Button(action: performLogin) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.gray)
                        .cornerRadius(10)
                }
                .disabled(true)
            }
            
                HStack {
                Button("Don't have an account? Sign Up") {
                    showingSignUp = true
                }
                .foregroundColor(primaryColor)
                
                Spacer()
                
                NavigationLink(destination: ForgotPasswordView()) {
                    Text("Forgot Password?")
                        .foregroundColor(primaryColor)
                }
            }
        }
        .padding()
        .navigationDestination(isPresented: $showingSignUp) {
            signupView
        }
    }
}

private var signupView: some View {
    VStack(spacing: 20) {
        Text("Create an Account")
            .font(.title)
            .fontWeight(.bold)
        
        TextField("First Name", text: $FirstName)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        
        TextField("Last Name", text: $LastName)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        
        TextField("Email", text: $email)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none)
            .keyboardType(.emailAddress)
        
        if !isValidEmail(email) && !email.isEmpty {
            Text("Please enter a valid email")
                .font(.caption)
                .foregroundColor(.red)
        }
        
        TextField("Phone Number (xxx)xxx xxx xxx", text: $phoneNumber)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.phonePad)
        
        if !isValidPhoneNumber(phoneNumber) && !phoneNumber.isEmpty {
            Text("Please enter a valid phone number")
                .font(.caption)
                .foregroundColor(.red)
        }
        
        SecureField("Password", text: $password)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        
        let passwordErrors = passwordStrengthCheck(password: password)
        if !passwordErrors.isEmpty && !password.isEmpty {
            ForEach(passwordErrors, id: \.self) { error in
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        
        if !FirstName.isEmpty && !LastName.isEmpty && isValidPhoneNumber(phoneNumber) && isValidEmail(email) && passwordErrors.isEmpty {
            Button(action: performSignup) {
                Text("Sign Up")
                            .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(primaryColor)
                    .cornerRadius(10)
            }
        } else {
            Button(action: performSignup) {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(.white)
        .padding()
                    .frame(maxWidth: .infinity)
                    .background(.gray)
        .cornerRadius(10)
    }
            .disabled(true)
        }
    }
    .padding()
    .navigationTitle("Sign Up")
    .navigationBarTitleDisplayMode(.inline)
}

// ... rest of the existing code ...
    
    private func performLogin() {
        // Implement login logic here
    
        showingLogin = false
    }
    private func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        // Define the regular expression pattern
        let pattern = "^(\\+\\d{1,3}[- ]?)?\\(?\\d{1,4}?\\)?[- ]?\\d{1,4}[- ]?\\d{1,4}[- ]?\\d{1,9}$"
            
            // Create a regular expression object
        let regex = try! NSRegularExpression(pattern: pattern)
        
        // Check if the phone number matches the regex pattern
        let range = NSRange(location: 0, length: phoneNumber.utf16.count)
        return regex.firstMatch(in: phoneNumber, options: [], range: range) != nil
    }
    

     private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func isValidPassword(password: String) -> Bool {
        // Define the regex pattern for password validation
        let passwordPattern = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*()\\-_=+{};:,<.>])(?=.*[^\\s]).{8,}$"
        
        // Create a regular expression object
        guard let regex = try? NSRegularExpression(pattern: passwordPattern, options: []) else {
            return false
        }
        
        // Check if the password matches the regex pattern
        let range = NSRange(location: 0, length: password.utf16.count)
        let match = regex.firstMatch(in: password, options: [], range: range)
        
        // Return true if there is a match, false otherwise
        return match != nil
    }

    private func performSignup() {
        // Implement signup logic here, including the phone number
        print("Signing up with name: \(FirstName) \(LastName), email: \(email), phone: \(phoneNumber)")
        
        showingLogin = false
    }
}

enum Tab: String {
    case home, upload, learn
    
    var title: String {
        switch self {
        case .home: return "EcoBetter"
        case .upload: return "Upload Action"
        case .learn: return "Learning"
        }
    }
}

enum ActionType: String, CaseIterable {
    case recycle = "Recycle"
    case plantTree = "Plant a Tree"
    case cleanUp = "Clean Up"
    case reduceEnergy = "Reduce Energy"
    case conserveWater = "Conserve Water"

    var creditValue: Int {
        switch self {
        case .recycle: return 5
        case .plantTree: return 10
        case .cleanUp: return 8
        case .reduceEnergy: return 6
        case .conserveWater: return 7
        }
    }

    var iconName: String {
        switch self {
        case .recycle: return "arrow.3.trianglepath"
        case .plantTree: return "leaf"
        case .cleanUp: return "trash"
        case .reduceEnergy: return "bolt.slash"
        case .conserveWater: return "drop"
        }
    }

    var description: String {
        switch self {
        case .recycle: return "Properly sort and recycle materials"
        case .plantTree: return "Contribute to local reforestation efforts"
        case .cleanUp: return "Participate in community clean-up events"
        case .reduceEnergy: return "Implement energy-saving practices at home"
        case .conserveWater: return "Adopt water-saving habits"
        }
    }

    var exampleAction: String {
        switch self {
        case .recycle: return "Recycle a plastic bottle"
        case .plantTree: return "Plant a sapling in your garden"
        case .cleanUp: return "Pick up litter in your neighborhood"
        case .reduceEnergy: return "Switch to LED bulbs"
        case .conserveWater: return "Fix a leaky faucet"
        }
    }
}

extension ActionType {
    var color: Color {
        switch self {
        case .recycle: return .blue
        case .plantTree: return .green
        case .cleanUp: return .orange
        case .reduceEnergy: return .yellow
        case .conserveWater: return .cyan
        }
    }
}

struct ActionDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let actionType: ActionType

    var primaryColor: Color {
        colorScheme == .dark ? .green : .blue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(actionType.rawValue)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Earn \(actionType.creditValue) credits")
                    .font(.title3)
                    .foregroundColor(primaryColor)

                Text(actionDescription)
                    .font(.body)

                Text("How to take action:")
                    .font(.headline)
                    .padding(.top)

                ForEach(actionSteps, id: \.self) { step in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(primaryColor)
                        Text(step)
                    }
                }

                Text("Environmental Impact:")
                    .font(.headline)
                    .padding(.top)

                Text(environmentalImpact)
                    .font(.body)

            Button(action: {
                    // Implement action completion logic
                }) {
                    Text("Complete Action")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(primaryColor)
                        .cornerRadius(10)
                }
                .padding(.top)
        }
        .padding()
        }
        .navigationTitle("Action Details")
    }

    private var actionDescription: String {
        switch actionType {
        case .recycle:
            return "Recycling helps conserve natural resources, reduce pollution, and save energy."
        case .plantTree:
            return "Trees absorb CO2, provide habitat for wildlife, and improve air quality."
        case .cleanUp:
            return "Cleaning up litter helps protect wildlife and improve community spaces."
        case .reduceEnergy:
            return "Reducing energy consumption helps lower greenhouse gas emissions."
        case .conserveWater:
            return "Conserving water helps preserve this vital resource for future generations."
        }
    }

    private var actionSteps: [String] {
        switch actionType {
        case .recycle:
            return [
                "Sort recyclable items properly",
                "Clean and sort items by material type",
                "Place items in appropriate recycling bins",
                "Take a photo of your recycling action"
            ]
        case .plantTree:
            return [
                "Choose a suitable location for planting",
                "Prepare the soil and dig a hole",
                "Plant the tree and water it thoroughly",
                "Take a photo of your newly planted tree"
            ]
        case .cleanUp:
            return [
                "Gather cleaning supplies and protective gear",
                "Identify an area that needs cleaning",
                "Collect and properly dispose of litter",
                "Take a before and after photo of the area"
            ]
        case .reduceEnergy:
            return [
                "Identify energy-consuming devices in your home",
                "Unplug unnecessary devices or use power strips",
                "Use natural light or energy-efficient bulbs",
                "Track your energy usage reduction"
            ]
        case .conserveWater:
            return [
                "Fix any leaky faucets or pipes",
                "Install water-saving devices on taps and showers",
                "Collect and reuse greywater for plants",
                "Track your water usage reduction"
            ]
        }
    }

    private var environmentalImpact: String {
        switch actionType {
        case .recycle:
            return "Recycling one ton of paper can save 17 trees and 7,000 gallons of water."
        case .plantTree:
            return "A single tree can absorb up to 48 pounds of CO2 per year and provide enough oxygen for two people."
        case .cleanUp:
            return "Removing litter prevents the release of harmful chemicals into the environment and protects wildlife from ingesting or becoming entangled in waste."
        case .reduceEnergy:
            return "Reducing household energy use by 20% can prevent up to 2,000 pounds of CO2 from entering the atmosphere annually."
        case .conserveWater:
            return "Saving 100 gallons of water per day would amount to 36,500 gallons per year, significantly reducing strain on water resources."
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct YouTubeVideoList: View {
    let searchQuery: String
    @State private var videos: [YouTubeVideo] = []

    var body: some View {
        List(videos) { video in
            NavigationLink(destination: YouTubeVideoView(videoId: video.id)) {
                HStack {
                    AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 120, height: 50)
                    .cornerRadius(8)

                    Text(video.title)
                        .lineLimit(2)
                }
            }
        }
        .onAppear {
            fetchVideos()
        }
    }

    private func fetchVideos() {
        // Implement YouTube API call here
        // For now, we'll use dummy data
        videos = [
            YouTubeVideo(id: "dQw4w9WgXcQ", title: "10 Creative Ways to Reuse Plastic Bottles", thumbnailUrl: "https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg"),
            YouTubeVideo(id: "dQw4w9WgXcQ", title: "DIY Plastic Bottle Crafts", thumbnailUrl: "https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg"),
            YouTubeVideo(id: "dQw4w9WgXcQ", title: "Upcycling Plastic: From Waste to Art", thumbnailUrl: "https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg")
        ]
    }
}

struct YouTubeVideo: Identifiable {
    let id: String
    let title: String
    let thumbnailUrl: String
}

struct YouTubeVideoView: View {
    let videoId: String

    var body: some View {
        WebView(urlString: "https://www.youtube.com/embed/\(videoId)")
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}

struct UserAction: Identifiable {
    let id = UUID()
    let type: ActionType
    let date: Date
    let description: String
    let location: String
    let peopleInvolved: String
}

struct ActionDetailWidget: View {
    let action: UserAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: action.type.iconName)
                .font(.title2)
                    .foregroundColor(.white)
                Spacer()
                Text("+\(action.type.creditValue)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(action.type.rawValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(action.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            HStack {
                Text(action.location)
                                .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(action.peopleInvolved)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(action.type.color)
        .cornerRadius(15)
        .shadow(color: action.type.color.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct ProfileActionsView: View {
    @State private var userActions: [UserAction] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(userActions) { action in
                    ActionDetailWidget(action: action)
            }
        }
        .padding()
        }
        .onAppear(perform: loadUserActions)
        .navigationTitle("My Actions")
    }
    
    private func loadUserActions() {
        // Sample data - replace with actual data loading logic
        userActions = [
            UserAction(type: .recycle,
                       date: Date().addingTimeInterval(-86400),
                       description: "Recycled paper and plastic bottles from the office",
                       location: "Office",
                       peopleInvolved: "Coworkers"),
            UserAction(type: .plantTree,
                       date: Date().addingTimeInterval(-172800),
                       description: "Planted an oak tree in the community garden",
                       location: "Community Garden",
                       peopleInvolved: "Neighbors"),
            UserAction(type: .cleanUp,
                       date: Date().addingTimeInterval(-259200),
                       description: "Participated in beach cleanup, collected 5 bags of trash",
                       location: "Local Beach",
                       peopleInvolved: "Volunteer Group"),
            UserAction(type: .reduceEnergy,
                       date: Date().addingTimeInterval(-345600),
                       description: "Installed LED bulbs throughout the house and set up smart thermostats",
                       location: "Home",
                       peopleInvolved: "Family")
        ]
    }
}

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var userData: UserData
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("colorScheme") private var appColorScheme: AppColorScheme = .light
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("dailyGoal") private var dailyGoal = 3
    @AppStorage("preferredUnits") private var preferredUnits = "Metric"
    @StateObject private var notificationManager = NotificationManager()
    @State private var activityData: [Date: Int] = [:]
    @State private var showingLanguagePicker = false
    @State private var selectedLanguage = "English"
    var onLogout: () -> Void

    var primaryColor: Color {
        colorScheme == .dark ? .green : .blue
    }
        
        var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Account Information")) {
                    Text("Name: \(userData.firstName) \(userData.lastName)")
                    Text("Email: \(userData.email)")
                    Text("Total Credits: \(userData.credits)")
                }
                
                Section(header: Text("Settings")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                        #if compiler(>=5.9) // Xcode 15+, iOS 17+
                        .onChange(of: isDarkMode) { _, newValue in
                            appColorScheme = newValue ? .dark : .light
                        }
                        #else
                        .onChange(of: isDarkMode) { newValue in
                            appColorScheme = newValue ? .dark : .light
                        }
                        #endif
                    
                    Toggle("Receive Notifications", isOn: $notificationsEnabled)
                        #if compiler(>=5.9) // Xcode 15+, iOS 17+
                        .onChange(of: notificationsEnabled) { _, newValue in
                            if newValue {
                                notificationManager.requestAuthorization()
                            } else {
                                // Disable notifications
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                        #else
                        .onChange(of: notificationsEnabled) { newValue in
                            if newValue {
                                notificationManager.requestAuthorization()
                            } else {
                                // Disable notifications
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                        #endif
                    
                    Stepper(value: $dailyGoal, in: 1...10) {
                        Text("Daily Goal: \(dailyGoal) actions")
                    }
                    
                    Picker("Preferred Units", selection: $preferredUnits) {
                        Text("Metric").tag("Metric")
                        Text("Imperial").tag("Imperial")
                    }
                    
                    Button("Change Language") {
                        showingLanguagePicker = true
                    }
                    .sheet(isPresented: $showingLanguagePicker) {
                        LanguagePicker(selectedLanguage: $selectedLanguage)
                    }
                }
                
                Section(header: Text("Actions")) {
                    NavigationLink("View My Actions") {
                        ProfileActionsView()
                    }
                }
                
                Section(header: Text("Activity History")) {
                    ActivityGraph(activityData: $activityData)
                        .padding(.vertical)
                }
                
                Section {
                    Button("Logout") {
                        onLogout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Profile")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear(perform: loadActivityData)
    }
    
    private func loadActivityData() {
        // Sample data - replace with actual data loading logic
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for day in 0..<365 {
            if let date = calendar.date(byAdding: .day, value: -day, to: today) {
                activityData[date] = Int.random(in: 0...5) // Random data for demonstration
            }
        }
    }
}

struct LanguagePicker: View {
    @Binding var selectedLanguage: String
    @Environment(\.presentationMode) var presentationMode
    
    let languages = ["English", "Swahili"]
        
        var body: some View {
        NavigationView {
            List {
                ForEach(languages, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(language)
                            Spacer()
                            if language == selectedLanguage {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        
        
        VStack(spacing: 20) {
            Text("Reset Password")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Enter your email address to reset your password")
                .font(.subheadline)
                .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
            
            
            if isValidEmail(email){
                Button(action: resetPassword) {
                    Text("Reset Password")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            else{
                Button(action: resetPassword) {
                    Text("Reset Password")
                        .font(.headline)
                        .foregroundColor(.white)
            .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .cornerRadius(10)
                }
                .disabled(true)
            }
        }
        .padding()
        .navigationTitle("Forgot Password")
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Password Reset"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func resetPassword() {
        // Implement password reset logic here
        // For now, we'll just show a success message
        alertMessage = "If an account exists for \(email), you will receive an email with instructions to reset your password."
        showingAlert = true
    }
}

struct ImpactMetricView: View {
    let icon: String
    let value: String
    let unit: String
        
        var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.green)
            Text(value)
                .font(.headline)
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActionGuideContent {
    let description: String
    let steps: [String]
    let environmentalImpact: String
    
    init(for actionType: ActionType) {
        switch actionType {
        case .recycle:
            description = "Recycling helps conserve natural resources and reduce waste in landfills."
            steps = [
                "Collect recyclable items",
                "Clean and sort items by material type",
                "Place items in appropriate recycling bins",
                "Take a photo of your recycling action"
            ]
            environmentalImpact = "Recycling reduces landfill waste, conserves natural resources, and decreases greenhouse gas emissions."
        case .plantTree:
            description = "Planting trees helps combat climate change and improve local ecosystems."
            steps = [
                "Choose a suitable location for planting",
                "Prepare the soil and dig a hole",
                "Plant the tree and water it thoroughly",
                "Take a photo of your newly planted tree"
            ]
            environmentalImpact = "Trees absorb CO2, provide habitat for wildlife, and improve air quality in urban areas."
        case .cleanUp:
            description = "Cleaning up litter helps protect wildlife and improve community spaces."
            steps = [
                "Gather cleaning supplies and protective gear",
                "Identify an area that needs cleaning",
                "Collect and properly dispose of litter",
                "Take a before and after photo of the area"
            ]
            environmentalImpact = "Removing litter prevents pollution of waterways, protects wildlife, and improves community aesthetics."
        case .reduceEnergy:
            description = "Reducing energy consumption helps lower greenhouse gas emissions."
            steps = [
                "Identify energy-consuming devices in your home",
                "Unplug unnecessary devices or use power strips",
                "Use natural light or energy-efficient bulbs",
                "Track your energy usage reduction"
            ]
            environmentalImpact = "Lowering energy consumption reduces greenhouse gas emissions and helps combat climate change."
        case .conserveWater:
            description = "Conserving water helps preserve this vital resource for future generations."
            steps = [
                "Fix any leaky faucets or pipes",
                "Install water-saving devices on taps and showers",
                "Collect and reuse greywater for plants",
                "Track your water usage reduction"
            ]
            environmentalImpact = "Water conservation helps preserve this vital resource, protects ecosystems, and reduces energy used for water treatment."
        }
    }
}

struct ChallengeCard: View {
    var body: some View {
                VStack(alignment: .leading) {
            Text("Recycle 5 items")
                        .font(.headline)
            Text("Earn 50 credits")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
                }
                
struct AchievementBadge: View {
    var body: some View {
                VStack {
            Image(systemName: "star.fill")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            Text("Eco Warrior")
                        .font(.caption)
            }
            .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ChallengesView: View {
    var body: some View {
        NavigationView {
            List {
                ForEach(0..<10) { _ in
                    ChallengeCard()
                }
            }
            .navigationTitle("Daily Challenges")
        }
    }
}

struct RewardsView: View {
    @ObservedObject var userData: UserData
    
    var body: some View {
        NavigationView {
            List {
                ForEach(0..<5) { index in
                    HStack {
                        Text("Eco-friendly Product \(index + 1)")
                        Spacer()
                        Text("\(100 * (index + 1)) credits")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Rewards")
        }
    }
}

struct AchievementsView: View {
    var body: some View {
        NavigationView {
            List {
                ForEach(0..<10) { _ in
                    AchievementBadge()
                }
            }
            .navigationTitle("Achievements")
        }
    }
}


func passwordStrengthCheck(password: String) -> [String] {
    var errors: [String] = []
    
    if password.count < 8 {
        errors.append("Password must be at least 8 characters long")
    }
    if !password.contains(where: { $0.isLowercase }) {
        errors.append("Password must contain at least one lowercase letter")
    }
    if !password.contains(where: { $0.isUppercase }) {
        errors.append("Password must contain at least one uppercase letter")
    }
    if !password.contains(where: { $0.isNumber }) {
        errors.append("Password must contain at least one number")
    }
    if !password.contains(where: { "!@#$%^&*()\\-_=+{};:,<.>".contains($0) }) {
        errors.append("Password must contain at least one special character")
    }
    if password.contains(where: { $0.isWhitespace }) {
        errors.append("Password cannot contain whitespace characters")
    }
    
    return errors
}

// Add this struct after the ActionGuideContent struct

struct ActionGuideView: View {
    let actionType: ActionType
    @Binding var selectedTab: Tab
    @Environment(\.presentationMode) var presentationMode
    
    // Preload the content
    private let content: ActionGuideContent
    
    init(actionType: ActionType, selectedTab: Binding<Tab>) {
        self.actionType = actionType
        self._selectedTab = selectedTab
        self.content = ActionGuideContent(for: actionType)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(actionType.rawValue)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(content.description)
                    .font(.body)
                
                Text("How to complete this action:")
                    .font(.headline)
                
                ForEach(content.steps, id: \.self) { step in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text(step)
                    }
                }
                
                Text("Environmental Impact:")
                    .font(.headline)
                
                Text(content.environmentalImpact)
                    .font(.body)
                
                Button("Start Action") {
                    selectedTab = .upload
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Action Guide")
    }
}

// Add this class before ContentView
class ImageClassifier {
    static let shared = ImageClassifier()
    private var classificationRequest: VNCoreMLRequest?
    
    init() {
        setupClassifier()
    }
    
    private func setupClassifier() {
        do {
            // Load the MobileNet model
            if let modelURL = Bundle.main.url(forResource: "MobileNet", withExtension: "mlmodelc") {
                let config = MLModelConfiguration()
                if let model = try? MLModel(contentsOf: modelURL, configuration: config) {
                    let vnModel = try VNCoreMLModel(for: model)
                    classificationRequest = VNCoreMLRequest(model: vnModel) { request, error in
                        if let error = error {
                            print("Classification error: \(error.localizedDescription)")
                            return
                        }
                    }
                    
                    // Configure the request for best accuracy
                    classificationRequest?.imageCropAndScaleOption = .centerCrop
                } else {
                    print("Error: Could not create MLModel")
                }
            } else {
                print("Error: MobileNet model file not found in bundle")
            }
        } catch {
            print("Error setting up classifier: \(error.localizedDescription)")
        }
    }
    
    func classifyImage(_ image: UIImage, completion: @escaping ([ClassificationResult]) -> Void) {
        guard let ciImage = CIImage(image: image),
              let request = classificationRequest else {
            completion([])
            return
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }
                
                // Filter and map the results
                let classifications = observations
                    .prefix(5) // Get top 5 results
                    .filter { $0.confidence > 0.1 } // Filter results with confidence > 10%
                    .map { ClassificationResult(
                        label: $0.identifier,
                        confidence: Double($0.confidence)
                    )}
                
                DispatchQueue.main.async {
                    completion(classifications)
                }
            } catch {
                print("Error classifying image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    func validateEnvironmentalAction(_ classifications: [ClassificationResult], for actionType: ActionType) -> Bool {
        // Define keywords for each action type
        let keywords: Set<String>
        
        switch actionType {
        case .recycle:
            keywords = ["bottle", "container", "plastic", "paper", "cardboard", "can", "glass", "recycling"]
        case .plantTree:
            keywords = ["tree", "plant", "garden", "soil", "sapling", "seedling", "nature"]
        case .cleanUp:
            keywords = ["trash", "garbage", "waste", "litter", "cleaning", "beach", "park"]
        case .reduceEnergy:
            keywords = ["light", "bulb", "led", "thermostat", "switch", "appliance"]
        case .conserveWater:
            keywords = ["water", "tap", "faucet", "shower", "irrigation", "garden"]
        }
        
        // Check if any of the top classifications match our keywords
        let classificationSet = Set(classifications.map { $0.label.lowercased().components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }.joined())
        return !keywords.isDisjoint(with: classificationSet)
    }
}

struct ClassificationResult: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Double
    
    var formattedConfidence: String {
        String(format: "%.1f%%", confidence * 100)
    }
}

