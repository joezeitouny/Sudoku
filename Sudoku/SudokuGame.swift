import SwiftUI
import Combine

struct SudokuGame: View {
    @StateObject private var viewModel = SudokuViewModel()
    @State private var showNewGameAlert = false
    @State private var selectedDifficulty: Difficulty = .easy
    @State private var showCongratulations = false

    var body: some View {
        VStack {
            HStack {
                Button("New Game") {
                    showNewGameAlert = true
                }
                Spacer()
                Text("Difficulty: \(viewModel.difficulty.rawValue)")
                Spacer()
                Text(viewModel.formattedTime)
            }
            .padding()

            SudokuBoard(viewModel: viewModel)

            HStack {
                ForEach(1...9, id: \.self) { number in
                    Button(action: {
                        viewModel.selectNumber(number)
                    }) {
                        Text("\(number)")
                            .frame(width: 30, height: 30)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(5)
                    }
                }
            }
            .padding()

            Button("Toggle Annotation Mode") {
                viewModel.toggleAnnotationMode()
            }
            .padding()

            Text("Best Time - Easy: \(viewModel.formattedBestTime(.easy))")
            Text("Best Time - Hard: \(viewModel.formattedBestTime(.hard))")
        }
        .alert(isPresented: $showNewGameAlert) {
            Alert(
                title: Text("New Game"),
                message: Text("Select difficulty"),
                primaryButton: .default(Text("Easy")) {
                    selectedDifficulty = .easy
                    viewModel.newGame(difficulty: .easy)
                },
                secondaryButton: .default(Text("Hard")) {
                    selectedDifficulty = .hard
                    viewModel.newGame(difficulty: .hard)
                }
            )
        }
        .alert("Congratulations!", isPresented: $showCongratulations) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You solved the puzzle in \(viewModel.formattedTime)!")
        }
        .onReceive(viewModel.$isPuzzleSolved) { isSolved in
            if isSolved {
                showCongratulations = true
            }
        }
    }
}

struct SudokuBoard: View {
    @ObservedObject var viewModel: SudokuViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3) { blockRow in
                HStack(spacing: 0) {
                    ForEach(0..<3) { blockCol in
                        VStack(spacing: 0) {
                            ForEach(0..<3) { row in
                                HStack(spacing: 0) {
                                    ForEach(0..<3) { col in
                                        SudokuCell(viewModel: viewModel,
                                                   row: blockRow * 3 + row,
                                                   col: blockCol * 3 + col)
                                    }
                                }
                            }
                        }
                        .border(Color.black, width: 2)
                    }
                }
            }
        }
        .border(Color.black, width: 2)
    }
}

struct SudokuCell: View {
    @ObservedObject var viewModel: SudokuViewModel
    let row: Int
    let col: Int

