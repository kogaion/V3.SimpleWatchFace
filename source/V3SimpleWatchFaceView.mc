using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time.Gregorian as Greg;
using Toybox.ActivityMonitor as Mon;
using Toybox.Activity as Act;
using Toybox.Math as Math;
using Toybox.Application as App;

class V3SimpleWatchFaceView extends Ui.WatchFace {

    hidden var dc, radius, fgColor, bgColor, bdColor, hrColor, btColor, stColor, ihColor, imColor, isColor, hhColor, active;

    function initialize() {
        WatchFace.initialize();
        radius = Sys.getDeviceSettings().screenWidth / 2;

        fgColor = Gfx.COLOR_WHITE;// App.getApp().getProperty("ForegroundColor");
        ihColor = Gfx.COLOR_YELLOW;
        imColor = Gfx.COLOR_YELLOW;
        isColor = Gfx.COLOR_ORANGE;
        hhColor = Gfx.COLOR_YELLOW;
        bgColor = Gfx.COLOR_BLACK;// App.getApp().getProperty("BackgroundColor");
        bdColor = Gfx.COLOR_LT_GRAY; //App.getApp().getProperty("BorderColor");
        hrColor = Gfx.COLOR_RED;// App.getApp().getProperty("HeartRateColor");
        btColor = Gfx.COLOR_DK_GREEN;// App.getApp().getProperty("BatteryColor");
        stColor = Gfx.COLOR_DK_BLUE;// App.getApp().getProperty("StepsColor");
    }

    function onLayout(dc) {
    }

    function onPartialUpdate(dc) {
    }

    function onShow() {
        onExitSleep();
    }

    function onHide() {
        onEnterSleep();
    }

    function onEnterSleep() {
        active = false;
    }

    function onExitSleep() {
        active = true;
    }

    // Load your resources here
    function onUpdate(dc) {
        me.dc = dc;

        drawBackground();
        drawTime();
    }

    hidden function drawBackground() {
        dc.setColor(Gfx.COLOR_TRANSPARENT, bgColor);
        dc.clear();
    }

