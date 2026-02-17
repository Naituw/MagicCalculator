//
//  ViewController.swift
//  MagicCalculator
//
//  Created by 吴天 on 2026/2/16.
//

import UIKit
import CoreMotion

/// 魔术计算器的状态机
enum MagicState {
    case inputFirstNumber      // 等待输入第一个数字（4位数）
    case waitingSecondNumber   // 按了加号，等待开始输入第二个数字
    case inputSecondNumber     // 正在输入第二个数字
    case waitingMagicInput     // 按了加号，等待开始魔术输入
    case magicInput            // 魔术模式：无论按什么都显示魔术数字
    case showFinalResult       // 显示最终日期时间结果
}

class ViewController: UIViewController {
    
    // MARK: - UI Components
    private var displayLabel: UILabel!       // 显示主数字和表达式
    private var buttons: [[UIButton]] = []
    
    // MARK: - Calculator State
    private var currentState: MagicState = .inputFirstNumber
    private var displayText: String = "0"    // 当前显示的完整文本
    private var currentInputValue: String = "0"  // 当前正在输入的数字
    private var firstNumber: Int = 0           // 观众A的4位数
    private var secondNumber: Int = 0          // 观众B的5位数
    private var sumResult: Int = 0             // A + B 的结果
    private var magicNumber: Int = 0           // 第4步需要显示的魔术数字
    private var magicDigits: [Int] = []        // 魔术数字的各位数字
    private var currentMagicIndex: Int = 0     // 当前显示到魔术数字的第几位
    
    // MARK: - Motion Detection
    private let motionManager = CMMotionManager()
    private var isScreenFacingDown: Bool = false
    
