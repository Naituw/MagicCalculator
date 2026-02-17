package com.wutian.magiccalculatorandroid

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs

/** 魔术计算器的状态机 */
enum class MagicState {
    InputFirstNumber,       // 等待输入第一个数字（4位数）
    WaitingSecondNumber,    // 按了加号，等待开始输入第二个数字
    InputSecondNumber,      // 正在输入第二个数字
    ShowFirstResult,        // 按了等号，显示 A+B 的结果，等待按加号
    WaitingMagicInput,      // 按了加号，等待开始魔术输入
    MagicInput,             // 魔术模式：无论按什么都显示魔术数字
    ShowFinalResult         // 显示最终日期时间结果
}

/** 触觉反馈类型 */
enum class HapticType {
    Light,                  // 轻触确认（普通输入）
    Heavy,                  // 强烈反馈（魔术提示）
    NotificationSuccess,    // 成功提示（魔术数字输入完毕）
    NotificationWarning     // 警告提示（屏幕朝下时按等号）
}

class MagicCalculatorViewModel : ViewModel() {

    // ---- Observable UI State ----

    var displayText by mutableStateOf("0")
        private set

    var secondsText by mutableStateOf("")
        private set

    /** 屏幕是否朝下（由传感器设置） */
    var isScreenFacingDown by mutableStateOf(false)

    // ---- Internal Calculator State ----

    private var currentState by mutableStateOf(MagicState.InputFirstNumber)
    private var currentInputValue = "0"
    private var firstNumber = 0
    private var secondNumber = 0
    private var sumResult = 0
    private var magicNumber = 0
    private var magicDigits = listOf<Int>()
    private var currentMagicIndex = 0
    private var magicInputReady = false

    /** 触觉反馈回调（由 Composable 设置） */
    var hapticCallback: ((HapticType) -> Unit)? = null

    /** 是否处于魔术触摸模式（魔术状态 + 屏幕朝下） */
    val isMagicTouchMode: Boolean
        get() = (currentState == MagicState.MagicInput ||
                currentState == MagicState.WaitingMagicInput) && isScreenFacingDown

    // ---- Public API ----

    /** 更新秒数显示 */
    fun updateSeconds() {
        val seconds = Calendar.getInstance().get(Calendar.SECOND)
        secondsText = String.format(Locale.US, ":%02d", seconds)
    }

    /** 全屏点击（魔术触摸模式下的覆盖层点击） */
    fun onScreenTap() {
        if (!isMagicTouchMode) return
        if (magicInputReady) {
            hapticCallback?.invoke(HapticType.Heavy)
        } else {
            hapticCallback?.invoke(HapticType.Light)
        }
        handleNumberInput("")
    }

    /** 按钮点击 */
    fun onButtonTap(title: String) {
        if (magicInputReady) {
            hapticCallback?.invoke(HapticType.Heavy)
        } else {
            hapticCallback?.invoke(HapticType.Light)
        }

        // 魔术模式 + 屏幕朝下：所有按钮都视为输入数字
        if (isMagicTouchMode) {
            handleNumberInput(title)
            return
        }

        when (title) {
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" -> handleNumberInput(title)
            "+" -> handlePlus()
            "=" -> handleEquals()
            "AC" -> handleClear()
            "⌫" -> handleBackspace()
            "." -> { /* 魔术计算器不需要小数 */ }
        }
    }

    // ---- Input Handlers ----

    private fun handleNumberInput(digit: String) {
        when (currentState) {
            MagicState.InputFirstNumber -> {
                if (currentInputValue == "0") {
                    currentInputValue = digit
                } else {
                    currentInputValue += digit
                }
                displayText = currentInputValue
            }

            MagicState.WaitingSecondNumber -> {
                currentInputValue = digit
                displayText = formatNumber(firstNumber) + "+" + digit
                currentState = MagicState.InputSecondNumber
            }

            MagicState.InputSecondNumber -> {
                currentInputValue += digit
                displayText = formatNumber(firstNumber) + "+" + currentInputValue
            }

            MagicState.ShowFirstResult -> {
                // 显示结果后按数字，不做任何事
            }

            MagicState.WaitingMagicInput -> {
                // 开始魔术输入
                currentState = MagicState.MagicInput
                currentMagicIndex = 0
                inputMagicDigit()
            }

            MagicState.MagicInput -> {
                inputMagicDigit()
            }

            MagicState.ShowFinalResult -> {
                resetCalculator()
                currentInputValue = digit
                displayText = digit
            }
        }
    }

    /** 输入魔术数字的下一位 */
    private fun inputMagicDigit() {
        if (currentMagicIndex < magicDigits.size) {
            if (currentMagicIndex == 0) {
                currentInputValue = magicDigits[currentMagicIndex].toString()
            } else {
                currentInputValue += magicDigits[currentMagicIndex].toString()
            }
            currentMagicIndex++
            displayText = formatNumber(sumResult) + "+" + currentInputValue

            // 当输入完所有魔术数字时，标记为就绪
            if (currentMagicIndex >= magicDigits.size && !magicInputReady) {
                magicInputReady = true
                hapticCallback?.invoke(HapticType.NotificationSuccess)
            }
        }
        // 如果已经显示完所有魔术数字，继续发出 heavy 反馈但不增加数字
    }

