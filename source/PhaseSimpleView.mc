import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Math;

class PhaseSimpleView extends WatchUi.WatchFace {

    // AOD (低電力モード) かどうかを管理するフラグ
    private var mIsSleepMode as Boolean = false;

    // 画面の中心座標 (onLayoutで設定)
    private var mCenterX as Number = 0;
    private var mCenterY as Number = 0;
    private var mScreenRadius as Number = 0;


    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) {
        mCenterX = dc.getWidth() / 2;
        mCenterY = dc.getHeight() / 2;
        mScreenRadius = dc.getWidth() / 2;
    }

    function onShow() {
    }

    function onUpdate(dc as Dc) {
        var clockTime = System.getClockTime();
        var stats = System.getSystemStats(); // バッテリー残量用
        // [修正] 通知と電話接続は System.getDeviceSettings() から取得
        var deviceSettings = System.getDeviceSettings(); 

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var minuteOffset = clockTime.min % 5;
        var globalRotationDegree = 0; 

        if (minuteOffset == 0) { globalRotationDegree = 12; }
        else if (minuteOffset == 1) { globalRotationDegree = 0; }
        else if (minuteOffset == 2) { globalRotationDegree = 18; }
        else if (minuteOffset == 3) { globalRotationDegree = 6; }
        else if (minuteOffset == 4) { globalRotationDegree = 24; }
        
        var globalRotationRad = Math.toRadians(globalRotationDegree);

        drawDials(dc, globalRotationRad);
        
        // [修正] stats と deviceSettings から null 安全に値を取得
        var battery = 0.0f; // Float
        var notificationCount = 0; // Number
        var phoneConnected = false; // Boolean

        if (stats != null) {
            battery = stats.battery;
        }
        // [修正] deviceSettings から通知と接続情報を取得
        if (deviceSettings != null) {
            notificationCount = deviceSettings.notificationCount;
            phoneConnected = deviceSettings.phoneConnected;
        }
        
        // 取得した値を drawIndicators に渡す
        drawIndicators(dc, battery, notificationCount, phoneConnected, globalRotationRad);
        
        drawHands(dc, clockTime, globalRotationRad);
        
        if (!mIsSleepMode) {
            drawSecondHand(dc, clockTime, globalRotationRad);
        }
    }

    function onEnterSleep() {
        mIsSleepMode = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        mIsSleepMode = false;
        WatchUi.requestUpdate();
    }

    function onHide() {
    }

    function onStop(state) {
    }

    // --- 描画ヘルパー関数 ---

    /**
     * 戻り値も .toNumber() で整数(Number)にする
     */
    private function calculatePoint(angleDegree as Number, radius as Number, rotationOffsetRad as Float) as Array<Number> {
        var angleRad = Math.toRadians(angleDegree);
        var finalAngle = angleRad + rotationOffsetRad;
        
        var x = mCenterX + radius * Math.sin(finalAngle);
        var y = mCenterY - radius * Math.cos(finalAngle);
        
        return [x.toNumber(), y.toNumber()];
    }

    /**
     * ダイヤル (12個の赤い円) を描画
     */
    private function drawDials(dc as Dc, rotationOffsetRad as Float) {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        var dialRadius = (mScreenRadius * 0.9).toNumber(); 

        for (var i = 1; i <= 12; i++) {
            var angleDeg = i * 30;
            var point = calculatePoint(angleDeg, dialRadius, rotationOffsetRad);
            dc.fillCircle(point[0], point[1], 5);
        }
    }

    /**
     * インジケーター (バッテリー, 通知, Bluetooth) を描画
     * [修正] 引数を (stats as System.Stats) から具体的な値に変更
     */
    private function drawIndicators(
        dc as Dc, 
        batteryPercent as Float, 
        notificationCountIn as Number, 
        phoneConnected as Boolean, 
        rotationOffsetRad as Float
    ) {
        var outerRadius = mScreenRadius; 
        var innerRadius = outerRadius - 10; 

        // --- 1. バッテリー (黄 / 反時計回り) ---
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        var batteryTicks = (batteryPercent / 10).toNumber(); 

        for (var i = 0; i < batteryTicks; i++) {
            var angleDeg = 180 - (i * 6); 
            var startPt = calculatePoint(angleDeg, outerRadius, rotationOffsetRad);
            var endPt = calculatePoint(angleDeg, innerRadius, rotationOffsetRad);
            dc.drawLine(startPt[0], startPt[1], endPt[0], endPt[1]);
        }

        // --- 2. 通知 (水色 / 時計回り) ---
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        var notificationCount = notificationCountIn;
        if (notificationCount > 10) { notificationCount = 10; } 

        for (var i = 0; i < notificationCount; i++) {
            var angleDeg = 180 + (i * 6);
            var startPt = calculatePoint(angleDeg, outerRadius, rotationOffsetRad);
            var endPt = calculatePoint(angleDeg, innerRadius, rotationOffsetRad);
            dc.drawLine(startPt[0], startPt[1], endPt[0], endPt[1]);
        }
        
        // --- 3. Bluetooth アイコン (接続時) ---
        if (phoneConnected) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            var angleDegB = 270;
            var pointB = calculatePoint(angleDegB, (mScreenRadius * 0.75).toNumber(), rotationOffsetRad);
            dc.drawText(pointB[0], pointB[1], Graphics.FONT_TINY, "B", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    /**
     * 針 (時・分) を描画
     */
    private function drawHands(dc as Dc, clockTime as ClockTime, rotationOffsetRad as Float) {
        var hour = clockTime.hour;
        var handColor = Graphics.COLOR_RED;
        if (hour >= 4 && hour < 8) { handColor = Graphics.COLOR_ORANGE; }
        else if (hour >= 8 && hour < 12) { handColor = Graphics.COLOR_YELLOW; }
        else if (hour >= 12 && hour < 16) { handColor = Graphics.COLOR_GREEN; }
        else if (hour >= 16 && hour < 20) { handColor = Graphics.COLOR_BLUE; }
        else if (hour >= 20) { handColor = Graphics.COLOR_PURPLE; } 

        dc.setColor(handColor, Graphics.COLOR_TRANSPARENT);

        // --- 1. 時針 (30% - 50%) ---
        var hourAngleDeg = ((clockTime.hour % 12) * 30) + (clockTime.min * 0.5); // Float
        var startPtH = calculatePoint(hourAngleDeg.toNumber(), (mScreenRadius * 0.30).toNumber(), rotationOffsetRad);
        var endPtH = calculatePoint(hourAngleDeg.toNumber(), (mScreenRadius * 0.50).toNumber(), rotationOffsetRad);
        dc.setPenWidth(8); 
        dc.drawLine(startPtH[0], startPtH[1], endPtH[0], endPtH[1]);

        // --- 2. 分針 (50% - 80%) ---
        var minAngleDeg = clockTime.min * 6; // Number
        var startPtM = calculatePoint(minAngleDeg, (mScreenRadius * 0.50).toNumber(), rotationOffsetRad);
        var endPtM = calculatePoint(minAngleDeg, (mScreenRadius * 0.80).toNumber(), rotationOffsetRad);
        dc.setPenWidth(5); 
        dc.drawLine(startPtM[0], startPtM[1], endPtM[0], endPtM[1]);
    }

    /**
     * 秒針を描画 (AODモードでは呼ばれない)
     */
    private function drawSecondHand(dc as Dc, clockTime as ClockTime, rotationOffsetRad as Float) {
        dc.setPenWidth(2); 

        var secAngleDeg = clockTime.sec * 6; // Number
        
        var startPtS = calculatePoint(secAngleDeg, (mScreenRadius * 0.80).toNumber(), rotationOffsetRad);
        var endPtS = calculatePoint(secAngleDeg, (mScreenRadius * 0.90).toNumber(), rotationOffsetRad);
        
        dc.drawLine(startPtS[0], startPtS[1], endPtS[0], endPtS[1]);
    }

}