    hidden function drawTime() {

        var time = Sys.getClockTime();
        var hour = time.hour;
        var min = time.min;

        for (var i = 0; i < 60; i += 1) {

            var radian = Math.toRadians(i * 6 + 270); // 270 = strange degrees offset of Garmin round display
            var rx = Math.cos(radian);
            var ry = Math.sin(radian);

            // hour ticks, or all the minutes tick in the current 5 min interval
            if ((i % 5 == 0) /*|| ((i > 5 * Math.floor(min / 5)) && (i < 5 + 5 * Math.floor(min / 5)))*/) {
                dc.setPenWidth(2);
                dc.setColor(i % 15 == 0 ? hhColor : fgColor, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(radius, radius, radius + radius * rx, radius + radius * ry);
            }

            // hour ticks background, minutes ticks background
            dc.setPenWidth(4);
            /*if (i % 15 == 0) {
                dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(radius, radius, radius + (radius - 7) * rx, radius + (radius - 7) * ry);
            } else*/ if (i % 5 == 0) {
                dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(radius, radius, radius + (radius - 15) * rx, radius + (radius - 15) * ry);
            } else  if ((i >= 5 * Math.floor(min / 5)) && (i < 5 + 5 * Math.floor(min / 5))) {
                dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(radius, radius, radius + (radius - 5) * rx, radius + (radius - 5) * ry);
            }
        }

        drawDate();
        drawHeartRate();
        drawSteps();
        drawBattery();

        for (var i = 0; i < 360; i += 1) {

            var radian = Math.toRadians(i + 270); // 270 = strange degrees offset of Garmin round display
            var rx = Math.cos(radian);
            var ry = Math.sin(radian);

            // hour text - 12 3 6 9
            /*if (i % 90 == 0) {
                var text = "" + (i == 0 ? "12" : Math.ceil(i / 30));
                var size = dc.getTextDimensions(text, Gfx.FONT_TINY);
                dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
                dc.drawText(
                    radius * (i == 0 || i == 180 ? 1 : (i == 270 ? 0 : 2)) + (3 + size[0] / 2) * (i == 270 ? 1 : (i == 90 ? -1 : 0)),
                    radius * (i == 90 || i == 270 ? 1 : (i == 0 ? 0 : 2)) + (3 + size[1] / 2) * (i == 0 ? 1 : (i == 180 ? -1 : 0)),
                    Gfx.FONT_TINY,
                    text,
                    (i == 270 ? Gfx.TEXT_JUSTIFY_LEFT : (i == 15 ? Gfx.TEXT_JUSTIFY_RIGHT : Gfx.TEXT_JUSTIFY_CENTER)) | Gfx.TEXT_JUSTIFY_VCENTER
                );
            }*/

            // minute indicator
            if (i == min * 6) {
                dc.setPenWidth(3);
                dc.setColor(imColor, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(radius, radius, radius + (radius - 17) * rx, radius + (radius - 17) * ry);
            }

            // hour indicator
            if ((i == (hour % 12) * 30 + Math.floor(min / 2))) {
                dc.setPenWidth(3);
                dc.setColor(ihColor, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(radius, radius, radius + radius * 3 / 5 * rx, radius + radius * 3 / 5 * ry);
            }

            // second indicator
            if (active && (i == time.sec * 6)) {

                // for the opposite tail of the second indicator
                var oppradian = Math.toRadians(i + 270 + 180); // 270 = strange degrees offset of Garmin round display
                var opprx = Math.cos(oppradian);
                var oppry = Math.sin(oppradian);

                dc.setPenWidth(1);
                dc.setColor(isColor, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(radius, radius, radius + (radius - 15) * rx, radius + (radius - 15) * ry);
                dc.drawLine(radius, radius, radius + 20 * opprx, radius + 20 * oppry);
            }
        }

        // draw center circle
        dc.setPenWidth(3);
        dc.setColor(active ? isColor : fgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(radius, radius, 6);
        dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(radius, radius, 4);
    }

    hidden function drawDate() {
        var text = Greg.info(Time.now(), Time.FORMAT_SHORT).day.format("%d");
        var size = dc.getTextDimensions("9999", Gfx.FONT_XTINY);
        var w = size[0] + 8;
        var h = size[1] + 4;

        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(radius + radius / 2 - w / 2, radius - h / 2, w, h, 3);

        dc.setColor(bdColor, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(radius + radius / 2 - w / 2 - 1, radius - h / 2 - 1, w + 2, h + 2, 3);

        dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(radius + radius / 2, radius, Gfx.FONT_XTINY, text, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawHeartRate() {
        if (active != true) {
            return null;
        }
        var hr = Act.getActivityInfo().currentHeartRate;
        if (hr == null || hr == Mon.INVALID_HR_SAMPLE) {
            hr = Mon.getHeartRateHistory(1, true).next().heartRate;
        }
        if (hr == null || hr == Mon.INVALID_HR_SAMPLE) {
            return null;
        }
        var text = hr.format("%d");

        var size = dc.getTextDimensions("9999", Gfx.FONT_XTINY);
        var w = size[0] + 8;
        var h = size[1] + 4;

        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(radius - w / 2, radius / 2 - h / 2, w, h, 3);

        dc.setColor(bdColor, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(radius - w / 2 - 1, radius / 2 - h / 2 - 1, w + 2, h + 2, 3);

        dc.setColor(hrColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(radius, radius / 2, Gfx.FONT_XTINY, text, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawSteps() {
        if (active != true) {
            return null;
        }
        var steps = Mon.getInfo().steps;
        var text = ((steps == null) ? "0" : ((steps < 1000) ? steps.format("%d") : ((steps / 1000.0).format("%.1f")) + "k"));

        var size = dc.getTextDimensions("9999", Gfx.FONT_XTINY);
        var w = size[0] + 8;
        var h = size[1] + 4;

        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(radius - w / 2, radius * 3 / 2 - h / 2, w, h, 3);

        dc.setColor(bdColor, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(radius - w / 2 - 1, radius * 3 / 2 - h / 2 - 1, w + 2, h + 2, 3);

        dc.setColor(stColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(radius, radius * 3 / 2, Gfx.FONT_XTINY, text, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawBattery() {
        if (active != true) {
            return null;
        }
        var text = Sys.getSystemStats().battery.format("%d");
        var size = dc.getTextDimensions("9999", Gfx.FONT_XTINY);
        var w = size[0] + 8;
        var h = size[1] + 4;

        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(radius - radius / 2 - w / 2, radius - h / 2, w, h, 3);

        dc.setColor(bdColor, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(radius - radius / 2 - w / 2 - 1, radius - h / 2 - 1, w + 2, h + 2, 3);

        dc.setColor(btColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(radius - radius / 2, radius, Gfx.FONT_XTINY, text, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawRectangle(text, color, position) {

        var size = dc.getTextDimensions("9999", Gfx.FONT_XTINY);
        var w = size[0] + 8;
        var h = size[1] + 4;

        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);

        x = y = 0;
        if (position == 3) {

        } else if (position == 6) {
        } else if (position == 9) {
        } else {
        }

        dc.fillRoundedRectangle(radius - radius / 2 - w / 2, radius - h / 2, w, h, 3);

        dc.setColor(bdColor, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(radius - radius / 2 - w / 2 - 1, radius - h / 2 - 1, w + 2, h + 2, 3);

        dc.setColor(btColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(radius - radius / 2, radius, Gfx.FONT_XTINY, text, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

    }

}

/*
class V3SimpleWatchFaceViewOld extends Ui.WatchFace {

    //hidden var settings;
    hidden var screenRadius, hh, mm;
    hidden var showHR, showSteps, showFloors, showBattery;
    hidden var dc;

    hidden var hhColor, mmColor, dtColor, hrColor, stColor, flColor, btColor, bgColor;
    hidden var hhFont, mmFont, dtFont, hrFont, stFont, flFont, btFont;

    hidden var hhPos, mmPos, dtPos, hrPos, stPos, flPos, btPos;

    function initialize() {
        WatchFace.initialize();

        me.bgColor = Gfx.COLOR_BLACK;//App.getApp().getProperty("BackgroundColor")
        me.hhColor = Gfx.COLOR_LT_GRAY;
        me.mmColor = Gfx.COLOR_LT_GRAY;
        me.dtColor = Gfx.COLOR_ORANGE;
        me.hrColor = Gfx.COLOR_RED;
        me.stColor = Gfx.COLOR_DK_GREEN;
        me.flColor = Gfx.COLOR_DK_BLUE;
        me.btColor = Gfx.COLOR_PURPLE;

        me.hhFont = Gfx.FONT_NUMBER_THAI_HOT;
        me.mmFont = Gfx.FONT_NUMBER_MILD;
        me.dtFont = Gfx.FONT_SYSTEM_XTINY;
        me.hrFont = Gfx.FONT_SYSTEM_XTINY;
        me.stFont = Gfx.FONT_SYSTEM_XTINY;
        me.flFont = Gfx.FONT_SYSTEM_XTINY;
        me.btFont = Gfx.FONT_SYSTEM_XTINY;


        //var settings = Sys.getDeviceSettings();
        //me.screenRadius = Math.floor(dc.screenHeight / 2);
    }

    // Load your resources here
    function onLayout(dc) {
        //setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {

        me.dc = dc;
        me.screenRadius = Math.floor(dc.getWidth() / 2);

        var time = Sys.getClockTime();
        me.hh = time.hour;
        me.mm = time.min;

        me.drawBackground();

        me.hhPos = me.drawHour();
        me.mmPos = me.drawMinute();
        me.dtPos = me.drawDate();
        me.hrPos = me.drawHR();
        me.stPos = me.drawSteps();
        me.flPos = me.drawFloors();
        me.btPos = me.drawBattery();

    }

    function onPartialUpdate(dc) {
        me.dc = dc;
        me.hrPos = me.drawHR();
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        me.showHR = true;
        me.showBattery = true;
        me.showFloors = true;
        me.showSteps = true;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
        me.showHR = false;
        me.showBattery = false;
        me.showFloors = false;
        me.showSteps = false;
    }

    hidden function drawBackground() {
        me.dc.setColor(Gfx.COLOR_TRANSPARENT, me.bgColor);
        me.dc.clear();
    }

    hidden function drawHour() {
        return me.drawText(
            me.screenRadius,
            me.screenRadius,
            me.hh.format("%02d"),
            me.hhFont,
            me.hhColor
        );
    }

    hidden function drawMinute() {
        var text = me.mm.format("%02d");
        var position = me.getMinutePosition(
            me.mm,
            text,
            me.screenRadius,
            me.mmFont
        );
        return me.drawText(
            position[0] + me.screenRadius,
            position[1] + me.screenRadius,
            text,
            me.mmFont,
            me.mmColor
        );
    }

    hidden function drawDate() {
        var date = Greg.info(Time.now(), Time.FORMAT_MEDIUM);
        var sizeDD = me.dc.getTextDimensions(date.day + "", me.dtFont);
        var sizeDW = me.dc.getTextDimensions(date.day_of_week + "", me.dtFont);
        if (me.mm >= 52 || me.mm <= 7 || me.mm >= 23 && me.mm <= 37) {
            me.drawText(
                me.screenRadius - me.hhPos[2] / 2 - sizeDW[0] / 2 - 2,
                me.screenRadius,
                date.day_of_week + "",
                me.dtFont,
                me.dtColor
            );
            me.drawText(
                me.screenRadius + me.hhPos[2] / 2 + sizeDD[0] / 2 + 2,
                me.screenRadius,
                date.day + "",
                me.dtFont,
                me.dtColor
            );
            return null;
        } else {
            return me.drawText(
                me.screenRadius,
                me.screenRadius + me.hhPos[3] / 2 + sizeDW[1] / 2 + 2,
                date.day_of_week + " " + date.day,
                me.dtFont,
                me.dtColor
            );
        }
    }

    hidden function drawBattery() {
        if (me.showBattery != true) {
            return null;
        }
        var battery = Sys.getSystemStats().battery;
        var text = battery.format("%d") + "%";
        var position = me.getMinutePosition(
            me.mm + 30,
            text,
            me.screenRadius * 3 / 5,
            me.btFont
        );
        return me.drawText(
            position[0] + me.screenRadius,
            position[1] + me.screenRadius,
            text,
            me.btFont,
            me.btColor
        );

    }

    hidden function drawHR() {
        if (me.showHR != true) {
            return null;
        }
        var hr = Activity.getActivityInfo().currentHeartRate;
        if (hr == null || hr == Monitor.INVALID_HR_SAMPLE) {
            hr = Monitor.getHeartRateHistory(1, true).next().heartRate;
        }
        var text = ((hr == null || hr == Monitor.INVALID_HR_SAMPLE) ? "00" : hr.format("%d"));
        var position = me.getMinutePosition(
            me.mm + 30,
            text,
            me.screenRadius,
            me.hrFont
        );
        return me.drawText(
            position[0] + me.screenRadius,
            position[1] + me.screenRadius,
            text,
            me.hrFont,
            me.hrColor
        );
    }

    hidden function drawSteps() {
        if (me.showSteps != true) {
            return null;
        }
        var steps = Monitor.getInfo().steps;
        var text = ((steps == null) ? "0" : ((steps < 1000) ? steps.format("%d") : ((steps / 1000.0).format("%.1f")) + "k"));
        var position = me.getMinutePosition(
            me.mm + 33,
            text,
            me.screenRadius * 7 / 8,
            me.stFont
        );
        return me.drawText(
            position[0] + me.screenRadius,
            position[1] + me.screenRadius,
            text,
            me.stFont,
            me.stColor
        );
    }

    hidden function drawFloors() {
        if (me.showFloors != true) {
            return null;
        }
        var floors = Monitor.getInfo().floorsClimbed;
        var text = floors == null ? "0" : floors.format("%d");
        var position = me.getMinutePosition(
            me.mm + 27,
            text,
            me.screenRadius * 7 / 8,
            me.flFont
        );
        return me.drawText(
            position[0] + me.screenRadius,
            position[1] + me.screenRadius,
            text,
            me.flFont,
            me.flColor
        );
    }

    hidden function drawText(x, y, text, font, color) {
        var size = me.dc.getTextDimensions(text + "", font);
        me.dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        me.dc.drawText(
            x, y, font, text, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER
        );
        return [x, y, size[0], size[1]];
    }

    hidden function getMinutePosition(minute, text, radius, font) {
        var textSize = me.dc.getTextDimensions(text + "", font);
        return me.minutePosition(minute, textSize, radius);
    }

    hidden function minutePosition(minute, textSize, radius) {
        var radian = Math.toRadians(minute * 6 + 270); // 270 = strange degrees offset of Garmin round display

        // get the offset to substract from the screen radius so that the text could be drawn centered to the point
        var radiusOffset = Math.ceil(Math.sqrt(Math.pow((textSize[0] / 2), 2) + Math.pow((textSize[1] / 2), 2)));

        return [
            Math.floor((radius - radiusOffset) * Math.cos(radian)),
            Math.floor((radius - radiusOffset) * Math.sin(radian))
        ];
    }
}*/
