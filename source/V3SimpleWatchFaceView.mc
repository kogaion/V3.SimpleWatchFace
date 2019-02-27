using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time.Gregorian as Greg;
using Toybox.ActivityMonitor as Mon;
using Toybox.Activity as Act;
using Toybox.Math as Math;
using Toybox.Application as App;


var partialUpdatesAllowed = false;

// This implements an analog watch face
// Original design by Austen Harbour
class V3SimpleWatchFaceView extends Ui.WatchFace
{   
    var isAwake;
    var offscreenBuffer;
    var dateBuffer;
    var screenCenterPoint;
    var fullScreenRefresh;
    
    var fgColor, bgColor, bdColor, ticksColor, handColor;  

    // Initialize variables for this view
    function initialize() 
    {
        WatchFace.initialize();
        fullScreenRefresh = true;
        partialUpdatesAllowed = (Toybox.WatchUi.WatchFace has :onPartialUpdate);
        
        fgColor = Gfx.COLOR_WHITE;
        bgColor = Gfx.COLOR_BLACK;
        ticksColor = Gfx.COLOR_YELLOW;
        handColor = Gfx.COLOR_ORANGE;
        bdColor = Gfx.COLOR_LT_GRAY;
    }
    
    // This method is called when the device re-enters sleep mode.
    // Set the isAwake flag to let onUpdate know it should stop rendering the second hand.
    function onEnterSleep() 
    {
        isAwake = false;
        WatchUi.requestUpdate();
    }

    // This method is called when the device exits sleep mode.
    // Set the isAwake flag to let onUpdate know it should render the second hand.
    function onExitSleep() 
    {
        isAwake = true;
    }

    // Configure the layout of the watchface for this device
    function onLayout(dc) 
    {
    	offscreenBuffer = null;
    	dateBuffer = null;

        // If this device supports BufferedBitmap, allocate the buffers we use for drawing
        if(Gfx has :BufferedBitmap) {
            // Allocate a full screen size buffer with a palette of only 4 colors to draw
            // the background image of the watchface.  This is used to facilitate blanking
            // the second hand during partial updates of the display
            offscreenBuffer = new Gfx.BufferedBitmap({
                :width => dc.getWidth(),
                :height => dc.getHeight(),
                :palette => [
                    bgColor,
                    fgColor,
                    bdColor,
                    ticksColor,
                    handColor
                ]
            });

            // Allocate a buffer tall enough to draw the date into the full width of the
            // screen. This buffer is also used for blanking the second hand. This full
            // color buffer is needed because anti-aliased fonts cannot be drawn into
            // a buffer with a reduced color palette
            dateBuffer = new Gfx.BufferedBitmap({
                :width => dc.getTextWidthInPixels("99", Gfx.FONT_XTINY),
                :height => Gfx.getFontHeight(Gfx.FONT_XTINY)
            });
        } 

        screenCenterPoint = [dc.getWidth() / 2, dc.getHeight() / 2];
    }

    // Handle the update event
    function onUpdate(dc) 
    {
        var width, height;
        var targetDc = null;
        
		// We always want to refresh the full screen when we get a regular onUpdate call.
        fullScreenRefresh = true;

        if (null != offscreenBuffer) {
            dc.clearClip();
            // If we have an offscreen buffer that we are using to draw the background,
            // set the draw context of that buffer as our target.
            targetDc = offscreenBuffer.getDc();
        } else {
            targetDc = dc;
        }

        width = targetDc.getWidth();
        height = targetDc.getHeight();

        // Fill the entire background with Black.
        //targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        //targetDc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());
        targetDc.setColor(Gfx.COLOR_TRANSPARENT, bgColor);
        targetDc.clear();       

        // Draw the tick marks around the edges of the screen
        drawHoursTicks(targetDc);
        drawHoursHand(targetDc);
        drawMinutesHand(targetDc);
        drawCenter(targetDc);
       
        // If we have an offscreen buffer that we are using for the date string,
        // Draw the date into it. If we do not, the date will get drawn every update
        // after blanking the second hand.
        if( null != dateBuffer ) {
            var dateDc = dateBuffer.getDc();

            //Draw the background image buffer into the date buffer to set the background
            dateDc.drawBitmap(0, -(height / 4), offscreenBuffer);

            //Draw the date string into the buffer.
            drawDateString( dateDc, width / 2, 0 );
        }

        // Output the offscreen buffers to the main display if required.
        drawBackground(dc);

        // Draw the battery percentage directly to the main screen.
        var dataString = (System.getSystemStats().battery + 0.5).toNumber().toString() + "%";       
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
//        dc.drawText(width / 2, 3*height/4, Graphics.FONT_TINY, dataString, Graphics.TEXT_JUSTIFY_CENTER);

        if (partialUpdatesAllowed) {
            // If this device supports partial updates and they are currently
            // allowed run the onPartialUpdate method to draw the second hand.
            onPartialUpdate(dc);
        } else if (isAwake) {
            // Otherwise, if we are out of sleep mode, draw the second hand
            // directly in the full update method.
            drawSecondsHand(dc);
        }

        fullScreenRefresh = false;
    }