    // MARK: - Haptic Feedback
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)      // 轻触反馈（普通输入）
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)      // 强烈反馈（魔术提示）
    
    // 是否已经输入完所有魔术数字（根据 magicDigits.count 动态决定）
    private var magicInputReady: Bool = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMotionDetection()
        setupGestureRecognizer()
        lightImpact.prepare()
        notificationFeedback.prepare()
        heavyImpact.prepare()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motionManager.stopDeviceMotionUpdates()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 主显示屏
        displayLabel = UILabel()
        displayLabel.text = "0"
        displayLabel.textColor = .white
        displayLabel.font = UIFont.systemFont(ofSize: 88, weight: .light)
        displayLabel.textAlignment = .right
        displayLabel.adjustsFontSizeToFitWidth = true
        displayLabel.minimumScaleFactor = 0.3
        displayLabel.numberOfLines = 1
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(displayLabel)
        
        // 按钮布局配置 - 更接近 iOS 计算器
        let buttonTitles = [
            ["⌫", "AC", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "-"],
            ["1", "2", "3", "+"],
            ["0", "", ".", "="]
        ]
        
        let operatorButtons = Set(["÷", "×", "-", "+", "="])
        let functionButtons = Set(["⌫", "AC", "%"])
        
        // 创建按钮容器
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainer)
        
        // 创建按钮
        let spacing: CGFloat = 14
        let buttonSize: CGFloat = (UIScreen.main.bounds.width - spacing * 5) / 4
        
        for (rowIndex, row) in buttonTitles.enumerated() {
            var buttonRow: [UIButton] = []
            for (colIndex, title) in row.enumerated() {
                if title.isEmpty { continue }
                
                let button = UIButton(type: .system)
                button.setTitle(title, for: .normal)
                button.setTitleColor(.white, for: .normal)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
                
                // 设置按钮样式
                if operatorButtons.contains(title) {
                    button.backgroundColor = .systemOrange
                    button.titleLabel?.font = UIFont.systemFont(ofSize: 40, weight: .medium)
                } else if functionButtons.contains(title) {
                    button.backgroundColor = UIColor(white: 0.65, alpha: 1)
                    button.setTitleColor(.black, for: .normal)
                    if title == "⌫" {
                        button.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)
                    } else {
                        button.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)
                    }
                } else {
                    button.backgroundColor = UIColor(white: 0.2, alpha: 1)
                    button.titleLabel?.font = UIFont.systemFont(ofSize: 36, weight: .regular)
                }
                
                button.layer.cornerRadius = buttonSize / 2
                buttonContainer.addSubview(button)
                
                // 0按钮特殊处理（横跨两格）
                let isZeroButton = title == "0"
                let buttonWidth = isZeroButton ? buttonSize * 2 + spacing : buttonSize
                
                NSLayoutConstraint.activate([
                    button.widthAnchor.constraint(equalToConstant: buttonWidth),
                    button.heightAnchor.constraint(equalToConstant: buttonSize),
                    button.topAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: CGFloat(rowIndex) * (buttonSize + spacing)),
                    button.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: CGFloat(colIndex) * (buttonSize + spacing))
                ])
                
                // 0按钮内容左对齐
                if isZeroButton {
                    button.contentHorizontalAlignment = .left
                    button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 0)
                }
                
                buttonRow.append(button)
            }
            buttons.append(buttonRow)
        }
        
        // 布局约束
        NSLayoutConstraint.activate([
            displayLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            displayLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            displayLabel.bottomAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: -16),
            displayLabel.heightAnchor.constraint(equalToConstant: 100),
            
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: spacing),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -spacing),
            buttonContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            buttonContainer.heightAnchor.constraint(equalToConstant: CGFloat(buttonTitles.count) * (buttonSize + spacing) - spacing)
        ])
    }
    
    // MARK: - Motion Detection
    
    private func setupMotionDetection() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let motion = motion, error == nil else { return }
            
            // 检测屏幕是否朝下
            // gravity.z > 0.7 表示屏幕朝下（设备正面朝向地面）
            self?.isScreenFacingDown = motion.gravity.z > 0.7
        }
    }
    
    // MARK: - Gesture Recognizer
    
    private func setupGestureRecognizer() {
        // 添加点击手势识别器，覆盖整个屏幕
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(screenTapped(_:)))
        // 在魔术模式下需要拦截所有点击，所以默认 cancelsTouchesInView = true
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func screenTapped(_ gesture: UITapGestureRecognizer) {
        // 在魔术输入模式且屏幕朝下时，点击屏幕任何位置都输入数字
        if (currentState == .magicInput || currentState == .waitingMagicInput) && isScreenFacingDown {
            // 触发反馈
            if magicInputReady {
                heavyImpact.impactOccurred()
            } else {
                lightImpact.impactOccurred()
            }
            
            // 输入魔术数字
            handleNumberInput("")  // 传入空字符串，反正魔术模式下会忽略
            updateDisplay()
            return
        }
        
        // 非魔术模式下，检查是否点击在按钮上
        let location = gesture.location(in: view)
        for buttonRow in buttons {
            for button in buttonRow {
                if button.frame.contains(view.convert(location, to: button.superview)) {
                    // 点击在按钮上，手动触发按钮点击
                    buttonTapped(button)
                    return
                }
            }
        }
        
        // 点击在空白区域，什么都不做
    }
    
    // MARK: - Button Actions
    
    @objc private func buttonTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        
        // 根据状态决定触觉反馈
        if magicInputReady {
            // 魔术输入就绪，每次都发出强烈反馈
            heavyImpact.impactOccurred()
        } else {
            // 普通输入，轻触反馈
            lightImpact.impactOccurred()
        }
        
        // 在魔术输入模式且屏幕朝下时，所有按钮都视为输入数字
        if (currentState == .magicInput || currentState == .waitingMagicInput) && isScreenFacingDown {
            handleNumberInput(title)  // 无论按什么，都当作输入数字
            updateDisplay()
            return
        }
        
        // 正常模式下的按钮处理
        switch title {
        case "0"..."9":
            handleNumberInput(title)
        case "+":
            handlePlus()
        case "=":
            handleEquals()
        case "AC":
            handleClear()
        case "⌫":
            handleBackspace()
        case ".":
            handleDecimal()
        default:
            // 其他运算符暂不处理（÷、×、-、%）
            break
        }
        
        updateDisplay()
    }
    
    // MARK: - Input Handlers
    
    private func handleNumberInput(_ digit: String) {
        switch currentState {
        case .inputFirstNumber:
            // 正常输入第一个数字
            if currentInputValue == "0" {
                currentInputValue = digit
            } else {
                currentInputValue += digit
            }
            displayText = currentInputValue
            
        case .waitingSecondNumber:
            // 开始输入第二个数字，替换显示
            currentInputValue = digit
            displayText = formatNumber(firstNumber) + "+" + digit
            currentState = .inputSecondNumber
            
        case .inputSecondNumber:
            // 继续输入第二个数字
            currentInputValue += digit
            displayText = formatNumber(firstNumber) + "+" + currentInputValue
            
        case .waitingMagicInput:
            // 开始魔术输入
            currentState = .magicInput
            currentMagicIndex = 0
            fallthrough
            
        case .magicInput:
            // 魔术模式：无论按什么数字，都显示魔术数字的下一位
            if currentMagicIndex < magicDigits.count {
                if currentMagicIndex == 0 {
                    currentInputValue = String(magicDigits[currentMagicIndex])
                } else {
                    currentInputValue += String(magicDigits[currentMagicIndex])
                }
                currentMagicIndex += 1
                displayText = formatNumber(sumResult) + "+" + currentInputValue
                
                // 当输入完所有魔术数字时，标记为就绪
                if currentMagicIndex >= magicDigits.count && !magicInputReady {
                    magicInputReady = true
                    // 输入完成，发出成功提示（下一次按键开始会用 heavy 反馈）
                    notificationFeedback.notificationOccurred(.success)
                }
            }
            // 如果已经显示完所有魔术数字，继续发出 heavy 反馈但不增加数字
            
        case .showFinalResult:
            // 最终结果显示后，如果按数字，重置
            resetCalculator()
            currentInputValue = digit
            displayText = digit
        }
    }
    
    private func handlePlus() {
        switch currentState {
        case .inputFirstNumber:
            // 保存第一个数字，显示加号
            firstNumber = Int(currentInputValue) ?? 0
            displayText = formatNumber(firstNumber) + "+"
            currentInputValue = "0"
            currentState = .waitingSecondNumber
            
        case .waitingSecondNumber:
            // 已经按了加号，忽略重复按加号
            break
            
        case .inputSecondNumber:
            // 按加号相当于"等号+加号"的效果
            // 先计算 A + B
            secondNumber = Int(currentInputValue) ?? 0
            sumResult = firstNumber + secondNumber
            // 准备魔术数字
            prepareMagicNumber()
            // 显示结果+加号
            displayText = formatNumber(sumResult) + "+"
            currentInputValue = "0"
            currentState = .waitingMagicInput
            
        case .waitingMagicInput:
            // 已经在等待魔术输入，忽略
            break
            
        case .magicInput:
            // 魔术模式下忽略加号
            break
            
        case .showFinalResult:
            // 最终结果后按加号，重置
            resetCalculator()
        }
    }
    
    private func handleEquals() {
        switch currentState {
        case .inputFirstNumber:
            // 只输入了一个数字，忽略
            break
            
        case .waitingSecondNumber:
            // 按了加号但还没输入数字，忽略
            break
            
        case .inputSecondNumber:
            // 计算 A + B 并显示结果
            secondNumber = Int(currentInputValue) ?? 0
            sumResult = firstNumber + secondNumber
            displayText = formatNumber(sumResult)
            currentInputValue = String(sumResult)
            // 准备魔术数字（为下一步做准备）
            prepareMagicNumber()
            currentState = .waitingMagicInput
            
        case .waitingMagicInput:
            // 等待魔术输入时按等号，忽略
            break
            
        case .magicInput:
            // 检查屏幕是否朝下
            if isScreenFacingDown {
                // 屏幕朝下，不允许按等号，给一个警告反馈
                notificationFeedback.notificationOccurred(.warning)
                return
            }
            
            // 显示最终日期时间结果
            let targetNumber = generateTargetNumber()
            displayText = formatNumber(targetNumber)
            currentState = .showFinalResult
            magicInputReady = false
            
            // 成功完成魔术，强烈反馈
            notificationFeedback.notificationOccurred(.success)
            
        case .showFinalResult:
            // 最终结果后按等号，重置
            resetCalculator()
        }
    }
    
    private func handleClear() {
        resetCalculator()
    }
    
    private func handleBackspace() {
        switch currentState {
        case .inputFirstNumber:
            if currentInputValue.count > 1 {
                currentInputValue.removeLast()
            } else {
                currentInputValue = "0"
            }
            displayText = currentInputValue
            
        case .waitingSecondNumber:
            // 退格回到输入第一个数字的状态
            currentInputValue = String(firstNumber)
            displayText = currentInputValue
            currentState = .inputFirstNumber
            
        case .inputSecondNumber:
            if currentInputValue.count > 1 {
                currentInputValue.removeLast()
                displayText = formatNumber(firstNumber) + "+" + currentInputValue
            } else {
                // 退格到等待输入状态
                currentInputValue = "0"
                displayText = formatNumber(firstNumber) + "+"
                currentState = .waitingSecondNumber
            }
            
        case .waitingMagicInput:
            // 退格回到显示结果状态
            displayText = formatNumber(sumResult)
            
        case .magicInput:
            // 魔术模式下忽略退格
            break
            
        case .showFinalResult:
            break
        }
    }
    
    private func handleDecimal() {
        // 计算器魔术不需要小数，忽略
    }
    
    // MARK: - Magic Logic
    
    /// 生成目标数字（当前日期+时间）
    /// 例如：2月16日14:18 → 2161418
    private func generateTargetNumber() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // 组合成目标数字: 月日时分
        // 例如: 2月16日14:18 → 2161418
        let targetString = String(format: "%d%02d%02d%02d", month, day, hour, minute)
        return Int(targetString) ?? 0
    }
    
    /// 准备魔术数字
    /// 魔术数字 = 目标数字 - 当前累加结果
    private func prepareMagicNumber() {
        let targetNumber = generateTargetNumber()
        magicNumber = targetNumber - sumResult
        
        // 将魔术数字拆分成各位数字
        magicDigits = []
        var temp = abs(magicNumber)
        
        if temp == 0 {
            magicDigits = [0]
        } else {
            while temp > 0 {
                magicDigits.insert(temp % 10, at: 0)
                temp /= 10
            }
        }
        
        // 如果魔术数字是负数，我们需要处理（但正常情况下不应该发生）
        if magicNumber < 0 {
            print("Warning: Magic number is negative! A+B is too large.")
        }
        
        currentMagicIndex = 0
        magicInputReady = false
    }
    
    /// 重置计算器
    private func resetCalculator() {
        currentState = .inputFirstNumber
        displayText = "0"
        currentInputValue = "0"
        firstNumber = 0
        secondNumber = 0
        sumResult = 0
        magicNumber = 0
        magicDigits = []
        currentMagicIndex = 0
        magicInputReady = false
    }
    
    // MARK: - Display
    
    private func updateDisplay() {
        // 格式化显示
        displayLabel.text = displayText
    }
    
    /// 格式化数字，添加千位分隔符
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
    
    // MARK: - Status Bar
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
