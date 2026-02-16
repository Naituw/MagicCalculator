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
    case inputSecondNumber     // 等待输入第二个数字（5位数）
    case showFirstResult       // 显示 A+B 的结果
    case magicInput            // 魔术模式：无论按什么都显示魔术数字
    case showFinalResult       // 显示最终日期时间结果
}

class ViewController: UIViewController {
    
    // MARK: - UI Components
    private var expressionLabel: UILabel!   // 显示表达式（如 89,502+2,072,725）
    private var displayLabel: UILabel!       // 显示主数字
    private var buttons: [[UIButton]] = []
    
    // MARK: - Calculator State
    private var currentState: MagicState = .inputFirstNumber
    private var displayValue: String = "0"
    private var expressionText: String = ""  // 表达式文本
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
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    
    // 魔术数字输入达到多少位时发出反馈
    private let hapticThreshold = 5
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMotionDetection()
        impactFeedback.prepare()
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
        
        // 表达式标签（小字，显示在上方）
        expressionLabel = UILabel()
        expressionLabel.text = ""
        expressionLabel.textColor = UIColor(white: 0.6, alpha: 1)
        expressionLabel.font = UIFont.systemFont(ofSize: 28, weight: .regular)
        expressionLabel.textAlignment = .right
        expressionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(expressionLabel)
        
        // 主显示屏
        displayLabel = UILabel()
        displayLabel.text = "0"
        displayLabel.textColor = .white
        displayLabel.font = UIFont.systemFont(ofSize: 88, weight: .light)
        displayLabel.textAlignment = .right
        displayLabel.adjustsFontSizeToFitWidth = true
        displayLabel.minimumScaleFactor = 0.3
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
            expressionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            expressionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            expressionLabel.bottomAnchor.constraint(equalTo: displayLabel.topAnchor, constant: -4),
            
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
    
    // MARK: - Button Actions
    
    @objc private func buttonTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        
        // 按钮点击反馈
        impactFeedback.impactOccurred()
        
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
        case .inputFirstNumber, .inputSecondNumber:
            // 正常输入模式
            if displayValue == "0" {
                displayValue = digit
            } else {
                displayValue += digit
            }
            
        case .showFirstResult:
            // 显示结果后，如果按数字，不做任何事
            break
            
        case .magicInput:
            // 魔术模式：无论按什么数字，都显示魔术数字的下一位
            if currentMagicIndex < magicDigits.count {
                if currentMagicIndex == 0 {
                    displayValue = String(magicDigits[currentMagicIndex])
                } else {
                    displayValue += String(magicDigits[currentMagicIndex])
                }
                currentMagicIndex += 1
                
                // 当输入足够多位数时，发出 haptic 反馈
                if currentMagicIndex >= hapticThreshold && currentMagicIndex == magicDigits.count {
                    // 输入完成，发出成功反馈
                    notificationFeedback.notificationOccurred(.success)
                } else if currentMagicIndex == hapticThreshold {
                    // 达到阈值，发出强烈反馈提示可以按等号了
                    heavyImpact.impactOccurred()
                }
            }
            // 如果已经显示完所有魔术数字，忽略更多输入
            
        case .showFinalResult:
            // 最终结果显示后，如果按数字，重置
            resetCalculator()
            displayValue = digit
        }
    }
    
    private func handlePlus() {
        switch currentState {
        case .inputFirstNumber:
            // 保存第一个数字，切换到输入第二个数字
            firstNumber = Int(displayValue) ?? 0
            // 显示表达式：数字+
            expressionText = formatNumber(firstNumber) + "+"
            displayValue = "0"
            currentState = .inputSecondNumber
            
        case .inputSecondNumber:
            // 不应该在这里按加号，忽略
            break
            
        case .showFirstResult:
            // 准备魔术输入
            prepareMagicNumber()
            // 显示表达式：结果+
            expressionText = formatNumber(sumResult) + "+"
            displayValue = "0"
            currentState = .magicInput
            
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
            
        case .inputSecondNumber:
            // 计算 A + B
            secondNumber = Int(displayValue) ?? 0
            sumResult = firstNumber + secondNumber
            // 显示表达式
            expressionText = formatNumber(firstNumber) + "+" + formatNumber(secondNumber)
            displayValue = String(sumResult)
            currentState = .showFirstResult
            
        case .showFirstResult:
            // 显示结果后按等号，忽略
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
            let magicInputValue = Int(displayValue) ?? 0
            // 显示表达式
            expressionText = formatNumber(sumResult) + "+" + formatNumber(magicInputValue)
            displayValue = String(targetNumber)
            currentState = .showFinalResult
            
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
        case .inputFirstNumber, .inputSecondNumber:
            if displayValue.count > 1 {
                displayValue.removeLast()
            } else {
                displayValue = "0"
            }
        case .magicInput:
            // 魔术模式下忽略退格
            break
        default:
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
            // 这种情况说明 A+B 已经大于目标数字了
            // 可以考虑显示错误或者用其他方式处理
            print("Warning: Magic number is negative! A+B is too large.")
        }
        
        currentMagicIndex = 0
    }
    
    /// 重置计算器
    private func resetCalculator() {
        currentState = .inputFirstNumber
        displayValue = "0"
        expressionText = ""
        firstNumber = 0
        secondNumber = 0
        sumResult = 0
        magicNumber = 0
        magicDigits = []
        currentMagicIndex = 0
    }
    
    // MARK: - Display
    
    private func updateDisplay() {
        // 更新表达式标签
        expressionLabel.text = expressionText
        
        // 格式化主显示，添加千位分隔符
        if let number = Int(displayValue) {
            displayLabel.text = formatNumber(number)
        } else {
            displayLabel.text = displayValue
        }
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
