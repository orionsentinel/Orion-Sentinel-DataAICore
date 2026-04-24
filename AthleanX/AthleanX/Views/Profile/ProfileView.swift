import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutConfirmation = false
    @State private var notificationsEnabled = true
    @State private var workoutReminders = true
    @AppStorage(Constants.UserDefaults.preferredWeightUnit) private var weightUnit = "lbs"

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                List {
                    profileHeader
                    membershipSection
                    preferencesSection
                    supportSection
                    logoutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    Task { await authViewModel.logout() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private var profileHeader: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Constants.Colors.athleanRed)
                        .frame(width: 72, height: 72)
                    Text(authViewModel.currentUser?.firstName.prefix(1).uppercased() ?? "A")
                        .font(.title.bold())
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(authViewModel.currentUser?.fullName ?? "Athlete")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(authViewModel.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                    if let user = authViewModel.currentUser {
                        membershipBadge(user.membershipType)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Constants.Colors.cardBackground)
    }

    private func membershipBadge(_ type: User.MembershipType) -> some View {
        Text(type == .allAxcess ? "ALL AXCESS" : "STANDARD")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(type == .allAxcess ? Constants.Colors.athleanRed : Constants.Colors.secondaryBackground)
            .cornerRadius(4)
            .tracking(1)
    }

    private var membershipSection: some View {
        Section("MEMBERSHIP") {
            NavigationLink {
                MembershipView()
            } label: {
                Label("Manage Membership", systemImage: "star.circle.fill")
                    .foregroundColor(.white)
            }
            if let expiry = authViewModel.currentUser?.membershipExpiry {
                HStack {
                    Label("Expires", systemImage: "calendar")
                        .foregroundColor(.white)
                    Spacer()
                    Text(expiry.formatted("MMM d, yyyy"))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
        }
        .listRowBackground(Constants.Colors.cardBackground)
    }

    private var preferencesSection: some View {
        Section("PREFERENCES") {
            Toggle(isOn: $notificationsEnabled) {
                Label("Push Notifications", systemImage: "bell.fill")
                    .foregroundColor(.white)
            }
            .tint(Constants.Colors.athleanRed)

            Toggle(isOn: $workoutReminders) {
                Label("Workout Reminders", systemImage: "clock.fill")
                    .foregroundColor(.white)
            }
            .tint(Constants.Colors.athleanRed)

            HStack {
                Label("Weight Unit", systemImage: "scalemass.fill")
                    .foregroundColor(.white)
                Spacer()
                Picker("", selection: $weightUnit) {
                    Text("lbs").tag("lbs")
                    Text("kg").tag("kg")
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
        }
        .listRowBackground(Constants.Colors.cardBackground)
    }

    private var supportSection: some View {
        Section("SUPPORT") {
            NavigationLink {
                CommunityView()
            } label: {
                Label("Community Forum", systemImage: "person.3.fill")
                    .foregroundColor(.white)
            }
            Link(destination: URL(string: "https://support.athleanx.com")!) {
                Label("Get Expert Support", systemImage: "questionmark.circle.fill")
                    .foregroundColor(.white)
            }
            Link(destination: URL(string: "https://athleanx.com")!) {
                Label("Visit ATHLEAN-X", systemImage: "globe")
                    .foregroundColor(.white)
            }
        }
        .listRowBackground(Constants.Colors.cardBackground)
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "arrow.backward.circle.fill")
            }
        }
        .listRowBackground(Constants.Colors.cardBackground)
    }
}

struct MembershipView: View {
    var body: some View {
        ZStack {
            Constants.Colors.athleanDark.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)
                        Text("ALL AXCESS")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .tracking(4)
                        Text("The complete ATHLEAN-X experience")
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 12) {
                        membershipFeature("40+ Training Programs", icon: "list.clipboard.fill")
                        membershipFeature("Customizable Meal Plans", icon: "fork.knife")
                        membershipFeature("120+ Exercise Library", icon: "dumbbell.fill")
                        membershipFeature("Expert Support Access", icon: "person.fill.questionmark")
                        membershipFeature("Private Community Forum", icon: "person.3.fill")
                        membershipFeature("Progress Tracking Tools", icon: "chart.line.uptrend.xyaxis")
                        membershipFeature("Unlimited Ab Generator", icon: "bolt.fill")
                        membershipFeature("New Programs Included", icon: "sparkles")
                    }
                    .padding()
                    .background(Constants.Colors.cardBackground)
                    .cornerRadius(Constants.UI.cornerRadius)
                    .padding(.horizontal)

                    Link(destination: URL(string: "https://athleanx.com/all-axcess")!) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Upgrade Membership")
                                .fontWeight(.bold)
                        }
                    }
                    .athleanButtonStyle()
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Membership")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func membershipFeature(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Constants.Colors.athleanRed)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}
