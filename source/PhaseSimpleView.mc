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
    
    // [修正] 曜日に応じた基準角度を（1時〜7時に）修正
    private var mDayAngleMap as Dictionary = {
        Time.Gregorian.DAY_SUNDAY => 210, // 7時
        Time.Gregorian.DAY_MONDAY => 30,  // 1時
        Time.Gregorian.DAY_TUESDAY => 60, // 2時
        Time.Gregorian.DAY_WEDNESDAY => 90, // 3時
        Time.Gregorian.DAY_THURSDAY => 120, // 4時
        Time.Gregorian.DAY_FRIDAY => 150, // 5時
        Time.Gregorian.DAY_SATURDAY => 180  // 6時
    };


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
        var stats = System.getSystemStats(); 
        var deviceSettings = System.getDeviceSettings();
        
        var now = Time.now();
        var todayInfo = Time.Gregorian.info(now, Time.FORMAT_SHORT);
        var dateStr = todayInfo.day.format("%d"); 

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
        
        var battery = 0.0f;
        var notificationCount = 0;
        var phoneConnected = false;

        if (stats != null) {
            battery = stats.battery;
        }
        if (deviceSettings != null) {
            notificationCount = deviceSettings.notificationCount;
            phoneConnected = deviceSettings.phoneConnected;
        }
        
        drawIndicators(dc, battery, notificationCount, phoneConnected, globalRotationRad);
        
        // AOD時は日付を描画しない
        if (!mIsSleepMode) {
            var dateAngle = calculateDateAngle(todayInfo);
            drawDate(dc, dateStr, dateAngle, globalRotationRad);
        }

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

    private function calculatePoint(angleDegree as Number, radius as Number, rotationOffsetRad as Float) as Array<Number> {
        var angleRad = Math.toRadians(angleDegree);
        var finalAngle = angleRad + rotationOffsetRad;
        
        var x = mCenterX + radius * Math.sin(finalAngle);
        var y = mCenterY - radius * Math.cos(finalAngle);
        
        return [x.toNumber(), y.toNumber()];
    }

    private function calculateDateAngle(todayInfo as Gregorian.Info) as Float {
        var baseAngle = mDayAngleMap[todayInfo.day_of_week] as Float;
        var totalMinutes = (todayInfo.hour * 60.0) + todayInfo.min;
        var dayProgress = totalMinutes / 1440.0;
        // [修正] ご提示のコードに合わせて 15° (60-45=15) にする
        var offsetAngle = dayProgress * 15.0; 

        return baseAngle + offsetAngle;
    }

    /**
     * [修正] 日付（数字）の色をライトグレーに変更 + drawText に戻す
     */
    private function drawDate(dc as Dc, dateStr as String, dateAngle as Float, rotationOffsetRad as Float) {
        var grayColor = Graphics.COLOR_LT_GRAY;
        dc.setColor(grayColor, Graphics.COLOR_TRANSPARENT);

        var radius = (mScreenRadius * 0.5).toNumber();
        var point = calculatePoint(dateAngle.toNumber(), radius, rotationOffsetRad);

        // [修正] drawRotatedText -> drawText に戻す
        dc.drawText(
            point[0], 
            point[1], 
            Graphics.FONT_MEDIUM, 
            dateStr, 
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    /**
     * [修正] ダイヤルの色をライトグレーに変更
     */
    private function drawDials(dc as Dc, rotationOffsetRad as Float) {
        var grayColor = Graphics.COLOR_LT_GRAY;
        dc.setColor(grayColor, Graphics.COLOR_TRANSPARENT);

        var lineInner = (mScreenRadius * 0.80).toNumber(); 
        var lineOuter = (mScreenRadius * 0.95).toNumber();
        var circleRadius = (mScreenRadius * 0.9).toNumber();
        var angleOffset = 1.5; // 1.5度 (Float型)

        for (var i = 1; i <= 12; i++) {
            var angleDeg = i * 30; 

            if (i == 12 || i == 3 || i == 6 || i == 9) {
                dc.setPenWidth(2); 
                
                var angleDeg1 = angleDeg - angleOffset; 
                var startPt1 = calculatePoint(angleDeg1.toNumber(), lineInner, rotationOffsetRad);
                var endPt1 = calculatePoint(angleDeg1.toNumber(), lineOuter, rotationOffsetRad);
                dc.drawLine(startPt1[0], startPt1[1], endPt1[0], endPt1[1]);
                
                var angleDeg2 = angleDeg + angleOffset; 
                var startPt2 = calculatePoint(angleDeg2.toNumber(), lineInner, rotationOffsetRad);
                var endPt2 = calculatePoint(angleDeg2.toNumber(), lineOuter, rotationOffsetRad);
                dc.drawLine(startPt2[0], startPt2[1], endPt2[0], endPt2[1]);

            } else {
                var point = calculatePoint(angleDeg, circleRadius, rotationOffsetRad);
                dc.fillCircle(point[0], point[1], 5); 
            }
        }
    }


    /**
     * [修正] AOD時の描画を制限
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
        dc.setPenWidth(3);
        var batteryTicks = (batteryPercent / 10).toNumber(); 
        var lastBatteryTick = batteryTicks - 1; 
        var darkYellowColor = 0x808000; 

        for (var i = 0; i < batteryTicks; i++) {
            var isLastTick = (i == lastBatteryTick);
            
            if (!mIsSleepMode || isLastTick) {
                if (isLastTick) {
                    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(darkYellowColor, Graphics.COLOR_TRANSPARENT);
                }

                var angleDeg = 180 - (i * 6); 
                var startPt = calculatePoint(angleDeg, outerRadius, rotationOffsetRad);
                var endPt = calculatePoint(angleDeg, innerRadius, rotationOffsetRad);
                dc.drawLine(startPt[0], startPt[1], endPt[0], endPt[1]);
            }
        }

        // --- 2. 通知 (フィボナッチ) ---
        var notificationCount = notificationCountIn;
        var notificationTicks = 0; 

        if (notificationCount >= 89) { notificationTicks = 10; }
        else if (notificationCount >= 55) { notificationTicks = 9; }
        else if (notificationCount >= 34) { notificationTicks = 8; }
        else if (notificationCount >= 21) { notificationTicks = 7; }
        else if (notificationCount >= 13) { notificationTicks = 6; }
        else if (notificationCount >= 8) { notificationTicks = 5; }
        else if (notificationCount >= 5) { notificationTicks = 4; }
        else if (notificationCount >= 3) { notificationTicks = 3; }
        else if (notificationCount >= 2) { notificationTicks = 2; }
        else if (notificationCount >= 1) { notificationTicks = 1; }

        if (notificationTicks > 0) {
            dc.setPenWidth(3);
            var lastNotificationTick = notificationTicks - 1; 
            var darkBlueColor = 0x000080;

            for (var i = 0; i < notificationTicks; i++) {
                var isLastTick = (i == lastNotificationTick);
                
                if (!mIsSleepMode || isLastTick) {
                    if (isLastTick) {
                        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                    } else {
                        dc.setColor(darkBlueColor, Graphics.COLOR_TRANSPARENT);
                    }

                    var angleDeg = 180 + (i * 6);
                    var startPt = calculatePoint(angleDeg, outerRadius, rotationOffsetRad);
                    var endPt = calculatePoint(angleDeg, innerRadius, rotationOffsetRad);
                    dc.drawLine(startPt[0], startPt[1], endPt[0], endPt[1]);
                }
            }
        }
        
        // --- 3. Bluetooth アイコン (接続時) ---
        if (!mIsSleepMode) {
            if (phoneConnected) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                var angleDegB = 270; // 9時
                var radiusB = (mScreenRadius * 0.50).toNumber();
                
                var pointB = calculatePoint(angleDegB, radiusB, rotationOffsetRad);
                
                // [修正] drawRotatedText -> drawText に戻す
                dc.drawText(
                    pointB[0], 
                    pointB[1], 
                    Graphics.FONT_TINY, 
                    "B", 
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
        }
    }

    /**
     * [修正] 針 (時・分) の色を「明るい紫」と「明るい赤」に変更
     */
    private function drawHands(dc as Dc, clockTime as ClockTime, rotationOffsetRad as Float) {
        var hour = clockTime.hour;
        
        // [修正] COLOR_PINK (0xFFAAAA) を使用
        var handColor = 0xFFAAAA; // デフォルト (0-4時) = "明るい赤/ピンク"
        if (hour >= 4 && hour < 8) { handColor = Graphics.COLOR_ORANGE; }
        else if (hour >= 8 && hour < 12) { handColor = Graphics.COLOR_YELLOW; }
        else if (hour >= 12 && hour < 16) { handColor = Graphics.COLOR_GREEN; }
        else if (hour >= 16 && hour < 20) { handColor = Graphics.COLOR_BLUE; }
        else if (hour >= 20) { 
            // [修正] COLOR_MAGENTA (0xFF00FF) を使用
            handColor = 0xFF00FF; // 20-24時 = "明るい紫/マゼンタ"
        } 

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