    private fun handlePlus() {
        when (currentState) {
            MagicState.InputFirstNumber -> {
                firstNumber = currentInputValue.toIntOrNull() ?: 0
                displayText = formatNumber(firstNumber) + "+"
                currentInputValue = "0"
                currentState = MagicState.WaitingSecondNumber
            }

            MagicState.WaitingSecondNumber -> { /* 忽略重复按加号 */ }

            MagicState.InputSecondNumber -> {
                // 按加号相当于"等号+加号"的效果
                secondNumber = currentInputValue.toIntOrNull() ?: 0
                sumResult = firstNumber + secondNumber
                prepareMagicNumber()
                displayText = formatNumber(sumResult) + "+"
                currentInputValue = "0"
                currentState = MagicState.WaitingMagicInput
            }

            MagicState.ShowFirstResult -> {
                prepareMagicNumber()
                displayText = formatNumber(sumResult) + "+"
                currentInputValue = "0"
                currentState = MagicState.WaitingMagicInput
            }

            MagicState.WaitingMagicInput -> { /* 忽略 */ }
            MagicState.MagicInput -> { /* 忽略 */ }

            MagicState.ShowFinalResult -> {
                resetCalculator()
            }
        }
    }

    private fun handleEquals() {
        when (currentState) {
            MagicState.InputFirstNumber -> { /* 忽略 */ }
            MagicState.WaitingSecondNumber -> { /* 忽略 */ }

            MagicState.InputSecondNumber -> {
                secondNumber = currentInputValue.toIntOrNull() ?: 0
                sumResult = firstNumber + secondNumber
                displayText = formatNumber(sumResult)
                currentInputValue = sumResult.toString()
                currentState = MagicState.ShowFirstResult
            }

            MagicState.ShowFirstResult -> { /* 忽略 */ }
            MagicState.WaitingMagicInput -> { /* 忽略 */ }

            MagicState.MagicInput -> {
                if (isScreenFacingDown) {
                    // 屏幕朝下，不允许按等号
                    hapticCallback?.invoke(HapticType.NotificationWarning)
                    return
                }
                // 显示最终日期时间结果
                val targetNumber = generateTargetNumber()
                displayText = formatNumber(targetNumber)
                currentState = MagicState.ShowFinalResult
                magicInputReady = false
                hapticCallback?.invoke(HapticType.NotificationSuccess)
            }

            MagicState.ShowFinalResult -> {
                resetCalculator()
            }
        }
    }

    private fun handleClear() {
        resetCalculator()
    }

    private fun handleBackspace() {
        when (currentState) {
            MagicState.InputFirstNumber -> {
                if (currentInputValue.length > 1) {
                    currentInputValue = currentInputValue.dropLast(1)
                } else {
                    currentInputValue = "0"
                }
                displayText = currentInputValue
            }

            MagicState.WaitingSecondNumber -> {
                currentInputValue = firstNumber.toString()
                displayText = currentInputValue
                currentState = MagicState.InputFirstNumber
            }

            MagicState.InputSecondNumber -> {
                if (currentInputValue.length > 1) {
                    currentInputValue = currentInputValue.dropLast(1)
                    displayText = formatNumber(firstNumber) + "+" + currentInputValue
                } else {
                    currentInputValue = "0"
                    displayText = formatNumber(firstNumber) + "+"
                    currentState = MagicState.WaitingSecondNumber
                }
            }

            MagicState.ShowFirstResult -> { /* 忽略 */ }

            MagicState.WaitingMagicInput -> {
                displayText = formatNumber(sumResult)
                currentState = MagicState.ShowFirstResult
            }

            MagicState.MagicInput -> { /* 忽略 */ }
            MagicState.ShowFinalResult -> { /* 忽略 */ }
        }
    }

    // ---- Magic Logic ----

    /**
     * 生成目标数字（当前日期+时间）
     * 例如：2月16日14:18 → 2161418
     * 如果当前秒数 > 30，则按下一分钟计算（避免操作到一半跨分钟）
     */
    private fun generateTargetNumber(): Int {
        val calendar = Calendar.getInstance()
        val seconds = calendar.get(Calendar.SECOND)
        if (seconds > 30) {
            calendar.add(Calendar.MINUTE, 1)
        }
        val month = calendar.get(Calendar.MONTH) + 1  // Calendar.MONTH is 0-based
        val day = calendar.get(Calendar.DAY_OF_MONTH)
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val minute = calendar.get(Calendar.MINUTE)

        val targetString = String.format(Locale.US, "%d%02d%02d%02d", month, day, hour, minute)
        return targetString.toIntOrNull() ?: 0
    }

    /**
     * 准备魔术数字
     * 魔术数字 = 目标数字 - 当前累加结果
     */
    private fun prepareMagicNumber() {
        val targetNumber = generateTargetNumber()
        magicNumber = targetNumber - sumResult

        val digits = mutableListOf<Int>()
        var temp = abs(magicNumber)

        if (temp == 0) {
            digits.add(0)
        } else {
            while (temp > 0) {
                digits.add(0, temp % 10)
                temp /= 10
            }
        }

        magicDigits = digits
        currentMagicIndex = 0
        magicInputReady = false

        if (magicNumber < 0) {
            println("Warning: Magic number is negative! A+B is too large.")
        }
    }

    /** 重置计算器 */
    private fun resetCalculator() {
        currentState = MagicState.InputFirstNumber
        displayText = "0"
        currentInputValue = "0"
        firstNumber = 0
        secondNumber = 0
        sumResult = 0
        magicNumber = 0
        magicDigits = emptyList()
        currentMagicIndex = 0
        magicInputReady = false
    }

    /** 格式化数字，添加千位分隔符 */
    private fun formatNumber(number: Int): String {
        return NumberFormat.getNumberInstance(Locale.US).format(number)
    }
}
