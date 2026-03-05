import XCTest
@testable import Alma

final class AlmaTests: XCTestCase {

    // MARK: - MeditationViewModel

    func testMeditationViewModelStart() {
        let vm = MeditationViewModel()
        vm.start(duration: 60)
        XCTAssertTrue(vm.isPlaying)
        XCTAssertEqual(vm.timeRemaining, 60)
        XCTAssertFalse(vm.hasCompleted)
        vm.stop()
    }

    func testMeditationViewModelToggle() {
        let vm = MeditationViewModel()
        vm.start(duration: 120)
        XCTAssertTrue(vm.isPlaying)
        vm.togglePlayPause()
        XCTAssertFalse(vm.isPlaying)
        vm.togglePlayPause()
        XCTAssertTrue(vm.isPlaying)
        vm.stop()
    }

    func testFormattedTime() {
        let vm = MeditationViewModel()
        vm.start(duration: 150)
        vm.togglePlayPause() // pause immediately so timer doesn't fire
        XCTAssertEqual(vm.formattedTime, "02:30")
        vm.stop()
    }

    // MARK: - MoodViewModel

    func testMoodAdd() {
        let vm = MoodViewModel()
        let before = vm.entries.count
        vm.add(mood: .great, note: "Feeling awesome")
        XCTAssertEqual(vm.entries.count, before + 1)
        XCTAssertEqual(vm.entries.first?.mood, .great)
    }

    func testTodayEntry() {
        let vm = MoodViewModel()
        vm.add(mood: .good, note: "")
        XCTAssertNotNil(vm.todayEntry)
        XCTAssertEqual(vm.todayEntry?.mood, .good)
    }

    // MARK: - Meditation Model

    func testMeditationFormattedDuration() {
        let med = Meditation.all[0]
        XCTAssertEqual(med.formattedDuration, "\(med.duration / 60) min")
    }

    func testMeditationSampleDataNotEmpty() {
        XCTAssertFalse(Meditation.all.isEmpty)
    }

    // MARK: - MoodEntry

    func testMoodLevelEmoji() {
        XCTAssertEqual(MoodEntry.MoodLevel.great.emoji, "😄")
        XCTAssertEqual(MoodEntry.MoodLevel.terrible.emoji, "😔")
    }
}
