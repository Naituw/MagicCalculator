//
//  ViewController.swift
//  MagicCalculator
//
//  Created by 吴天 on 2026/2/16.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: - UI
    
    private var displayLabel: UILabel!
    
    // MARK: - Calculator State
    
    private var displayText = "0" {
        didSet { refreshDisplay() }
    }
    private var storedValue = 0
    private var isTyping = false
    private var showingResult = false
    
    // MARK: - Magic State
    
    /// 魔术模式：观众乱点阶段，所有按键都产生魔术数字的下一位
    private var magicActive = false
    /// 魔术数字已全部输入完毕，等待魔术师按 =
    private var waitingForEquals = false
    /// 魔术已完成（最终结果已显示），防止再次触发
    private var trickDone = false
    /// 目标数字各位数字的字符串（C = target - sum）
    private var magicDigits = ""
    /// 当前已显示到第几位
    private var magicIndex = 0
    
    // MARK: - Haptic
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let successFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        lightImpact.prepare()
        heavyImpact.prepare()
        successFeedback.prepare()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // 显示屏
        displayLabel = UILabel()
        displayLabel.text = "0"
        displayLabel.textColor = .white
        displayLabel.font = .systemFont(ofSize: 80, weight: .light)
        displayLabel.textAlignment = .right
        displayLabel.adjustsFontSizeToFitWidth = true
        displayLabel.minimumScaleFactor = 0.2
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(displayLabel)
        
        // 按钮网格容器
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)
        
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            displayLabel.leadingAnchor.constraint(equalTo: grid.leadingAnchor, constant: 8),
            displayLabel.trailingAnchor.constraint(equalTo: grid.trailingAnchor, constant: -8),
            displayLabel.bottomAnchor.constraint(equalTo: grid.topAnchor, constant: -20),
        ])
        
        let numBg = UIColor(white: 0.2, alpha: 1)
        let opBg = UIColor.systemOrange
        let fnBg = UIColor(white: 0.65, alpha: 1)
        
        // (标题, 背景色, 文字色, 列宽倍数)
        let rows: [[(String, UIColor, UIColor, Int)]] = [
            [("AC",  fnBg,  .black, 1), ("+/−", fnBg,  .black, 1), ("%",  fnBg,  .black, 1), ("÷", opBg, .white, 1)],
            [("7",   numBg, .white, 1), ("8",   numBg, .white, 1), ("9",  numBg, .white, 1), ("×", opBg, .white, 1)],
            [("4",   numBg, .white, 1), ("5",   numBg, .white, 1), ("6",  numBg, .white, 1), ("−", opBg, .white, 1)],
            [("1",   numBg, .white, 1), ("2",   numBg, .white, 1), ("3",  numBg, .white, 1), ("+", opBg, .white, 1)],
            [("0",   numBg, .white, 2), (".",   numBg, .white, 1), ("=",  opBg, .white, 1)],
        ]
        
        var refButton: UIButton?
        
        for rowDef in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 12
            rowStack.distribution = .fill
            
            for (title, bg, fg, span) in rowDef {
                let btn = UIButton(type: .custom)
                btn.setTitle(title, for: .normal)
                btn.backgroundColor = bg
                btn.setTitleColor(fg, for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: 32, weight: .regular)
                btn.clipsToBounds = true
                btn.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
                btn.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
                btn.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
                
                rowStack.addArrangedSubview(btn)
                
                if span == 1 {
                    if refButton == nil {
                        refButton = btn
                    } else {
                        btn.widthAnchor.constraint(equalTo: refButton!.widthAnchor).isActive = true
                    }
                    btn.heightAnchor.constraint(equalTo: btn.widthAnchor).isActive = true
                } else {
                    // "0" 按钮：宽度 = 2倍按钮 + 1个间距
                    btn.widthAnchor.constraint(equalTo: refButton!.widthAnchor, multiplier: 2, constant: 12).isActive = true
                    btn.heightAnchor.constraint(equalTo: refButton!.widthAnchor).isActive = true
                    btn.contentHorizontalAlignment = .left
                    btn.tag = 999
                }
            }
            
            grid.addArrangedSubview(rowStack)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateButtonAppearance(in: view)
    }
    
    private func updateButtonAppearance(in parentView: UIView) {
        for subview in parentView.subviews {
            if let btn = subview as? UIButton {
                btn.layer.cornerRadius = btn.bounds.height / 2
                if btn.tag == 999, let titleLabel = btn.titleLabel {
                    // 用约束替代已弃用的 titleEdgeInsets
                    titleLabel.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        titleLabel.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: btn.bounds.height * 0.37),
                        titleLabel.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
                    ])
                    btn.tag = 0  // 只设置一次
                }
            } else {
                updateButtonAppearance(in: subview)
            }
        }
    }
    
    // MARK: - Button Press Feedback
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05) {
            sender.alpha = 0.6
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15) {
            sender.alpha = 1.0
        }
    }
    
    // MARK: - Button Logic
    
    @objc private func buttonTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        
        lightImpact.impactOccurred()
        
        // ====== 魔术输入阶段：观众乱点，所有按键都产生魔术数字 ======
        if magicActive {
            advanceMagicDigit()
            return
        }
        
        // ====== 魔术数字已全部输入，等待魔术师按 = ======
        if waitingForEquals {
            if title == "=" {
                performEquals()
                waitingForEquals = false
                trickDone = true
                successFeedback.notificationOccurred(.success)
            } else if title == "AC" {
                resetAll()
            }
            // 其他按键一律忽略，防止观众误触修改数字
            return
        }
        
        // ====== 魔术完成后，只有 AC 可以重置 ======
        if trickDone {
            if title == "AC" {
                resetAll()
            }
            return
        }
        
        // ====== 正常计算器模式 ======
        switch title {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            inputDigit(title)
        case "+":
            handlePlus()
        case "=":
            performEquals()
        case "AC":
            resetAll()
        default:
            break
        }
    }
    
    // MARK: - Normal Calculator
    
    private func inputDigit(_ d: String) {
        if isTyping {
            if displayText == "0" {
                displayText = d
            } else {
                displayText += d
            }
        } else {
            displayText = d
            isTyping = true
            showingResult = false
        }
    }
    
    private func handlePlus() {
        if showingResult && !trickDone && storedValue > 0 {
            // 显示 A+B 的结果后按 +  →  触发魔术！
            activateMagic()
        } else {
            // 正常加法：保存当前值
            storedValue = Int(displayText) ?? 0
            isTyping = false
        }
    }
    
    private func performEquals() {
        let current = Int(displayText) ?? 0
        let result = storedValue + current
        displayText = String(result)
        storedValue = result
        isTyping = false
        showingResult = true
    }
    
    private func resetAll() {
        displayText = "0"
        storedValue = 0
        isTyping = false
        showingResult = false
        magicActive = false
        waitingForEquals = false
        trickDone = false
        magicDigits = ""
        magicIndex = 0
    }
    
    // MARK: - Magic Core
    
    /// 触发魔术模式：计算 C = target - (A+B)，拆分为各位数字
    private func activateMagic() {
        let sum = storedValue
        let target = computeTarget()
        let c = target - sum
        
        guard c > 0 else {
            // 极端情况：A+B ≥ target，无法执行魔术，回退到普通加法
            storedValue = Int(displayText) ?? 0
            isTyping = false
            showingResult = false
            return
        }
        
        magicDigits = String(c)
        magicIndex = 0
        magicActive = true
        isTyping = false
        showingResult = false
        // 不清除显示：保持显示 A+B，直到观众第一次点击
    }
    
    /// 每次触摸产生魔术数字的下一位
    private func advanceMagicDigit() {
        guard magicIndex < magicDigits.count else {
            // 所有位都已显示，额外点击被吸收（不做任何事）
            return
        }
        
        let idx = magicDigits.index(magicDigits.startIndex, offsetBy: magicIndex)
        let ch = String(magicDigits[idx])
        
        if magicIndex == 0 {
            displayText = ch
        } else {
            displayText += ch
        }
        magicIndex += 1
        
        if magicIndex >= magicDigits.count {
            // 所有魔术数字已输入完毕
            magicActive = false
            waitingForEquals = true
            isTyping = true
            
            // 强烈震动提示魔术师：可以按 = 了
            heavyImpact.impactOccurred()
        }
    }
    
    /// 计算目标数字：月(不补零) + 日(补零2位) + 时(补零2位) + 分(补零2位)
    /// 例如 2月16日14:18 → 2161418
    /// 这种格式确保 target ≥ 1,010,000 > max(A+B) ≈ 110,000
    private func computeTarget() -> Int {
        let now = Date()
        let cal = Calendar.current
        let m   = cal.component(.month,  from: now)
        let d   = cal.component(.day,    from: now)
        let h   = cal.component(.hour,   from: now)
        let min = cal.component(.minute, from: now)
        return Int(String(format: "%d%02d%02d%02d", m, d, h, min)) ?? 0
    }
    
    // MARK: - Display
    
    private func refreshDisplay() {
        guard let n = Int(displayText) else {
            displayLabel.text = displayText
            return
        }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = ","
        displayLabel.text = fmt.string(from: NSNumber(value: n)) ?? displayText
    }
}
