package com.wutian.magiccalculatorandroid

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.delay

// 按钮颜色 - 匹配 iOS 计算器
private val OperatorColor = Color(0xFFFF9500)       // 运算符：系统橙色
private val FunctionColor = Color(0xFFA6A6A6)       // 功能键：浅灰色
private val NumberColor = Color(0xFF333333)          // 数字键：深灰色
private val SecondsColor = Color(0xFF333333)         // 秒数标签：极不明显

@Composable
fun CalculatorScreen(viewModel: MagicCalculatorViewModel = viewModel()) {
    val context = LocalContext.current
    val view = LocalView.current

    // 设置重力传感器，检测屏幕是否朝下
    DisposableEffect(Unit) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val gravitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                event?.let {
                    // Android 传感器: z < -6.8 m/s² 表示屏幕朝下
                    // （对应 iOS CoreMotion gravity.z > 0.7）
                    viewModel.isScreenFacingDown = it.values[2] < -6.8f
                }
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        gravitySensor?.let {
            sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_UI)
        }

        onDispose {
            sensorManager.unregisterListener(listener)
        }
    }

    // 设置触觉反馈回调
    LaunchedEffect(Unit) {
        viewModel.hapticCallback = { type ->
            when (type) {
                HapticType.Light ->
                    view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                HapticType.Heavy ->
                    view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                HapticType.NotificationSuccess ->
                    if (Build.VERSION.SDK_INT >= 30) {
                        view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                    } else {
                        view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                    }
                HapticType.NotificationWarning ->
                    if (Build.VERSION.SDK_INT >= 30) {
                        view.performHapticFeedback(HapticFeedbackConstants.REJECT)
                    } else {
                        view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                    }
            }
        }
    }

    // 秒数定时器（每秒更新）
    LaunchedEffect(Unit) {
        while (true) {
            viewModel.updateSeconds()
            delay(1000L)
        }
    }

    // UI 布局
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(bottom = 8.dp)
        ) {
            // 秒数标签（左上角，极不明显）
            Text(
                text = viewModel.secondsText,
                color = SecondsColor,
                fontSize = 14.sp,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier.padding(start = 20.dp, top = 4.dp)
            )

            // 弹性空间
            Spacer(modifier = Modifier.weight(1f))

            // 主显示屏
            AutoSizeDisplay(
                text = viewModel.displayText,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .height(100.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // 按钮网格
            ButtonGrid(
                onButtonClick = { viewModel.onButtonTap(it) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp)
            )
        }

        // 魔术模式覆盖层 - 屏幕朝下时拦截所有触摸
        if (viewModel.isMagicTouchMode) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) {
                        viewModel.onScreenTap()
                    }
            )
        }
    }
}

