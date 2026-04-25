import SwiftUI
import Charts
import PhotosUI

struct ProgressTrackingView: View {
    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                if viewModel.isLoading && viewModel.workoutHistory.isEmpty {
                    ProgressView().tint(Constants.Colors.athleanRed)
                } else {
                    content
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingAddEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Constants.Colors.athleanRed)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddEntry) {
                AddProgressEntryView(viewModel: viewModel)
            }
            .task { await viewModel.loadProgress() }
            .refreshable { await viewModel.loadProgress() }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.sectionSpacing) {
                statsRow
                progressPhotoSection
                if !viewModel.weightHistory.isEmpty {
                    weightChart
                }
                workoutHistorySection
                if !viewModel.personalRecords.isEmpty {
                    personalRecordsSection
                }
            }
            .padding()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(viewModel.totalWorkoutsThisMonth)", label: "This Month", icon: "calendar.badge.checkmark")
            statCard(value: "\(viewModel.streakDays)", label: "Day Streak", icon: "flame.fill", color: .orange)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color = Constants.Colors.athleanRed) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Progress photos

    @ViewBuilder
    private var progressPhotoSection: some View {
        if let latest = viewModel.progressEntries.first(where: { !$0.photos.isEmpty }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("PROGRESS PHOTOS")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.textSecondary)
                        .tracking(1)
                    Spacer()
                    Text(latest.date.relativeString)
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                HStack(spacing: 8) {
                    ForEach([ProgressEntry.ProgressPhoto.PhotoAngle.front,
                             .side,
                             .back], id: \.self) { angle in
                        photoSlotDisplay(entry: latest, angle: angle)
                    }
                }
            }
            .cardStyle()
        }
    }

    private func photoSlotDisplay(entry: ProgressEntry, angle: ProgressEntry.ProgressPhoto.PhotoAngle) -> some View {
        VStack(spacing: 4) {
            Group {
                if let photo = entry.photos.first(where: { $0.angle == angle }),
                   let image = ProgressViewModel.loadProgressPhoto(photo.localPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Constants.Colors.secondaryBackground
                        .overlay(
                            Image(systemName: "person.crop.rectangle")
                                .font(.title2)
                                .foregroundColor(Constants.Colors.textSecondary)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipped()
            .cornerRadius(8)

            Text(angle.displayName.uppercased())
                .font(.caption2.bold())
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }

    // MARK: - Weight chart

    @ViewBuilder
    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEIGHT TREND")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            Chart(viewModel.weightHistory, id: \.0) { entry in
                LineMark(
                    x: .value("Date", entry.0),
                    y: .value("Weight", entry.1)
                )
                .foregroundStyle(Constants.Colors.athleanRed)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Date", entry.0),
                    y: .value("Weight", entry.1)
                )
                .foregroundStyle(Constants.Colors.athleanRed.opacity(0.1))
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(Constants.Colors.secondaryBackground)
                    AxisValueLabel().foregroundStyle(Constants.Colors.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(Constants.Colors.secondaryBackground)
                    AxisValueLabel().foregroundStyle(Constants.Colors.textSecondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - History / PRs

    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKOUT HISTORY")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            ForEach(viewModel.workoutHistory.prefix(10)) { entry in
                WorkoutHistoryRow(entry: entry)
            }
        }
    }

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERSONAL RECORDS")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            ForEach(viewModel.personalRecords.prefix(5)) { pr in
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(pr.exerciseName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(pr.weight)) lbs × \(pr.reps)")
                        .font(.subheadline.bold())
                        .foregroundColor(Constants.Colors.athleanRed)
                }
                .padding(.vertical, 6)
                if pr.id != viewModel.personalRecords.prefix(5).last?.id {
                    Divider().background(Constants.Colors.secondaryBackground)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Workout history row

struct WorkoutHistoryRow: View {
    let entry: WorkoutHistory

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.workoutTitle)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(entry.date.relativeString)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.duration)m")
                    .font(.subheadline.bold())
                    .foregroundColor(Constants.Colors.athleanRed)
                Text("\(entry.exerciseLogs.count) exercises")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Add progress entry

struct AddProgressEntryView: View {
    @ObservedObject var viewModel: ProgressViewModel
    @Environment(\.dismiss) var dismiss

    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var notes = ""

    // Photo picker state
    @State private var pendingPhotos: [ProgressEntry.ProgressPhoto.PhotoAngle: UIImage] = [:]
    @State private var activeAngle: ProgressEntry.ProgressPhoto.PhotoAngle = .front
    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var cameraImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                Form {
                    metricsSection
                    photoSection
                    notesSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Log Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: save)
                        .foregroundColor(Constants.Colors.athleanRed)
                        .fontWeight(.bold)
                }
            }
            .confirmationDialog("Progress Photo", isPresented: $showSourceDialog) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showLibraryPicker = true }
                if pendingPhotos[activeAngle] != nil {
                    Button("Remove Photo", role: .destructive) {
                        pendingPhotos[activeAngle] = nil
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $cameraImage)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showLibraryPicker, selection: $libraryItem, matching: .images)
            .onChange(of: cameraImage) { _, img in
                guard let img else { return }
                pendingPhotos[activeAngle] = img
                cameraImage = nil
            }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pendingPhotos[activeAngle] = image
                    }
                    libraryItem = nil
                }
            }
        }
    }

    // MARK: - Sections

    private var metricsSection: some View {
        Section("BODY METRICS") {
            HStack {
                Text("Weight (lbs)")
                    .foregroundColor(.white)
                Spacer()
                TextField("0.0", text: $weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(Constants.Colors.athleanRed)
            }
            HStack {
                Text("Body Fat %")
                    .foregroundColor(.white)
                Spacer()
                TextField("0.0", text: $bodyFat)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(Constants.Colors.athleanRed)
            }
        }
        .listRowBackground(Constants.Colors.cardBackground)
    }

    private var photoSection: some View {
        Section("PROGRESS PHOTOS") {
            HStack(spacing: 10) {
                photoSlotButton(angle: .front)
                photoSlotButton(angle: .side)
                photoSlotButton(angle: .back)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Constants.Colors.cardBackground)
        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
    }

    private var notesSection: some View {
        Section("NOTES") {
            TextField("How are you feeling?", text: $notes, axis: .vertical)
                .foregroundColor(.white)
                .lineLimit(3...6)
        }
        .listRowBackground(Constants.Colors.cardBackground)
    }

    // MARK: - Photo slot

    private func photoSlotButton(angle: ProgressEntry.ProgressPhoto.PhotoAngle) -> some View {
        Button {
            activeAngle = angle
            showSourceDialog = true
        } label: {
            VStack(spacing: 4) {
                Group {
                    if let image = pendingPhotos[angle] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundColor(Constants.Colors.success)
                                    .padding(4)
                            }
                    } else {
                        Constants.Colors.secondaryBackground
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                                    .foregroundColor(Constants.Colors.textSecondary)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .clipped()
                .cornerRadius(8)

                Text(angle.displayName.uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(
                        pendingPhotos[angle] != nil
                            ? Constants.Colors.success
                            : Constants.Colors.textSecondary
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() {
        var photos: [ProgressEntry.ProgressPhoto] = []
        for angle in [ProgressEntry.ProgressPhoto.PhotoAngle.front, .side, .back] {
            guard let image = pendingPhotos[angle],
                  let path = ProgressViewModel.saveProgressPhoto(image) else { continue }
            photos.append(ProgressEntry.ProgressPhoto(id: UUID(), localPath: path, angle: angle))
        }
        let entry = ProgressEntry(
            id: UUID(),
            date: Date(),
            weight: Double(weight),
            bodyFatPercentage: Double(bodyFat),
            measurements: nil,
            photos: photos,
            notes: notes.isEmpty ? nil : notes
        )
        viewModel.addProgressEntry(entry)
        dismiss()
    }
}

// MARK: - Camera picker (UIImagePickerController wrapper)

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