    var body: some View {
        let value = viewModel.board[row][col]
        let isFixed = viewModel.fixedCells[row][col]
        let annotations = viewModel.annotations[row][col]
        let isCorrect = viewModel.isCorrectMove(row: row, col: col)

        ZStack {
            Rectangle()
                .fill(isFixed ? Color.gray.opacity(0.3) : Color.white)
                .border(Color.black, width: 0.5)

            if value != 0 {
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isFixed ? .black : (isCorrect ? .blue : .red))
            } else if !annotations.isEmpty {
                VStack {
                    ForEach(0..<3) { row in
                        HStack {
                            ForEach(1...3, id: \.self) { col in
                                let num = row * 3 + col
                                if annotations.contains(num) {
                                    Text("\(num)")
                                        .font(.system(size: 10))
                                } else {
                                    Text(" ")
                                        .font(.system(size: 10))
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 40, height: 40)
        .onTapGesture {
            viewModel.cellTapped(row: row, col: col)
        }
    }
}


class SudokuViewModel: ObservableObject {
    @Published var board: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    @Published var fixedCells: [[Bool]] = Array(repeating: Array(repeating: false, count: 9), count: 9)
    @Published var annotations: [[[Int]]] = Array(repeating: Array(repeating: [], count: 9), count: 9)
    @Published var selectedNumber: Int?
    @Published var isAnnotationMode = false
    @Published var difficulty: Difficulty = .easy
    @Published var elapsedTime: TimeInterval = 0
    @Published var isPuzzleSolved = false

    private var solution: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    private var timer: Timer?
    private var bestTimes: [Difficulty: TimeInterval] = [.easy: .infinity, .hard: .infinity]

    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init() {
        newGame(difficulty: .easy)
    }

    func newGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        generateBoard()
        removeNumbers(forDifficulty: difficulty)
        resetAnnotations()
        startTimer()
        isPuzzleSolved = false
    }

    private func startTimer() {
        elapsedTime = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }

    func generateBoard() {
        board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        _ = solveSudoku(&board)
        solution = board
        fixedCells = board.map { $0.map { $0 != 0 } }
    }

    func solveSudoku(_ board: inout [[Int]]) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == 0 {
                    for num in 1...9 {
                        if isValid(board: board, row: row, col: col, num: num) {
                            board[row][col] = num
                            if solveSudoku(&board) {
                                return true
                            }
                            board[row][col] = 0
                        }
                    }
                    return false
                }
            }
        }
        return true
    }

    func isValid(board: [[Int]], row: Int, col: Int, num: Int) -> Bool {
        for x in 0..<9 {
            if board[row][x] == num || board[x][col] == num {
                return false
            }
        }

        let startRow = row - row % 3
        let startCol = col - col % 3
        for i in 0..<3 {
            for j in 0..<3 {
                if board[i + startRow][j + startCol] == num {
                    return false
                }
            }
        }

        return true
    }

    func removeNumbers(forDifficulty difficulty: Difficulty) {
        let numbersToRemove = difficulty == .easy ? 40 : 50
        var positions = Array(0..<81)
        positions.shuffle()

        for i in 0..<numbersToRemove {
            let row = positions[i] / 9
            let col = positions[i] % 9
            let temp = board[row][col]
            board[row][col] = 0
            fixedCells[row][col] = false

            var tempBoard = board
            let solutions = countSolutions(&tempBoard)
            if solutions != 1 {
                board[row][col] = temp
                fixedCells[row][col] = true
            }
        }
    }

    func countSolutions(_ board: inout [[Int]]) -> Int {
        var count = 0
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == 0 {
                    for num in 1...9 {
                        if isValid(board: board, row: row, col: col, num: num) {
                            board[row][col] = num
                            count += countSolutions(&board)
                            if count > 1 {
                                return count
                            }
                            board[row][col] = 0
                        }
                    }
                    return count
                }
            }
        }
        return 1
    }

    func resetAnnotations() {
            annotations = Array(repeating: Array(repeating: [], count: 9), count: 9)
        }

        func cellTapped(row: Int, col: Int) {
            guard !fixedCells[row][col] else { return }

            if isAnnotationMode {
                if let number = selectedNumber {
                    if annotations[row][col].contains(number) {
                        annotations[row][col].removeAll { $0 == number }
                    } else {
                        annotations[row][col].append(number)
                    }
                }
            } else {
                if let number = selectedNumber {
                    board[row][col] = number
                    checkPuzzleCompletion()
                }
            }
        }

        func selectNumber(_ number: Int) {
            selectedNumber = number
        }

        func toggleAnnotationMode() {
            isAnnotationMode.toggle()
        }

        func isCorrectMove(row: Int, col: Int) -> Bool {
            return board[row][col] == solution[row][col]
        }

        private func checkPuzzleCompletion() {
            if board == solution {
                timer?.invalidate()
                isPuzzleSolved = true
                updateBestTime()
            }
        }

        private func updateBestTime() {
            if elapsedTime < bestTimes[difficulty, default: .infinity] {
                bestTimes[difficulty] = elapsedTime
            }
        }

        func formattedBestTime(_ difficulty: Difficulty) -> String {
            let bestTime = bestTimes[difficulty, default: .infinity]
            if bestTime == .infinity {
                return "N/A"
            } else {
                let minutes = Int(bestTime) / 60
                let seconds = Int(bestTime) % 60
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
}

enum Difficulty: String {
    case easy = "Easy"
    case hard = "Hard"
}