/** 自适应大小的显示文本 */
@Composable
private fun AutoSizeDisplay(
    text: String,
    modifier: Modifier = Modifier
) {
    val textMeasurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val maxFontSize = 88f
    val minFontSize = 26f

    BoxWithConstraints(
        modifier = modifier,
        contentAlignment = Alignment.CenterEnd
    ) {
        val maxWidthPx = constraints.maxWidth

        val fontSize = remember(text, maxWidthPx, density) {
            var size = maxFontSize
            while (size > minFontSize) {
                val result = textMeasurer.measure(
                    text = AnnotatedString(text),
                    style = TextStyle(
                        fontSize = with(density) { (size).sp },
                        fontWeight = FontWeight.Light,
                    ),
                    maxLines = 1,
                    softWrap = false
                )
                if (result.size.width <= maxWidthPx) break
                size -= 2f
            }
            size
        }

        Text(
            text = text,
            color = Color.White,
            fontWeight = FontWeight.Light,
            fontSize = fontSize.sp,
            maxLines = 1,
            softWrap = false,
            textAlign = TextAlign.End,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

/** 按钮网格 */
@Composable
private fun ButtonGrid(
    onButtonClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val spacing = 14.dp

    BoxWithConstraints(modifier = modifier) {
        val buttonDiameter = (maxWidth - spacing * 3) / 4

        Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
            // Row 1: ⌫ AC % ÷
            ButtonRow(
                titles = listOf("⌫", "AC", "%", "÷"),
                buttonDiameter = buttonDiameter,
                spacing = spacing,
                onButtonClick = onButtonClick
            )
            // Row 2: 7 8 9 ×
            ButtonRow(
                titles = listOf("7", "8", "9", "×"),
                buttonDiameter = buttonDiameter,
                spacing = spacing,
                onButtonClick = onButtonClick
            )
            // Row 3: 4 5 6 -
            ButtonRow(
                titles = listOf("4", "5", "6", "-"),
                buttonDiameter = buttonDiameter,
                spacing = spacing,
                onButtonClick = onButtonClick
            )
            // Row 4: 1 2 3 +
            ButtonRow(
                titles = listOf("1", "2", "3", "+"),
                buttonDiameter = buttonDiameter,
                spacing = spacing,
                onButtonClick = onButtonClick
            )
            // Row 5: 0 (宽按钮) . =
            Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                CalculatorButton(
                    title = "0",
                    width = buttonDiameter * 2 + spacing,
                    height = buttonDiameter,
                    backgroundColor = NumberColor,
                    textColor = Color.White,
                    fontSize = 36f,
                    isWide = true,
                    onClick = { onButtonClick("0") }
                )
                CalculatorButton(
                    title = ".",
                    width = buttonDiameter,
                    height = buttonDiameter,
                    backgroundColor = NumberColor,
                    textColor = Color.White,
                    fontSize = 36f,
                    onClick = { onButtonClick(".") }
                )
                CalculatorButton(
                    title = "=",
                    width = buttonDiameter,
                    height = buttonDiameter,
                    backgroundColor = OperatorColor,
                    textColor = Color.White,
                    fontSize = 40f,
                    onClick = { onButtonClick("=") }
                )
            }
        }
    }
}

/** 按钮行 */
@Composable
private fun ButtonRow(
    titles: List<String>,
    buttonDiameter: Dp,
    spacing: Dp,
    onButtonClick: (String) -> Unit
) {
    val operators = setOf("÷", "×", "-", "+", "=")
    val functions = setOf("⌫", "AC", "%")

    Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
        for (title in titles) {
            val backgroundColor: Color
            val textColor: Color
            val fontSize: Float

            when {
                operators.contains(title) -> {
                    backgroundColor = OperatorColor
                    textColor = Color.White
                    fontSize = 40f
                }
                functions.contains(title) -> {
                    backgroundColor = FunctionColor
                    textColor = Color.Black
                    fontSize = 28f
                }
                else -> {
                    backgroundColor = NumberColor
                    textColor = Color.White
                    fontSize = 36f
                }
            }

            CalculatorButton(
                title = title,
                width = buttonDiameter,
                height = buttonDiameter,
                backgroundColor = backgroundColor,
                textColor = textColor,
                fontSize = fontSize,
                onClick = { onButtonClick(title) }
            )
        }
    }
}

/** 单个计算器按钮 */
@Composable
private fun CalculatorButton(
    title: String,
    width: Dp,
    height: Dp,
    backgroundColor: Color,
    textColor: Color,
    fontSize: Float,
    isWide: Boolean = false,
    onClick: () -> Unit
) {
    val shape = if (isWide) RoundedCornerShape(percent = 50) else CircleShape

    val fontWeight = when {
        title in setOf("÷", "×", "-", "+", "=") -> FontWeight.Medium
        title in setOf("⌫", "AC", "%") -> FontWeight.Medium
        else -> FontWeight.Normal
    }

    Box(
        modifier = Modifier
            .size(width = width, height = height)
            .clip(shape)
            .background(backgroundColor)
            .clickable(onClick = onClick),
        contentAlignment = if (isWide) Alignment.CenterStart else Alignment.Center
    ) {
        Text(
            text = title,
            color = textColor,
            fontSize = fontSize.sp,
            fontWeight = fontWeight,
            modifier = if (isWide) Modifier.padding(start = 30.dp) else Modifier
        )
    }
}