    // Handle the partial update event
    function onPartialUpdate(dc) 
    {
        // If we're not doing a full screen refresh we need to re-draw the background
        // before drawing the updated second hand position. Note this will only re-draw
        // the background in the area specified by the previously computed clipping region.
        if(!fullScreenRefresh) {
            drawBackground(dc);
        }

        // Update the cliping rectangle to the new location of the second hand.
        var secondsHand = getSecondsHand();
        var curClip = getBoundingBox(secondsHand);
        var bboxWidth = curClip[1][0] - curClip[0][0] + 1;
        var bboxHeight = curClip[1][1] - curClip[0][1] + 1;
        dc.setClip(curClip[0][0], curClip[0][1], bboxWidth, bboxHeight);
        
        dc.setColor(handColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon(secondsHand);
    }
    
    // Draws the clock tick marks around the outside edges of the screen.
    function drawHoursTicks(dc) 
    {
    	var width = dc.getWidth();
        var height = dc.getHeight();
        
        var sX, sY;
        var eX, eY;
        var outerRad = width / 2;
        var innerRad = outerRad - 10;
            
        // Loop through each 15 minute block and draw tick marks.
        for (var i = 0; i < 12; i += 1) {
            // Partially unrolled loop to draw two tickmarks in 15 minute block.
            
            var radians = Math.PI / 6 * i;
            
            sY = outerRad + innerRad * Math.sin(radians);
            eY = outerRad + outerRad * Math.sin(radians);
            sX = outerRad + innerRad * Math.cos(radians);
            eX = outerRad + outerRad * Math.cos(radians);
            
            dc.setPenWidth(2);
            dc.setColor(i % 3 == 0 ? ticksColor : fgColor, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(sX, sY, eX, eY);
        }    
    }
    
    function drawHoursHand(dc)
    {
    	var clockTime = Sys.getClockTime();
    	var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
        hourHandAngle = hourHandAngle / (12 * 60.0);
        hourHandAngle = hourHandAngle * Math.PI * 2;

		dc.setColor(ticksColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon(
        	generateHandCoordinates(
        		screenCenterPoint, 
        		hourHandAngle, 
        		screenCenterPoint[0] * 3 / 5, 
        		0, 
        		3
        	)
        );
    }
    
    function drawMinutesHand(dc)
    {
    	var clockTime = Sys.getClockTime();
    	var minHandAngle = (clockTime.min / 60.0) * Math.PI * 2;

		dc.setColor(ticksColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon(
        	generateHandCoordinates(
        		screenCenterPoint, 
        		minHandAngle, 
        		screenCenterPoint[0] - 17, 
        		0, 
        		2
        	)
        );
    }
    
    function drawSecondsHand(dc)
    {
    	dc.setColor(handColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon(
        	getSecondsHand()
        );
    }
    
    function getSecondsHand()
    {
    	var clockTime = Sys.getClockTime();
    	var secHandAngle = (clockTime.sec / 60.0) * Math.PI * 2;
    	
    	return generateHandCoordinates(
			screenCenterPoint, 
			secHandAngle, 
			screenCenterPoint[0] - 15, 
			20, 
			1
		);
    }
    
    function drawCenter(dc)
    {
    	// draw center circle
        dc.setPenWidth(3);
        dc.setColor(handColor, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(screenCenterPoint[0], screenCenterPoint[1], 6);
        dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(screenCenterPoint[0], screenCenterPoint[1], 4);
    }
    

    

    // Draw the watch face background
    // onUpdate uses this method to transfer newly rendered Buffered Bitmaps
    // to the main display.
    // onPartialUpdate uses this to blank the second hand from the previous
    // second before outputing the new one.
    function drawBackground(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        //If we have an offscreen buffer that has been written to
        //draw it to the screen.
        if( null != offscreenBuffer ) {
            dc.drawBitmap(0, 0, offscreenBuffer);
        }

        // Draw the date
        if( null != dateBuffer ) {
            // If the date is saved in a Buffered Bitmap, just copy it from there.
            dc.drawBitmap(0, (height / 4), dateBuffer );
        } else {
            // Otherwise, draw it from scratch.
            drawDateString( dc, width / 2, height / 4 );
        }
    }
    
    // Draw the date string into the provided buffer at the specified location
    hidden function drawDateString( dc, x, y ) {
        var info = Greg.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    
    
    // This function is used to generate the coordinates of the 4 corners of the polygon
    // used to draw a watch hand. The coordinates are generated with specified length,
    // tail length, and width and rotated around the center point at the provided angle.
    // 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    hidden function generateHandCoordinates(centerPoint, angle, handLength, tailLength, width) {
        // Map out the coordinates of the watch hand
        var coords = [[-(width / 2), tailLength], [-(width / 2), -handLength], [width / 2, -handLength], [width / 2, tailLength]];
        var result = new [4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < 4; i += 1) {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin) + 0.5;
            var y = (coords[i][0] * sin) + (coords[i][1] * cos) + 0.5;

            result[i] = [centerPoint[0] + x, centerPoint[1] + y];
        }

        return result;
    }
    
    // Compute a bounding box from the passed in points
    hidden function getBoundingBox( points ) {
        var min = [9999,9999];
        var max = [0,0];

        for (var i = 0; i < points.size(); ++i) {
            if(points[i][0] < min[0]) {
                min[0] = points[i][0];
            }

            if(points[i][1] < min[1]) {
                min[1] = points[i][1];
            }

            if(points[i][0] > max[0]) {
                max[0] = points[i][0];
            }

            if(points[i][1] > max[1]) {
                max[1] = points[i][1];
            }
        }

        return [min, max];
    }
}

class V3SimpleWatchFaceDelegate extends Ui.WatchFaceDelegate {
    // The onPowerBudgetExceeded callback is called by the system if the
    // onPartialUpdate method exceeds the allowed power budget. If this occurs,
    // the system will stop invoking onPartialUpdate each second, so we set the
    // partialUpdatesAllowed flag here to let the rendering methods know they
    // should not be rendering a second hand.
    function onPowerBudgetExceeded(powerInfo) {
        System.println( "Average execution time: " + powerInfo.executionTimeAverage );
        System.println( "Allowed execution time: " + powerInfo.executionTimeLimit );
        partialUpdatesAllowed = false;
    }
}




class V3SimpleWatchFaceViewOld extends Ui.WatchFace {

    hidden var radius;
    
    hidden var fgColor, bgColor, bdColor, hrColor, btColor, stColor, flColor, ihColor, imColor, isColor, hhColor;
    
    hidden var fullScreenRefresh;
    hidden var centerPoint;
    hidden var partialUpdatesAllowed;
    hidden var offscreenBuffer, dateBuffer;
    hidden var active;

    function initialize() 
    {
        WatchFace.initialize();
        
        partialUpdatesAllowed = Ui.WatchFace has :onPartialUpdate;

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
        flColor = Gfx.COLOR_PURPLE;
    }

    function onLayout(dc) 
    {
    	fullScreenRefresh = true;
    	centerPoint = [dc.getWidth() / 2, dc.getHeight() / 2];
    	
    	offscreenBuffer = null;
    	dateBuffer = null;
    	
    	if (Gfx has :BufferedBitmap) {
    		offscreenBuffer = new Gfx.BufferedBitmap({
                :width => dc.getWidth(),
                :height => dc.getHeight(),
                :palette => [
                	bgColor,
                	fgColor,
                	ihColor,
                	hhColor
                ]
            });
            
            dateBuffer = new Gfx.BufferedBitmap({
                :width => dc.getWidth(),//dc.getTextWidthInPixels("99", Gfx.FONT_XTINY), // the date contains 2 digits
                :height => Gfx.getFontHeight(Gfx.FONT_XTINY)
            });
    	}
    }
    
    hidden function getDc(dc)
    {
    	// If we have an offscreen buffer that we are using to draw the background,
        // set the draw context of that buffer as our target.
    	if (null != offscreenBuffer) {
			dc.clearClip();
			return offscreenBuffer.getDc(); 
		} 
		return dc;
    }
    
    function onUpdate(dc) 
    {
    	var width, height;
    
    	fullScreenRefresh = true;
    	
    	dc = getDc(dc);
    	    	
    	width = dc.getWidth();
        height = dc.getHeight();
    	
		// Fill the entire background with Black.
		dc.setColor(Gfx.COLOR_TRANSPARENT, bgColor);
        dc.clear();
//        targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
//        targetDc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

        drawHourMarks(dc);
        
        drawMinutesHand(dc);
        drawHourHand(dc);
        drawCenter(dc);
        
        if( null != dateBuffer ) {
            var dateDc = dateBuffer.getDc();

            //Draw the background image buffer into the date buffer to set the background
            dateDc.drawBitmap(0, -(height / 4), offscreenBuffer);

            //Draw the date string into the buffer.
            drawDate(dateDc);
        }
        
        drawBackground(dc);
        
        if (partialUpdatesAllowed) {
            // If this device supports partial updates and they are currently
            // allowed run the onPartialUpdate method to draw the second hand.
            onPartialUpdate(dc);
        } else if (active) {
            // Otherwise, if we are out of sleep mode, draw the second hand
            // directly in the full update method.
            drawSecondsHand(dc);
        }

        fullScreenRefresh = false;

        
    }
    

    function onPartialUpdate(dc) 
    {
    	if (!fullScreenRefresh) {
            drawBackground(dc);
        }
        
        var clockTime = System.getClockTime();
        var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;
        var secondHandPoints = generateHandCoordinates(centerPoint, secondHand, 60, 20, 2);
        
        var curClip = getBoundingBox( secondHandPoints );
        var bboxWidth = curClip[1][0] - curClip[0][0] + 1;
        var bboxHeight = curClip[1][1] - curClip[0][1] + 1;
        dc.setClip(curClip[0][0], curClip[0][1], bboxWidth, bboxHeight);
        
        drawSecondsHand(dc);
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
    
    // Compute a bounding box from the passed in points
    hidden function getBoundingBox( points ) {
        var min = [9999,9999];
        var max = [0,0];

        for (var i = 0; i < points.size(); ++i) {
            if(points[i][0] < min[0]) {
                min[0] = points[i][0];
            }

            if(points[i][1] < min[1]) {
                min[1] = points[i][1];
            }

            if(points[i][0] > max[0]) {
                max[0] = points[i][0];
            }

            if(points[i][1] > max[1]) {
                max[1] = points[i][1];
            }
        }

        return [min, max];
    }

    
    hidden function drawBackground(dc) {
    
    	var width = dc.getWidth();
        var height = dc.getHeight();

        //If we have an offscreen buffer that has been written to
        //draw it to the screen.
        if( null != offscreenBuffer ) {
            dc.drawBitmap(0, 0, offscreenBuffer);
        }

        // Draw the date
        if( null != dateBuffer ) {
            // If the date is saved in a Buffered Bitmap, just copy it from there.
            dc.drawBitmap(0, (height / 4), dateBuffer );
        } else {
            // Otherwise, draw it from scratch.
            drawDate(dc);
        }
    	
    }

    hidden function drawDate(dc) 
    {
    	var text = Greg.info(Time.now(), Time.FORMAT_SHORT).day.format("%d");
        drawRectangle(dc, text, bgColor, [centerPoint[0] * 3/2, centerPoint[1]]);
    }

    hidden function drawHeartRate() {
        if (active != true) {
            return ;
        }
        var hr = Act.getActivityInfo().currentHeartRate;
        if (hr == null || hr == Mon.INVALID_HR_SAMPLE) {
            hr = Mon.getHeartRateHistory(1, true).next().heartRate;
        }
        if (hr == null || hr == Mon.INVALID_HR_SAMPLE) {
            return ;
        }
        var text = hr.format("%d");

        drawRectangle(text, hrColor, 0);
    }

    hidden function drawSteps() {
        if (active != true) {
            return ;
        }
        var steps = Mon.getInfo().steps;
        var text = ((steps == null) ? "0" : ((steps < 1000) ? steps.format("%d") : ((steps / 1000.0).format("%.1f")) + "k"));

        drawRectangle(text, stColor, 9);
    }

    hidden function drawBattery() {
        if (active != true) {
            return ;
        }
        var text = Sys.getSystemStats().battery.format("%d");

        drawRectangle(text, btColor, 6);
    }

    hidden function drawFloors() {
        if (active != true) {
            return ;
        }
        var text = Mon.getInfo().floorsClimbed.format("%d");

        drawRectangle(text, flColor, 3);
    }

    hidden function drawRectangle(dc, text, color, position) {
    
    	var size = dc.getTextDimensions("9999", Gfx.FONT_XTINY);
        var w = size[0] + 8;
        var h = size[1] + 4;

        var tx = position[0];
        var ty = position[1];

        if (position == 3) {
            tx = radius + radius / 2;
            ty = radius;
        } else if (position == 6) {
            tx = radius;
            ty = radius * 3 / 2;
        } else if (position == 9) {
            tx = radius - radius / 2;
            ty = radius;
        } else if (position == 0) {
            tx = radius;
            ty = radius / 2;
        } else {
            return ;
        }

        var x = tx - w / 2;
        var y = ty - h / 2;

        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 3);

        dc.setColor(bdColor, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x - 1, y - 1, w + 2, h + 2, 3);

        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(tx, ty, Gfx.FONT_XTINY, text, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

    }
    
    hidden function generateHandCoordinates(centerPoint, angle, handLength, tailLength, width) 
    {
        // Map out the coordinates of the watch hand
        var coords = [[-(width / 2), tailLength], [-(width / 2), -handLength], [width / 2, -handLength], [width / 2, tailLength]];
        var result = new [4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < 4; i += 1) {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin) + 0.5;
            var y = (coords[i][0] * sin) + (coords[i][1] * cos) + 0.5;

            result[i] = [centerPoint[0] + x, centerPoint[1] + y];
        }

        return result;
    }
    
    hidden function drawHourMarks(dc) 
    {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        var sX, sY;
        var eX, eY;
        var outerRad = width / 2;
        var innerRad = outerRad - 10;
            
        // Loop through each 15 minute block and draw tick marks.
        for (var i = 0; i < 12; i += 1) {
            // Partially unrolled loop to draw two tickmarks in 15 minute block.
            
            var radians = Math.PI / 6 * i;
            
            sY = outerRad + innerRad * Math.sin(radians);
            eY = outerRad + outerRad * Math.sin(radians);
            sX = outerRad + innerRad * Math.cos(radians);
            eX = outerRad + outerRad * Math.cos(radians);
            
            dc.setPenWidth(2);
            dc.setColor(i % 3 == 0 ? hhColor : fgColor, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(sX, sY, eX, eY);
        }
    }
    
    hidden function drawHourHand(dc)
    {
    	var clockTime = Sys.getClockTime();
    	var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
        hourHandAngle = hourHandAngle / (12 * 60.0);
        hourHandAngle = hourHandAngle * Math.PI * 2;

		dc.setColor(ihColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon(
        	generateHandCoordinates(
        		centerPoint, 
        		hourHandAngle, 
        		centerPoint[0] * 3 / 5, 
        		0, 
        		3
        	)
        );
    }
    
    hidden function drawMinutesHand(dc)
    {
    	var clockTime = Sys.getClockTime();
    	var minHandAngle = (clockTime.min / 60.0) * Math.PI * 2;

		dc.setColor(imColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon(
        	generateHandCoordinates(
        		centerPoint, 
        		minHandAngle, 
        		centerPoint[0] - 17, 
        		0, 
        		2
        	)
        );
    }
    
    hidden function drawSecondsHand(dc)
    {
    	var clockTime = Sys.getClockTime();
    	var secHandAngle = (clockTime.sec / 60.0) * Math.PI * 2;
    	
    	dc.setColor(isColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon(
        	generateHandCoordinates(
        		centerPoint, 
        		secHandAngle, 
        		centerPoint[0] - 15, 
        		20, 
        		1
        	)
        );
    }
    
    hidden function drawCenter(dc)
    {
    	// draw center circle
        dc.setPenWidth(3);
        dc.setColor(active ? isColor : fgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(centerPoint[0], centerPoint[1], 6);
        dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(centerPoint[0], centerPoint[1], 4);
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
